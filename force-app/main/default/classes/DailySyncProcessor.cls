/**
 * DAILY SYNC PROCESSOR - Simple, Repeatable Solution
 * 
 * Syncs ALL records from Data Cloud to Salesforce Opportunities
 * Runs continuously until complete, then stops
 * Can be scheduled to run nightly
 * 
 * Usage:
 *   DailySyncProcessor batch = new DailySyncProcessor();
 *   Database.executeBatch(batch, 1);
 */
public class DailySyncProcessor implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    
    public Integer currentOffset = 0;
    public Integer totalProcessed = 0;
    public Integer totalBulkAPICalls = 0;
    private static final Integer RECORDS_PER_BATCH = 2000;
    
    // Start method - simple trigger
    public List<Integer> start(Database.BatchableContext context) {
        System.debug('=== DAILY SYNC STARTED ===');
        System.debug('Starting offset: ' + currentOffset);
        return new List<Integer>{1};
    }
    
    // Execute - query Data Cloud and send to Bulk API
    public void execute(Database.BatchableContext context, List<Integer> scope) {
        try {
            // Query Data Cloud
            String sqlQuery = 
                'SELECT "ExternalId__c", "stagename__c", "Amount__c", "Account__c", "Name__c", "CloseDate__c" ' +
                'FROM "ExtOpportunities__dlm" ' +
                'ORDER BY "ExternalId__c" ' +
                'LIMIT ' + RECORDS_PER_BATCH + ' ' +
                'OFFSET ' + currentOffset;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            // Check if we got data
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                System.debug('No more data at offset ' + currentOffset + '. Sync complete.');
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
            
            // Send to Bulk API
            if (!oppDataList.isEmpty()) {
                makeBulkAPICall(oppDataList);
                totalBulkAPICalls++;
            }
            
            totalProcessed += rowCount;
            currentOffset += rowCount;
            
            // Log every 10 batches
            if (Math.mod(totalBulkAPICalls, 10) == 0) {
                System.debug('Progress: ' + totalProcessed + ' records, ' + totalBulkAPICalls + ' API calls');
            }
            
        } catch (Exception e) {
            System.debug('ERROR at offset ' + currentOffset + ': ' + e.getMessage());
        }
    }
    
    // Finish - update progress record (Flow/Scheduler will start next batch)
    public void finish(Database.BatchableContext context) {
        System.debug('Batch complete. Total processed: ' + totalProcessed);
        
        // Update or create progress record
        try {
            List<DataCloudPartition__c> progressList = [
                SELECT CurrentOffset__c, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
                FROM DataCloudPartition__c
                WHERE Name = 'DailySync'
                LIMIT 1
            ];
            
            DataCloudPartition__c progress;
            if (progressList.isEmpty()) {
                progress = new DataCloudPartition__c(Name = 'DailySync', PartitionId__c = 0);
            } else {
                progress = progressList[0];
            }
            
            // Check if more records exist
            ConnectApi.CdpQueryInput testInput = new ConnectApi.CdpQueryInput();
            testInput.sql = 'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                           'ORDER BY "ExternalId__c" LIMIT 1 OFFSET ' + currentOffset;
            ConnectApi.CdpQueryOutputV2 testOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(testInput);
            
            progress.CurrentOffset__c = currentOffset;
            progress.TotalProcessed__c = totalProcessed;
            progress.TotalBulkAPICalls__c = totalBulkAPICalls;
            
            if (testOutput != null && !testOutput.data.isEmpty()) {
                progress.Status__c = 'Running';
                System.debug('More records exist, status = Running');
            } else {
                progress.Status__c = 'Completed';
                System.debug('=== DAILY SYNC COMPLETE ===');
                System.debug('Total records: ' + totalProcessed);
            }
            
            upsert progress;
            
        } catch (Exception e) {
            System.debug('ERROR updating progress: ' + e.getMessage());
        }
    }
    
    // Helper methods
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
        } catch (Exception e) {
            System.debug('Date parse error: ' + e.getMessage());
        }
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

