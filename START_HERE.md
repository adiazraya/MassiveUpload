# WHAT TO DO NEXT - Quick Start Guide

## Step 1: Create Fields in Salesforce UI (5 minutes)

You need to manually create 6 fields in the `DataCloudPartition__c` object:

1. **Go to Salesforce Setup**
2. **Quick Find → "Object Manager"**
3. **Click on "Data Cloud Partition"**
4. **Click "Fields & Relationships"**
5. **Click "New"** and create each field:

### Field 1: Partition ID
- Data Type: **Number**
- Length: **18, 0** (18 digits, 0 decimals)
- Field Label: **Partition ID**
- Field Name: **PartitionId** (will become PartitionId__c)
- ✅ Check **Required**
- ✅ Check **Unique**
- ✅ Check **External ID**

### Field 2: Current Offset
- Data Type: **Number**
- Length: **18, 0**
- Field Label: **Current Offset**
- Field Name: **CurrentOffset**

### Field 3: Total Processed
- Data Type: **Number**
- Length: **18, 0**
- Field Label: **Total Processed**
- Field Name: **TotalProcessed**

### Field 4: Total Bulk API Calls
- Data Type: **Number**
- Length: **18, 0**
- Field Label: **Total Bulk API Calls**
- Field Name: **TotalBulkAPICalls**

### Field 5: Status
- Data Type: **Picklist**
- Field Label: **Status**
- Field Name: **Status**
- Values (one per line):
  - Initialized
  - Running
  - Waiting
  - Completed
  - Error

### Field 6: Last Batch Started
- Data Type: **Date/Time**
- Field Label: **Last Batch Started**
- Field Name: **LastBatchStarted**

---

## Step 2: Initialize the 10 Partitions (1 minute)

Once the fields are created, run this command:

```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload && sf apex run --file init_partitions_dynamic.apex --target-org MassiveUploadOrg
```

This will create 10 partition records (Partition0 through Partition9).

---

## Step 3: Schedule the Orchestrator (1 minute)

Run this command:

```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload && sf apex run --file schedule_orchestrator.apex --target-org MassiveUploadOrg
```

This will schedule the orchestrator to run **every hour, 24/7**.

---

## Step 4: Monitor Progress

Check opportunity count:
```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload && sf apex run -f check_partition_progress.apex --target-org MassiveUploadOrg
```

(I'll create this monitoring script for you in a moment)

---

## Timeline

- **Hourly processing**: ~20,000 records/hour (10 partitions × 2K records)
- **Total time for 2M records**: ~100 hours continuous processing
- **Nightly runs**: Just leave it scheduled, it will run every night automatically

---

## If Something Goes Wrong

**Stop everything:**
```bash
sf apex run --file cancel_scheduled_jobs.apex --target-org MassiveUploadOrg
```

**Check what's running:**
- Setup → Apex Jobs
- Setup → Scheduled Jobs

---

## Ready? Start with Step 1! 👆

Create those 6 fields in Salesforce UI, then come back and run Step 2.




