# ACTION PLAN - When API Limits Reset

## When Will Limits Reset?

Salesforce API limits typically reset:
- **Rolling 24-hour window**: Your limits may start recovering gradually
- **Daily reset**: Usually at midnight in your org's timezone
- **Check in**: Try again in 2-4 hours, or wait until tomorrow

## Step-by-Step Plan (Run in Order)

### Step 1: Stop All Running Jobs (if any)

```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload
sf apex run --file emergency_stop.apex --target-org MassiveUploadOrg
```

**Purpose**: Ensure no old `DynamicPartitionProcessor` jobs are still running

---

### Step 2: Check Current State

```bash
sf apex run --file check_api_usage.apex --target-org MassiveUploadOrg
```

**Purpose**: Verify how many batches ran and confirm API usage issue

---

### Step 3: Deploy V2 (The Fixed Version)

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/DynamicPartitionProcessorV2.cls \
  --source-dir force-app/main/default/classes/DynamicPartitionProcessorV2.cls-meta.xml \
  --target-org MassiveUploadOrg
```

**Purpose**: Deploy the improved version with ExternalId-based pagination

---

### Step 4: Start V2

```bash
sf apex run --file start_v2.apex --target-org MassiveUploadOrg
```

**Purpose**: Start 10 parallel partitions with the fixed code

**Expected output**:
```
✓ Started DynamicPartitionV2_0: externalOpp0000001 to externalOpp0200001
✓ Started DynamicPartitionV2_1: externalOpp0200001 to externalOpp0400001
...
✅ STARTED V2 WITH 10 PARTITIONS
```

---

### Step 5: Monitor Progress (every 30-60 minutes)

```bash
sf apex run --file check_progress_v2.apex --target-org MassiveUploadOrg
```

I'll create this monitoring script below ⬇️

---

### Step 6: Verify Results (after 2-4 hours)

Check that ALL opportunities have the updated StageName:

```sql
SELECT StageName, COUNT(Id) cnt
FROM Opportunity
WHERE External_ID__c LIKE 'externalOpp%'
GROUP BY StageName
```

**Expected**:
- `Qualification: 2,000,000` ✅
- `Discovery: 0`
- `Negotiation: 0`

**This proves all records were processed!**

---

### Step 7: Update the Scheduler (if test successful)

Update the 2 AM daily scheduler to use V2:

```bash
sf apex run --file schedule_v2_daily.apex --target-org MassiveUploadOrg
```

I'll create this script below ⬇️

---

## What V2 Fixes

✅ **No more infinite loops** - tracks lastProcessedId, not offset  
✅ **No more skipped records** - ExternalId-based pagination  
✅ **No more premature stops** - requires 3 consecutive empty batches  
✅ **Better logging** - see exact progress  
✅ **Same performance** - still 10 parallel partitions

## Expected Timeline

- **Deploy V2**: 10 seconds
- **Start V2**: 30 seconds  
- **Process 2M records**: 2-4 hours
- **Total**: ~3-4 hours from start to completion

## Expected API Usage

- **Total calls**: ~4,000 (NOT 440k!)
- **Per record**: 0.002 calls (500 records per API call)
- **Well within limits**: Uses less than 1% of daily quota

## Files Ready to Use

All these files are already created and ready:

- ✅ `emergency_stop.apex` - Stop old jobs
- ✅ `check_api_usage.apex` - Check API consumption
- ✅ `DynamicPartitionProcessorV2.cls` - Fixed processor
- ✅ `start_v2.apex` - Start V2
- ⏳ `check_progress_v2.apex` - Monitor progress (creating below)
- ⏳ `schedule_v2_daily.apex` - Schedule for 2 AM (creating below)

## Your Test Setup

✅ All opportunities in Data Cloud have `StageName = 'Qualification'`  
✅ This will prove V2 processes ALL records, not just 20%  
✅ Clear, measurable success criteria

---

**When you're ready**: Just run Step 1, then Step 2, then Step 3, etc. 🚀




