/**
 * Batch class that makes Bulk API calls
 * Each batch execution can make up to 100 HTTP callouts
 * Processing 50K records = 5 API calls per batch execution
 */
public class OpportunityBulkAPIBatch implements Database.Batchable<OpportunityBulkAPIUploader.OpportunityData>, Database.AllowsCallouts {
    
    private List<OpportunityBulkAPIUploader.OpportunityData> allRecords;
    private static final Integer BATCH_SIZE = 10000;
    
    public OpportunityBulkAPIBatch(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        this.allRecords = records;
    }
    
    public Iterable<OpportunityBulkAPIUploader.OpportunityData> start(Database.BatchableContext bc) {
        return allRecords;
    }
    
    public void execute(Database.BatchableContext bc, List<OpportunityBulkAPIUploader.OpportunityData> scope) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BATCH EXECUTE - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + bc.getJobId());
        System.debug('Records in scope: ' + scope.size());
        System.debug('Timestamp: ' + System.now());
        
        // Split scope into chunks of 10,000 for API calls
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = splitIntoChunks(scope, BATCH_SIZE);
        System.debug('Number of chunks: ' + chunks.size());
        
        Integer chunkNumber = 0;
        for (List<OpportunityBulkAPIUploader.OpportunityData> chunk : chunks) {
            chunkNumber++;
            System.debug('────────────────────────────────────────────────────────');
            System.debug('Processing chunk #' + chunkNumber + ' of ' + chunks.size());
            System.debug('Chunk size: ' + chunk.size());
            try {
                makeBulkAPICall(chunk);
                System.debug('✓ Chunk #' + chunkNumber + ' processed successfully');
            } catch (Exception e) {
                System.debug('✗ ERROR in chunk #' + chunkNumber);
                System.debug('Error: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }
        }
        
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BATCH EXECUTE - END');
        System.debug('════════════════════════════════════════════════════════');
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BATCH FINISH');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + bc.getJobId());
        System.debug('Completion Time: ' + System.now());
        System.debug('Bulk API upload batch completed');
        System.debug('════════════════════════════════════════════════════════');
    }
    
    /**
     * Makes an HTTP callout to Salesforce Bulk API 2.0
     */
    private void makeBulkAPICall(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        System.debug('▸▸▸ makeBulkAPICall START');
        System.debug('Records to upload: ' + records.size());
        
        // Build CSV content
        String csvContent = buildCSVContent(records);
        Integer csvSize = csvContent.length();
        System.debug('CSV generated - Size: ' + csvSize + ' bytes');
        System.debug('CSV preview (first 500 chars): ' + csvContent.substring(0, Math.min(500, csvSize)));
        
        // Get session ID for authentication
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        System.debug('Instance URL: ' + instanceUrl);
        System.debug('Session ID obtained: ' + (String.isNotBlank(sessionId) ? 'Yes' : 'No'));
        
        // Create Bulk API 2.0 job
        System.debug('→ Creating Bulk API job...');
        String jobId = createBulkJob(sessionId, instanceUrl);
        
        if (String.isBlank(jobId)) {
            System.debug('✗ Failed to create bulk job');
            return;
        }
        System.debug('✓ Bulk job created: ' + jobId);
        
        // Upload data to the job
        System.debug('→ Uploading data to job...');
        Boolean uploadSuccess = uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        
        if (!uploadSuccess) {
            System.debug('✗ Failed to upload data to job');
            return;
        }
        System.debug('✓ Data uploaded successfully');
        
        // Close the job to start processing
        System.debug('→ Closing job to start processing...');
        closeJob(sessionId, instanceUrl, jobId);
        
        System.debug('✓✓✓ Successfully submitted ' + records.size() + ' records to Bulk API job: ' + jobId);
        System.debug('▸▸▸ makeBulkAPICall END');
    }
    
    /**
     * Creates a Bulk API 2.0 job
     */
    private String createBulkJob(String sessionId, String instanceUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        
        // Job configuration
        Map<String, Object> jobConfig = new Map<String, Object>{
            'object' => 'Opportunity',
            'externalIdFieldName' => 'External_Id__c',
            'operation' => 'upsert',
            'lineEnding' => 'LF',
            'columnDelimiter' => 'COMMA'
        };
        
        req.setBody(JSON.serialize(jobConfig));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('id');
        } else {
            System.debug('Error creating job: ' + res.getStatusCode() + ' - ' + res.getBody());
            return null;
        }
    }
    
    /**
     * Uploads CSV data to the bulk job
     */
    private Boolean uploadDataToJob(String sessionId, String instanceUrl, String jobId, String csvContent) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId + '/batches');
        req.setMethod('PUT');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'text/csv');
        req.setBody(csvContent);
        
        // Set timeout to max (120 seconds)
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 201) {
            return true;
        } else {
            System.debug('Error uploading data: ' + res.getStatusCode() + ' - ' + res.getBody());
            return false;
        }
    }
    
    /**
     * Closes the job to start processing
     */
    private void closeJob(String sessionId, String instanceUrl, String jobId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId);
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        
        Map<String, String> closeConfig = new Map<String, String>{'state' => 'UploadComplete'};
        req.setBody(JSON.serialize(closeConfig));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            System.debug('Error closing job: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
    
    /**
     * Builds CSV content from records
     */
    private String buildCSVContent(List<OpportunityBulkAPIUploader.OpportunityData> records) {
        List<String> lines = new List<String>();
        
        // Header
        lines.add('External_Id__c,Name,StageName,Amount,AccountId,CloseDate');
        
        // Data rows
        for (OpportunityBulkAPIUploader.OpportunityData record : records) {
            String line = String.format('{0},{1},{2},{3},{4},{5}', 
                new List<String>{
                    escapeCsvField(record.externalId),
                    escapeCsvField(record.name),
                    escapeCsvField(record.stageName),
                    String.valueOf(record.amount),
                    record.accountId,
                    record.closeDate
                }
            );
            lines.add(line);
        }
        
        return String.join(lines, '\n');
    }
    
    /**
     * Escapes CSV fields that contain special characters
     */
    private String escapeCsvField(String field) {
        if (field == null) return '';
        
        if (field.contains(',') || field.contains('"') || field.contains('\n')) {
            return '"' + field.replace('"', '""') + '"';
        }
        return field;
    }
    
    /**
     * Splits a list into chunks of specified size
     */
    private List<List<OpportunityBulkAPIUploader.OpportunityData>> splitIntoChunks(
        List<OpportunityBulkAPIUploader.OpportunityData> records, 
        Integer chunkSize
    ) {
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = 
            new List<List<OpportunityBulkAPIUploader.OpportunityData>>();
        
        List<OpportunityBulkAPIUploader.OpportunityData> currentChunk = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        for (OpportunityBulkAPIUploader.OpportunityData record : records) {
            currentChunk.add(record);
            
            if (currentChunk.size() >= chunkSize) {
                chunks.add(currentChunk);
                currentChunk = new List<OpportunityBulkAPIUploader.OpportunityData>();
            }
        }
        
        // Add remaining records
        if (!currentChunk.isEmpty()) {
            chunks.add(currentChunk);
        }
        
        return chunks;
    }
}

