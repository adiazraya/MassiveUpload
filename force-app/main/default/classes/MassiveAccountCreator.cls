/**
 * Creates 2 Million Person Accounts via Bulk API
 * Names: acc_test_massive_0000001 to acc_test_massive_2000000
 */
public class MassiveAccountCreator implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    
    public Integer currentOffset = 0;
    public Integer totalCreated = 0;
    public Integer totalBulkAPICalls = 0;
    
    private static final Integer RECORDS_PER_BATCH = 10000; // Bulk API can handle 10k
    private static final Integer TOTAL_ACCOUNTS = 2000000;
    
    public List<Integer> start(Database.BatchableContext context) {
        System.debug('=== STARTING MASSIVE ACCOUNT CREATION ===');
        System.debug('Target: 2,000,000 Person Accounts');
        return new List<Integer>{1};
    }
    
    public void execute(Database.BatchableContext context, List<Integer> scope) {
        try {
            if (currentOffset >= TOTAL_ACCOUNTS) {
                System.debug('Reached target: ' + TOTAL_ACCOUNTS);
                return;
            }
            
            // Get PersonAccount RecordTypeId
            String personAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId();
            
            // Build CSV for Bulk API
            String csv = 'RecordTypeId,FirstName,LastName,PersonEmail\n';
            
            Integer endOffset = Math.min(currentOffset + RECORDS_PER_BATCH, TOTAL_ACCOUNTS);
            Integer recordsThisBatch = endOffset - currentOffset;
            
            for (Integer i = currentOffset; i < endOffset; i++) {
                String accountNumber = String.valueOf(i + 1).leftPad(7, '0');
                String lastName = 'Massive_' + accountNumber;
                String email = 'test.massive.' + accountNumber + '@test.com';
                csv += personAccountRTId + ',Test,' + lastName + ',' + email + '\n';
            }
            
            // Make Bulk API call
            makeBulkAPICall(csv);
            
            totalCreated += recordsThisBatch;
            currentOffset = endOffset;
            totalBulkAPICalls++;
            
            if (Math.mod(totalBulkAPICalls, 10) == 0) {
                System.debug('Progress: ' + totalCreated + ' / ' + TOTAL_ACCOUNTS + 
                           ' (' + totalBulkAPICalls + ' API calls)');
            }
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('=== ACCOUNT CREATION COMPLETE ===');
        System.debug('Total Created: ' + totalCreated);
        System.debug('Total Bulk API Calls: ' + totalBulkAPICalls);
        
        // Self-schedule if not complete
        if (currentOffset < TOTAL_ACCOUNTS) {
            System.debug('Scheduling next batch from offset ' + currentOffset);
            MassiveAccountCreator nextBatch = new MassiveAccountCreator();
            nextBatch.currentOffset = this.currentOffset;
            nextBatch.totalCreated = this.totalCreated;
            nextBatch.totalBulkAPICalls = this.totalBulkAPICalls;
            Database.executeBatch(nextBatch, 1);
        } else {
            System.debug('✅ ALL 2,000,000 ACCOUNTS CREATED!');
            System.debug('Next: Run download_account_ids.apex to export Account IDs');
        }
    }
    
    private void makeBulkAPICall(String csvContent) {
        String sessionId = UserInfo.getSessionId();
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        
        // Create job
        String jobId = createBulkJob(sessionId, instanceUrl);
        if (String.isBlank(jobId)) {
            System.debug('Failed to create bulk job');
            return;
        }
        
        // Upload data
        uploadDataToJob(sessionId, instanceUrl, jobId, csvContent);
        
        // Close job
        closeJob(sessionId, instanceUrl, jobId);
    }
    
    private String createBulkJob(String sessionId, String instanceUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"object":"Account","contentType":"CSV","operation":"insert","lineEnding":"LF"}');
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('id');
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
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 201) {
            System.debug('Upload failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        
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
            System.debug('Close job failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
        
        return res.getStatusCode() == 200;
    }
}

