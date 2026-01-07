# Creating the Scheduled Flow for Parallel Processing

## Prerequisites
Before creating the flow, ensure:
1. ✅ `DataCloudPartition__c` object has all 6 custom fields created
2. ✅ `ParallelBatchOrchestrator` Apex class is deployed
3. ✅ 10 partition records are initialized (run `init_partitions_dynamic.apex`)

---

## Step-by-Step Instructions

### 1. Navigate to Flow Builder
1. In Salesforce, click the **⚙️ gear icon** (Setup)
2. In Quick Find, search for **"Flows"**
3. Click **Flows**
4. Click **New Flow**

### 2. Choose Flow Type
1. Select **Schedule-Triggered Flow**
2. Click **Create**

### 3. Configure the Schedule
1. In the Start element (automatically added):
   - **Flow Label**: `Data Cloud Sync - Parallel Processor`
   - **API Name**: `Data_Cloud_Sync_Parallel_Processor`
   
2. **Set Schedule**:
   - **Frequency**: Recurring
   - **Start Date**: Today
   - **Start Time**: Now (or whenever you want to start)
   - **Repeat**: Every **5 Minutes**
   - **End**: Never (or set a future date if testing)

3. **Set Schedule Optimization**:
   - Leave default settings
   - Click **Done**

### 4. Add the Orchestrator Action
1. From the toolbox on the left, click the **➕** button
2. Select **Action**
3. In the search box, type: `Check and Start Parallel Batches`
4. Select **Check and Start Parallel Batches** (from ParallelBatchOrchestrator class)
5. **Label**: `Check and Start Batches`
6. **API Name**: `Check_and_Start_Batches`
7. Click **Done**

**Note:** This action has no required input parameters - it automatically manages all 10 partitions.

### 5. Save and Activate
1. Click **Save**
2. Confirm the flow details
3. Click **Activate**
4. Confirm activation

---

## What Happens Next

Once activated, the flow will:

1. **Every 5 minutes**, check the status of all 10 partitions
2. **For each partition**:
   - If it's not running and has more records → Start a batch
   - If it's running → Wait for it to finish
   - If it's complete → Mark as done
3. **Each batch** processes 2,000 Data Cloud records and sends them to Bulk API
4. **All 10 partitions** run in parallel

---

## Expected Performance

```
10 partitions × 2,000 records/batch × 12 batches/hour
= ~240,000 records/hour
= ~2,000,000 records in 8-12 hours
```

---

## Monitoring Progress

### Option 1: Check Records in Salesforce
```sql
SELECT Name, Status__c, CurrentOffset__c, TotalProcessed__c, 
       TotalBulkAPICalls__c, LastBatchStarted__c
FROM DataCloudPartition__c
ORDER BY PartitionId__c
```

Run this SOQL query in:
- Developer Console → Query Editor
- Workbench
- VS Code with Salesforce Extension

### Option 2: Check from Anonymous Apex
Create a monitoring script:

```apex
List<DataCloudPartition__c> partitions = [
    SELECT Name, Status__c, CurrentOffset__c, TotalProcessed__c
    FROM DataCloudPartition__c
    ORDER BY PartitionId__c
];

Integer totalProcessed = 0;
for (DataCloudPartition__c p : partitions) {
    System.debug(p.Name + ': ' + p.Status__c + 
                 ' | Offset: ' + p.CurrentOffset__c + 
                 ' | Processed: ' + p.TotalProcessed__c);
    totalProcessed += Integer.valueOf(p.TotalProcessed__c);
}
System.debug('TOTAL PROCESSED: ' + totalProcessed + ' / 2,000,000');
```

### Option 3: Check Opportunity Count
```apex
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Total Opportunities: ' + count);
```

---

## Troubleshooting

### Flow isn't starting batches
1. Check if `ParallelBatchOrchestrator` class is deployed
2. Check if partition records exist and have valid data
3. Check Debug Logs in Setup → Debug Logs

### Batches are failing
1. Go to Setup → Apex Jobs → Monitor
2. Look for `DataCloudBatchProcessor` jobs
3. Click on a job to see error details
4. Check the logs

### Need to stop the process
1. Go to Setup → Flows
2. Find `Data Cloud Sync - Parallel Processor`
3. Click **Deactivate**
4. All running batches will complete, but no new ones will start

---

## After First Run

Once all 2 million records are processed:
1. The flow will detect all partitions are complete
2. It will stop starting new batches automatically
3. You can deactivate the flow or leave it running (it won't do anything if all partitions are complete)

For **nightly runs**, you can:
- Keep the flow active permanently
- It will process any new/changed records each night
- Adjust the schedule if needed (e.g., run every hour instead of every 5 minutes)

---

## Quick Reference Card

| Setting | Value |
|---------|-------|
| Flow Type | Schedule-Triggered Flow |
| Frequency | Every 5 Minutes |
| Action | Check and Start Parallel Batches |
| Records per Batch | 2,000 |
| Parallel Partitions | 10 |
| Expected Duration | 8-12 hours for 2M records |





