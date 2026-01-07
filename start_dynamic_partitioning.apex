// ════════════════════════════════════════════════════════════════════════════════
// START DYNAMIC PARTITIONING
// Queries Data Cloud to find ExternalId ranges, divides into 10 partitions
// ════════════════════════════════════════════════════════════════════════════════

System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 QUERYING DATA CLOUD FOR EXTERNALID RANGES');
System.debug('════════════════════════════════════════════════════════════════');

// Get min and max ExternalId
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

System.debug('Min ExternalId: ' + minId);
System.debug('Max ExternalId: ' + maxId);
System.debug('');

// Calculate range per partition
// If ExternalIds are numeric-like, divide numerically
// Otherwise, divide alphabetically
System.debug('Creating 10 dynamic partitions...');
System.debug('');

// For simplicity, let's use a different approach:
// Query to get evenly distributed sample points
List<String> rangePoints = new List<String>();
rangePoints.add(minId);

// Get 9 intermediate points by querying at intervals
Integer totalRecords = 2000000; // approximate
Integer intervalSize = totalRecords / 10;

for (Integer i = 1; i < 10; i++) {
    Integer offset = i * intervalSize;
    ConnectApi.CdpQueryInput pointInput = new ConnectApi.CdpQueryInput();
    pointInput.sql = 'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                     'ORDER BY "ExternalId__c" LIMIT 1 OFFSET ' + offset;
    
    try {
        ConnectApi.CdpQueryOutputV2 pointOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(pointInput);
        if (pointOutput != null && !pointOutput.data.isEmpty()) {
            String pointJson = JSON.serialize(pointOutput.data[0]);
            List<Object> pointValues = (List<Object>) JSON.deserializeUntyped(pointJson);
            rangePoints.add((String) pointValues[0]);
        }
    } catch (Exception e) {
        System.debug('Error getting point ' + i + ': ' + e.getMessage());
    }
}

rangePoints.add(maxId + 'Z'); // Add max + buffer for last partition

System.debug('Range points collected: ' + rangePoints.size());
System.debug('');

// Clean up old progress
delete [SELECT Id FROM DataCloudPartition__c];

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
System.debug('✓ Created 10 progress records');
System.debug('');

// Start dynamic partition batches
for (Integer i = 0; i < 10; i++) {
    String partitionName = 'DynamicPartition' + i;
    String rangeStart = rangePoints[i];
    String rangeEnd = rangePoints[i + 1];
    
    DynamicPartitionProcessor batch = new DynamicPartitionProcessor(
        i, partitionName, rangeStart, rangeEnd
    );
    
    Id batchId = Database.executeBatch(batch, 1);
    System.debug('✓ ' + partitionName + ' started (Job: ' + batchId + ')');
    System.debug('   Range: ' + rangeStart + ' to ' + rangeEnd);
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ DYNAMIC PARTITIONING STARTED');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Each partition processes its ExternalId range completely');
System.debug('No fixed offsets - adapts to actual data distribution');
System.debug('Expected: ~2-4 hours for all records');
System.debug('════════════════════════════════════════════════════════════════');




