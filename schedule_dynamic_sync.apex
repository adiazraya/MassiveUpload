// Schedule Dynamic Partitioning for 2 AM daily
System.debug('Scheduling Dynamic Partitioning for 2 AM daily...');

// Cancel any existing schedules
List<CronTrigger> existing = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name = 'Daily Sync - Dynamic Partitions - 2 AM'
];

for (CronTrigger job : existing) {
    System.abortJob(job.Id);
    System.debug('Cancelled existing job');
}

// Schedule for 2 AM every day
String cronExp = '0 0 2 * * ?';
String jobId = System.schedule('Daily Sync - Dynamic Partitions - 2 AM', cronExp, new DynamicPartitionScheduler());

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ SCHEDULED FOR 2 AM DAILY');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Job ID: ' + jobId);
System.debug('Schedule: Every day at 2:00 AM');
System.debug('');
System.debug('What it does:');
System.debug('  • Queries Data Cloud for ExternalId ranges');
System.debug('  • Creates 10 dynamic partitions');
System.debug('  • Processes ALL records (adapts to distribution)');
System.debug('  • Completes in 2-4 hours');
System.debug('');
System.debug('To view: Setup → Scheduled Jobs');
System.debug('To cancel: System.abortJob(\'' + jobId + '\');');
System.debug('════════════════════════════════════════════════════════════════');




