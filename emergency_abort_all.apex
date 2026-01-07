// EMERGENCY ABORT ALL JOBS
System.debug('══════════════════════════════════════════════════════════════');
System.debug('EMERGENCY: ABORT ALL DATACLOUD JOBS');
System.debug('══════════════════════════════════════════════════════════════');

// Step 1: Abort ALL scheduled jobs (stops the chain)
List<CronTrigger> allScheduled = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger 
];

Integer abortedScheduled = 0;
for (CronTrigger job : allScheduled) {
    try {
        System.abortJob(job.Id);
        System.debug('Aborted scheduled: ' + job.CronJobDetail.Name);
        abortedScheduled++;
    } catch (Exception e) {
        // Already aborted, ignore
    }
}
System.debug('✓ Aborted ' + abortedScheduled + ' scheduled jobs');

System.debug('');
System.debug('Step 2: Check running batch jobs');

List<AsyncApexJob> runningBatches = [
    SELECT Id, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems
    FROM AsyncApexJob
    WHERE Status IN ('Processing', 'Queued', 'Preparing')
    AND (ApexClass.Name = 'DataCloudBatchProcessor' 
         OR ApexClass.Name = 'DeleteTestOpportunitiesBatch')
    ORDER BY CreatedDate DESC
];

System.debug('Found ' + runningBatches.size() + ' active batch jobs:');
for (AsyncApexJob job : runningBatches) {
    System.debug('  - ' + job.ApexClass.Name + ' (' + job.Status + ') ' + 
                 job.JobItemsProcessed + '/' + job.TotalJobItems);
}

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('MANUAL STEP - DO THIS NOW:');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('1. Go to Setup → Apex Jobs');
System.debug('2. Quickly abort ALL "DataCloudBatchProcessor" jobs');
System.debug('3. Do it FAST before new ones spawn!');
System.debug('4. Also abort "DeleteTestOpportunitiesBatch" if any');
System.debug('');
System.debug('TIP: Keep the page open and refresh + abort repeatedly');
System.debug('      until no new jobs appear for 30 seconds');
System.debug('');
System.debug('THEN: Come back here and run check_all_stopped.apex');
System.debug('══════════════════════════════════════════════════════════════');

System.debug('');
System.debug('WHY THIS HAPPENS:');
System.debug('  The finish() method schedules the next batch automatically.');
System.debug('  Once you abort all active jobs, no new ones will spawn.');
System.debug('  The scheduled jobs are already aborted above.');
System.debug('══════════════════════════════════════════════════════════════');





