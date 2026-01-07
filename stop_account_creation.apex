// Stop all MassiveAccountCreator jobs
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🛑 STOPPING ALL ACCOUNT CREATION JOBS');
System.debug('════════════════════════════════════════════════════════════════');

// Find all running/queued MassiveAccountCreator jobs
List<AsyncApexJob> jobsToAbort = [
    SELECT Id, Status, ApexClass.Name
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'MassiveAccountCreator'
    AND Status IN ('Queued', 'Processing', 'Preparing')
];

System.debug('');
System.debug('Found ' + jobsToAbort.size() + ' jobs to abort');
System.debug('');

Integer abortedCount = 0;
for (AsyncApexJob job : jobsToAbort) {
    try {
        System.abortJob(job.Id);
        System.debug('✓ Aborted job: ' + job.Id);
        abortedCount++;
    } catch (Exception e) {
        System.debug('✗ Failed to abort job ' + job.Id + ': ' + e.getMessage());
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ STOPPED ' + abortedCount + ' JOBS');
System.debug('════════════════════════════════════════════════════════════════');

// Count how many accounts were created before stopping
Integer accountCount = [
    SELECT COUNT() 
    FROM Account 
    WHERE FirstName = 'Test' AND LastName LIKE 'Massive_%'
];

System.debug('');
System.debug('Accounts created before stopping: ' + accountCount);
System.debug('');




