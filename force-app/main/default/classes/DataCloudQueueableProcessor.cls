/**
 * PRODUCTION VERSION: Queueable Chain with Built-in Delay
 * Much simpler and more reliable than Platform Events
 * For nightly 2M record loads
 */
public class DataCloudQueueableProcessor implements Queueable, Database.AllowsCallouts {
    private Integer currentOffset;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer maxRecords;
    private static final Integer RECORDS_PER_BATCH = 2000;
    
    public DataCloudQueueableProcessor() {
        this(0, 0, 0, 0);
    }
    
    public DataCloudQueueableProcessor(Integer offset, Integer processed, Integer bulkCalls, Integer maxRecs) {
        this.currentOffset = offset;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = bulkCalls;
        this.maxRecords = maxRecs;
    }
    
    public void execute(QueueableContext context) {
        try {
            // Log progress every 10 batches
            Boolean shouldLog = Math.mod(currentOffset / RECORDS_PER_BATCH, 10) == 0;
            
            if (shouldLog) {
                System.debug('Processing offset: ' + currentOffset + ', Total: ' + totalProcessed);
            }
            
            // Check if we've hit max records limit
            if (maxRecords > 0 && totalProcessed >= maxRecords) {
                System.debug('COMPLETE: ' + totalProcessed + ' records (Max limit reached)');
                return;
            }
            
            // Query Data Cloud
            String sqlQuery = 
                'SELECT "ExternalId__c", "Name__c", "StageName__c", ' +
                '"CloseDate__c", "Amount__c", "Account__c" ' +
                'FROM "ExtOpportunities__dlm" ' +
                'ORDER BY "ExternalId__c" ' +
                'LIMIT ' + RECORDS_PER_BATCH + ' ' +
                'OFFSET ' + currentOffset;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                System.debug('ALL COMPLETE: ' + totalProcessed + ' records, ' + totalBulkAPICalls + ' API calls');
                return;
            }
            
            // Process records and send to Bulk API
            List<OpportunityBulkAPIUploader.OpportunityData> oppRecords = new List<OpportunityBulkAPIUploader.OpportunityData>();
            
            for (ConnectApi.CdpQueryV2Row row : queryOutput.data) {
                List<Object> rowData = (List<Object>) JSON.deserializeUntyped(JSON.serialize(row));
                
                String externalId = String.valueOf(rowData[0]);
                String name = rowData[1] != null ? String.valueOf(rowData[1]) : 'Unknown';
                String stageName = rowData[2] != null ? String.valueOf(rowData[2]) : 'Prospecting';
                Date closeDate = parseCloseDate(rowData[3]);
                Decimal amount = rowData[4] != null ? Decimal.valueOf(String.valueOf(rowData[4])) : 0;
                String accountId = rowData[5] != null ? String.valueOf(rowData[5]) : null;
                
                oppRecords.add(new OpportunityBulkAPIUploader.OpportunityData(
                    externalId, stageName, amount, accountId, name, closeDate
                ));
            }
            
            // Make Bulk API call
            makeBulkAPICall(oppRecords);
            
            // Update counters
            Integer rowCount = queryOutput.data.size();
            currentOffset += rowCount;
            totalProcessed += rowCount;
            totalBulkAPICalls++;
            
            if (shouldLog) {
                System.debug('Processed ' + rowCount + ' records, new offset: ' + currentOffset);
            }
            
            // Chain to next execution with 2-minute delay using scheduled job
            Datetime nextRun = Datetime.now().addMinutes(2);
            String cronExp = nextRun.format('ss mm HH dd MM ? yyyy');
            String jobName = 'DCQueue_' + currentOffset + '_' + System.now().getTime();
            
            System.schedule(jobName, cronExp, new DataCloudQueueableScheduler(
                currentOffset, totalProcessed, totalBulkAPICalls, maxRecords
            ));
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
    }
    
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
        } catch (Exception e) { }
        
        return Date.today().addDays(30);
    }
    
    private void makeBulkAPICall(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        String csvContent = buildCSVContent(records);
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        
        // Create job
        String jobId = createBulkJob(sessionId, instanceUrl);
        if (String.isBlank(jobId)) return;
        
        // Upload data
        Boolean uploadSuccess = uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        if (!uploadSuccess) return;
        
        // Close job
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
                   (record.accountId != null ? record.accountId : '') + '\n';
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
        return (res.getStatusCode() == 201);
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
        return (res.getStatusCode() == 200);
    }
}
