# Data Cloud to Salesforce Opportunity Upload - Solution

## The Problem

You have **2M records in Data Cloud** (`ExtOpportunities__dlm`) that need to be uploaded to Salesforce Opportunities using Bulk API.

**Why the Flow approach failed:**
- Record-triggered Flows run per record = 2M separate transactions
- Static buffer resets between transactions
- Never accumulates 10,000 records needed for Bulk API

## ✅ Recommended Solution: Use Data Cloud's Native Bulk Export

Since `ConnectApi.CdpQuery` may not be available in your API version, use Data Cloud's **built-in data export** feature:

### Option 1: Data Cloud Activation (Recommended) ⭐

1. **Create Data Action in Data Cloud**:
   - Go to Data Cloud → Activations
   - Create new Activation
   - Source: `ExtOpportunities__dlm`
   - Target: Salesforce Opportunity
   - Map fields:
     ```
     externalid__c     → External_Id__c
     stagename__c      → StageName
     amount__c         → Amount
     account__c        → AccountId
     name__c           → Name
     closedate__c      → CloseDate
     ```
   - Set to run once or on schedule

2. **This will**:
   - Use Data Cloud's native Bulk API integration
   - Handle all 2M records automatically
   - No governor limits
   - No custom code needed

---

### Option 2: Export CSV + Data Loader

1. **Export from Data Cloud**:
   - Data Cloud → Query → Run SQL:
     ```sql
     SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c
     FROM ExtOpportunities__dlm
     ```
   - Export results to CSV

2. **Use Salesforce Data Loader**:
   - Open Data Loader
   - Select **Upsert** operation
   - Choose Opportunity object
   - Map fields
   - Upload CSV

**Time**: ~30-60 minutes for 2M records

---

### Option 3: Custom Apex with Manual Query

Since ConnectAPI might not work, run this in **Execute Anonymous**:

```apex
// STEP 1: Test with small dataset first
String testQuery = 
    'SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c ' +
    'FROM ExtOpportunities__dlm ' +
    'LIMIT 100';

try {
    // Try the API call
    String result = ConnectApi.CdpQuery.queryAnsiSql(testQuery);
    System.debug('✓ API works! Result: ' + result);
    
    // If this works, proceed with full implementation
    
} catch (Exception e) {
    System.debug('✗ API not available: ' + e.getMessage());
    System.debug('Use Option 1 (Data Cloud Activation) or Option 2 (CSV Export) instead');
}
```

---

## 🎯 My Recommendation

**Use Option 1: Data Cloud Activation**

This is the **proper enterprise solution** for Data Cloud → Salesforce sync:

### Why?
- ✅ Built for this exact use case
- ✅ Handles millions of records
- ✅ No governor limits
- ✅ No custom code to maintain
- ✅ Can schedule for ongoing sync
- ✅ Uses Bulk API automatically

### Setup Steps:

1. **In Data Cloud**:
   - Click **Activations** in left menu
   - Click **New**
   - Name: "Sync Opportunities to Salesforce"
   - Source: `ExtOpportunities__dlm`
   - Target Type: Salesforce
   - Target Object: Opportunity
   - Operation: Upsert
   - External ID: `External_Id__c`

2. **Map Fields**:
   | Data Cloud Field | Salesforce Field |
   |-----------------|------------------|
   | externalid__c | External_Id__c |
   | stagename__c | StageName |
   | amount__c | Amount |
   | account__c | AccountId |
   | name__c | Name |
   | closedate__c | CloseDate |

3. **Configure & Run**:
   - Set schedule (one-time or recurring)
   - Click **Activate**
   - Monitor in Activations dashboard

---

## 📊 Comparison

| Method | Time | Complexity | Maintains | Best For |
|--------|------|------------|-----------|----------|
| **Data Cloud Activation** | 30-60 min | Low | Ongoing sync | Production ⭐ |
| **CSV Export + Data Loader** | 30-60 min | Low | One-time | Quick migration |
| **Custom Apex** | 60-90 min | High | Custom logic | Special requirements |
| **Flow (your attempt)** | ❌ Fails | Medium | N/A | Won't work for 2M |

---

## 🚨 Important Notes

1. **Your Flow won't work** for 2M records because:
   - Each record = separate transaction
   - Buffer never accumulates
   - Only processes ~100K before hitting limits

2. **Data Cloud Activation is the right tool** because:
   - Purpose-built for bulk data movement
   - Handles Data Cloud → Salesforce sync
   - No code maintenance
   - Enterprise-grade

3. **If you must use custom Apex**:
   - First verify `ConnectApi.CdpQuery` works in your org
   - Run the test query above
   - If it fails, use Option 1 or 2

---

## Next Steps

**Tell me which option you want to pursue:**

1. ✅ **Data Cloud Activation** (I'll guide you through setup)
2. **CSV Export + Data Loader** (I'll provide exact steps)
3. **Custom Apex** (Need to verify API availability first)

Which would you like to do?








