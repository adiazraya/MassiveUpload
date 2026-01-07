// Deep diagnostic - why did it stop again?
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 DEEP DIAGNOSTIC');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Count
Integer oppCount = [SELECT COUNT() FROM Opportunity WHERE External_ID__c LIKE 'externalOpp%'];
System.debug('');
System.debug('Opportunities: ' + oppCount + ' / 2,000,000');
System.debug('Missing: ' + (2000000 - oppCount));

// 2. Running jobs
List<AsyncApexJob> running = [
    SELECT Id, Status, JobItemsProcessed, NumberOfErrors, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
    ORDER BY CreatedDate DESC
];

System.debug('');
System.debug('Running Jobs: ' + running.size());
if (running.isEmpty()) {
    System.debug('⚠️  NO JOBS RUNNING!');
}

// 3. Recent errors
List<AsyncApexJob> errors = [
    SELECT Id, Status, NumberOfErrors, ExtendedStatus, CompletedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND (Status = 'Failed' OR NumberOfErrors > 0)
    ORDER BY CompletedDate DESC
    LIMIT 3
];

System.debug('');
System.debug('Recent Errors: ' + errors.size());
for (AsyncApexJob job : errors) {
    System.debug('  ' + job.Id + ': ' + job.ExtendedStatus);
}

// 4. Check partition progress records
List<DataCloudPartition__c> partitions = [
    SELECT Name, CurrentOffset__c, TotalProcessed__c, Status__c
    FROM DataCloudPartition__c
    ORDER BY Name
];

System.debug('');
System.debug('Partition Progress:');
for (DataCloudPartition__c p : partitions) {
    System.debug('  ' + p.Name + ': offset=' + p.CurrentOffset__c + 
                 ', processed=' + p.TotalProcessed__c + ', status=' + p.Status__c);
}

// 5. Check if all jobs completed
List<AsyncApexJob> completed = [
    SELECT Id, CompletedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND Status = 'Completed'
    ORDER BY CompletedDate DESC
    LIMIT 1
];

if (!completed.isEmpty()) {
    System.debug('');
    System.debug('Last completion: ' + completed[0].CompletedDate);
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




