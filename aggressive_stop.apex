// Keep aborting until all jobs are stopped
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🛑 AGGRESSIVE STOP - Keep aborting until all stopped');
System.debug('════════════════════════════════════════════════════════════════');

Integer totalAborted = 0;
Integer maxIterations = 5;

for (Integer i = 0; i < maxIterations; i++) {
    List<AsyncApexJob> runningJobs = [
        SELECT Id, ApexClass.Name, Status
        FROM AsyncApexJob 
        WHERE ApexClass.Name IN ('DynamicPartitionProcessor', 'DynamicPartitionProcessorV2')
        AND Status IN ('Processing', 'Queued', 'Preparing', 'Holding')
        ORDER BY CreatedDate DESC
    ];
    
    if (runningJobs.isEmpty()) {
        System.debug('');
        System.debug('✅ SUCCESS - All jobs stopped after ' + i + ' iterations');
        System.debug('Total aborted: ' + totalAborted);
        break;
    }
    
    System.debug('');
    System.debug('Iteration ' + (i + 1) + ': Found ' + runningJobs.size() + ' jobs, aborting...');
    
    for (AsyncApexJob job : runningJobs) {
        try {
            System.abortJob(job.Id);
            totalAborted++;
        } catch (Exception e) {
            System.debug('  Failed: ' + job.Id);
        }
    }
    
    if (i == maxIterations - 1) {
        System.debug('');
        System.debug('⚠️  Reached max iterations. Some jobs may still be running.');
        System.debug('Wait 30 seconds and run verify_stopped.apex');
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




