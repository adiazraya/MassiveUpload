// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSE STUCK PROCESS - Check what's happening
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🔍 DIAGNOSTIC CHECK - WHY IS IT STUCK?');
System.debug('═══════════════════════════════════════════════════════════════');

// 1. Check current opportunity count
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('');
System.debug('Current opportunities: ' + currentCount);
System.debug('');

// 2. Check if DataCloudBatchProcessor jobs are running
List<AsyncApexJob> runningJobs = [
    SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors,
           CreatedDate, CompletedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('════════════════════════════════════════════════════════════════════');
System.debug('RECENT BATCH JOBS (Last 10 Today):');
System.debug('════════════════════════════════════════════════════════════════════');
if (runningJobs.isEmpty()) {
    System.debug('❌ NO JOBS FOUND! The batch processor is not running!');
} else {
    for (AsyncApexJob job : runningJobs) {
        System.debug('Job ID: ' + job.Id);
        System.debug('  Status: ' + job.Status);
        System.debug('  Items Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
        System.debug('  Errors: ' + job.NumberOfErrors);
        System.debug('  Created: ' + job.CreatedDate);
        System.debug('  Completed: ' + job.CompletedDate);
        if (String.isNotBlank(job.ExtendedStatus)) {
            System.debug('  Extended Status: ' + job.ExtendedStatus);
        }
        System.debug('---');
    }
}
System.debug('');

// 3. Check scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];

System.debug('════════════════════════════════════════════════════════════════════');
System.debug('SCHEDULED JOBS:');
System.debug('════════════════════════════════════════════════════════════════════');
if (scheduledJobs.isEmpty()) {
    System.debug('⚠️  NO SCHEDULED JOBS! Self-scheduling might have stopped!');
} else {
    for (CronTrigger job : scheduledJobs) {
        System.debug('Job ID: ' + job.Id);
        System.debug('  Name: ' + job.CronJobDetail.Name);
        System.debug('  State: ' + job.State);
        System.debug('  Next Fire: ' + job.NextFireTime);
        System.debug('  Previous Fire: ' + job.PreviousFireTime);
        System.debug('---');
    }
}
System.debug('');

// 4. Check recent Bulk API jobs (last 5)
List<AsyncApexJob> bulkJobs = [
    SELECT Id, JobType, Status, JobItemsProcessed, TotalJobItems, 
           NumberOfErrors, CreatedDate
    FROM AsyncApexJob
    WHERE JobType = 'BatchApexWorker'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('════════════════════════════════════════════════════════════════════');
System.debug('RECENT APEX JOBS (Last 5 Today):');
System.debug('════════════════════════════════════════════════════════════════════');
for (AsyncApexJob job : bulkJobs) {
    System.debug('Job ID: ' + job.Id);
    System.debug('  Type: ' + job.JobType);
    System.debug('  Status: ' + job.Status);
    System.debug('  Errors: ' + job.NumberOfErrors);
    System.debug('  Created: ' + job.CreatedDate);
    System.debug('---');
}
System.debug('');

// 5. Check debug logs for errors (if available)
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('DIAGNOSIS SUMMARY:');
System.debug('════════════════════════════════════════════════════════════════════');

if (runningJobs.isEmpty()) {
    System.debug('❌ PROBLEM: No DataCloudBatchProcessor jobs found!');
    System.debug('   → The batch process is NOT running');
    System.debug('   → ACTION: Run restart_with_2k_batches.apex');
} else {
    Integer processingCount = 0;
    Integer failedCount = 0;
    Integer completedCount = 0;
    
    for (AsyncApexJob job : runningJobs) {
        if (job.Status == 'Processing' || job.Status == 'Queued' || job.Status == 'Preparing') {
            processingCount++;
        } else if (job.Status == 'Failed' || job.Status == 'Aborted') {
            failedCount++;
        } else if (job.Status == 'Completed') {
            completedCount++;
        }
    }
    
    System.debug('Recent jobs: ' + runningJobs.size() + ' total');
    System.debug('  - Processing/Queued: ' + processingCount);
    System.debug('  - Completed: ' + completedCount);
    System.debug('  - Failed/Aborted: ' + failedCount);
    System.debug('');
    
    if (processingCount == 0 && scheduledJobs.isEmpty()) {
        System.debug('⚠️  PROBLEM: No jobs currently running or scheduled!');
        System.debug('   → Self-scheduling stopped or all jobs completed');
        System.debug('   → ACTION: Run restart_with_2k_batches.apex');
    } else if (failedCount > 0) {
        System.debug('⚠️  PROBLEM: Recent jobs have failed!');
        System.debug('   → Check the ExtendedStatus messages above');
        System.debug('   → Might be HTTP errors, CPU limits, or other issues');
    } else {
        System.debug('✅ Jobs are running! Check:');
        System.debug('   1. Are they making HTTP callouts successfully?');
        System.debug('   2. Check Setup → Bulk Data Load Jobs for actual inserts');
        System.debug('   3. Might need to check Remote Site Settings');
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('NEXT STEPS:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('1. Review the diagnostics above');
System.debug('2. Check Setup → Environments → Jobs → Bulk Data Load Jobs');
System.debug('3. If no jobs running: Run restart_with_2k_batches.apex');
System.debug('4. If jobs failing: Check error messages and Remote Site Settings');
System.debug('════════════════════════════════════════════════════════════════════');




