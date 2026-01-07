// Check what's happening - detailed analysis
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 DIAGNOSTIC CHECK');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Check partition status
List<DataCloudPartition__c> partitions = [
    SELECT Name, Status__c, TotalProcessed__c, TotalBulkAPICalls__c
    FROM DataCloudPartition__c
    WHERE Name LIKE 'StaggeredPartition_%'
    ORDER BY Name
];

System.debug('Partitions:');
for (DataCloudPartition__c p : partitions) {
    System.debug('  ' + p.Name + ':');
    System.debug('    Status: ' + p.Status__c);
    System.debug('    Processed: ' + p.TotalProcessed__c);
    System.debug('    API Calls: ' + p.TotalBulkAPICalls__c);
}

// 2. Check opportunity counts
Integer test4Count = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test4'];
Integer test5Count = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test5'];
System.debug('');
System.debug('Opportunity Counts:');
System.debug('  Test4: ' + test4Count);
System.debug('  Test5: ' + test5Count);

// 3. Check for any recent Test5 opportunities
List<Opportunity> recentTest5 = [
    SELECT Id, Name, StageName, External_ID__c, CreatedDate
    FROM Opportunity
    WHERE StageName = 'Test5'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('');
System.debug('Recent Test5 Opportunities: ' + recentTest5.size());
for (Opportunity opp : recentTest5) {
    System.debug('  ' + opp.External_ID__c + ' - ' + opp.Name + ' (Created: ' + opp.CreatedDate + ')');
}

// 4. Check running/completed batch jobs
List<AsyncApexJob> jobs = [
    SELECT Id, Status, ApexClass.Name, NumberOfErrors, JobItemsProcessed, TotalJobItems
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('');
System.debug('Recent Batch Jobs:');
for (AsyncApexJob job : jobs) {
    System.debug('  ' + job.Status + ' - ' + job.JobItemsProcessed + '/' + job.TotalJobItems + ' (Errors: ' + job.NumberOfErrors + ')');
}

System.debug('════════════════════════════════════════════════════════════════');

