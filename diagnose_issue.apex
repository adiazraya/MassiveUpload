// COMPREHENSIVE DIAGNOSTIC
System.debug('══════════════════════════════════════════════════════════════');
System.debug('DIAGNOSTIC CHECK');
System.debug('══════════════════════════════════════════════════════════════');

// 1. Check total records in Data Cloud
System.debug('\n1. DATA CLOUD RECORD COUNT:');
ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
input.sql = 'SELECT COUNT(*) as total_count FROM ExtOpportunities__dlm';
ConnectApi.CdpQueryOutputV2 result = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
if (result.data != null && result.data.size() > 0) {
    ConnectApi.CdpQueryV2Row row = result.data[0];
    String jsonStr = JSON.serialize(row);
    List<Object> rowList = (List<Object>) JSON.deserializeUntyped(jsonStr);
    System.debug('   Total in Data Cloud: ' + rowList[0]);
}

// 2. Check Salesforce Opportunities
System.debug('\n2. SALESFORCE OPPORTUNITY COUNT:');
Integer totalOpps = [SELECT COUNT() FROM Opportunity];
System.debug('   Total in Salesforce: ' + totalOpps);

// 3. Check batch job history
System.debug('\n3. BATCH JOB HISTORY (Last 24 hours):');
List<AsyncApexJob> jobs = [
    SELECT Id, Status, CreatedDate, CompletedDate, 
           JobItemsProcessed, TotalJobItems, NumberOfErrors, 
           ExtendedStatus
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = LAST_N_DAYS:1
    ORDER BY CreatedDate DESC
    LIMIT 50
];
System.debug('   Total jobs found: ' + jobs.size());

Integer completedJobs = 0;
Integer failedJobs = 0;
Integer runningJobs = 0;
Integer totalProcessed = 0;

for (AsyncApexJob job : jobs) {
    if (job.Status == 'Completed') {
        completedJobs++;
        totalProcessed += job.JobItemsProcessed;
    } else if (job.Status == 'Failed' || job.Status == 'Aborted') {
        failedJobs++;
        System.debug('   ⚠ Failed/Aborted: ' + job.Id + ' - ' + job.ExtendedStatus);
    } else if (job.Status == 'Processing' || job.Status == 'Queued') {
        runningJobs++;
    }
}

System.debug('   Completed: ' + completedJobs);
System.debug('   Failed/Aborted: ' + failedJobs);
System.debug('   Running/Queued: ' + runningJobs);
System.debug('   Total batches processed: ' + totalProcessed);
System.debug('   Expected records processed: ' + (totalProcessed * 1000));

// 4. Check scheduled jobs
System.debug('\n4. SCHEDULED JOBS:');
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
    ORDER BY NextFireTime
];
System.debug('   Scheduled jobs: ' + scheduledJobs.size());
for (CronTrigger job : scheduledJobs) {
    System.debug('   - ' + job.CronJobDetail.Name + ' (State: ' + job.State + ', Next: ' + job.NextFireTime + ')');
}

// 5. Sample check - Recent opportunities
System.debug('\n5. RECENT OPPORTUNITIES (Last 10):');
List<Opportunity> sampleOpps = [
    SELECT Id, Name, CreatedDate
    FROM Opportunity 
    ORDER BY CreatedDate DESC 
    LIMIT 10
];
for (Opportunity opp : sampleOpps) {
    System.debug('   ' + opp.Name + ' (Created: ' + opp.CreatedDate + ')');
}

// 6. Check if any recent opportunities were created
System.debug('\n6. RECENT OPPORTUNITY CREATION:');
List<AggregateResult> recentCreated = [
    SELECT COUNT(Id) cnt, DAY_ONLY(CreatedDate) createdDay
    FROM Opportunity
    WHERE CreatedDate = LAST_N_DAYS:1
    GROUP BY DAY_ONLY(CreatedDate)
    ORDER BY DAY_ONLY(CreatedDate) DESC
];
for (AggregateResult ar : recentCreated) {
    System.debug('   ' + ar.get('createdDay') + ': ' + ar.get('cnt') + ' created');
}

// 7. Check the last batch that ran
System.debug('\n7. LAST BATCH DETAILS:');
if (jobs.size() > 0) {
    AsyncApexJob lastJob = jobs[0];
    System.debug('   Status: ' + lastJob.Status);
    System.debug('   Created: ' + lastJob.CreatedDate);
    System.debug('   Completed: ' + lastJob.CompletedDate);
    System.debug('   Items Processed: ' + lastJob.JobItemsProcessed);
    System.debug('   Errors: ' + lastJob.NumberOfErrors);
    System.debug('   Extended Status: ' + lastJob.ExtendedStatus);
}

System.debug('\n══════════════════════════════════════════════════════════════');
System.debug('DIAGNOSTIC COMPLETE');
System.debug('══════════════════════════════════════════════════════════════');

