# Bulk API Uploader Setup Guide

## Overview

This solution uses **Salesforce Bulk API 2.0** via HTTP callouts from Apex to handle 2 million records with 200 API calls (10,000 records each). This approach bypasses DML governor limits.

## 🎯 Why This Approach?

- ✅ **No DML Limits**: Uses HTTP callouts instead of Database.upsert()
- ✅ **Handles 2M Records**: Makes 200 API calls (10K records each)
- ✅ **Batch Apex**: Processes 50K records per batch (5 API calls), avoiding the 100 callout/transaction limit
- ✅ **Asynchronous**: Bulk API jobs process independently
- ✅ **Reliable**: Built-in retry and error handling

## 📋 Prerequisites

### 1. Create External ID Field
Same as before - you need the `External_Id__c` field on Opportunity:
- Setup → Object Manager → Opportunity → Fields → New
- Type: Text (255)
- Check: External ID ✅ and Unique ✅
- API Name: `External_Id__c`

### 2. Enable Remote Site Settings (IMPORTANT!)

The code makes HTTP callouts to Salesforce API endpoints. You must whitelist your instance URL:

#### Setup Remote Site Settings:

1. Go to **Setup** → Search for "Remote Site Settings"
2. Click **New Remote Site**
3. Configure:
   - **Remote Site Name**: `SalesforceBulkAPI`
   - **Remote Site URL**: Use your Salesforce instance URL
     - Production: `https://login.salesforce.com`
     - Sandbox: `https://test.salesforce.com`
     - Or your specific instance: `https://na1.salesforce.com` (check your URL)
   - **Active**: ✅ Checked
4. Click **Save**

**Note**: If unsure of your instance URL, run this in Execute Anonymous:
```apex
System.debug('Instance URL: ' + URL.getSalesforceBaseUrl().toExternalForm());
```

Alternatively, use a wildcard (less secure but works for all):
```
https://*.salesforce.com
https://*.force.com
```

### 3. Deploy Apex Classes

```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload

# Deploy the classes
sf project deploy start --source-path OpportunityBulkAPIUploader.cls,OpportunityBulkAPIUploaderTest.cls

# Or deploy via Setup UI
# Setup → Apex Classes → New → Paste code → Save
```

### 4. Run Tests
```bash
sf apex run test --class-names OpportunityBulkAPIUploaderTest --result-format human
```

## 🚀 Usage

### Basic Usage

```apex
// Create uploader instance
OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();

// Add records (can add all 2 million)
for (Integer i = 0; i < 2000000; i++) {
    uploader.addRecord(
        'EXT-' + i,           // External ID
        'Prospecting',        // Stage Name
        1000.00,              // Amount
        accountId,            // Account ID
        'Opportunity ' + i    // Name
    );
}

// Execute the upload (starts batch apex)
uploader.executeUpload();
```

### Real-World Example: Loading from CSV Data

```apex
// Assuming you have CSV data parsed
List<Map<String, String>> csvData = parseYourCSV();

OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();

for (Map<String, String> row : csvData) {
    uploader.addRecord(
        row.get('ExternalId'),
        row.get('StageName'),
        Decimal.valueOf(row.get('Amount')),
        row.get('Account'),
        row.get('Name')
    );
}

// Start the upload
Id batchJobId = uploader.executeUpload();
System.debug('Batch Job ID: ' + batchJobId);
```

### Using with Your Existing Data

You have `generated_opportunities_enhanced.csv` with 2M records. Here's how to use it:

#### Option 1: Via Apex REST API (Recommended for External Upload)

Create a REST endpoint to receive data:

```apex
@RestResource(urlMapping='/api/opportunity/bulk')
global class OpportunityBulkRestAPI {
    
    @HttpPost
    global static String uploadOpportunities(List<OppRecord> records) {
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        for (OppRecord rec : records) {
            uploader.addRecord(
                rec.externalId,
                rec.stageName,
                rec.amount,
                rec.accountId,
                rec.name
            );
        }
        
        Id jobId = uploader.executeUpload();
        
        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'batchJobId' => jobId,
            'recordCount' => records.size()
        });
    }
    
    global class OppRecord {
        global String externalId;
        global String stageName;
        global Decimal amount;
        global String accountId;
        global String name;
    }
}
```

Then use Python to call it:

