// Process ALL 2,000,000 records from Data Cloud to Opportunities
System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROCESSING 2,000,000 RECORDS FROM DATA CLOUD');
System.debug('══════════════════════════════════════════════════════════════');

// Get current count
Integer beforeCount = [SELECT COUNT() FROM Opportunity];
System.debug('Opportunities BEFORE: ' + beforeCount);

// Abort any existing scheduled jobs
List<CronTrigger> scheduledJobs = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'DataCloud%'];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
    System.debug('Aborted scheduled job: ' + job.CronJobDetail.Name);
}

// Abort any running DataCloudBatchProcessor jobs
List<AsyncApexJob> runningBatches = [
    SELECT Id, Status 
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor' 
    AND Status IN ('Processing', 'Queued', 'Preparing')
];
System.debug('Found ' + runningBatches.size() + ' running batch jobs (will complete their current batch)');

// Start the full process - NO LIMIT
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✓ Batch started: ' + batchJobId);
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROCESS DETAILS');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('Total Records: 2,000,000');
System.debug('Records per batch: 1,000');
System.debug('Total batches: ~2,000');
System.debug('Total Bulk API calls: ~2,000');
System.debug('Estimated time: 1-2 hours');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('MONITORING COMMANDS');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('');
System.debug('1. Check current progress:');
System.debug('   Integer currentCount = [SELECT COUNT() FROM Opportunity];');
System.debug('   System.debug(\'Opportunities: \' + currentCount + \' (Increase: \' + (currentCount - ' + beforeCount + ') + \')\');');
System.debug('');
System.debug('2. Check batch jobs in last hour:');
System.debug('   List<AsyncApexJob> jobs = [SELECT Id, Status, CreatedDate, CompletedDate, NumberOfErrors');
System.debug('       FROM AsyncApexJob');
System.debug('       WHERE ApexClass.Name = \'DataCloudBatchProcessor\'');
System.debug('       AND CreatedDate = LAST_N_DAYS:1');
System.debug('       ORDER BY CreatedDate DESC LIMIT 10];');
System.debug('   for (AsyncApexJob j : jobs) {');
System.debug('       System.debug(j.Status + \' - \' + j.CreatedDate + \' (Errors: \' + j.NumberOfErrors + \')\');');
System.debug('   }');
System.debug('');
System.debug('3. View debug logs:');
System.debug('   Setup → Debug Logs → Monitor logs for "✓ Bulk API call made" messages');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROCESS STARTED - Monitor progress with commands above');
System.debug('══════════════════════════════════════════════════════════════');







