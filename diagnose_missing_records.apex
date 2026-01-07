// Diagnose missing records
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 DIAGNOSING MISSING RECORDS');
System.debug('════════════════════════════════════════════════════════════════');

// Check Data Cloud total
ConnectApi.CdpQueryInput countInput = new ConnectApi.CdpQueryInput();
countInput.sql = 'SELECT COUNT(*) as total FROM "ExtOpportunities__dlm"';
ConnectApi.CdpQueryOutputV2 countOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(countInput);

Integer dcTotal = 0;
if (countOutput != null && !countOutput.data.isEmpty()) {
    String rowJson = JSON.serialize(countOutput.data[0]);
    List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
    dcTotal = Integer.valueOf(values[0]);
}

System.debug('📊 Data Cloud Total: ' + dcTotal);

// Check Salesforce total
Integer sfTotal = [SELECT COUNT() FROM Opportunity];
System.debug('📊 Salesforce Total: ' + sfTotal);
System.debug('❌ Missing: ' + (dcTotal - sfTotal));
System.debug('');

// Check if records exist beyond offset 2M
System.debug('Testing records at different offsets...');
List<Integer> testOffsets = new List<Integer>{1500000, 1800000, 2000000, 2200000};

for (Integer offset : testOffsets) {
    ConnectApi.CdpQueryInput testInput = new ConnectApi.CdpQueryInput();
    testInput.sql = 'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                    'ORDER BY "ExternalId__c" LIMIT 1 OFFSET ' + offset;
    
    try {
        ConnectApi.CdpQueryOutputV2 testOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(testInput);
        if (testOutput != null && !testOutput.data.isEmpty()) {
            System.debug('✓ Offset ' + offset + ': Record exists');
        } else {
            System.debug('✗ Offset ' + offset + ': No records');
        }
    } catch (Exception e) {
        System.debug('✗ Offset ' + offset + ': Error - ' + e.getMessage());
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('ISSUE: Fixed 200k per partition is incorrect!');
System.debug('Data Cloud has ~2M records but they extend beyond offset 2M');
System.debug('');
System.debug('SOLUTION: Need to query until no more records, not fixed offset');
System.debug('════════════════════════════════════════════════════════════════');




