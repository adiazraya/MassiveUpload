// Cancel all scheduled DC Sync jobs
System.debug('Cancelling all DC Sync scheduled jobs...');

List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DC Sync%'
];

System.debug('Found ' + jobs.size() + ' scheduled jobs');

for (CronTrigger job : jobs) {
    System.abortJob(job.Id);
    System.debug('✓ Cancelled: ' + job.CronJobDetail.Name + ' (was: ' + job.State + ')');
}

System.debug('');
System.debug('✅ All DC Sync jobs cancelled');




