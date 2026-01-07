// ════════════════════════════════════════════════════════════════════════════════
// START CONTINUOUS PARALLEL PROCESSING - All 10 Partitions
// Each partition will self-schedule continuously until complete
// ════════════════════════════════════════════════════════════════════════════════

System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING CONTINUOUS PARALLEL PROCESSING');
System.debug('════════════════════════════════════════════════════════════════');

// First, cancel the hourly scheduled jobs (we don't need them anymore)
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DC Sync%'
];

for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}
System.debug('✓ Cancelled ' + scheduledJobs.size() + ' hourly scheduled jobs');
System.debug('');

// Get all 10 partitions
List<DataCloudPartition__c> partitions = [
    SELECT Name, PartitionId__c, CurrentOffset__c, TotalProcessed__c, 
           TotalBulkAPICalls__c, Status__c
    FROM DataCloudPartition__c
    ORDER BY PartitionId__c
];

System.debug('Found ' + partitions.size() + ' partitions');
System.debug('');

// Start a batch for each partition
Integer started = 0;
for (DataCloudPartition__c part : partitions) {
    if (part.Status__c != 'Completed') {
        // Calculate starting offset for this partition
        Integer partitionId = Integer.valueOf(part.PartitionId__c);
        Integer partitionStartOffset = partitionId * 200000; // Each partition handles 200k records
        Integer currentOffset = partitionStartOffset + Integer.valueOf(part.CurrentOffset__c);
        
        // Start the batch
        DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
            currentOffset,
            Integer.valueOf(part.TotalProcessed__c),
            Integer.valueOf(part.TotalBulkAPICalls__c),
            0 // No limit, process until partition end
        );
        batch.setPartitionInfo(partitionId, part.Name);
        
        Id batchId = Database.executeBatch(batch, 1);
        
        System.debug('✓ Started ' + part.Name + ' (Job ID: ' + batchId + ')');
        System.debug('  Starting offset: ' + currentOffset);
        started++;
    } else {
        System.debug('⊘ ' + part.Name + ' already completed, skipping');
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ STARTED ' + started + ' PARALLEL BATCHES');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Each batch will:');
System.debug('  1. Process 2,000 records');
System.debug('  2. Send to Bulk API');
System.debug('  3. Immediately schedule next batch');
System.debug('  4. Repeat until partition complete');
System.debug('');
System.debug('Expected performance:');
System.debug('  10 partitions × 2,000 records × ~50 batches/hour');
System.debug('  = ~1,000,000 records/hour');
System.debug('  = ~2 hours for 2M records! 🚀');
System.debug('');
System.debug('Monitor: Setup → Apex Jobs');
System.debug('Progress: run check_partition_progress.apex');
System.debug('Stop all: run emergency_stop.apex');
System.debug('════════════════════════════════════════════════════════════════');




