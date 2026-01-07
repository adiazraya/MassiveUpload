// Get failed records from Bulk API Job
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 FETCHING FAILED RECORDS FROM BULK API');
System.debug('════════════════════════════════════════════════════════════════');

String jobId = '750KZ000009hH6u'; // From the screenshot
String sessionId = UserInfo.getSessionId();
String instanceUrl = URL.getOrgDomainUrl().toExternalForm();

try {
    // Get failed records
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
        
        // Parse first few lines to see the errors
        List<String> lines = failedRecordsCSV.split('\n');
        
        System.debug('');
        System.debug('Failed Records (first 10):');
        System.debug('════════════════════════════════════════════════════════════════');
        
        Integer linesToShow = Math.min(11, lines.size()); // Header + 10 records
        for (Integer i = 0; i < linesToShow; i++) {
            System.debug(lines[i]);
        }
        
        System.debug('');
        System.debug('Total failed record lines: ' + (lines.size() - 1)); // Minus header
        
        // Try to identify common error pattern
        if (lines.size() > 1) {
            System.debug('');
            System.debug('Analyzing error patterns...');
            
            // Count occurrences of common errors
            Integer requiredFieldCount = 0;
            Integer invalidFieldCount = 0;
            Integer duplicateCount = 0;
            Integer validationCount = 0;
            Integer otherCount = 0;
            
            for (String line : lines) {
                if (line.contains('REQUIRED_FIELD_MISSING')) requiredFieldCount++;
                else if (line.contains('INVALID_FIELD')) invalidFieldCount++;
                else if (line.contains('DUPLICATE')) duplicateCount++;
                else if (line.contains('VALIDATION')) validationCount++;
                else if (line.contains('sf__')) otherCount++; // Has error column
            }
            
            System.debug('');
            System.debug('Error Distribution:');
            if (requiredFieldCount > 0) System.debug('  Required Field Missing: ' + requiredFieldCount);
            if (invalidFieldCount > 0) System.debug('  Invalid Field: ' + invalidFieldCount);
            if (duplicateCount > 0) System.debug('  Duplicate: ' + duplicateCount);
            if (validationCount > 0) System.debug('  Validation: ' + validationCount);
            if (otherCount > 0) System.debug('  Other Errors: ' + otherCount);
        }
        
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
