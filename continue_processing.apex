// ════════════════════════════════════════════════════════════════════════════════
// CONTINUE PROCESSING - Resume from offset 2M to completion
// ════════════════════════════════════════════════════════════════════════════════

System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔄 RESUMING PROCESSING FROM OFFSET 2,000,000');
System.debug('════════════════════════════════════════════════════════════════');

// Start a single continuous batch from offset 2M
DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
    2000000,  // Start from where we stopped
    2000000,  // Total already processed (by partitions)
    1000,     // Total API calls already made
    0         // No limit - process until end
);
batch.setPartitionInfo(-1, 'ContinuationBatch');

Id batchId = Database.executeBatch(batch, 1);

System.debug('✓ Started continuation batch (Job ID: ' + batchId + ')');
System.debug('  Starting offset: 2,000,000');
System.debug('  Will process until no more records');
System.debug('');
System.debug('Expected: ~685,000 additional records');
System.debug('Time: ~30-45 minutes');
System.debug('');
System.debug('Monitor: run check_partition_progress.apex');
System.debug('════════════════════════════════════════════════════════════════');




