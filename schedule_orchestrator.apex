// ════════════════════════════════════════════════════════════════════════════════
// SCHEDULE PARALLEL BATCH ORCHESTRATOR - Every Hour (24/7)
// ════════════════════════════════════════════════════════════════════════════════

System.debug('Scheduling ParallelBatchOrchestrator to run every hour...');

// Cancel any existing schedules first
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DC Sync%'
];

for (CronTrigger job : existingJobs) {
    System.abortJob(job.Id);
    System.debug('Cancelled: ' + job.CronJobDetail.Name);
}

// Schedule for every hour (00 minutes past the hour)
// We'll create 24 separate schedules to ensure continuous operation
List<String> jobIds = new List<String>();

for (Integer hour = 0; hour < 24; hour++) {
    String jobName = 'DC Sync - Hour ' + hour;
    String cronExp = '0 ' + hour + ' * * * ?';  // At minute 0 of specified hour, every day
    
    String jobId = System.schedule(jobName, cronExp, new ParallelBatchScheduler());
    jobIds.add(jobId);
    System.debug('✓ Scheduled: ' + jobName + ' (ID: ' + jobId + ')');
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ SUCCESS! Scheduled 24 jobs (runs every hour, 24/7)');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Each hour, the orchestrator will:');
System.debug('  1. Check all 10 partitions');
System.debug('  2. Start batches for partitions that need processing');
System.debug('  3. Each batch processes 2,000 records via Bulk API');
System.debug('');
System.debug('Expected: ~20,000 records/hour (10 partitions × 2K records)');
System.debug('Total time for 2M records: ~100 hours (continuous)');
System.debug('');
System.debug('To view scheduled jobs: Setup → Scheduled Jobs');
System.debug('To cancel all: Run cancel_scheduled_jobs.apex');
System.debug('════════════════════════════════════════════════════════════════');




