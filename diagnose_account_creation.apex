// Check what happened with account creation
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 DIAGNOSING ACCOUNT CREATION FAILURE');
System.debug('════════════════════════════════════════════════════════════════');

// Check all MassiveAccountCreator jobs
List<AsyncApexJob> allJobs = [
    SELECT Id, Status, NumberOfErrors, ExtendedStatus, CompletedDate, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'MassiveAccountCreator'
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('');
System.debug('Account Creation Jobs:');
for (AsyncApexJob job : allJobs) {
    System.debug('  ' + job.Id + ': ' + job.Status);
    System.debug('    Created: ' + job.CreatedDate);
    if (job.CompletedDate != null) {
        System.debug('    Completed: ' + job.CompletedDate);
    }
    if (job.NumberOfErrors > 0 || job.Status == 'Failed') {
        System.debug('    ERROR: ' + job.ExtendedStatus);
    }
}

// Check if any accounts exist
Integer accountCount = [SELECT COUNT() FROM Account WHERE FirstName LIKE 'acc_test_massive_%'];
System.debug('');
System.debug('Accounts created: ' + accountCount);

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




