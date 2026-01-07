// Simple investigation - why only 387k?
System.debug('════════════════════════════════════════════════════════════════');

// Check partition status
List<DataCloudPartition__c> partitions = [
    SELECT Name, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
    FROM DataCloudPartition__c
    ORDER BY Name
];

System.debug('Partition Status:');
Integer totalProcessed = 0;
Integer totalCalls = 0;
for (DataCloudPartition__c p : partitions) {
    Integer processed = (p.TotalProcessed__c != null) ? Integer.valueOf(p.TotalProcessed__c) : 0;
    Integer calls = (p.TotalBulkAPICalls__c != null) ? Integer.valueOf(p.TotalBulkAPICalls__c) : 0;
    System.debug('  ' + p.Name + ': ' + processed + ' records, ' + calls + ' calls, ' + p.Status__c);
    totalProcessed += processed;
    totalCalls += calls;
}

System.debug('');
System.debug('Total Processed: ' + totalProcessed);
System.debug('Total Bulk API Calls: ' + totalCalls);
System.debug('');

// Check if jobs are still running
Integer runningJobs = [
    SELECT COUNT()
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Running Jobs: ' + runningJobs);
System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




