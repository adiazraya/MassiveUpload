// EMERGENCY STOP - Abort single partition test
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🛑 STOPPING SINGLE PARTITION TEST');
System.debug('════════════════════════════════════════════════════════════════');

List<AsyncApexJob> runningJobs = [
    SELECT Id, ApexClass.Name, Status
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing', 'Holding')
];

System.debug('Found ' + runningJobs.size() + ' running jobs');

for (AsyncApexJob job : runningJobs) {
    System.abortJob(job.Id);
    System.debug('✓ Aborted: ' + job.Id);
}

System.debug('');
System.debug('✅ All jobs stopped');
System.debug('════════════════════════════════════════════════════════════════');




