// Quick abort of scheduled jobs
List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Partition_%'];
System.debug('Found ' + jobs.size() + ' scheduled jobs');
for (CronTrigger job : jobs) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted: ' + job.CronJobDetail.Name);
    } catch (Exception e) {
        System.debug('⚠ Error: ' + e.getMessage());
    }
}
System.debug('✅ Done');


