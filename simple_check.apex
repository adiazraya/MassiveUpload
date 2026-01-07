// Simple check - just count and recent jobs
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Current: ' + count);

List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 3
];

System.debug('Recent jobs: ' + jobs.size());
for (AsyncApexJob job : jobs) {
    System.debug(job.Status + ' | Errors: ' + job.NumberOfErrors);
    if (String.isNotBlank(job.ExtendedStatus)) {
        System.debug('Error: ' + job.ExtendedStatus);
    }
}




