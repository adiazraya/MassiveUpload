// ════════════════════════════════════════════════════════════════════════════════
// SCHEDULE DAILY SYNC - Runs every night at 2 AM
// ════════════════════════════════════════════════════════════════════════════════

System.debug('Scheduling daily sync to run every night at 2 AM...');

// Cancel any existing schedules
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE '%Daily Sync%'
];

for (CronTrigger job : existingJobs) {
    System.abortJob(job.Id);
    System.debug('Cancelled: ' + job.CronJobDetail.Name);
}

// Schedule for 2 AM every day
String cronExp = '0 0 2 * * ?';  // At 2:00 AM every day
String jobId = System.schedule('Daily Sync - 2 AM', cronExp, new DailySyncScheduler());

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ DAILY SYNC SCHEDULED');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Job ID: ' + jobId);
System.debug('Schedule: Every day at 2:00 AM');
System.debug('');
System.debug('What it does:');
System.debug('  1. Queries ALL records from Data Cloud');
System.debug('  2. UPSERTs to Salesforce Opportunities via Bulk API');
System.debug('  3. Self-schedules until complete');
System.debug('  4. Stops automatically when done');
System.debug('');
System.debug('Expected time: 2-4 hours for 2M records');
System.debug('');
System.debug('To view: Setup → Scheduled Jobs');
System.debug('To cancel: System.abortJob(\'' + jobId + '\');');
System.debug('════════════════════════════════════════════════════════════════');




