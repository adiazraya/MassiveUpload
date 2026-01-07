// Investigate why only 387k records were processed
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 INVESTIGATING EARLY STOP');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Check Salesforce counts by stage
List<AggregateResult> stageCount = [
    SELECT StageName, COUNT(Id) cnt
    FROM Opportunity 
    WHERE External_ID__c LIKE 'externalOpp%'
    GROUP BY StageName
];

System.debug('');
System.debug('Opportunities by Stage:');
for (AggregateResult ar : stageCount) {
    System.debug('  ' + ar.get('StageName') + ': ' + ar.get('cnt'));
}

Integer total = 1064797 + 387415;
System.debug('Total: ' + total);
System.debug('Expected: 2,000,000');
System.debug('Missing: ' + (2000000 - total));

// 2. Check how many batch jobs actually ran
List<AggregateResult> jobCount = [
    SELECT COUNT(Id) cnt
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND CreatedDate = TODAY
    AND Status = 'Completed'
];

Integer completedJobs = (Integer) jobCount[0].get('cnt');
System.debug('');
System.debug('Completed jobs today: ' + completedJobs);
System.debug('Expected: ~100-200 jobs (10 partitions × 10-20 batches each)');

// 3. Check partition progress
List<DataCloudPartition__c> partitions = [
    SELECT Name, CurrentOffset__c, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
    FROM DataCloudPartition__c
    ORDER BY Name
];

System.debug('');
System.debug('Partition Status:');
Integer totalProcessedAcrossPartitions = 0;
for (DataCloudPartition__c p : partitions) {
    System.debug('  ' + p.Name + ':');
    System.debug('    Offset: ' + p.CurrentOffset__c);
    System.debug('    Processed: ' + p.TotalProcessed__c);
    System.debug('    Bulk API Calls: ' + p.TotalBulkAPICalls__c);
    System.debug('    Status: ' + p.Status__c);
    if (p.TotalProcessed__c != null) {
        totalProcessedAcrossPartitions += Integer.valueOf(p.TotalProcessed__c);
    }
}

System.debug('');
System.debug('Total records processed (from partitions): ' + totalProcessedAcrossPartitions);
System.debug('Total records updated (from SF stage check): 387415');
System.debug('Difference: ' + (totalProcessedAcrossPartitions - 387415));

// 4. Check for any failed jobs
List<AsyncApexJob> failedJobs = [
    SELECT Id, Status, NumberOfErrors, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND CreatedDate = TODAY
    AND (Status = 'Failed' OR NumberOfErrors > 0)
    LIMIT 5
];

System.debug('');
System.debug('Failed jobs: ' + failedJobs.size());
for (AsyncApexJob job : failedJobs) {
    System.debug('  ' + job.Id + ': ' + job.Status + ' - ' + job.ExtendedStatus);
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




