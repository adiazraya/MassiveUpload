/**
 * Self-scheduling Batch Apex for Data Cloud to Bulk API
 * Each batch processes 1000 records and schedules the next batch
 * No stack depth limit, no CPU timeout in start()
 * 
 * Usage:
 *   DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
 *   Database.executeBatch(batch, 1);
 */
public class DataCloudBatchProcessor implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    
    private Integer currentOffset;
    private Integer totalProcessed = 0;
    private Integer totalBulkAPICalls = 0;
    private Integer maxRecords = 0; // 0 means no limit
    private static final Integer RECORDS_PER_BATCH = 2000; // Safe value to avoid "Regex too complicated" error
    private Integer partitionId = -1; // -1 means no partition
    private String partitionName = 'Default';
    
    // Default constructor
    public DataCloudBatchProcessor() {
        this.currentOffset = 0;
        this.maxRecords = 0; // No limit
    }
    
    // Constructor with max records
    public DataCloudBatchProcessor(Integer maxRecords) {
        this.currentOffset = 0;
        this.maxRecords = maxRecords;
    }
    
    // Constructor with offset (for chaining)
    public DataCloudBatchProcessor(Integer offset, Integer processed, Integer bulkCalls, Integer maxRecs) {
        this.currentOffset = offset;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = bulkCalls;
        this.maxRecords = maxRecs;
    }
    
    // Set partition info for parallel processing
    public void setPartitionInfo(Integer pId, String pName) {
        this.partitionId = pId;
        this.partitionName = pName;
    }
    
    // Start method - returns a simple list with one element (acts as trigger)
    public List<Integer> start(Database.BatchableContext context) {
        // Minimal logging to avoid debug limits
        System.debug('START Offset: ' + currentOffset);
        return new List<Integer>{1}; // Just a trigger, actual work in execute
    }
    
    // Execute method - does the actual CDP query and processing
    public void execute(Database.BatchableContext context, List<Integer> scope) {
        // Log every 10th batch (every 100K records instead of every 100K)
        Boolean shouldLog = (Math.mod(currentOffset / RECORDS_PER_BATCH, 10) == 0);
        
        if (shouldLog) {
            System.debug('EXEC Offset: ' + currentOffset + ', Total: ' + totalProcessed + ', Bulk Calls: ' + totalBulkAPICalls);
        }
        
        // Check if we've hit the max records limit
        if (maxRecords > 0 && totalProcessed >= maxRecords) {
            if (shouldLog) System.debug('Max limit reached: ' + maxRecords);
            return;
        }
        
        // Calculate how many records to fetch
        Integer recordsToFetch = RECORDS_PER_BATCH;
        if (maxRecords > 0) {
            Integer remaining = maxRecords - totalProcessed;
            recordsToFetch = Math.min(RECORDS_PER_BATCH, remaining);
        }
        
        try {
            // Query Data Cloud with current offset
            String sqlQuery = 
                'SELECT "ExternalId__c", "stagename__c", "Amount__c", "Account__c", "Name__c", "CloseDate__c" ' +
                'FROM "ExtOpportunities__dlm" ' +
                'ORDER BY "ExternalId__c" ' +
                'LIMIT ' + recordsToFetch + ' ' +
                'OFFSET ' + currentOffset;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                if (shouldLog) System.debug('No more data at offset ' + currentOffset);
                return; // Will finish in finish() method
            }
            
            Integer rowCount = queryOutput.data.size();
            
            // Process rows
            List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
                new List<OpportunityBulkAPIUploader.OpportunityData>();
            
            Integer successCount = 0;
            Integer errorCount = 0;
            
            for (ConnectApi.CdpQueryV2Row row : queryOutput.data) {
                try {
                    String rowJson = JSON.serialize(row);
                    List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
                    
                    if (values == null || values.size() < 6) {
                        errorCount++;
                        continue;
                    }
                    
                    String externalId = (String) values[0];
                    String stageName = (String) values[1];
                    Object amountObj = values[2];
                    String accountId = (String) values[3];
                    String name = (String) values[4];
                    Object closeDateObj = values[5];
                    
                    Decimal amount = amountObj != null ? Decimal.valueOf(String.valueOf(amountObj)) : 0;
                    Date closeDate = parseCloseDate(closeDateObj);
                    
                    oppDataList.add(new OpportunityBulkAPIUploader.OpportunityData(
                        externalId, stageName, amount, accountId, name, closeDate
                    ));
                    successCount++;
                    
                } catch (Exception e) {
                    errorCount++;
                    // Only log first 3 errors to save debug space
                    if (shouldLog && errorCount <= 3) {
                        System.debug('Error parsing row: ' + e.getMessage());
                    }
                }
            }
            
            // Send to Bulk API directly (no nested batch)
            if (!oppDataList.isEmpty()) {
                try {
                    makeBulkAPICall(oppDataList);
                    totalBulkAPICalls++;
                } catch (Exception e) {
                    // Always log Bulk API errors
                    System.debug('Bulk API ERROR offset ' + currentOffset + ': ' + e.getMessage());
                }
            }
            
            totalProcessed += successCount;
            currentOffset += rowCount; // INCREMENT OFFSET HERE!
            
            // Log progress every 10 batches (every 100,000 records)
            if (shouldLog) {
                System.debug('Progress: ' + totalProcessed + ' records, ' + totalBulkAPICalls + ' API calls, Offset: ' + currentOffset);
            }
            
            // Check if we've hit max records limit
            if (maxRecords > 0 && totalProcessed >= maxRecords) {
                if (shouldLog) System.debug('Max limit reached: ' + maxRecords);
                return;
            }
            
        } catch (Exception e) {
            // Always log exceptions
            System.debug('EXCEPTION at offset ' + currentOffset);
            System.debug('Type: ' + e.getTypeName());
            System.debug('Message: ' + e.getMessage());
        }
    }
    
    // Finish method - self-schedule next batch immediately for continuous processing
    public void finish(Database.BatchableContext context) {
        System.debug('FINISH - Total processed: ' + totalProcessed);
        
        // Check if we should continue processing
        Boolean shouldContinue = true;
        
        // Stop if we hit max records limit
        if (maxRecords > 0 && totalProcessed >= maxRecords) {
            shouldContinue = false;
            System.debug('Reached max records limit: ' + maxRecords);
        }
        
        // For partitioned processing, check if we've reached partition end
        if (partitionId >= 0) {
            Integer partitionStartOffset = partitionId * 200000;
            Integer partitionEndOffset = partitionStartOffset + 200000;
            if (currentOffset >= partitionEndOffset) {
                shouldContinue = false;
                System.debug('Partition ' + partitionId + ' complete');
            }
        }
        
        // Update progress record
        try {
            List<DataCloudPartition__c> progress = [
                SELECT CurrentOffset__c, TotalProcessed__c, TotalBulkAPICalls__c, Status__c, PartitionId__c
                FROM DataCloudPartition__c
                WHERE Name = :partitionName
                LIMIT 1
            ];
            
            if (!progress.isEmpty()) {
                // For partitions, store relative offset
                if (partitionId >= 0) {
                    Integer partitionStartOffset = partitionId * 200000;
                    progress[0].CurrentOffset__c = currentOffset - partitionStartOffset;
                } else {
                    progress[0].CurrentOffset__c = currentOffset;
                }
                
                progress[0].TotalProcessed__c = totalProcessed;
                progress[0].TotalBulkAPICalls__c = totalBulkAPICalls;
                progress[0].Status__c = shouldContinue ? 'Running' : 'Completed';
                update progress[0];
                
                System.debug('Progress updated (' + partitionName + '): Status=' + progress[0].Status__c);
            }
        } catch (Exception e) {
            System.debug('ERROR updating progress: ' + e.getMessage());
        }
        
        // Self-schedule next batch immediately for continuous processing
        if (shouldContinue) {
            try {
                DataCloudBatchProcessor nextBatch = new DataCloudBatchProcessor(
                    currentOffset,
                    totalProcessed,
                    totalBulkAPICalls,
                    maxRecords
                );
                nextBatch.setPartitionInfo(partitionId, partitionName);
                
                Database.executeBatch(nextBatch, 1);
                System.debug('✓ Next batch scheduled for ' + partitionName);
            } catch (Exception e) {
                System.debug('ERROR scheduling next batch: ' + e.getMessage());
            }
        }
    }
    
    private Date parseCloseDate(Object closeDateObj) {
        if (closeDateObj == null) {
            return Date.today().addDays(30);
        }
        
        try {
            String dateStr = String.valueOf(closeDateObj);
            if (dateStr.contains('-')) {
                List<String> parts = dateStr.split('-');
                if (parts.size() >= 3) {
                    Integer year = Integer.valueOf(parts[0]);
                    Integer month = Integer.valueOf(parts[1]);
                    String dayPart = parts[2];
                    if (dayPart.contains(' ') || dayPart.contains('T')) {
                        dayPart = dayPart.split('[\\s T]')[0];
                    }
                    Integer day = Integer.valueOf(dayPart);
                    return Date.newInstance(year, month, day);
                }
            }
            return Date.today().addDays(30);
        } catch (Exception e) {
            return Date.today().addDays(30);
        }
    }
    
    /**
     * Makes an HTTP callout to Salesforce Bulk API 2.0
     */
    private void makeBulkAPICall(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        // Build CSV content
        String csvContent = buildCSVContent(records);
        
        System.debug('Bulk API: Starting call for ' + records.size() + ' records');
        System.debug('CSV size: ' + csvContent.length() + ' chars, ' + csvContent.split('\n').size() + ' lines');
        
        // Get session ID for authentication
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        
        // Create Bulk API 2.0 job
        String jobId = createBulkJob(sessionId, instanceUrl);
        
        if (String.isBlank(jobId)) {
            System.debug('ERROR: Job creation failed');
            return;
        }
        
        System.debug('Bulk API: Job created: ' + jobId);
        
        // Upload data to the job
        Boolean uploadSuccess = uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        
        if (!uploadSuccess) {
            System.debug('ERROR: Upload failed for job: ' + jobId);
            return;
        }
        
        System.debug('Bulk API: Upload success for job: ' + jobId);
        
        // Close the job to start processing
        Boolean closeSuccess = closeJob(sessionId, instanceUrl, jobId);
        
        if (closeSuccess) {
            System.debug('Bulk API: Job closed successfully: ' + jobId);
        } else {
            System.debug('ERROR: Close failed for job: ' + jobId);
        }
    }
    
    private String buildCSVContent(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        String csv = 'External_ID__c,Name,StageName,CloseDate,Amount,AccountId\n';
        
        for (OpportunityBulkAPIUploader.OpportunityData record : records) {
            String closeDateStr = String.valueOf(record.closeDate);
            csv += record.externalId + ',' +
                   escapeCsvField(record.name) + ',' +
                   escapeCsvField(record.stageName) + ',' +
                   closeDateStr + ',' +
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
        
        String requestBody = '{"object":"Opportunity","externalIdFieldName":"External_ID__c","contentType":"CSV","operation":"upsert","lineEnding":"LF"}';
        req.setBody(requestBody);
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Create job status: ' + res.getStatusCode());
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String jobId = (String) responseMap.get('id');
            System.debug('Job ID: ' + jobId);
            return jobId;
        }
        
        System.debug('Create job failed: ' + res.getStatusCode() + ' - ' + res.getBody());
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
        
        System.debug('Uploading ' + csvContent.length() + ' bytes to job ' + jobId);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Upload status: ' + res.getStatusCode());
        
        if (res.getStatusCode() == 201) {
            System.debug('Upload response: ' + res.getBody());
            return true;
        }
        
        System.debug('Upload failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        return false;
    }
    
    private Boolean closeJob(String sessionId, String instanceUrl, String jobId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId);
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"state":"UploadComplete"}');
        req.setTimeout(120000);
        
        System.debug('Closing job ' + jobId);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Close status: ' + res.getStatusCode());
        
        if (res.getStatusCode() == 200) {
            System.debug('Close response: ' + res.getBody());
            return true;
        }
        
        System.debug('Close job failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        return false;
    }
}
