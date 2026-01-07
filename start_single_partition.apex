// Stop all V2 jobs and start SINGLE partition (no locking)
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🛑 STOPPING ALL V2 JOBS');
System.debug('════════════════════════════════════════════════════════════════');

// Abort any running V2 jobs
List<AsyncApexJob> runningJobs = [
    SELECT Id FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing', 'Holding')
];

for (AsyncApexJob job : runningJobs) {
    System.abortJob(job.Id);
}
System.debug('✓ Aborted ' + runningJobs.size() + ' running jobs');

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING SINGLE PARTITION TEST');
System.debug('════════════════════════════════════════════════════════════════');

// Get min/max from Data Cloud
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

// Delete old progress records
delete [SELECT Id FROM DataCloudPartition__c WHERE Name LIKE 'DynamicPartitionV2_%'];

// Create single partition progress record
DataCloudPartition__c progress = new DataCloudPartition__c(
    Name = 'SinglePartition_Test',
    PartitionId__c = 0,
    CurrentOffset__c = 0,
    TotalProcessed__c = 0,
    TotalBulkAPICalls__c = 0,
    Status__c = 'Initialized'
);
insert progress;

// Start SINGLE partition (entire range)
DynamicPartitionProcessorV2 batch = new DynamicPartitionProcessorV2(
    0, 'SinglePartition_Test', minId, maxId
);

Database.executeBatch(batch, 1);

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ STARTED SINGLE PARTITION');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Partition: SinglePartition_Test');
System.debug('Range: ' + minId + ' to ' + maxId);
System.debug('Batch size: 2,000 records');
System.debug('');
System.debug('EXPECTED RESULTS:');
System.debug('  - NO lock errors (only 1 batch at a time)');
System.debug('  - 100% success rate (0 failed records)');
System.debug('  - Slower: ~4-6 hours to complete 2M records');
System.debug('  - BUT proves the solution works!');
System.debug('');
System.debug('After success, we\'ll implement Option 3 (delays) for speed');
System.debug('════════════════════════════════════════════════════════════════');