```python
import pandas as pd
import requests

# Read CSV
df = pd.read_csv('generated_opportunities_enhanced.csv')

# Prepare data
records = []
for _, row in df.iterrows():
    records.append({
        'externalId': row['ExternalId'],
        'stageName': row['StageName'],
        'amount': float(row['Amount']),
        'accountId': row['Account'],
        'name': row['Name']
    })

# Call Apex REST API (send in chunks)
chunk_size = 10000
for i in range(0, len(records), chunk_size):
    chunk = records[i:i+chunk_size]
    
    response = requests.post(
        f'{instance_url}/services/apexrest/api/opportunity/bulk',
        headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        },
        json=chunk
    )
    print(f'Chunk {i//chunk_size + 1}: {response.json()}')
```

#### Option 2: Load Directly in Apex (if data is in Custom Object)

```apex
// If your CSV data is already loaded into a staging custom object
List<Staging_Opportunity__c> stagingRecords = [
    SELECT External_Id__c, Name__c, Stage__c, Amount__c, Account__c
    FROM Staging_Opportunity__c
];

OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();

for (Staging_Opportunity__c staging : stagingRecords) {
    uploader.addRecord(
        staging.External_Id__c,
        staging.Stage__c,
        staging.Amount__c,
        staging.Account__c,
        staging.Name__c
    );
}

uploader.executeUpload();
```

## 🔍 How It Works

### Architecture

```
┌──────────────────────────┐
│ Your Code                │
│ (adds 2M records)        │
└────────────┬─────────────┘
             │
             │ addRecord() × 2,000,000
             ▼
┌──────────────────────────────────┐
│ OpportunityBulkAPIUploader       │
│ (holds records in memory)        │
└────────────┬─────────────────────┘
             │
             │ executeUpload()
             ▼
┌──────────────────────────────────┐
│ Batch Apex                       │
│ Processes 50K records per batch  │
│ (40 batch executions for 2M)     │
└────────────┬─────────────────────┘
             │
             │ Each batch makes 5 API calls
             │ (5 × 10K records = 50K)
             ▼
┌──────────────────────────────────┐
│ Bulk API 2.0 Jobs                │
│ 200 total jobs                   │
│ Each job: 10,000 records         │
└────────────┬─────────────────────┘
             │
             │ Asynchronous processing
             ▼
┌──────────────────────────────────┐
│ Opportunity Records              │
│ Upserted by External_Id__c       │
└──────────────────────────────────┘
```

### Processing Flow

1. **Add Records**: Call `addRecord()` 2 million times
2. **Execute Batch**: Call `executeUpload()` starts batch apex
3. **Batch Processing**: 
   - 40 batch executions (50K records each)
   - Each execution makes 5 HTTP callouts (10K records each)
   - Total: 200 Bulk API jobs
4. **Bulk API**: Each job processes asynchronously
5. **Complete**: Records are upserted to Salesforce

### Batch Size Calculation

- **Total Records**: 2,000,000
- **Records per API call**: 10,000
- **Total API calls needed**: 200
- **Callout limit per transaction**: 100
- **Solution**: Process 50K records per batch = 5 API calls per batch
- **Total batch executions**: 2,000,000 ÷ 50,000 = 40 batches

## 📊 Monitoring

### Monitor Batch Job

```apex
// Get batch job status
AsyncApexJob job = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'OpportunityBulkAPIBatch'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

System.debug('Status: ' + job.Status);
System.debug('Progress: ' + job.JobItemsProcessed + ' / ' + job.TotalJobItems);
```

### Monitor Bulk API Jobs

```apex
// Query bulk API job status via REST
// Setup → Bulk Data Load Jobs (UI)
// Or use Workbench → REST Explorer → /services/data/v59.0/jobs/ingest
```

### Check Debug Logs

1. Setup → Debug Logs
2. Create log for your user
3. Check for messages like:
   ```
   Successfully submitted 10000 records to Bulk API job: 750xx0000000ABC
   ```

## ⚙️ Configuration

### Adjust Batch Size

If you want to change how many records are processed per batch:

```apex
// In OpportunityBulkAPIUploader.cls, line 9
private static final Integer RECORDS_PER_BATCH_EXECUTION = 50000; // Change this

// Remember: RECORDS_PER_BATCH_EXECUTION ÷ 10000 must be < 100 (callout limit)
// Examples:
// 50000 = 5 API calls per batch ✅
// 90000 = 9 API calls per batch ✅
// 100000 = 10 API calls per batch ✅
// 1000000 = 100 API calls per batch ✅ (max)
```

