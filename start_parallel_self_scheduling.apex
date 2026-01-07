// ════════════════════════════════════════════════════════════════════════════════
// START 10 PARALLEL SELF-SCHEDULING PARTITIONS
// Each partition processes 200k records (100 batches) - stays under 300 limit!
// ════════════════════════════════════════════════════════════════════════════════

System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING 10 PARALLEL PARTITIONS WITH SELF-SCHEDULING');
System.debug('════════════════════════════════════════════════════════════════');

// Clean up old progress records
delete [SELECT Id FROM DataCloudPartition__c];
System.debug('✓ Cleaned up old progress records');
System.debug('');

// Start 10 parallel partitions
for (Integer i = 0; i < 10; i++) {
    String partitionName = 'Partition' + i;
    Integer startOffset = i * 200000; // Each partition: 200k records
    
    DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
        startOffset,  // Starting offset
        0,            // Total processed
        0,            // Bulk API calls
        0             // No limit
    );
    batch.setPartitionInfo(i, partitionName);
    
    Id batchId = Database.executeBatch(batch, 1);
    
    System.debug('✓ ' + partitionName + ' started (Job: ' + batchId + ')');
    System.debug('   Range: ' + startOffset + ' - ' + (startOffset + 199999));
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ ALL 10 PARTITIONS STARTED');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Each partition:');
System.debug('  • Processes 200,000 records');
System.debug('  • Self-schedules next batch immediately');
System.debug('  • Total: 100 batches per partition');
System.debug('  • 100 < 300 limit ✅');
System.debug('');
System.debug('Expected performance:');
System.debug('  • 10 parallel × 2,000 records/batch');
System.debug('  • ~100 batches per partition');
System.debug('  • ~3-4 hours total');
System.debug('');
System.debug('Monitor: Setup → Apex Jobs');
System.debug('Progress: sf apex run --file check_partition_progress.apex');
System.debug('════════════════════════════════════════════════════════════════');




