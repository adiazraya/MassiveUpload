// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE DIAGNOSTIC: Why only 785,015 opportunities?
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🔍 DIAGNOSTIC: Why did processing stop at 785,015?');
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('');

// 1. Current status
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('📊 Current opportunities: ' + currentCount);
System.debug('📊 Expected: ~2,000,000');
System.debug('📊 Gap: ' + (2000000 - currentCount) + ' records');
System.debug('');

// 2. Check if batch is still running
List<AsyncApexJob> activeJobs = [
    SELECT Id, Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('════════════════════════════════════════════════════════════════════');
System.debug('BATCH STATUS:');
System.debug('════════════════════════════════════════════════════════════════════');
if (activeJobs.isEmpty()) {
    System.debug('❌ NO ACTIVE BATCHES - Process has stopped!');
} else {
    System.debug('✅ ' + activeJobs.size() + ' active batch(es) running');
}

// 3. Check scheduled jobs
List<CronTrigger> scheduled = [
    SELECT Id, CronJobDetail.Name, NextFireTime
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];

if (scheduled.isEmpty()) {
    System.debug('❌ NO SCHEDULED JOBS - Self-scheduling stopped!');
} else {
    System.debug('✅ ' + scheduled.size() + ' job(s) scheduled');
    System.debug('   Next run: ' + scheduled[0].NextFireTime);
}
System.debug('');

// 4. When was last opportunity modified?
List<Opportunity> recent = [
    SELECT LastModifiedDate, External_ID__c
    FROM Opportunity
    ORDER BY LastModifiedDate DESC
    LIMIT 1
];

System.debug('════════════════════════════════════════════════════════════════════');
System.debug('LAST ACTIVITY:');
System.debug('════════════════════════════════════════════════════════════════════');
if (!recent.isEmpty()) {
    Datetime lastMod = recent[0].LastModifiedDate;
    Long minsAgo = (Datetime.now().getTime() - lastMod.getTime()) / 60000;
    Long hoursAgo = minsAgo / 60;
    
    System.debug('Last modified: ' + lastMod.format('MM/dd HH:mm:ss'));
    System.debug('Time ago: ' + hoursAgo + ' hours ' + Math.mod(minsAgo, 60) + ' minutes');
    System.debug('External ID: ' + recent[0].External_ID__c);
    
    if (hoursAgo > 1) {
        System.debug('⚠️ Process stopped over 1 hour ago!');
    }
}
System.debug('');

// 5. Check Data Cloud record count
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('DATA CLOUD RECORD COUNT:');
System.debug('════════════════════════════════════════════════════════════════════');
try {
    ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
    input.sql = 'SELECT COUNT(*) as total FROM "ExtOpportunities__dlm"';
    ConnectApi.CdpQueryOutputV2 output = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
    
    if (!output.data.isEmpty()) {
        List<Object> row = (List<Object>) JSON.deserializeUntyped(JSON.serialize(output.data[0]));
        Integer dcCount = Integer.valueOf(String.valueOf(row[0]));
        
        System.debug('Records in Data Cloud: ' + dcCount);
        System.debug('Records in Salesforce: ' + currentCount);
        System.debug('Difference: ' + (dcCount - currentCount));
        System.debug('');
        
        if (dcCount < 2000000) {
            System.debug('⚠️ Data Cloud has FEWER than 2M records!');
            System.debug('   Expected: 2,000,000');
            System.debug('   Actual: ' + dcCount);
        } else if (currentCount >= dcCount) {
            System.debug('✅ ALL RECORDS SYNCED!');
        } else {
            System.debug('⚠️ Still ' + (dcCount - currentCount) + ' records to sync');
        }
    }
} catch (Exception e) {
    System.debug('❌ Could not query Data Cloud: ' + e.getMessage());
}
System.debug('');

// 6. Recent batch job history
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('RECENT BATCH JOBS (Last 10):');
System.debug('════════════════════════════════════════════════════════════════════');
List<AsyncApexJob> recentBatches = [
    SELECT Id, Status, NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    ORDER BY CreatedDate DESC
    LIMIT 10
];

for (AsyncApexJob job : recentBatches) {
    System.debug(job.Status + ' | Created: ' + job.CreatedDate.format('MM/dd HH:mm') + 
                 ' | Errors: ' + job.NumberOfErrors);
    if (String.isNotBlank(job.ExtendedStatus)) {
        System.debug('  Error: ' + job.ExtendedStatus);
    }
}
System.debug('');

// 7. Summary and recommendations
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('DIAGNOSIS SUMMARY:');
System.debug('════════════════════════════════════════════════════════════════════');

if (activeJobs.isEmpty() && scheduled.isEmpty()) {
    System.debug('❌ STOPPED: No active or scheduled jobs');
    System.debug('   CAUSE: Process stopped running');
    System.debug('   ACTION: Check last batch job error, then restart');
} else if (!activeJobs.isEmpty() || !scheduled.isEmpty()) {
    System.debug('✅ RUNNING: Process is still active');
    System.debug('   Just need to wait for completion');
} else {
    System.debug('⚠️ UNCLEAR: Need to check Bulk Data Load Jobs manually');
}

System.debug('');
System.debug('NEXT STEPS:');
System.debug('1. Check Setup → Bulk Data Load Jobs (last 50 jobs)');
System.debug('2. Look at failure rates');
System.debug('3. If stopped: Check ExtendedStatus above for errors');
System.debug('4. Run: check_where_it_stopped.apex to see exact offset');
System.debug('════════════════════════════════════════════════════════════════════');




