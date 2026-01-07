# Nightly Opportunity Sync - Production Setup Guide

## Overview
This solution syncs 2,000,000 opportunities from Data Cloud (`ExtOpportunities__dlm`) to Salesforce Opportunities every night using **UPSERT** (updates existing, creates new).

---

## Components

### 1. DataCloudBatchProcessor.cls
- Queries Data Cloud using `ConnectApi.CdpQuery.queryAnsiSqlV2()`
- Processes **10,000 records per batch**
- Makes Bulk API calls directly (no DML limits)
- Self-chains to process all 2M records (~200 batches)
- **Time:** ~2 hours for full sync

### 2. NightlyOpportunitySyncScheduler.cls
- Schedulable wrapper to run the sync automatically
- Checks for running batches (prevents overlap)
- Starts the `DataCloudBatchProcessor` at scheduled time

### 3. DeleteTestOpportunitiesBatch.cls
- Helper class to clean up test data
- Deletes all opportunities with `External_ID__c` field

---

## Testing Workflow

### Step 1: Clean Up Test Data
```apex
// Option A: Quick delete (if < 10K records)
Delete [SELECT Id FROM Opportunity WHERE External_ID__c != null];

// Option B: Batch delete (for large datasets)
// Run: delete_all_test_opps.apex
DeleteTestOpportunitiesBatch batch = new DeleteTestOpportunitiesBatch();
Database.executeBatch(batch, 2000);
```

### Step 2: Run Full Sync Test
```apex
// Run: restart_with_10k_batches.apex
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Database.executeBatch(batch, 1);
```

### Step 3: Monitor Progress
```apex
// Check every 15-20 minutes
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Opportunities: ' + count);
```

### Step 4: Verify Completion
```apex
// After ~2 hours, verify results
Integer finalCount = [SELECT COUNT() FROM Opportunity];
System.debug('Final count: ' + finalCount);
System.debug('Expected: ~2,000,000');

// Check for errors
List<AsyncApexJob> jobs = [
    SELECT Status, NumberOfErrors 
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
];
```

---

## Production Setup

### Schedule the Nightly Sync

**Method 1: Via Apex (Execute Anonymous)**
```apex
// Run: schedule_nightly_sync.apex
String cronExp = '0 0 2 * * ?';  // 2:00 AM daily
System.schedule('Nightly Opportunity Sync', cronExp, new NightlyOpportunitySyncScheduler());
```

**Method 2: Via Setup UI**
1. Go to **Setup → Apex Classes**
2. Click **Schedule Apex**
3. Select: `NightlyOpportunitySyncScheduler`
4. Set time (e.g., 2:00 AM)
5. Set frequency: Daily

### Cron Expressions
```
'0 0 1 * * ?'   = 1:00 AM daily
'0 0 2 * * ?'   = 2:00 AM daily (recommended)
'0 30 3 * * ?'  = 3:30 AM daily
'0 0 23 * * ?'  = 11:00 PM daily
```

---

## Performance Specs

| Metric | Value |
|--------|-------|
| **Total Records** | 2,000,000 |
| **Records per Batch** | 10,000 |
| **Total Batches** | ~200 |
| **Batch Duration** | ~30-40 seconds |
| **Total Time** | ~2 hours |
| **Bulk API Calls** | ~200 |
| **Governor Limits Safe** | ✅ Yes |

---

## Monitoring & Troubleshooting

### Check if Scheduled Job is Active
```apex
List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime 
    FROM CronTrigger 
    WHERE CronJobDetail.Name = 'Nightly Opportunity Sync'
];
for (CronTrigger job : jobs) {
    System.debug(job.CronJobDetail.Name + ' - Next run: ' + job.NextFireTime);
}
```

### Check Last Night's Run
```apex
List<AsyncApexJob> jobs = [
    SELECT Status, CreatedDate, CompletedDate, NumberOfErrors
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = YESTERDAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];
for (AsyncApexJob job : jobs) {
    System.debug(job.Status + ' - ' + job.CreatedDate + ' - Errors: ' + job.NumberOfErrors);
}
```

### Stop/Unschedule
```apex
// Get the job ID
List<CronTrigger> jobs = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name = 'Nightly Opportunity Sync'
];

// Abort all
for (CronTrigger job : jobs) {
    System.abortJob(job.Id);
}
```

---

## Field Mapping

| Data Cloud Field | Salesforce Field |
|-----------------|------------------|
| `externalid__c` | `External_ID__c` (unique identifier) |
| `name__c` | `Name` |
| `stagename__c` | `StageName` |
| `closedate__c` | `CloseDate` |
| `amount__c` | `Amount` |
| `account__c` | `AccountId` |

---

## Important Notes

### ✅ UPSERT Operation
- **External_ID__c** is the unique identifier
- Existing opportunities are **UPDATED** (not duplicated)
- New opportunities are **CREATED**
- Safe to run nightly - no duplicates!

### ✅ Governor Limits
- Uses Bulk API (bypasses DML limits)
- No heap/CPU issues with 10K batches
- Self-chains safely (no stack depth limit)

### ✅ Error Handling
- Bulk API errors are logged
- Failed records don't stop the process
- Check debug logs for details

### ⚠ Prerequisites
1. **External_ID__c** field must exist on Opportunity (unique, external ID)
2. **Remote Site Settings** must allow Bulk API endpoint
3. Data Cloud object `ExtOpportunities__dlm` must be accessible

---

## Quick Reference Scripts

| Script | Purpose |
|--------|---------|
| `delete_all_test_opps.apex` | Clean up test data |
| `restart_with_10k_batches.apex` | Run full sync manually |
| `schedule_nightly_sync.apex` | Schedule automatic nightly sync |
| `check_what_happened.apex` | Diagnose issues |

---

## Support

For issues, check:
1. Debug logs for the `DataCloudBatchProcessor` class
2. Bulk API job status in Salesforce (Setup → Bulk Data Load Jobs)
3. Scheduled job status (Setup → Scheduled Jobs)

**Expected behavior:** Process completes in ~2 hours, all 2M records synced, no errors.






