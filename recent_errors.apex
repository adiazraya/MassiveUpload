// Check recent batch jobs for errors
List<AsyncApexJob> jobs = [
    SELECT Status, NumberOfErrors, CompletedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('Recent batch jobs:');
for (AsyncApexJob job : jobs) {
    System.debug(job.Status + ' | Errors: ' + job.NumberOfErrors);
    if (String.isNotBlank(job.ExtendedStatus)) {
        System.debug('  ERROR: ' + job.ExtendedStatus.substring(0, Math.min(100, job.ExtendedStatus.length())));
    }
}




