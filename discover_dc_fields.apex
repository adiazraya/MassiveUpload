// DISCOVER CORRECT FIELD NAMES IN DATA CLOUD
System.debug('══════════════════════════════════════════════════════════════');
System.debug('DISCOVERING DATA CLOUD FIELD NAMES');
System.debug('══════════════════════════════════════════════════════════════');

try {
    // Query just 1 record to see all available fields
    ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
    input.sql = 'SELECT * FROM "ExtOpportunities__dlm" LIMIT 1';
    
    System.debug('Querying: SELECT * FROM "ExtOpportunities__dlm" LIMIT 1');
    System.debug('');
    
    ConnectApi.CdpQueryOutputV2 result = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
    
    System.debug('✓ Query successful!');
    System.debug('Row count: ' + result.rowCount);
    System.debug('');
    
    // Debug the entire structure first
    System.debug('FULL RESPONSE STRUCTURE:');
    System.debug('════════════════════════════════════════════════════════════');
    System.debug('Metadata: ' + result.metadata);
    System.debug('');
    
    // Try to get column names from metadata
    if (result.metadata != null) {
        System.debug('Metadata class: ' + result.metadata);
        // Serialize to see structure
        String metadataJson = JSON.serializePretty(result.metadata);
        System.debug('Metadata JSON:');
        System.debug(metadataJson);
    }
    
    System.debug('');
    System.debug('SAMPLE DATA (First row):');
    System.debug('════════════════════════════════════════════════════════════');
    
    if (result.data != null && result.data.size() > 0) {
        ConnectApi.CdpQueryV2Row firstRow = result.data[0];
        System.debug('First row structure: ' + firstRow);
        System.debug('');
        System.debug('First row data serialized:');
        System.debug(JSON.serializePretty(firstRow));
    }
    
    System.debug('');
    System.debug('══════════════════════════════════════════════════════════════');
    System.debug('INSTRUCTIONS:');
    System.debug('══════════════════════════════════════════════════════════════');
    System.debug('Look at the fields above and identify:');
    System.debug('1. Which field is the EXTERNAL ID (unique identifier)?');
    System.debug('2. Confirm the other field names:');
    System.debug('   - Name field');
    System.debug('   - Amount field');
    System.debug('   - StageName field');
    System.debug('   - CloseDate field');
    System.debug('   - Account field');
    System.debug('');
    System.debug('Share the EXACT field names from Data Cloud!');
    System.debug('══════════════════════════════════════════════════════════════');
    
} catch (Exception e) {
    System.debug('⚠️  ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

