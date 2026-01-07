/**
 * Bulk API 1.0 Helper - Supports Serial Mode!
 */
public class BulkAPI1Helper {
    
    /**
     * Creates a Bulk API 1.0 job with Serial mode
     */
    public static String createJob(String sessionId, String instanceUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/async/59.0/job');
        req.setMethod('POST');
        req.setHeader('X-SFDC-Session', sessionId);
        req.setHeader('Content-Type', 'application/xml; charset=UTF-8');
        
        // XML JobInfo with Serial mode
        String jobXml = 
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload">' +
            '  <operation>upsert</operation>' +
            '  <object>Opportunity</object>' +
            '  <externalIdFieldName>External_ID__c</externalIdFieldName>' +
            '  <concurrencyMode>Serial</concurrencyMode>' +
            '  <contentType>CSV</contentType>' +
            '</jobInfo>';
        
        req.setBody(jobXml);
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 201) {
            // Parse XML response to get job ID
            String responseBody = res.getBody();
            Integer idStart = responseBody.indexOf('<id>') + 4;
            Integer idEnd = responseBody.indexOf('</id>');
            String jobId = responseBody.substring(idStart, idEnd);
            
            System.debug('✅ Bulk API 1.0 job created: ' + jobId + ' (Serial mode)');
            return jobId;
        } else {
            System.debug('❌ Job creation failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            return null;
        }
    }
    
    /**
     * Adds a batch to the job (CSV data)
     */
    public static String addBatch(String sessionId, String instanceUrl, String jobId, String csvContent) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/async/59.0/job/' + jobId + '/batch');
        req.setMethod('POST');
        req.setHeader('X-SFDC-Session', sessionId);
        req.setHeader('Content-Type', 'text/csv; charset=UTF-8');
        req.setBody(csvContent);
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 201) {
            // Parse batch ID from XML response
            String responseBody = res.getBody();
            Integer idStart = responseBody.indexOf('<id>') + 4;
            Integer idEnd = responseBody.indexOf('</id>');
            String batchId = responseBody.substring(idStart, idEnd);
            
            System.debug('✅ Batch added: ' + batchId);
            return batchId;
        } else {
            System.debug('❌ Batch failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            return null;
        }
    }
    
    /**
     * Closes the job
     */
    public static Boolean closeJob(String sessionId, String instanceUrl, String jobId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/async/59.0/job/' + jobId);
        req.setMethod('POST');
        req.setHeader('X-SFDC-Session', sessionId);
        req.setHeader('Content-Type', 'application/xml; charset=UTF-8');
        
        String closeXml = 
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload">' +
            '  <state>Closed</state>' +
            '</jobInfo>';
        
        req.setBody(closeXml);
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            System.debug('✅ Job closed: ' + jobId);
            return true;
        } else {
            System.debug('❌ Close failed: ' + res.getStatusCode());
            return false;
        }
    }
}


