// ABORT CURRENT SLOW PROCESS AND RESTART WITH 10K BATCHES
System.debug('══════════════════════════════════════════════════════════════');
System.debug('ABORTING SLOW PROCESS - RESTARTING WITH 10X SPEED');
System.debug('══════════════════════════════════════════════════════════════');

// 1. Current state
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + currentCount);

// 2. Abort all running batch jobs
List<AsyncApexJob> runningBatches = [
    SELECT Id, Status 
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor' 
    AND Status IN ('Processing', 'Queued', 'Preparing')
    LIMIT 100
];
System.debug('Found ' + runningBatches.size() + ' running batch jobs to abort');
// Note: Can't abort from Execute Anonymous, they'll finish their current batch

// 3. Abort scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}
System.debug('Aborted ' + scheduledJobs.size() + ' scheduled jobs');

System.debug('');
System.debug('IMPORTANT: Wait 1-2 minutes for running batches to complete');
System.debug('Then run: restart_with_10k_batches.apex');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');






