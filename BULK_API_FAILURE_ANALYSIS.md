## CRITICAL FINDING

**V2 processed 1,997,999 records but only 372,862 were actually updated!**

### The Problem

The Bulk API is **completing successfully** but **not actually upserting the records**.

###  Most Likely Causes

1. **Invalid `AccountId` values** - The `Account__c` field from Data Cloud contains IDs that don't exist in Salesforce
2. **Required fields missing** - Opportunity requires fields we're not providing
3. **Validation rules** - Blocking the upsert
4. **Field-level security** - The running user doesn't have access to update fields

### How to Verify

**Go to Setup → Bulk Data Load Jobs**

Look for jobs from today and check:
- **Records Processed**: Should be 2,000 per job
- **Records Failed**: Likely ~1,600+ per job
- **Download Failed Records** to see the actual error messages

### What to Look For

The failed records CSV will show errors like:
- `INVALID_CROSS_REFERENCE_KEY: invalid cross reference id`  → Invalid AccountId
- `REQUIRED_FIELD_MISSING: Required fields are missing` → Missing required fields
- `FIELD_CUSTOM_VALIDATION_EXCEPTION` → Validation rule blocking
- `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` → No access to Account

### Quick Test

I'll create a script to check if the `Account__c` IDs from Data Cloud actually exist in Salesforce.

**This is why only ~20% of records are updating** - the other 80% are failing validation!




