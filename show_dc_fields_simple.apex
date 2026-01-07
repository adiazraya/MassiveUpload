// SIMPLE FIELD DISCOVERY - Clear Output
System.debug('══════════════════════════════════════════════════════════════');
System.debug('DATA CLOUD FIELD DISCOVERY');
System.debug('══════════════════════════════════════════════════════════════');

try {
    // Query with SELECT * to get all fields
    ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
    input.sql = 'SELECT * FROM "ExtOpportunities__dlm" LIMIT 1';
    
    System.debug('Executing: SELECT * FROM "ExtOpportunities__dlm" LIMIT 1');
    
    ConnectApi.CdpQueryOutputV2 result = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
    
    System.debug('✓ Success! Row count: ' + result.rowCount);
    System.debug('');
    
    // Get the first row
    if (result.data != null && result.data.size() > 0) {
        ConnectApi.CdpQueryV2Row firstRow = result.data[0];
        
        // Convert to JSON and parse
        String rowJson = JSON.serialize(firstRow);
        Map<String, Object> rowMap = (Map<String, Object>) JSON.deserializeUntyped(rowJson);
        
        System.debug('FIELD NAMES AND SAMPLE VALUES:');
        System.debug('══════════════════════════════════════════════════════════════');
        
        // Get the 'data' array from the row
        if (rowMap.containsKey('data')) {
            Object dataObj = rowMap.get('data');
            System.debug('Data type: ' + dataObj);
            System.debug('Data content:');
            System.debug(JSON.serializePretty(dataObj));
        }
        
        System.debug('');
        System.debug('FULL ROW STRUCTURE:');
        System.debug('══════════════════════════════════════════════════════════════');
        System.debug(JSON.serializePretty(rowMap));
    }
    
    System.debug('');
    System.debug('══════════════════════════════════════════════════════════════');
    System.debug('PLEASE COPY THE ENTIRE DEBUG LOG AND PASTE IT');
    System.debug('══════════════════════════════════════════════════════════════');
    
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}





