# Bulk API Upload - Quick Start (2M Records)

## 🎯 Solution for 2 Million Records via Bulk API

This approach makes **200 HTTP callouts to Salesforce Bulk API** (10,000 records each) instead of using Database.upsert(), avoiding DML governor limits.

## ⚡ 5-Minute Setup

### Step 1: Create External ID Field (2 min)
Same as before:
1. Setup → Object Manager → Opportunity → Fields → New
2. Text field (255 chars)
3. Check ✅ External ID and ✅ Unique
4. Name: `External_Id__c`

### Step 2: Configure Remote Site Settings (1 min)
**CRITICAL** - The code makes HTTP callouts:

1. Setup → Search "Remote Site Settings" → New
2. Configure:
   - Name: `SalesforceBulkAPI`
   - URL: Your instance URL (see below)
   - Active: ✅

**Find your instance URL:**
```apex
// Execute Anonymous
System.debug(URL.getSalesforceBaseUrl().toExternalForm());
// Output example: https://na1.salesforce.com
```

**Or use wildcard (works for all):**
```
https://*.salesforce.com
https://*.force.com
```

### Step 3: Deploy Apex Classes (2 min)

**Option A: CLI**
```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload
sf project deploy start --source-path OpportunityBulkAPIUploader.cls,OpportunityBulkAPIUploaderTest.cls
```

**Option B: Setup UI**
1. Setup → Apex Classes → New
2. Copy/paste `OpportunityBulkAPIUploader.cls`
3. Save
4. Repeat for test class

## 🚀 Usage - Two Approaches

### Approach 1: Direct Apex (Best for Data Already in Salesforce)

```apex
// If you have data in a custom object or from another source
OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();

// Add all 2M records
for (Integer i = 0; i < 2000000; i++) {
    uploader.addRecord(
        'EXT-' + i,           // External ID
        'Prospecting',        // Stage
        1000.00,              // Amount
        accountId,            // Account ID
        'Opportunity ' + i    // Name
    );
}

// Start the batch process (makes 200 Bulk API calls)
Id batchJobId = uploader.executeUpload();
System.debug('Batch Job ID: ' + batchJobId);

// Monitor: Setup → Apex Jobs
```

### Approach 2: Python Script (Best for CSV Files)

```bash
# Install dependencies
pip install simple-salesforce pandas requests

# Set credentials
export SF_USERNAME='your_username@example.com'
export SF_PASSWORD='your_password'
export SF_SECURITY_TOKEN='your_token'
export SF_DOMAIN='test'  # or 'login' for production

# Run the uploader
python upload_via_bulk_api.py
```

The script will:
1. Show you REST API code to deploy (one-time setup)
2. Upload your CSV in chunks
3. Monitor progress
4. Report when complete

## 📋 Complete Setup Checklist

- [ ] External_Id__c field created
- [ ] Remote Site Settings configured
- [ ] OpportunityBulkAPIUploader.cls deployed
- [ ] OpportunityBulkAPIUploaderTest.cls deployed
- [ ] Tests passed (run: `sf apex run test --class-names OpportunityBulkAPIUploaderTest`)
- [ ] (Optional) REST API endpoint deployed if using Python

## 🔍 How It Works

```
Your Code/Script
    ↓ Sends 2M records
OpportunityBulkAPIUploader (Apex)
    ↓ Groups into 10K batches
Batch Apex (40 executions)
    ↓ Each makes 5 HTTP callouts
Bulk API 2.0 (200 jobs)
    ↓ Processes asynchronously
2M Opportunities Upserted ✓
```

**Key Numbers:**
- 2,000,000 total records
- 10,000 records per API call
- 200 total API calls
- 5 API calls per batch execution
- 40 batch executions
- 60-90 minutes total time

## 📊 Monitoring

### Check Batch Progress
```apex
// Execute Anonymous
AsyncApexJob job = [
    SELECT Status, JobItemsProcessed, TotalJobItems, NumberOfErrors
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'OpportunityBulkAPIBatch'
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('Status: ' + job.Status);
System.debug('Progress: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
```

### Check Bulk API Jobs
- **UI**: Setup → Bulk Data Load Jobs
- **Debug Logs**: Setup → Debug Logs (look for job IDs)