### Adjust Records Per API Call

```apex
// In OpportunityBulkAPIUploader.cls, line 8
private static final Integer BATCH_SIZE = 10000; // Change this

// Salesforce Bulk API 2.0 limits:
// - Max 150MB per job
// - Recommended: 10,000 records per job
```

## 🐛 Troubleshooting

### Error: "Unauthorized endpoint"

**Cause**: Remote Site Settings not configured

**Solution**: 
1. Setup → Remote Site Settings → New
2. Add your Salesforce instance URL
3. Activate the remote site

### Error: "Too many callouts"

**Cause**: Batch size too large (> 100 API calls per batch)

**Solution**: Reduce `RECORDS_PER_BATCH_EXECUTION` to 900,000 or less

### Error: "Heap size exceeded"

**Cause**: Trying to hold too many records in memory

**Solution**: 
- Process data in smaller chunks
- Call `executeUpload()` more frequently
- Don't accumulate all 2M records at once

### Bulk API Jobs Not Processing

**Cause**: Jobs created but not closing properly

**Solution**: Check debug logs for "Error closing job" messages

### Records Not Appearing

**Cause**: Bulk API jobs may still be processing

**Solution**: 
- Bulk API is asynchronous - wait 5-30 minutes
- Check Setup → Bulk Data Load Jobs for status
- Query for partial results

## 🎯 Best Practices

### 1. Process in Chunks (Recommended Approach)

Instead of loading all 2M records at once:

```apex
// Process CSV in chunks of 100K
Integer chunkSize = 100000;
List<String> csvLines = readYourCSVFile();

for (Integer i = 0; i < csvLines.size(); i += chunkSize) {
    OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
    
    Integer endIdx = Math.min(i + chunkSize, csvLines.size());
    for (Integer j = i; j < endIdx; j++) {
        // Parse CSV line and add record
        List<String> fields = csvLines[j].split(',');
        uploader.addRecord(fields[0], fields[4], Decimal.valueOf(fields[3]), fields[2], fields[1]);
    }
    
    uploader.executeUpload();
    System.debug('Chunk ' + (i/chunkSize + 1) + ' submitted');
}
```

### 2. Monitor Job Progress

Create a dashboard to track:
- Batch Apex jobs (AsyncApexJob)
- Bulk API jobs (via API or UI)
- Success/failure counts

### 3. Error Handling

Implement retry logic for failed jobs:

```apex
// Check job results after processing
// Query Bulk API for failed records
// Reprocess failed records
```

### 4. Testing

Always test with a small dataset first:

```apex
// Test with 1000 records
OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
for (Integer i = 0; i < 1000; i++) {
    uploader.addRecord('TEST-' + i, 'Prospecting', 1000, accountId, 'Test ' + i);
}
uploader.executeUpload();
```

## ⏱️ Performance

### Expected Processing Time for 2M Records

- **Batch Apex Start**: < 1 minute
- **All API Calls Submitted**: ~20-40 minutes (40 batch executions)
- **Bulk API Processing**: 30-60 minutes
- **Total Time**: ~60-90 minutes

### Governor Limits Compliance

- ✅ **Heap Size**: Batch processes chunks, not all at once
- ✅ **CPU Time**: HTTP callouts don't count toward CPU
- ✅ **DML Rows**: No DML used, only API calls
- ✅ **Callouts**: Max 5 per batch execution (within 100 limit)
- ✅ **Batch Jobs**: 40 executions (within 250 limit per 24 hours)

## 📝 Summary

**Files Created:**
- `OpportunityBulkAPIUploader.cls` - Main class
- `OpportunityBulkAPIBatch.cls` - Batch processor (inner class)
- `OpportunityBulkAPIUploaderTest.cls` - Test class
- Metadata files (.cls-meta.xml)

**Setup Required:**
1. ✅ Create External_Id__c field
2. ✅ Configure Remote Site Settings
3. ✅ Deploy Apex classes
4. ✅ Run tests

**Usage:**
```apex
OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
// Add 2M records
uploader.executeUpload();
```

**Result:**
- 200 Bulk API jobs created
- 2M opportunities upserted
- Complete in ~60-90 minutes

---

**Ready to Upload Your 2 Million Records! 🚀**









