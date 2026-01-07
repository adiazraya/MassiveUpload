// DIAGNOSE HTTP CODE[0] ERROR
System.debug('══════════════════════════════════════════════════════════════');
System.debug('DIAGNOSING HTTP CODE[0] ERROR');
System.debug('══════════════════════════════════════════════════════════════');

// Check session ID
String sessionId = UserInfo.getSessionId();
System.debug('Session ID length: ' + sessionId.length());
System.debug('Session ID starts with: ' + sessionId.substring(0, Math.min(10, sessionId.length())));

// Check instance URL
String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
System.debug('Instance URL: ' + instanceUrl);

// Test endpoint
String endpoint = instanceUrl + '/services/data/v59.0/jobs/ingest';
System.debug('Full endpoint: ' + endpoint);

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('TESTING SIMPLE HTTP CALLOUT');
System.debug('══════════════════════════════════════════════════════════════');

try {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + sessionId);
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(120000);
    
    System.debug('Making test callout...');
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    System.debug('');
    System.debug('✓ SUCCESS!');
    System.debug('Status Code: ' + res.getStatusCode());
    System.debug('Status: ' + res.getStatus());
    System.debug('Response: ' + res.getBody().substring(0, Math.min(200, res.getBody().length())));
    
} catch (System.CalloutException e) {
    System.debug('');
    System.debug('❌ CALLOUT EXCEPTION!');
    System.debug('Error: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
    
    if (e.getMessage().contains('Unauthorized endpoint')) {
        System.debug('');
        System.debug('SOLUTION:');
        System.debug('══════════════════════════════════════════════════════════');
        System.debug('You need to add Remote Site Settings!');
        System.debug('');
        System.debug('1. Go to Setup → Remote Site Settings');
        System.debug('2. Click "New Remote Site"');
        System.debug('3. Name: SalesforceBulkAPI');
        System.debug('4. URL: ' + instanceUrl);
        System.debug('5. Check "Disable Protocol Security"');
        System.debug('6. Save');
        System.debug('');
        System.debug('Then run restart_with_5k_batches.apex again');
        System.debug('══════════════════════════════════════════════════════════');
    }
    
} catch (Exception e) {
    System.debug('');
    System.debug('❌ OTHER EXCEPTION!');
    System.debug('Error: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
    System.debug('Stack: ' + e.getStackTraceString());
}

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');





