// ABORT DELETION AND START FULL 2M PROCESS
System.debug('══════════════════════════════════════════════════════════════');
System.debug('ABORTING DELETION & STARTING FULL 2M PROCESS');
System.debug('══════════════════════════════════════════════════════════════');

// Abort all batch jobs (deletion + any scheduled processors)
List<AsyncApexJob> runningJobs = [
    SELECT Id, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems
    FROM AsyncApexJob
    WHERE Status IN ('Processing', 'Queued', 'Preparing')
    AND ApexClass.Name IN ('DeleteTestOpportunitiesBatch', 'DataCloudBatchProcessor')
];

System.debug('Found ' + runningJobs.size() + ' running/queued jobs');

for (AsyncApexJob job : runningJobs) {
    System.debug('  ' + job.ApexClass.Name + ' (' + job.Status + ')');
}

// Note: Can't abort AsyncApexJob from Apex, need to do manually in Setup
System.debug('');
System.debug('⚠️  TO ABORT DELETION:');
System.debug('1. Go to Setup → Apex Jobs');
System.debug('2. Find "DeleteTestOpportunitiesBatch"');
System.debug('3. Click Abort');
System.debug('');

// Clean up scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE '%Cloud%'
    OR CronJobDetail.Name LIKE '%Test%'
];

for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
    System.debug('Aborted scheduled: ' + job.CronJobDetail.Name);
}

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('STARTING FULL 2M PROCESS');
System.debug('══════════════════════════════════════════════════════════════');

Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current opportunities: ' + currentCount);
System.debug('');
System.debug('What will happen:');
System.debug('  - UPSERT existing ~' + currentCount + ' records (fast, just updates)');
System.debug('  - INSERT remaining ~' + (2000000 - currentCount) + ' NEW records');
System.debug('  - Total batches: ~200');
System.debug('  - Estimated time: 2-3 hours');
System.debug('  - Final count: ~2,000,000');
System.debug('');

// Start DataCloudBatchProcessor for ALL 2M records
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('✓ BATCH STARTED: ' + batchJobId);
System.debug('');
System.debug('MONITORING:');
System.debug('  Run check_what_happened.apex every 15 minutes');
System.debug('  Watch count grow from ' + currentCount + ' to 2,000,000');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('FULL 2M PROCESS RUNNING!');
System.debug('══════════════════════════════════════════════════════════════');





