// EMERGENCY RESTART - Process remaining 798k records
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚨 EMERGENCY RESTART');
System.debug('════════════════════════════════════════════════════════════════');

// Delete old progress records
delete [SELECT Id FROM DataCloudPartition__c];
System.debug('✓ Cleared old progress');

// Get actual min/max from Data Cloud
ConnectApi.CdpQueryInput minMaxInput = new ConnectApi.CdpQueryInput();
minMaxInput.sql = 'SELECT MIN("ExternalId__c") as min_id, MAX("ExternalId__c") as max_id FROM "ExtOpportunities__dlm"';
ConnectApi.CdpQueryOutputV2 minMaxOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(minMaxInput);

String minId = '';
String maxId = '';

if (minMaxOutput != null && !minMaxOutput.data.isEmpty()) {
    String rowJson = JSON.serialize(minMaxOutput.data[0]);
    List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
    minId = (String) values[0];
    maxId = (String) values[1];
}

System.debug('Data Cloud range: ' + minId + ' to ' + maxId);
System.debug('');

// Sample 10 partition boundary points
List<String> boundaryPoints = new List<String>();
boundaryPoints.add(minId);

for (Integer i = 1; i < 10; i++) {
    Integer offset = i * 200000;
    ConnectApi.CdpQueryInput pointInput = new ConnectApi.CdpQueryInput();
    pointInput.sql = 'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                     'ORDER BY "ExternalId__c" LIMIT 1 OFFSET ' + offset;
    
    try {
        ConnectApi.CdpQueryOutputV2 pointOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(pointInput);
        if (pointOutput != null && !pointOutput.data.isEmpty()) {
            String pointJson = JSON.serialize(pointOutput.data[0]);
            List<Object> pointValues = (List<Object>) JSON.deserializeUntyped(pointJson);
            boundaryPoints.add((String) pointValues[0]);
        }
    } catch (Exception e) {
        System.debug('Error sampling point ' + i + ': ' + e.getMessage());
    }
}

boundaryPoints.add(maxId);

// Create progress records
List<DataCloudPartition__c> progressRecords = new List<DataCloudPartition__c>();
for (Integer i = 0; i < 10; i++) {
    progressRecords.add(new DataCloudPartition__c(
        Name = 'DynamicPartition' + i,
        PartitionId__c = i,
        CurrentOffset__c = 0,
        TotalProcessed__c = 0,
        TotalBulkAPICalls__c = 0,
        Status__c = 'Initialized'
    ));
}
insert progressRecords;
System.debug('✓ Created progress records');
System.debug('');

// Start all 10 partitions
Integer started = 0;
for (Integer i = 0; i < 10; i++) {
    String partitionName = 'DynamicPartition' + i;
    String rangeStart = boundaryPoints[i];
    String rangeEnd = (i < 9) ? boundaryPoints[i + 1] : maxId;
    
    DynamicPartitionProcessor batch = new DynamicPartitionProcessor(
        i, partitionName, rangeStart, rangeEnd
    );
    
    Database.executeBatch(batch, 1);
    System.debug('✓ Started ' + partitionName + ': ' + rangeStart + ' to ' + rangeEnd);
    started++;
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ RESTARTED ' + started + ' PARTITIONS');
System.debug('Target: 798,255 missing records');
System.debug('ETA: 2-4 hours');
System.debug('════════════════════════════════════════════════════════════════');




