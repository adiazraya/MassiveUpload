// Monitor single partition progress
System.debug('════════════════════════════════════════════════════════════════');
System.debug('📊 SINGLE PARTITION PROGRESS');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Check Salesforce count
Integer oppCount = [SELECT COUNT() FROM Opportunity WHERE External_ID__c LIKE 'externalOpp%'];
System.debug('');
System.debug('Total Opportunities: ' + oppCount + ' / 2,000,000');
System.debug('Progress: ' + ((oppCount * 100.0) / 2000000.0).setScale(1) + '%');

// 2. Check running jobs
Integer runningJobs = [
    SELECT COUNT()
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Running Jobs: ' + runningJobs);

// 3. Check partition progress
List<DataCloudPartition__c> partitions = [
    SELECT Name, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
    FROM DataCloudPartition__c
    WHERE Name = 'SinglePartition_Test'
    LIMIT 1
];

if (!partitions.isEmpty()) {
    DataCloudPartition__c p = partitions[0];
    Integer processed = (p.TotalProcessed__c != null) ? Integer.valueOf(p.TotalProcessed__c) : 0;
    Integer calls = (p.TotalBulkAPICalls__c != null) ? Integer.valueOf(p.TotalBulkAPICalls__c) : 0;
    
    System.debug('');
    System.debug('Partition Status: ' + p.Status__c);
    System.debug('  Processed: ' + processed + ' records');
    System.debug('  Bulk API Calls: ' + calls);
    System.debug('  Records per call: ' + (calls > 0 ? (processed / calls) : 0));
}

// 4. Check latest Bulk API job
List<AsyncApexJob> recentJobs = [
    SELECT Id, CompletedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status = 'Completed'
    ORDER BY CompletedDate DESC
    LIMIT 1
];

if (!recentJobs.isEmpty()) {
    System.debug('');
    System.debug('Last batch completed: ' + recentJobs[0].CompletedDate);
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Run this script every 15-30 minutes to monitor progress');
System.debug('════════════════════════════════════════════════════════════════');




