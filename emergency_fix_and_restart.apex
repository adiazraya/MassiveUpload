// ═══════════════════════════════════════════════════════════════════════════════
// EMERGENCY FIX: Abort all jobs and restart with 2000 batch size
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚨 EMERGENCY ABORT - FIXING REGEX ERROR');
System.debug('═══════════════════════════════════════════════════════════════');

// Step 1: Abort all running and queued batches
List<AsyncApexJob> runningJobs = [
    SELECT Id, Status, JobItemsProcessed, TotalJobItems
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Found ' + runningJobs.size() + ' running jobs to abort');
for (AsyncApexJob job : runningJobs) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted job: ' + job.Id);
    } catch (Exception e) {
        System.debug('Failed to abort: ' + job.Id + ' - ' + e.getMessage());
    }
}

// Step 2: Abort all scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, NextFireTime 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];

System.debug('Found ' + scheduledJobs.size() + ' scheduled jobs to abort');
for (CronTrigger job : scheduledJobs) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted scheduled job: ' + job.Id);
    } catch (Exception e) {
        System.debug('Failed to abort: ' + job.Id + ' - ' + e.getMessage());
    }
}

System.debug('');
System.debug('⏳ Waiting for all jobs to stop... (check in 1 minute)');
System.debug('');

// Step 3: Get current opportunity count
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current opportunities: ' + currentCount);
System.debug('');

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('NEXT STEPS:');
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('1. Wait 1 minute for jobs to stop');
System.debug('2. Deploy the fixed DataCloudBatchProcessor (batch size = 2000)');
System.debug('3. Run restart_with_2k_batches.apex');
System.debug('═══════════════════════════════════════════════════════════════');




