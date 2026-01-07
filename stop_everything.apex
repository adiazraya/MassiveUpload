// STOP EVERYTHING
System.debug('🛑 STOPPING ALL PROCESSES');

// 1. Stop Test5 partitions
List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Partition_%'];
for (CronTrigger job : jobs) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted: ' + job.CronJobDetail.Name);
    } catch (Exception e) {}
}

// 2. Check for running batches
List<AsyncApexJob> batches = [
    SELECT Id, Status, ApexClass.Name 
    FROM AsyncApexJob 
    WHERE ApexClass.Name IN ('DynamicPartitionProcessorV2', 'DeleteTest4OpportunitiesBatch')
    AND Status IN ('Processing', 'Queued', 'Preparing')
];
System.debug('Running batches: ' + batches.size());

System.debug('');
System.debug('✅ STOPPED - Ready to fix SessionId issue');
