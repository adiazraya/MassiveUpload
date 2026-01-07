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
    private static final Integer RECORDS_PER_BATCH = 1000;
    
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
    
    // Start method - returns a simple list with one element (acts as trigger)
    public List<Integer> start(Database.BatchableContext context) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BATCH START - Offset: ' + currentOffset);
        System.debug('════════════════════════════════════════════════════════');
        return new List<Integer>{1}; // Just a trigger, actual work in execute
    }
    
    // Execute method - does the actual CDP query and processing
    public void execute(Database.BatchableContext context, List<Integer> scope) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BATCH EXECUTE');
        System.debug('Current Offset: ' + currentOffset);
        System.debug('Total Processed So Far: ' + totalProcessed);
        System.debug('Max Records: ' + (maxRecords > 0 ? String.valueOf(maxRecords) : 'No Limit'));
        System.debug('════════════════════════════════════════════════════════');
        
        // Check if we've hit the max records limit
        if (maxRecords > 0 && totalProcessed >= maxRecords) {
            System.debug('✓ Max records limit reached (' + maxRecords + ')');
            return;
        }
        
        // Calculate how many records to fetch
        Integer recordsToFetch = RECORDS_PER_BATCH;
        if (maxRecords > 0) {
            Integer remaining = maxRecords - totalProcessed;
            recordsToFetch = Math.min(RECORDS_PER_BATCH, remaining);
        }
        System.debug('Records to fetch this batch: ' + recordsToFetch);
        
        try {
            // Query Data Cloud with current offset
            String sqlQuery = 
                'SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c ' +
                'FROM ExtOpportunities__dlm ' +
                'ORDER BY externalid__c ' +
                'LIMIT ' + recordsToFetch + ' ' +
                'OFFSET ' + currentOffset;
            
            System.debug('SQL: ' + sqlQuery);
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                System.debug('✓ No more data at offset ' + currentOffset);
                return; // Will finish in finish() method
            }
            
            Integer rowCount = queryOutput.data.size();
            System.debug('✓ Retrieved ' + rowCount + ' rows');
            
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
                    if (errorCount <= 3) {
                        System.debug('  ✗ Error: ' + e.getMessage());
                    }
                }
            }
            
            // Send to Bulk API directly (no nested batch)
            if (!oppDataList.isEmpty()) {
                try {
                    makeBulkAPICall(oppDataList);
                    totalBulkAPICalls++;
                    System.debug('  ✓ Bulk API call made (' + oppDataList.size() + ' records)');
                } catch (Exception e) {
                    System.debug('  ✗ Error making Bulk API call: ' + e.getMessage());
                    System.debug('  Stack: ' + e.getStackTraceString());
                }
            }
            
            totalProcessed += successCount;
            System.debug('✓ Processed: ' + successCount + ', Errors: ' + errorCount);
            System.debug('Running total: ' + totalProcessed + ' records, ' + totalBulkAPICalls + ' Bulk API calls');
            
            // Check if we've hit max records limit
            if (maxRecords > 0 && totalProcessed >= maxRecords) {
                System.debug('✓ Max records limit reached (' + maxRecords + ')');
                return;
            }
            
            // Schedule next batch if we got a full set (meaning there might be more)
            if (rowCount >= recordsToFetch) {
                System.debug('→ Full batch received, will schedule next batch in finish()');
            } else {
                System.debug('→ Partial batch received, this is the last batch');
            }
            
        } catch (Exception e) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('ERROR');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('════════════════════════════════════════════════════════');
        }
    }
    
    // Finish method - schedule next batch if needed
    public void finish(Database.BatchableContext context) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BATCH FINISH');
        System.debug('════════════════════════════════════════════════════════');
        
        // Check if we've hit max records limit
        if (maxRecords > 0 && totalProcessed >= maxRecords) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('MAX RECORDS LIMIT REACHED!');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Total Records Processed: ' + totalProcessed);
            System.debug('Total Bulk API Calls: ' + totalBulkAPICalls);
            System.debug('Max Records Limit: ' + maxRecords);
            System.debug('════════════════════════════════════════════════════════');
            return;
        }
        
        // Check if we processed a full batch (indicating more records might exist)
        // We need to query again to see if there are more records
        try {
            String sqlQuery = 
                'SELECT externalid__c FROM ExtOpportunities__dlm ' +
                'ORDER BY externalid__c ' +
                'LIMIT 1 OFFSET ' + (currentOffset + RECORDS_PER_BATCH);
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput != null && queryOutput.data != null && !queryOutput.data.isEmpty()) {
                // More records exist, schedule next batch
                System.debug('→ More records exist, scheduling next batch...');
                
                DataCloudBatchProcessor nextBatch = new DataCloudBatchProcessor(
                    currentOffset + RECORDS_PER_BATCH,
                    totalProcessed,
                    totalBulkAPICalls,
                    maxRecords
                );
                
                Database.executeBatch(nextBatch, 1);
                System.debug('✓ Next batch scheduled with offset ' + (currentOffset + RECORDS_PER_BATCH));
                
            } else {
                // No more records
                System.debug('════════════════════════════════════════════════════════');
                System.debug('ALL PROCESSING COMPLETE!');
                System.debug('════════════════════════════════════════════════════════');
                System.debug('Total Records Processed: ' + totalProcessed);
                System.debug('Total Bulk API Calls: ' + totalBulkAPICalls);
                System.debug('════════════════════════════════════════════════════════');
            }
            
        } catch (Exception e) {
            System.debug('✗ Error checking for more records: ' + e.getMessage());
            System.debug('Final stats - Records: ' + totalProcessed + ', Bulk API Calls: ' + totalBulkAPICalls);
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
        
        // Get session ID for authentication
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        
        // Create Bulk API 2.0 job
        String jobId = createBulkJob(sessionId, instanceUrl);
        
        if (String.isBlank(jobId)) {
            System.debug('  ✗ Failed to create bulk job');
            return;
        }
        
        // Upload data to the job
        Boolean uploadSuccess = uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        
        if (!uploadSuccess) {
            System.debug('  ✗ Failed to upload data to job');
            return;
        }
        
        // Close the job to start processing
        Boolean closeSuccess = closeJob(sessionId, instanceUrl, jobId);
        
        if (!closeSuccess) {
            System.debug('  ✗ Failed to close job');
            return;
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
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('id');
        }
        
        System.debug('  ✗ Create job failed: ' + res.getStatusCode() + ' - ' + res.getBody());
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
        
        if (res.getStatusCode() == 201) {
            return true;
        }
        
        System.debug('  ✗ Upload data failed: ' + res.getStatusCode() + ' - ' + res.getBody());
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
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return true;
        }
        
        System.debug('  ✗ Close job failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        return false;
    }
}
