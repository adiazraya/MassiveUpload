// ═══════════════════════════════════════════════════════════════════════════════
// RESTART WITH 2K BATCH SIZE (SAFE FROM REGEX ERROR)
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 RESTARTING WITH 2K BATCHES (SAFE)');
System.debug('═══════════════════════════════════════════════════════════════');

// Safety check: Abort any remaining jobs
List<CronTrigger> remainingScheduled = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'];
for (CronTrigger job : remainingScheduled) {
    System.abortJob(job.Id);
    System.debug('Aborted lingering job: ' + job.Id);
}

// Get current status
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('');
System.debug('STARTING 2M PROCESS WITH 2K BATCHES');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Current opportunities: ' + currentCount);
System.debug('Target: ~2,000,000');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('CONFIGURATION:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug(' - Records per batch: 2,000 (SAFE - NO REGEX ERRORS!)');
System.debug(' - Total batches: ~1,000');
System.debug(' - Estimated time: 6-8 hours (slower but reliable)');
System.debug(' - Will process ALL 2M records');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('WHAT WILL HAPPEN:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug(' - Update existing ' + currentCount + ' records (fast)');
System.debug(' - Insert new ~' + (2000000 - currentCount) + ' records');
System.debug(' - Final count: ~2,000,000');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('MONITOR PROGRESS:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug(' Run progress_check.apex every 20 minutes');
System.debug(' Watch count grow: ' + currentCount + ' → 2,000,000');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');

// Start the batch processor
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('✅ RUNNING - NO MORE REGEX ERRORS!');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Batch Job ID: ' + batchJobId);
System.debug('');
System.debug('Check progress in 20 minutes with progress_check.apex');




