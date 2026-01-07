// SCHEDULE THE NIGHTLY SYNC
// Run this once to set up the nightly automatic sync
System.debug('══════════════════════════════════════════════════════════════');
System.debug('SCHEDULING NIGHTLY OPPORTUNITY SYNC');
System.debug('══════════════════════════════════════════════════════════════');

// First, remove any existing scheduled jobs with same name
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Nightly Opportunity Sync'
];

for (CronTrigger job : existingJobs) {
    System.abortJob(job.Id);
    System.debug('Removed existing job: ' + job.Id);
}

// Schedule for every night at 2:00 AM
// Cron expression: Second Minute Hour Day Month Weekday
// '0 0 2 * * ?' = At 2:00 AM every day
String cronExp = '0 0 2 * * ?';

// You can change the time here:
// '0 0 1 * * ?' = 1:00 AM
// '0 30 3 * * ?' = 3:30 AM
// '0 0 23 * * ?' = 11:00 PM

String jobId = System.schedule('Nightly Opportunity Sync', cronExp, new NightlyOpportunitySyncScheduler());

System.debug('');
System.debug('✓ Job scheduled successfully!');
System.debug('Job ID: ' + jobId);
System.debug('Schedule: Every night at 2:00 AM');
System.debug('');
System.debug('To verify:');
System.debug('  Setup → Environments → Jobs → Scheduled Jobs');
System.debug('  Look for "Nightly Opportunity Sync"');
System.debug('');
System.debug('To unschedule:');
System.debug('  System.abortJob(\'' + jobId + '\');');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');






