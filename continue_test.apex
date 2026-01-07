// CONTINUE TEST - Complete the remaining records
System.debug('══════════════════════════════════════════════════════════════');
System.debug('CONTINUING TEST WITH 10K BATCHES');
System.debug('══════════════════════════════════════════════════════════════');

// Current state
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + currentCount);
System.debug('Target: ~2,000,000');
System.debug('Remaining: ~' + (2000000 - currentCount));
System.debug('Progress: ' + (currentCount * 100 / 2000000) + '%');

// Abort any stuck jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}
System.debug('Cleaned up ' + scheduledJobs.size() + ' scheduled jobs');

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('STARTING TEST RUN');
System.debug('══════════════════════════════════════════════════════════════');

// Start from beginning with 10K batches
// UPSERT will update existing 1.5M and create remaining 700K
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✓ TEST BATCH STARTED: ' + batchJobId);
System.debug('');
System.debug('CONFIGURATION:');
System.debug('  Records per batch: 10,000');
System.debug('  Total batches: ~200');
System.debug('  Estimated time: ~2 hours');
System.debug('  Operation: UPSERT');
System.debug('');
System.debug('WHAT WILL HAPPEN:');
System.debug('  - Existing ' + currentCount + ' opps will be UPDATED');
System.debug('  - Remaining ~' + (2000000 - currentCount) + ' opps will be CREATED');
System.debug('  - No duplicates (External_ID__c is unique)');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('MONITORING');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Check progress every 15 minutes:');
System.debug('  Integer count = [SELECT COUNT() FROM Opportunity];');
System.debug('  System.debug(\'Count: \' + count + \' (\' + (count * 100 / 2000000) + \'%)\');');
System.debug('');
System.debug('Check batch status:');
System.debug('  List<AsyncApexJob> jobs = [');
System.debug('      SELECT Status, CreatedDate, NumberOfErrors');
System.debug('      FROM AsyncApexJob');
System.debug('      WHERE ApexClass.Name = \'DataCloudBatchProcessor\'');
System.debug('      AND CreatedDate = TODAY');
System.debug('      ORDER BY CreatedDate DESC LIMIT 5');
System.debug('  ];');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('TEST RUNNING - MONITOR FOR ~2 HOURS');
System.debug('══════════════════════════════════════════════════════════════');






