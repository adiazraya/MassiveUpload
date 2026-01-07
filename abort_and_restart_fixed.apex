// ABORT FAILED JOBS & RESTART WITH 5K BATCHES
System.debug('══════════════════════════════════════════════════════════════');
System.debug('ABORT & RESTART WITH FIXED BATCH SIZE (5K)');
System.debug('══════════════════════════════════════════════════════════════');

// Clean up scheduled jobs (these can be aborted from Apex)
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
];

System.debug('Aborting ' + scheduledJobs.size() + ' scheduled jobs...');
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}
System.debug('✓ Scheduled jobs aborted');

System.debug('');
System.debug('⚠️  MANUAL STEP REQUIRED:');
System.debug('1. Go to Setup → Apex Jobs');
System.debug('2. Abort any "DataCloudBatchProcessor" jobs that are:');
System.debug('   - Status: Processing, Queued, or Preparing');
System.debug('   - Have errors');
System.debug('');
System.debug('Then come back and continue below...');
System.debug('');

// Get current state
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('══════════════════════════════════════════════════════════════');
System.debug('CURRENT STATE');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('Current opportunities: ' + currentCount);
System.debug('Target: 2,000,000');
System.debug('Remaining: ' + (2000000 - currentCount));
System.debug('Progress: ' + (currentCount * 100 / 2000000) + '%');

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('AFTER ABORTING JOBS IN SETUP, RUN THIS:');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('');
System.debug('  DataCloudBatchProcessor batch = new DataCloudBatchProcessor();');
System.debug('  Database.executeBatch(batch, 1);');
System.debug('');
System.debug('This will:');
System.debug('  - Use 5,000 records per batch (was 10,000)');
System.debug('  - Total batches: ~400 (was 200)');
System.debug('  - No more "Regex too complicated" error!');
System.debug('  - Estimated time: 3-4 hours');
System.debug('  - Resume from offset: 0 (will UPSERT existing, INSERT new)');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');





