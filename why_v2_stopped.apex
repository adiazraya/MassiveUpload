// Check why V2 stopped
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 WHY DID V2 STOP?');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Total count
Integer totalOpps = 808407 + 372862 + 287183;
System.debug('');
System.debug('Total opportunities: ' + totalOpps);
System.debug('Qualification (updated by V2): 372,862');
System.debug('Discovery + Negotiation (old): ' + (808407 + 287183));
System.debug('Expected: 2,000,000 with Qualification');
System.debug('');

// 2. Check running V2 jobs
List<AsyncApexJob> runningJobs = [
    SELECT Id, Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing', 'Holding')
];

System.debug('Running V2 Jobs: ' + runningJobs.size());

// 3. Check V2 partition status
List<DataCloudPartition__c> partitions = [
    SELECT Name, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
    FROM DataCloudPartition__c
    WHERE Name LIKE 'DynamicPartitionV2_%'
    ORDER BY Name
];

System.debug('');
System.debug('Partition Status:');
Integer totalProcessed = 0;
for (DataCloudPartition__c p : partitions) {
    Integer processed = (p.TotalProcessed__c != null) ? Integer.valueOf(p.TotalProcessed__c) : 0;
    Integer calls = (p.TotalBulkAPICalls__c != null) ? Integer.valueOf(p.TotalBulkAPICalls__c) : 0;
    System.debug('  ' + p.Name + ': ' + processed + ' records, ' + calls + ' calls, ' + p.Status__c);
    totalProcessed += processed;
}

System.debug('');
System.debug('Total processed by V2: ' + totalProcessed);
System.debug('Total updated in SF: 372,862');
System.debug('Difference: ' + (totalProcessed - 372862));

// 4. Check for errors in last 10 V2 jobs
List<AsyncApexJob> recentJobs = [
    SELECT Id, Status, NumberOfErrors, ExtendedStatus, CompletedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND CreatedDate = TODAY
    ORDER BY CompletedDate DESC
    LIMIT 10
];

System.debug('');
System.debug('Last 10 V2 jobs:');
for (AsyncApexJob job : recentJobs) {
    System.debug('  ' + job.Id + ': ' + job.Status);
    if (job.NumberOfErrors > 0 || job.Status == 'Failed') {
        System.debug('    ERROR: ' + job.ExtendedStatus);
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




