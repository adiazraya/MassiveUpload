// STOP ALL CURRENT PROCESSING
System.debug('🛑 STOPPING ALL PARTITIONS');

// Abort batch jobs
List<AsyncApexJob> jobs = [
    SELECT Id
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

for (AsyncApexJob job : jobs) {
    System.abortJob(job.Id);
}

System.debug('✓ Aborted ' + jobs.size() + ' batch jobs');

// Cancel scheduled partitions
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'Partition%'
];

for (CronTrigger ct : scheduledJobs) {
    System.abortJob(ct.Id);
}

System.debug('✓ Cancelled ' + scheduledJobs.size() + ' scheduled jobs');
System.debug('');
System.debug('✅ All stopped. Ready for Test4 with 500-record batches.');



