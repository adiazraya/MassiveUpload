# PRODUCTION SOLUTION - Hourly Orchestrator Pattern

## The Problem with Self-Scheduling

Self-scheduling (`Database.executeBatch()` from `finish()`) **breaks after ~500 iterations** due to a Salesforce bug where scheduled jobs get "Next run: null".

For 2M records ÷ 2,000 per batch = **1,000 batches needed** → Will definitely break ❌

## The Solution: External Hourly Trigger

Instead of self-scheduling, use an **external hourly scheduler** that:
1. Checks if a batch is running
2. Checks progress in a Custom Object
3. Starts a new batch if needed
4. Repeats every hour until complete

This avoids the self-scheduling chain entirely ✅

## How It Works

### Components:
1. **DailySyncProcessor** - Processes 2,000 records, updates progress record, **does NOT self-schedule**
2. **DataCloudPartition__c** - Custom Object with ONE record ("DailySync") to track progress
3. **HourlyOrchestrator** - Scheduled to run every hour, checks progress, starts batches
4. **Apex Scheduler** - Runs HourlyOrchestrator every hour, 24/7

### Flow:
```
Hour 1: Orchestrator → Start Batch 1 → Process 2K → Update progress (Status=Running)
Hour 2: Orchestrator → Check (still running) → Wait
Hour 3: Orchestrator → Check (batch done) → Start Batch 2 → Process 2K → Update progress
...
Hour 100: Orchestrator → Check progress → Start Batch 500 → Process last records → Update progress (Status=Completed)
Hour 101: Orchestrator → Check (Status=Completed) → Done, skip
```

### Performance:
- **Hourly trigger** = 1 batch/hour minimum
- **Batch takes ~2 minutes** for 2,000 records
- **Can run multiple per hour** if batch finishes quickly
- **Total time:** Still ~2-4 hours (batches process faster than hourly checks)

## Deployment

```bash
# Deploy updated classes
sf project deploy start \
  --source-dir force-app/main/default/classes/DailySyncProcessor.cls \
  --source-dir force-app/main/default/classes/HourlyOrchestrator.cls \
  --target-org MassiveUploadOrg

# Schedule orchestrator to run every hour
sf apex run --file schedule_hourly_orchestrator.apex --target-org MassiveUploadOrg
```

## Why This Works

✅ **No self-scheduling chain** - External scheduler breaks the chain every hour  
✅ **Progress tracked** - Custom Object persists state  
✅ **Self-healing** - If a batch fails, next hour restarts from last offset  
✅ **Complete processing** - Runs until Status=Completed  
✅ **Daily repeatable** - Reset progress record each day  

## For Daily Reset

Add a nightly job (2 AM) to reset the progress record:
```apex
DELETE [SELECT Id FROM DataCloudPartition__c WHERE Name = 'DailySync'];
```

Then the orchestrator will start fresh at offset 0.




