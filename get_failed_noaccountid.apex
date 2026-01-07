// Get failed records from latest job (no AccountId)
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 FETCHING FAILED RECORDS (No AccountId Version)');
System.debug('════════════════════════════════════════════════════════════════');

String jobId = '750KZ000009hHwI'; // From the screenshot
String sessionId = UserInfo.getSessionId();
String instanceUrl = URL.getOrgDomainUrl().toExternalForm();

try {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId + '/failedResults');
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + sessionId);
    req.setTimeout(120000);
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    System.debug('');
    System.debug('Response Status: ' + res.getStatusCode());
    
    if (res.getStatusCode() == 200) {
        String failedRecordsCSV = res.getBody();
        List<String> lines = failedRecordsCSV.split('\n');
        
        System.debug('');
        System.debug('Failed Records (first 10):');
        System.debug('════════════════════════════════════════════════════════════════');
        
        Integer linesToShow = Math.min(11, lines.size());
        for (Integer i = 0; i < linesToShow; i++) {
            System.debug(lines[i]);
        }
        
        System.debug('');
        System.debug('Total failed: ' + (lines.size() - 1));
        
    } else {
        System.debug('ERROR: ' + res.getStatus());
        System.debug('Body: ' + res.getBody());
    }
    
} catch (Exception e) {
    System.debug('');
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




