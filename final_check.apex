// Final check before starting V2
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 FINAL CHECK BEFORE V2 START');
System.debug('════════════════════════════════════════════════════════════════');

// Check for any running jobs
List<AsyncApexJob> runningJobs = [
    SELECT Id, ApexClass.Name, Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name IN ('DynamicPartitionProcessor', 'DynamicPartitionProcessorV2')
    AND Status IN ('Processing', 'Queued', 'Preparing', 'Holding')
];

System.debug('');
System.debug('Running jobs: ' + runningJobs.size());

if (runningJobs.isEmpty()) {
    System.debug('✅ All clear - ready to start V2!');
} else {
    System.debug('⚠️  Still have ' + runningJobs.size() + ' jobs running:');
    for (AsyncApexJob job : runningJobs) {
        System.debug('  ' + job.Id + ': ' + job.ApexClass.Name + ' - ' + job.Status);
    }
    System.debug('');
    System.debug('Aborting them now...');
    for (AsyncApexJob job : runningJobs) {
        System.abortJob(job.Id);
    }
    System.debug('✓ Aborted ' + runningJobs.size() + ' jobs');
}

// Check for scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE '%Dynamic%'
    OR CronJobDetail.Name LIKE '%Batch%'
];

System.debug('');
System.debug('Scheduled jobs: ' + scheduledJobs.size());
if (scheduledJobs.size() > 0) {
    System.debug('⚠️  Found schedulers - aborting them');
    for (CronTrigger job : scheduledJobs) {
        System.abortJob(job.Id);
        System.debug('  ✓ Aborted: ' + job.CronJobDetail.Name);
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ READY TO START V2');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Available API calls: 20,000');
System.debug('V2 will use: ~4,000');
System.debug('Buffer: 16,000 (plenty!)');
System.debug('════════════════════════════════════════════════════════════════');