### Check Records Created
```apex
// Execute Anonymous
Integer count = [SELECT COUNT() FROM Opportunity WHERE External_Id__c != null];
System.debug('Opportunities created: ' + count);
```

## ⚙️ Configuration

### Change Batch Size
Edit `OpportunityBulkAPIUploader.cls`:

```apex
// Line 8: Records per API call (max 10,000)
private static final Integer BATCH_SIZE = 10000;

// Line 9: Records per batch execution
// Must be: (value ÷ 10000) < 100 due to callout limit
private static final Integer RECORDS_PER_BATCH_EXECUTION = 50000;

// Examples:
// 50000 = 5 API calls per batch ✅ (conservative)
// 100000 = 10 API calls per batch ✅
// 500000 = 50 API calls per batch ✅
// 900000 = 90 API calls per batch ✅ (aggressive)
```

## 🐛 Common Issues

### "Unauthorized endpoint"
- **Fix**: Setup → Remote Site Settings → Add your instance URL

### "Too many callouts: 101"
- **Fix**: Reduce `RECORDS_PER_BATCH_EXECUTION` to 900,000 or less

### "Heap size exceeded"
- **Fix**: Process in smaller chunks, don't load all 2M at once

### Jobs created but records not appearing
- **Wait**: Bulk API is async, takes 30-60 minutes
- **Check**: Setup → Bulk Data Load Jobs for status

## 💡 Best Practice: Process in Chunks

Instead of loading all 2M at once:

```apex
// Process 100K records at a time
Integer totalRecords = 2000000;
Integer chunkSize = 100000;

for (Integer i = 0; i < totalRecords; i += chunkSize) {
    OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
    
    Integer endIdx = Math.min(i + chunkSize, totalRecords);
    for (Integer j = i; j < endIdx; j++) {
        uploader.addRecord(
            'EXT-' + j,
            'Prospecting',
            1000.00,
            accountId,
            'Opportunity ' + j
        );
    }
    
    uploader.executeUpload();
    System.debug('Chunk ' + ((i/chunkSize) + 1) + ' submitted');
}
```

## ✅ Verification

After upload completes, verify:

```apex
// Total count
System.debug([SELECT COUNT() FROM Opportunity WHERE External_Id__c != null]);

// Check for duplicates (should be 0)
System.debug([
    SELECT External_Id__c, COUNT(Id)
    FROM Opportunity 
    WHERE External_Id__c != null
    GROUP BY External_Id__c
    HAVING COUNT(Id) > 1
].size());

// Sample records
List<Opportunity> sample = [
    SELECT External_Id__c, Name, StageName, Amount, AccountId
    FROM Opportunity 
    WHERE External_Id__c LIKE 'EXT-%'
    LIMIT 10
];
for (Opportunity opp : sample) {
    System.debug(opp);
}
```

## 📁 Files Reference

**Apex Classes:**
- `OpportunityBulkAPIUploader.cls` - Main uploader
- `OpportunityBulkAPIBatch.cls` - Batch processor (inner class)
- `OpportunityBulkAPIUploaderTest.cls` - Tests

**Python Scripts:**
- `upload_via_bulk_api.py` - Interactive uploader with menu

**Documentation:**
- `BULK_API_SETUP_GUIDE.md` - Comprehensive guide
- `BULK_API_QUICKSTART.md` - This file

## ⏱️ Timeline for 2M Records

1. **Setup** (5 min): Create field, remote site, deploy classes
2. **Upload Start** (1 min): Run script or apex code
3. **Batch Processing** (20-40 min): 40 batch executions
4. **Bulk API Processing** (30-60 min): Async upsert
5. **Total**: ~60-90 minutes

## 🎉 Ready to Go!

You now have everything to upload 2M records using Bulk API:

```bash
# Quick test with 1000 records first
python upload_via_bulk_api.py
# Choose option 2, modify CSV to first 1000 lines

# Then run full 2M upload
python upload_via_bulk_api.py
```

---

**Questions? Check:**
- Full guide: `BULK_API_SETUP_GUIDE.md`
- Troubleshooting: Setup → Debug Logs
- Monitor: Setup → Apex Jobs, Bulk Data Load Jobs









