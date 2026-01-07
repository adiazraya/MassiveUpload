// TEST WITH NEW EXTERNAL IDs (outside existing range)
System.debug('══════════════════════════════════════════════════════════════');
System.debug('TESTING WITH NEW EXTERNAL IDs');
System.debug('══════════════════════════════════════════════════════════════');

// Clean up any running jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}

// Get current count
Integer beforeCount = [SELECT COUNT() FROM Opportunity];
System.debug('Opportunities before: ' + beforeCount);

// Check highest External ID
List<Opportunity> highest = [
    SELECT External_ID__c
    FROM Opportunity
    WHERE External_ID__c != null
    ORDER BY External_ID__c DESC
    LIMIT 1
];

if (highest.size() > 0) {
    System.debug('Highest External_ID__c: ' + highest[0].External_ID__c);
}

System.debug('');
System.debug('We will test with External IDs: externalOpp09999991 to externalOpp10000000');
System.debug('(These should NOT exist in the 465K)');
System.debug('');
System.debug('Starting test with 10 NEW records...');

// Start with limit of 10 records at a high offset
// If we have records 0-465399, offset 9999991 should give us new records
DataCloudBatchProcessor batch = new DataCloudBatchProcessor(10);
// We'll need to modify the code to start at a different offset
// For now, let's just check if this will work

System.debug('');
System.debug('⚠️  WAIT! The current code always starts at offset 0!');
System.debug('This means it will always try to insert records 1-10, which exist.');
System.debug('');
System.debug('SOLUTION OPTIONS:');
System.debug('1. Delete the 465K existing test opportunities first');
System.debug('2. Modify code to start at a higher offset (e.g., 1,000,000)');
System.debug('3. Run the full 2M process - it will update first 465K, then insert next 1.535M');
System.debug('');
System.debug('RECOMMENDATION:');
System.debug('Since this is a nightly sync process, and the Bulk API UPSERT is working,');
System.debug('let\'s just run the FULL 2M process!');
System.debug('It will:');
System.debug('  - Update existing 465,400 records (fast)');
System.debug('  - Insert remaining 1,534,600 NEW records');
System.debug('  - Take ~2-3 hours total');
System.debug('══════════════════════════════════════════════════════════════');





