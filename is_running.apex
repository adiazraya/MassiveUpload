// Just check if jobs are running
List<AsyncApexJob> jobs = [
    SELECT Id, Status 
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued')
];
System.debug('Active jobs: ' + jobs.size());

List<CronTrigger> scheduled = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];
System.debug('Scheduled: ' + scheduled.size());

if (jobs.size() == 0 && scheduled.size() == 0) {
    System.debug('❌ NOT RUNNING - Need to restart!');
} else {
    System.debug('✅ Running');
}




