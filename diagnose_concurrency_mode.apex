// Diagnostic Test Suite for Concurrency Mode

System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 BULK API CONCURRENCY MODE DIAGNOSTICS');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');

// Test 1: Check Organization Info
System.debug('TEST 1: Organization Information');
System.debug('  Org ID: ' + UserInfo.getOrganizationId());
System.debug('  Org Name: ' + UserInfo.getOrganizationName());
System.debug('  User: ' + UserInfo.getUserName());
System.debug('  Profile: ' + UserInfo.getProfileId());
System.debug('');

// Test 2: Check API Access
System.debug('TEST 2: API Permissions');
System.debug('  Can make callouts: ' + (Limits.getLimitCallouts() > 0));
System.debug('  Session ID available: ' + (UserInfo.getSessionId() != null));
System.debug('');

// Test 3: Try different API versions
String sessionId = UserInfo.getSessionId();
String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
List<String> apiVersions = new List<String>{'v47.0', 'v50.0', 'v55.0', 'v59.0'};

System.debug('TEST 3: Testing Concurrency Mode across API versions');
for (String apiVer : apiVersions) {
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(instanceUrl + '/services/data/' + apiVer + '/jobs/ingest');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"object":"Opportunity","externalIdFieldName":"External_ID__c","contentType":"CSV","operation":"upsert","concurrencyMode":"Serial"}');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 400 && res.getBody().contains('concurrencyMode')) {
            System.debug('  ' + apiVer + ': ❌ ConcurrencyMode NOT supported');
        } else if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
            System.debug('  ' + apiVer + ': ✅ ConcurrencyMode SUPPORTED!');
            
            // Abort the job we just created
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String jobId = (String) responseMap.get('id');
            
            HttpRequest abortReq = new HttpRequest();
            abortReq.setEndpoint(instanceUrl + '/services/data/' + apiVer + '/jobs/ingest/' + jobId);
            abortReq.setMethod('PATCH');
            abortReq.setHeader('Authorization', 'Bearer ' + sessionId);
            abortReq.setHeader('Content-Type', 'application/json');
            abortReq.setBody('{"state":"Aborted"}');
            http.send(abortReq);
        } else {
            System.debug('  ' + apiVer + ': ⚠️  Unexpected response: ' + res.getStatusCode());
        }
    } catch (Exception e) {
        System.debug('  ' + apiVer + ': ⚠️  Error: ' + e.getMessage());
    }
}

System.debug('');
System.debug('TEST 4: Check if Parallel mode works (baseline)');
try {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest');
    req.setMethod('POST');
    req.setHeader('Authorization', 'Bearer ' + sessionId);
    req.setHeader('Content-Type', 'application/json');
    req.setBody('{"object":"Opportunity","externalIdFieldName":"External_ID__c","contentType":"CSV","operation":"upsert"}');
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
        System.debug('  ✅ Parallel mode (default) works!');
        
        // Abort this job too
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String jobId = (String) responseMap.get('id');
        
        HttpRequest abortReq = new HttpRequest();
        abortReq.setEndpoint(instanceUrl + '/services/data/v59.0/jobs/ingest/' + jobId);
        abortReq.setMethod('PATCH');
        abortReq.setHeader('Authorization', 'Bearer ' + sessionId);
        abortReq.setHeader('Content-Type', 'application/json');
        abortReq.setBody('{"state":"Aborted"}');
        http.send(abortReq);
    } else {
        System.debug('  ❌ Even Parallel mode failed: ' + res.getStatusCode());
    }
} catch (Exception e) {
    System.debug('  ⚠️  Error: ' + e.getMessage());
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('DIAGNOSIS COMPLETE');
System.debug('════════════════════════════════════════════════════════════════');


