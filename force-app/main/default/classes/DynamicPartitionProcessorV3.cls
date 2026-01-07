/**
 * OPTION 3: DELAYED PARALLEL PROCESSING
 * 
 * This version adds delays between batch executions to avoid lock contention
 * while still processing in parallel (but staggered)
 */
public class DynamicPartitionProcessorV3 implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    
    public Integer totalProcessed = 0;
    public Integer totalBulkAPICalls = 0;
    public Integer partitionId = -1;
    public String partitionName = 'DynamicPartition';
    public String rangeStart;
    public String rangeEnd;
    public String lastProcessedId;
    public Integer consecutiveEmptyBatches = 0;
    
    private static final Integer RECORDS_PER_BATCH = 2000;
    private static final Integer MAX_EMPTY_BATCHES = 3;
    private static final Integer MAX_BATCHES = 500;
    private static final Integer DELAY_SECONDS = 60; // 60 second delay between batches
    
    public DynamicPartitionProcessorV3(Integer pId, String pName, String start, String endVal) {
        this.partitionId = pId;
        this.partitionName = pName;
        this.rangeStart = start;
        this.rangeEnd = endVal;
        this.lastProcessedId = start;
        this.totalProcessed = 0;
        this.totalBulkAPICalls = 0;
        this.consecutiveEmptyBatches = 0;
    }
    
    public List<Integer> start(Database.BatchableContext context) {
        System.debug('START ' + partitionName + ' - Range: ' + rangeStart + ' to ' + rangeEnd);
        return new List<Integer>{1};
    }
    
    public void execute(Database.BatchableContext context, List<Integer> scope) {
        try {
            String sqlQuery = 
                'SELECT "ExternalId__c", "stagename__c", "Amount__c", "Account__c", "Name__c", "CloseDate__c" ' +
                'FROM "ExtOpportunities__dlm" ' +
                'WHERE "ExternalId__c" > \'' + lastProcessedId + '\' ' +
                'AND "ExternalId__c" <= \'' + rangeEnd + '\' ' +
                'ORDER BY "ExternalId__c" ' +
                'LIMIT ' + RECORDS_PER_BATCH;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                consecutiveEmptyBatches++;
                System.debug(partitionName + ': No more data after ' + lastProcessedId);
                return;
            }
            
            consecutiveEmptyBatches = 0;
            
            List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
                new List<OpportunityBulkAPIUploader.OpportunityData>();
            String currentMaxId = lastProcessedId;
            
            for (ConnectApi.CdpQueryV2Row row : queryOutput.data) {
                try {
                    String rowJson = JSON.serialize(row);
                    List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
                    
                    if (values != null && values.size() >= 6) {
                        String externalId = (String) values[0];
                        String stageName = (String) values[1];
                        Decimal amount = values[2] != null ? Decimal.valueOf(String.valueOf(values[2])) : 0;
                        String accountId = (String) values[3];
                        String name = (String) values[4];
                        Date closeDate = parseCloseDate(values[5]);
                        
                        oppDataList.add(new OpportunityBulkAPIUploader.OpportunityData(
                            externalId, stageName, amount, accountId, name, closeDate
                        ));
                        
                        if (externalId.compareTo(currentMaxId) > 0) {
                            currentMaxId = externalId;
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error parsing row: ' + e.getMessage());
                }
            }
            
            lastProcessedId = currentMaxId;
            
            if (!oppDataList.isEmpty()) {
                makeBulkAPICall(oppDataList);
                totalBulkAPICalls++;
                totalProcessed += oppDataList.size();
            }
            
            if (Math.mod(totalBulkAPICalls, 10) == 0 && totalBulkAPICalls > 0) {
                System.debug(partitionName + ': ' + totalProcessed + ' records, ' + 
                           totalBulkAPICalls + ' API calls, lastId=' + lastProcessedId);
            }
            
        } catch (Exception e) {
            System.debug('ERROR in ' + partitionName + ': ' + e.getMessage());
            consecutiveEmptyBatches++;
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('FINISH ' + partitionName + ' - Processed: ' + totalProcessed);
        
        try {
            List<DataCloudPartition__c> progressList = [
                SELECT Id FROM DataCloudPartition__c
                WHERE Name = :partitionName LIMIT 1
            ];
            
            DataCloudPartition__c progress;
            if (progressList.isEmpty()) {
                progress = new DataCloudPartition__c(
                    Name = partitionName,
                    PartitionId__c = partitionId,
                    CurrentOffset__c = 0,
                    TotalProcessed__c = 0,
                    TotalBulkAPICalls__c = 0,
                    Status__c = 'Running'
                );
            } else {
                progress = progressList[0];
            }
            
            progress.TotalProcessed__c = totalProcessed;
            progress.TotalBulkAPICalls__c = totalBulkAPICalls;
            
            Boolean shouldContinue = true;
            
            if (consecutiveEmptyBatches >= MAX_EMPTY_BATCHES) {
                shouldContinue = false;
                System.debug('⏹️ ' + partitionName + ' stopping: empty batches');
            } else if (totalBulkAPICalls >= MAX_BATCHES) {
                shouldContinue = false;
                System.debug('⏹️ ' + partitionName + ' stopping: batch limit');
            } else if (lastProcessedId.compareTo(rangeEnd) >= 0) {
                shouldContinue = false;
                System.debug('⏹️ ' + partitionName + ' stopping: reached end');
            }
            
            if (shouldContinue) {
                progress.Status__c = 'Running';
                upsert progress;
                
                // SCHEDULE NEXT BATCH WITH DELAY (instead of immediate execution)
                Datetime nextRun = System.now().addSeconds(DELAY_SECONDS);
                String cronExp = nextRun.second() + ' ' + 
                               nextRun.minute() + ' ' + 
                               nextRun.hour() + ' ' + 
                               nextRun.day() + ' ' + 
                               nextRun.month() + ' ? ' + 
                               nextRun.year();
                
                // Create a schedulable wrapper
                String jobName = partitionName + '_' + System.now().getTime();
                System.schedule(jobName, cronExp, new DelayedBatchStarterV3(
                    partitionId, partitionName, rangeStart, rangeEnd,
                    lastProcessedId, totalProcessed, totalBulkAPICalls, consecutiveEmptyBatches
                ));
                
                System.debug('✓ ' + partitionName + ' scheduled in ' + DELAY_SECONDS + ' seconds');
            } else {
                progress.Status__c = 'Completed';
                upsert progress;
                System.debug('✅ ' + partitionName + ' COMPLETE');
            }
            
        } catch (Exception e) {
            System.debug('ERROR in finish: ' + e.getMessage());
        }
    }
    
    // Same helper methods as V2
    private Date parseCloseDate(Object closeDateObj) {
        if (closeDateObj == null) return Date.today().addDays(30);
        try {
            String dateStr = String.valueOf(closeDateObj);
            if (dateStr.contains('-')) {
                List<String> parts = dateStr.split('-');
                if (parts.size() >= 3) {
                    Integer year = Integer.valueOf(parts[0]);
                    Integer month = Integer.valueOf(parts[1]);
                    String dayPart = parts[2].split('[\\s T]')[0];
                    Integer day = Integer.valueOf(dayPart);
                    return Date.newInstance(year, month, day);
                }
            }
        } catch (Exception e) {}
        return Date.today().addDays(30);
    }
    
    private void makeBulkAPICall(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        String csvContent = buildCSVContent(records);
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        
        String jobId = createBulkJob(sessionId, instanceUrl);
        if (String.isBlank(jobId)) return;
        
        uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        closeJob(sessionId, instanceUrl, jobId);
    }
    
    private String buildCSVContent(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        String csv = 'External_ID__c,Name,StageName,CloseDate,Amount,AccountId\n';
        for (OpportunityBulkAPIUploader.OpportunityData record : records) {
            csv += record.externalId + ',' +
                   escapeCsvField(record.name) + ',' +
                   escapeCsvField(record.stageName) + ',' +
                   String.valueOf(record.closeDate) + ',' +
                   record.amount + ',' +
                   record.accountId + '\n';
        }
        return csv;
    }
    
    private String escapeCsvField(String field) {
        if (field == null) return '';
        if (field.contains(',') || field.contains('"') || field.contains('\n')) {
            return '"' + field.replace('"', '""') + '"';
        }
        return field;
    }
    
    private String createBulkJob(String sessionId, String instanceUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"object":"Opportunity","externalIdFieldName":"External_ID__c","contentType":"CSV","operation":"upsert","lineEnding":"LF"}');
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('id');
        }
        return null;
    }
    
    private Boolean uploadDataToJob(String sessionId, String instanceUrl, String jobId, String csvContent) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId + '/batches');
        req.setMethod('PUT');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'text/csv');
        req.setBody(csvContent);
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        return res.getStatusCode() == 201;
    }
    
    private Boolean closeJob(String sessionId, String instanceUrl, String jobId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId);
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"state":"UploadComplete"}');
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        return res.getStatusCode() == 200;
    }
}

