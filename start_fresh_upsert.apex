// START FRESH - Process all 2M records with UPSERT
// Existing records will be UPDATED, new records will be INSERTED
System.debug('══════════════════════════════════════════════════════════════');
System.debug('STARTING FRESH - UPSERT ALL 2,000,000 RECORDS');
System.debug('══════════════════════════════════════════════════════════════');

// Current state
Integer beforeCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + beforeCount);
System.debug('Target: ~2,111,000 (after processing all Data Cloud records)');

// Abort any existing jobs/scheduled jobs
List<CronTrigger> scheduledJobs = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'DataCloud%'];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
}
System.debug('Aborted ' + scheduledJobs.size() + ' scheduled jobs');

// Check for running batch jobs
List<AsyncApexJob> runningBatches = [
    SELECT Id, Status 
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor' 
    AND Status IN ('Processing', 'Queued', 'Preparing')
];
System.debug('Found ' + runningBatches.size() + ' running batch jobs (they will complete their current batch)');

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('STARTING NEW PROCESS');
System.debug('══════════════════════════════════════════════════════════════');

// Start from offset 0 - process ALL 2M records
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✓ Batch started: ' + batchJobId);
System.debug('Starting from offset: 0');
System.debug('Total records: 2,000,000');
System.debug('Total batches: ~2,000');
System.debug('Operation: UPSERT (updates existing, creates new)');
System.debug('Estimated time: 1-2 hours');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('MONITORING COMMANDS');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('');
System.debug('1. Check progress every 10-15 minutes:');
System.debug('   Integer currentCount = [SELECT COUNT() FROM Opportunity];');
System.debug('   System.debug(\'Opportunities: \' + currentCount);');
System.debug('');
System.debug('2. Check batch status:');
System.debug('   List<AsyncApexJob> jobs = [SELECT Status, CreatedDate, NumberOfErrors');
System.debug('       FROM AsyncApexJob WHERE ApexClass.Name = \'DataCloudBatchProcessor\'');
System.debug('       AND CreatedDate = TODAY ORDER BY CreatedDate DESC LIMIT 5];');
System.debug('   for (AsyncApexJob j : jobs) {');
System.debug('       System.debug(j.Status + \' - \' + j.CreatedDate);');
System.debug('   }');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROCESS STARTED - WITH FIXED OFFSET INCREMENT!');
System.debug('══════════════════════════════════════════════════════════════');

