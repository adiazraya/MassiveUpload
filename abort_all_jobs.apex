// ═══════════════════════════════════════════════════════════════════════════════
// ABORT ALL JOBS - Before restarting with the fixed version
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🛑 ABORTING ALL JOBS');
System.debug('═══════════════════════════════════════════════════════════════');

// Abort running batches
List<AsyncApexJob> runningJobs = [
    SELECT Id, Status
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Aborting ' + runningJobs.size() + ' running jobs...');
for (AsyncApexJob job : runningJobs) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted: ' + job.Id);
    } catch (Exception e) {
        System.debug('Failed: ' + job.Id);
    }
}

// Abort scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];

System.debug('Aborting ' + scheduledJobs.size() + ' scheduled jobs...');
for (CronTrigger job : scheduledJobs) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted: ' + job.CronJobDetail.Name);
    } catch (Exception e) {
        System.debug('Failed: ' + job.Id);
    }
}

Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('');
System.debug('Current opportunities: ' + currentCount);
System.debug('');
System.debug('✅ All jobs aborted! Ready to restart with fix.');
System.debug('Next: Run restart_with_2min_delays.apex');




