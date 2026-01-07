/**
 * DYNAMIC PARTITION PROCESSOR
 * Partitions based on ExternalId ranges, not fixed offsets
 * Queries Data Cloud to get min/max ExternalId, divides into 10 ranges
 */
public class DynamicPartitionProcessor implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    
    public Integer currentOffset = 0;
    public Integer totalProcessed = 0;
    public Integer totalBulkAPICalls = 0;
    public Integer partitionId = -1;
    public String partitionName = 'DynamicPartition';
    public String rangeStart;  // ExternalId range start
    public String rangeEnd;    // ExternalId range end
    
    private static final Integer RECORDS_PER_BATCH = 2000;
    
    // Constructor for dynamic partitioning
    public DynamicPartitionProcessor(Integer pId, String pName, String start, String endVal) {
        this.partitionId = pId;
        this.partitionName = pName;
        this.rangeStart = start;
        this.rangeEnd = endVal;
        this.currentOffset = 0;
        this.totalProcessed = 0;
        this.totalBulkAPICalls = 0;
    }
    
    public List<Integer> start(Database.BatchableContext context) {
        System.debug('START ' + partitionName + ' - Range: ' + rangeStart + ' to ' + rangeEnd);
        return new List<Integer>{1};
    }
    
    public void execute(Database.BatchableContext context, List<Integer> scope) {
        try {
            // Query Data Cloud with ExternalId range filter
            String sqlQuery = 
                'SELECT "ExternalId__c", "stagename__c", "Amount__c", "Account__c", "Name__c", "CloseDate__c" ' +
                'FROM "ExtOpportunities__dlm" ' +
                'WHERE "ExternalId__c" >= \'' + rangeStart + '\' ' +
                'AND "ExternalId__c" <= \'' + rangeEnd + '\' ' +
                'ORDER BY "ExternalId__c" ' +
                'LIMIT ' + RECORDS_PER_BATCH + ' ' +
                'OFFSET ' + currentOffset;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                System.debug(partitionName + ': No more data at offset ' + currentOffset);
                // Don't increment anything, finish() will see totalBulkAPICalls and stop
                return;
            }
            
            Integer rowCount = queryOutput.data.size();
            
            // Process rows
            List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
                new List<OpportunityBulkAPIUploader.OpportunityData>();
            
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
                    }
                } catch (Exception e) {
                    System.debug('Error parsing row: ' + e.getMessage());
                }
            }
            
            // Send to Bulk API (only if we have data)
            if (!oppDataList.isEmpty()) {
                makeBulkAPICall(oppDataList);
                totalBulkAPICalls++;
                totalProcessed += rowCount;
                currentOffset += rowCount;
            } else {
                // Parsed 0 records, but queried some - likely all parse errors
                // Still increment offset to avoid infinite loop
                currentOffset += rowCount;
            }
            
            // Log every 10 batches
            if (Math.mod(totalBulkAPICalls, 10) == 0 && totalBulkAPICalls > 0) {
                System.debug(partitionName + ': ' + totalProcessed + ' records, ' + totalBulkAPICalls + ' API calls, offset=' + currentOffset);
            }
            
        } catch (Exception e) {
            System.debug('ERROR in ' + partitionName + ' at offset ' + currentOffset + ': ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('FINISH ' + partitionName + ' - Total: ' + totalProcessed + ', Offset: ' + currentOffset);
        
        // Update progress
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
            
            progress.CurrentOffset__c = currentOffset;
            progress.TotalProcessed__c = totalProcessed;
            progress.TotalBulkAPICalls__c = totalBulkAPICalls;
            
            // Always self-schedule unless we hit the iteration limit or no records processed
            // Don't rely on checking Data Cloud again (can timeout)
            Boolean shouldContinue = true;
            
            // Stop conditions:
            // 1. If we processed 0 records in this batch (means we're done)
            // 2. If we've done more than 500 batches (safety limit)
            if (totalBulkAPICalls == 0) {
                shouldContinue = false;
                System.debug('⚠️ ' + partitionName + ' stopping: no records processed');
            } else if (totalBulkAPICalls >= 500) {
                shouldContinue = false;
                System.debug('⚠️ ' + partitionName + ' stopping: hit 500 batch limit');
            }
            
            if (shouldContinue) {
                // More records likely exist, self-schedule
                progress.Status__c = 'Running';
                upsert progress;
                
                DynamicPartitionProcessor nextBatch = new DynamicPartitionProcessor(
                    partitionId, partitionName, rangeStart, rangeEnd
                );
                nextBatch.currentOffset = this.currentOffset;
                nextBatch.totalProcessed = this.totalProcessed;
                nextBatch.totalBulkAPICalls = this.totalBulkAPICalls;
                
                Database.executeBatch(nextBatch, 1);
                System.debug('✓ ' + partitionName + ' next batch scheduled (offset: ' + currentOffset + ')');
            } else {
                // Complete
                progress.Status__c = 'Completed';
                upsert progress;
                System.debug('=== ' + partitionName + ' COMPLETE ===');
            }
            
        } catch (Exception e) {
            System.debug('ERROR in finish: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
    
    // Helper methods (same as DataCloudBatchProcessor)
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

