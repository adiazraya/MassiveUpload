// RESUME PROCESSING FROM WHERE IT STOPPED
System.debug('══════════════════════════════════════════════════════════════');
System.debug('RESUMING 2M RECORD PROCESS');
System.debug('══════════════════════════════════════════════════════════════');

// Current state
Integer beforeCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + beforeCount);
System.debug('Target: ~2,111,000 (111k original + 2M new)');
System.debug('Remaining: ~' + (2111000 - beforeCount));

// Abort any existing jobs
List<CronTrigger> scheduledJobs = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'DataCloud%'];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}
System.debug('Aborted ' + scheduledJobs.size() + ' scheduled jobs');

// Start from where we left off (50,000 records already processed)
// The offset will now properly increment!
DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
    50000,  // Start offset (50 batches * 1000 = 50,000)
    50000,  // Total processed so far
    50,     // Bulk API calls made so far
    0       // No limit
);
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✓ Batch started: ' + batchJobId);
System.debug('Starting from offset: 50,000');
System.debug('Remaining batches: ~1,950');
System.debug('Estimated time: 1-2 hours');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROCESS RESUMED');
System.debug('══════════════════════════════════════════════════════════════');