/**
 * Schedulable wrapper to start delayed batch
 */
public class DelayedBatchStarterV3 implements Schedulable {
    private Integer partitionId;
    private String partitionName;
    private String rangeStart;
    private String rangeEnd;
    private String lastProcessedId;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer consecutiveEmptyBatches;
    
    public DelayedBatchStarterV3(Integer pId, String pName, String start, String endVal,
                                  String lastId, Integer processed, Integer apiCalls, Integer emptyBatches) {
        this.partitionId = pId;
        this.partitionName = pName;
        this.rangeStart = start;
        this.rangeEnd = endVal;
        this.lastProcessedId = lastId;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = apiCalls;
        this.consecutiveEmptyBatches = emptyBatches;
    }
    
    public void execute(SchedulableContext context) {
        DynamicPartitionProcessorV3 nextBatch = new DynamicPartitionProcessorV3(
            partitionId, partitionName, rangeStart, rangeEnd
        );
        nextBatch.lastProcessedId = this.lastProcessedId;
        nextBatch.totalProcessed = this.totalProcessed;
        nextBatch.totalBulkAPICalls = this.totalBulkAPICalls;
        nextBatch.consecutiveEmptyBatches = this.consecutiveEmptyBatches;
        
        Database.executeBatch(nextBatch, 1);
    }
}




