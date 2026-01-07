// EMERGENCY STOP - Abort ALL running batch jobs
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🛑 EMERGENCY STOP - ABORTING ALL BATCHES');
System.debug('════════════════════════════════════════════════════════════════');

// Get all running/queued DynamicPartitionProcessor jobs (both V1 and V2)
List<AsyncApexJob> runningJobs = [
    SELECT Id, ApexClass.Name, Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name IN ('DynamicPartitionProcessor', 'DynamicPartitionProcessorV2')
    AND Status IN ('Processing', 'Queued', 'Preparing', 'Holding')
    ORDER BY CreatedDate DESC
];

System.debug('');
System.debug('Found ' + runningJobs.size() + ' running jobs');
System.debug('');

if (runningJobs.isEmpty()) {
    System.debug('✅ No jobs running');
} else {
    // Abort them
    for (AsyncApexJob job : runningJobs) {
        try {
            System.abortJob(job.Id);
            System.debug('✓ Aborted: ' + job.Id + ' (' + job.ApexClass.Name + ', ' + job.Status + ')');
        } catch (Exception e) {
            System.debug('✗ Failed to abort ' + job.Id + ': ' + e.getMessage());
        }
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ EMERGENCY STOP COMPLETE');
System.debug('════════════════════════════════════════════════════════════════');




