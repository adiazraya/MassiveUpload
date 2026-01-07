// Schedule V2 for daily 2 AM runs
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🕐 SCHEDULING V2 FOR 2 AM DAILY');
System.debug('════════════════════════════════════════════════════════════════');

// Cancel existing schedules (both old and new)
List<CronTrigger> existing = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE '%Dynamic Partition%'
];

for (CronTrigger job : existing) {
    System.abortJob(job.Id);
    System.debug('✓ Cancelled: ' + job.CronJobDetail.Name);
}

System.debug('');
System.debug('Scheduling new V2 job...');
System.debug('');

// Schedule V2 for 2 AM every day
String cronExp = '0 0 2 * * ?';

// Note: You'll need to update DynamicPartitionScheduler to use V2
// For now, let's create a simple inline scheduler

String jobId = System.schedule(
    'Daily Sync V2 - 2 AM', 
    cronExp, 
    new DynamicPartitionScheduler()
);

System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ SCHEDULED V2 FOR 2 AM DAILY');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('Job ID: ' + jobId);
System.debug('Schedule: Every day at 2:00 AM');
System.debug('');
System.debug('⚠️  NOTE: You need to update DynamicPartitionScheduler.cls');
System.debug('to use DynamicPartitionProcessorV2 instead of DynamicPartitionProcessor');
System.debug('');
System.debug('View: Setup → Scheduled Jobs');
System.debug('════════════════════════════════════════════════════════════════');




