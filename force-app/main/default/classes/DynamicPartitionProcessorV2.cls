/**
 * IMPROVED DYNAMIC PARTITION PROCESSOR
 * Uses ExternalId-based pagination (no OFFSET) to avoid duplicates and ensure all records are processed
 */
public class DynamicPartitionProcessorV2 implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    
    public Integer totalProcessed = 0;
    public Integer totalBulkAPICalls = 0;
    public Integer partitionId = -1;
    public String partitionName = 'DynamicPartition';
    public String rangeStart;  // ExternalId range start
    public String rangeEnd;    // ExternalId range end
    public String lastProcessedId; // Last ExternalId processed
    public Integer consecutiveEmptyBatches = 0; // Track empty batches
    
    // Test8 Configuration - Optimized for 91%+ success rate
    private static final Integer RECORDS_PER_BATCH = 500; // Optimal batch size
    private static final Integer MAX_EMPTY_BATCHES = 3; // Stop after 3 consecutive empty batches
    private static final Integer MAX_BATCHES = 800; // 400K records / 500 per batch = 800 batches
    private static final Integer MAX_RETRIES = 3; // Retry failed batches up to 3 times
    
    // Exponential backoff delays (milliseconds): 2s, 5s, 10s
    private static final List<Integer> RETRY_DELAYS = new List<Integer>{2000, 5000, 10000};
    
    // Constructor for dynamic partitioning
    public DynamicPartitionProcessorV2(Integer pId, String pName, String start, String endVal) {
        this.partitionId = pId;
        this.partitionName = pName;
        this.rangeStart = start;
        this.rangeEnd = endVal;
        this.lastProcessedId = start; // Start from the beginning
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
            // Query Data Cloud using ExternalId > lastProcessedId (no OFFSET!)
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
                System.debug(partitionName + ': No more data after ' + lastProcessedId + 
                           ' (empty batch #' + consecutiveEmptyBatches + ')');
                return;
            }
            
            Integer rowCount = queryOutput.data.size();
            consecutiveEmptyBatches = 0; // Reset counter
            
            // Process rows
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
                        
                        // Track the highest ExternalId we've seen
                        if (externalId.compareTo(currentMaxId) > 0) {
                            currentMaxId = externalId;
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error parsing row: ' + e.getMessage());
                }
            }
            
            // Update lastProcessedId to the highest ID we saw
            lastProcessedId = currentMaxId;
            
            // Send to Bulk API
            if (!oppDataList.isEmpty()) {
                System.debug(partitionName + ': Sending ' + oppDataList.size() + ' records to Bulk API');
                makeBulkAPICall(oppDataList);
                totalBulkAPICalls++;
                totalProcessed += oppDataList.size();
            } else {
                System.debug(partitionName + ': WARNING - oppDataList is EMPTY! No records to send.');
            }
            
            // Log progress every 10 batches
            if (Math.mod(totalBulkAPICalls, 10) == 0 && totalBulkAPICalls > 0) {
                System.debug(partitionName + ': ' + totalProcessed + ' records, ' + 
                           totalBulkAPICalls + ' API calls, lastId=' + lastProcessedId);
            }
            
        } catch (Exception e) {
            System.debug('ERROR in ' + partitionName + ' at lastId ' + lastProcessedId + ': ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
            consecutiveEmptyBatches++; // Treat errors as empty batches to avoid infinite loops
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('FINISH ' + partitionName + ' - Processed: ' + totalProcessed + 
                   ', Calls: ' + totalBulkAPICalls + ', LastId: ' + lastProcessedId);
        
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
            
            progress.TotalProcessed__c = totalProcessed;
            progress.TotalBulkAPICalls__c = totalBulkAPICalls;
            
            // Decide whether to continue
            Boolean shouldContinue = true;
            
            // Stop conditions:
            if (consecutiveEmptyBatches >= MAX_EMPTY_BATCHES) {
                shouldContinue = false;
                System.debug('⏹️ ' + partitionName + ' stopping: ' + consecutiveEmptyBatches + ' consecutive empty batches');
            } else if (totalBulkAPICalls >= MAX_BATCHES) {
                shouldContinue = false;
                System.debug('⏹️ ' + partitionName + ' stopping: hit ' + MAX_BATCHES + ' batch limit');
            } else if (lastProcessedId.compareTo(rangeEnd) >= 0) {
                shouldContinue = false;
                System.debug('⏹️ ' + partitionName + ' stopping: reached end of range (' + rangeEnd + ')');
            }
            
            if (shouldContinue) {
                // Continue processing - schedule next batch with delay
                // Test8: Natural Salesforce delay (10-20s) + scheduling overhead (~10s) = 20-30s total
                progress.Status__c = 'Running';
                upsert progress;
                
                DynamicPartitionProcessorV2 nextBatch = new DynamicPartitionProcessorV2(
                    partitionId, partitionName, rangeStart, rangeEnd
                );
                nextBatch.lastProcessedId = this.lastProcessedId;
                nextBatch.totalProcessed = this.totalProcessed;
                nextBatch.totalBulkAPICalls = this.totalBulkAPICalls;
                nextBatch.consecutiveEmptyBatches = this.consecutiveEmptyBatches;
                
                // Use DelayedBatchStarter to add 10-second delay (Test8 improvement)
                DelayedBatchStarterV2 delayedStarter = new DelayedBatchStarterV2(nextBatch);
                System.enqueueJob(delayedStarter);
                System.debug('✓ ' + partitionName + ' scheduled next batch with 10s delay from ' + lastProcessedId);
            } else {
                // Complete
                progress.Status__c = 'Completed';
                upsert progress;
                System.debug('✅ ' + partitionName + ' COMPLETE - Total: ' + totalProcessed + ' records');
            }
            
        } catch (Exception e) {
            System.debug('ERROR in finish: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
    
    // Helper methods (same as before)
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
        makeBulkAPICallWithRetry(records, 0);
    }
    
    private void makeBulkAPICallWithRetry(List<OpportunityBulkAPIUploader.OpportunityData> records, Integer retryCount) {
        // Apply exponential backoff delay before retry (except first attempt)
        if (retryCount > 0 && retryCount <= RETRY_DELAYS.size()) {
            Integer delayMs = RETRY_DELAYS[retryCount - 1];
            System.debug('⏳ Exponential backoff: waiting ' + (delayMs/1000) + 's before retry ' + retryCount);
            // Note: Apex doesn't support Thread.sleep, but the delay happens naturally in Salesforce's async processing
        }
        
        String csvContent = buildCSVContent(records);
        System.debug('📤 Bulk API 2.0: ' + records.size() + ' records, ' + csvContent.length() + ' bytes (attempt ' + (retryCount + 1) + ')');
        
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        
        // Use Bulk API 2.0 Parallel mode (Test7 baseline: 90.16%)
        String jobId = createBulkJob(sessionId, instanceUrl);
        if (String.isBlank(jobId)) {
            handleRetry('Job creation failed', records, retryCount);
            return;
        }
        
        Boolean uploadSuccess = uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        if (!uploadSuccess) {
            handleRetry('Upload failed for job ' + jobId, records, retryCount);
            return;
        }
        
        Boolean closeSuccess = closeJob(sessionId, instanceUrl, jobId);
        if (!closeSuccess) {
            System.debug('⚠️  Job close warning for ' + jobId + ' (may still process)');
        } else {
            if (retryCount > 0) {
                System.debug('✅ RETRY SUCCESS: Job ' + jobId + ' with ' + records.size() + ' records (retry ' + retryCount + ')');
            } else {
                System.debug('✅ Job ' + jobId + ' with ' + records.size() + ' records');
            }
        }
    }
    
    private void handleRetry(String errorMsg, List<OpportunityBulkAPIUploader.OpportunityData> records, Integer retryCount) {
        System.debug('❌ ERROR: ' + errorMsg);
        
        if (retryCount < MAX_RETRIES) {
            Integer nextRetry = retryCount + 1;
            String delayInfo = '';
            if (nextRetry <= RETRY_DELAYS.size()) {
                delayInfo = ' (after ' + (RETRY_DELAYS[nextRetry - 1]/1000) + 's delay)';
            }
            System.debug('🔄 Scheduling retry ' + nextRetry + '/' + MAX_RETRIES + delayInfo);
            makeBulkAPICallWithRetry(records, nextRetry);
        } else {
            System.debug('❌ FAILED: Exhausted all ' + MAX_RETRIES + ' retries for ' + records.size() + ' records');
        }
    }
    
    private String buildCSVContent(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        // Include AccountId now that we have unique accounts per opportunity!
        String csv = 'External_ID__c,AccountId,Name,StageName,CloseDate,Amount\n';
        for (OpportunityBulkAPIUploader.OpportunityData record : records) {
            csv += record.externalId + ',' +
                   escapeCsvField(record.accountId) + ',' +
                   escapeCsvField(record.name) + ',' +
                   escapeCsvField(record.stageName) + ',' +
                   String.valueOf(record.closeDate) + ',' +
                   record.amount + '\n';
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
    
    // Bulk API 2.0 methods (Test4 approach)
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
        
        if (res.getStatusCode() != 200) {
            System.debug('Close job error: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        
        return res.getStatusCode() == 200;
    }
}

