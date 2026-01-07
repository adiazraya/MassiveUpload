// ════════════════════════════════════════════════════════════════════════════════
// RESTART 10 PARALLEL PARTITIONS (Fixed Version)
// Create progress records FIRST, then start batches
// ════════════════════════════════════════════════════════════════════════════════

System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 RESTARTING 10 PARALLEL PARTITIONS');
System.debug('════════════════════════════════════════════════════════════════');

// Clean up
delete [SELECT Id FROM DataCloudPartition__c];
System.debug('✓ Cleaned up old records');
System.debug('');

// Create 10 partition records FIRST
List<DataCloudPartition__c> partitions = new List<DataCloudPartition__c>();
for (Integer i = 0; i < 10; i++) {
    String partitionName = 'Partition' + i;
    partitions.add(new DataCloudPartition__c(
        Name = partitionName,
        PartitionId__c = i,
        CurrentOffset__c = 0,
        TotalProcessed__c = 0,
        TotalBulkAPICalls__c = 0,
        Status__c = 'Initialized'
    ));
}
insert partitions;
System.debug('✓ Created 10 partition records');
System.debug('');

// NOW start the batches
for (Integer i = 0; i < 10; i++) {
    String partitionName = 'Partition' + i;
    Integer startOffset = i * 200000;
    
    DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
        startOffset,
        0,
        0,
        0
    );
    batch.setPartitionInfo(i, partitionName);
    
    Id batchId = Database.executeBatch(batch, 1);
    System.debug('✓ ' + partitionName + ' started (Job: ' + batchId + ')');
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ ALL 10 PARTITIONS STARTED WITH PROGRESS TRACKING');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Each partition processes 200k records (100 batches)');
System.debug('Expected: ~2-3 hours for all 2M records');
System.debug('Monitor: sf apex run --file check_all_partitions.apex');
System.debug('════════════════════════════════════════════════════════════════');




