// Check Platform Event version status
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('PLATFORM EVENT VERSION - DIAGNOSTIC');
System.debug('═══════════════════════════════════════════════════════════════');

// 1. Current count
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Current count: ' + count);

// 2. Last update time
List<Opportunity> recent = [
    SELECT LastModifiedDate FROM Opportunity
    ORDER BY LastModifiedDate DESC LIMIT 1
];
if (!recent.isEmpty()) {
    Long minsAgo = (Datetime.now().getTime() - recent[0].LastModifiedDate.getTime()) / 60000;
    System.debug('Last update: ' + minsAgo + ' min ago');
}

// 3. Active batch jobs
List<AsyncApexJob> batches = [
    SELECT Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued')
];
System.debug('Active batches: ' + batches.size());

// 4. Recent batch jobs (completed)
List<AsyncApexJob> recentBatches = [
    SELECT Status, NumberOfErrors, CreatedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    ORDER BY CreatedDate DESC
    LIMIT 3
];
System.debug('Recent batches:');
for (AsyncApexJob job : recentBatches) {
    System.debug('  ' + job.Status + ' | ' + job.CreatedDate.format('HH:mm:ss') + ' | Errors: ' + job.NumberOfErrors);
    if (String.isNotBlank(job.ExtendedStatus)) {
        System.debug('    Error: ' + job.ExtendedStatus.substring(0, Math.min(100, job.ExtendedStatus.length())));
    }
}

// 5. Scheduled jobs (DelayedBatch*)
List<CronTrigger> scheduled = [
    SELECT Id, CronJobDetail.Name, NextFireTime, State
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DelayedBatch%'
];
System.debug('DelayedBatch scheduled jobs: ' + scheduled.size());
for (CronTrigger job : scheduled) {
    System.debug('  ' + job.CronJobDetail.Name + ' | Next: ' + job.NextFireTime + ' | State: ' + job.State);
}

// 6. Queueable jobs
List<AsyncApexJob> queueables = [
    SELECT Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DelayedBatchStarter'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 3
];
System.debug('DelayedBatchStarter jobs today: ' + queueables.size());

System.debug('');
System.debug('DIAGNOSIS:');
if (batches.size() > 0) {
    System.debug('✅ Batch is running');
} else if (scheduled.size() > 0) {
    System.debug('⏰ Waiting for scheduled job to fire');
} else if (queueables.size() > 0) {
    System.debug('⚙️ Queueable processing');
} else {
    System.debug('❌ NOTHING RUNNING - Check for errors above');
}




