// EMERGENCY STOP - Abort all running batches
System.debug('🛑 EMERGENCY STOP - Aborting all batches...');

List<AsyncApexJob> runningBatches = [
    SELECT Id, Status, ApexClass.Name
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Found ' + runningBatches.size() + ' running batches');

for (AsyncApexJob job : runningBatches) {
    System.abortJob(job.Id);
    System.debug('✓ Aborted job: ' + job.Id);
}

// Also cancel scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DC Sync%'
];

for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}

System.debug('');
System.debug('✅ All batches stopped');
System.debug('Total stopped: ' + (runningBatches.size() + scheduledJobs.size()));




