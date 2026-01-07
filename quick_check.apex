// Quick progress check
System.debug('════════════════════════════════════════════════════════════════');
System.debug('⚡ QUICK PROGRESS CHECK');
System.debug('════════════════════════════════════════════════════════════════');

// Count opportunities with Test1 stage
Integer updatedOpps = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test1'];
System.debug('');
System.debug('Opportunities with StageName=Test1: ' + updatedOpps + ' / 2,000,000');
System.debug('Progress: ' + ((updatedOpps * 100.0) / 2000000.0).setScale(1) + '%');

// Count running V2 jobs
Integer runningJobs = [
    SELECT COUNT() 
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('');
System.debug('Running V2 Jobs: ' + runningJobs + ' / 10');

// Get total processed from partitions
Integer totalProcessed = 0;
for (DataCloudPartition__c p : [
    SELECT TotalProcessed__c 
    FROM DataCloudPartition__c 
    WHERE Name LIKE 'DynamicPartitionV2_%'
]) {
    if (p.TotalProcessed__c != null) {
        totalProcessed += Integer.valueOf(p.TotalProcessed__c);
    }
}

System.debug('');
System.debug('Records Processed by Batches: ' + totalProcessed);
System.debug('Estimated Completion: ' + ((totalProcessed * 100.0) / 2000000.0).setScale(1) + '%');

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
