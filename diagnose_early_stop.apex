// Check why dynamic partitions stopped early
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 DIAGNOSING EARLY STOP');
System.debug('════════════════════════════════════════════════════════════════');

// 1. What's the actual range in Data Cloud?
ConnectApi.CdpQueryInput rangeInput = new ConnectApi.CdpQueryInput();
rangeInput.sql = 'SELECT MIN("ExternalId__c") as min_id, MAX("ExternalId__c") as max_id FROM "ExtOpportunities__dlm"';
ConnectApi.CdpQueryOutputV2 rangeOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(rangeInput);

String dcMinId = '';
String dcMaxId = '';

if (rangeOutput != null && !rangeOutput.data.isEmpty()) {
    String rowJson = JSON.serialize(rangeOutput.data[0]);
    List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
    dcMinId = (String) values[0];
    dcMaxId = (String) values[1];
}

System.debug('');
System.debug('Data Cloud Range: ' + dcMinId + ' to ' + dcMaxId);

// 2. What's in Salesforce?
List<AggregateResult> sfRange = [
    SELECT MIN(External_ID__c) minId, MAX(External_ID__c) maxId
    FROM Opportunity 
    WHERE External_ID__c LIKE 'externalOpp%'
];

String sfMinId = (String) sfRange[0].get('minId');
String sfMaxId = (String) sfRange[0].get('maxId');

System.debug('Salesforce Range: ' + sfMinId + ' to ' + sfMaxId);
System.debug('');

// 3. Test if records exist beyond what we loaded
ConnectApi.CdpQueryInput testInput = new ConnectApi.CdpQueryInput();
testInput.sql = 'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                'WHERE "ExternalId__c" > \'' + sfMaxId + '\' ' +
                'ORDER BY "ExternalId__c" LIMIT 5';

try {
    ConnectApi.CdpQueryOutputV2 testOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(testInput);
    
    if (testOutput != null && !testOutput.data.isEmpty()) {
        System.debug('⚠️  MISSING RECORDS FOUND in Data Cloud after ' + sfMaxId + ':');
        for (ConnectApi.CdpQueryV2Row row : testOutput.data) {
            String rowJson = JSON.serialize(row);
            List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
            System.debug('  ' + values[0]);
        }
    } else {
        System.debug('✓ No records found after ' + sfMaxId);
    }
} catch (Exception e) {
    System.debug('Error checking: ' + e.getMessage());
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




