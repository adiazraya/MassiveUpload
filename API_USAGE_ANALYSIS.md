# API USAGE ANALYSIS

## Current Process API Consumption

### For 2 Million Records:

#### 1. Data Cloud Queries (ConnectApi.CdpQuery.queryAnsiSqlV2)
- Batch size: 2,000 records
- Number of batches: 2,000,000 ÷ 2,000 = **1,000 batches**
- API calls per query: **1 call**
- **Total: ~1,000 API calls**

#### 2. Bulk API HTTP Callouts (per batch)
- `createBulkJob` (POST): 1 call
- `uploadDataToJob` (PUT): 1 call  
- `closeJob` (PATCH): 1 call
- **Per batch: 3 HTTP calls**
- **Total for 2M records: 1,000 batches × 3 = 3,000 calls**

#### 3. Internal Operations (NOT counted as API calls)
- SOQL queries in `finish()`: Don't count toward API limit
- DML (upsert progress): Don't count toward API limit
- `Database.executeBatch`: Don't count toward API limit

#### 4. Bulk API Background Processing
- **Does NOT count** toward API limits
- The actual record insert/update happens asynchronously
- Only the 3 management calls count

## Total API Calls for 2M Records

```
Data Cloud queries:     1,000
Bulk API management:    3,000
─────────────────────────────
TOTAL:                  4,000 API calls
```

## Your Org: 441,726 Calls Available

- **Available daily**: 441,726
- **Other services**: ~1,000
- **Available for sync**: ~440,000
- **Actually needed**: ~4,000

### ✅ **You're using less than 1% of your daily limit!**

## Wait... Are You Actually Using 440k?

If you're seeing 440k API calls being consumed, something is **very wrong**. 

### Possible Issues:

1. **Self-scheduling gone wild**: If there's a bug causing infinite loops
2. **Failed HTTP calls retrying**: Bulk API calls timing out and retrying
3. **Monitoring the wrong metric**: 
   - Are you looking at "Total Requests"? (includes internal calls)
   - Or actual API calls?
4. **Multiple processes running**: Old batches still running alongside new ones

## How to Check Actual Usage

Run this to see what's consuming API calls:

```apex
// Check API usage over last hour
List<AggregateResult> apiUsage = [
    SELECT COUNT(Id) cnt
    FROM AsyncApexJob
    WHERE ApexClass.Name IN ('DynamicPartitionProcessor', 'DynamicPartitionProcessorV2')
    AND CreatedDate = LAST_N_HOURS:1
];

System.debug('Batches in last hour: ' + apiUsage[0].get('cnt'));

// Each batch = 4 API calls (1 Data Cloud + 3 HTTP)
Integer expectedAPICalls = Integer.valueOf(apiUsage[0].get('cnt')) * 4;
System.debug('Expected API calls: ' + expectedAPICalls);
```

## Actual API Usage Per Record

**With current design**:
- 2,000,000 records ÷ 4,000 API calls = **500 records per API call**
- **NOT** 1 API call per record!

**The Bulk API is the magic**:
- 1 Data Cloud query = 2,000 records
- 3 HTTP calls to Bulk API = 2,000 records processed
- **Total: 4 API calls for 2,000 records**

## If You're Really Using 440k Calls...

That would mean:
- 440,000 ÷ 4 = **110,000 batches ran**
- 110,000 × 2,000 = **220 MILLION records processed**

That's 110x more than you have! This suggests:

### Likely Culprit: Infinite Self-Scheduling Loop

The old `DynamicPartitionProcessor` might have had a bug where:
1. Batch starts with offset 0
2. Processes 2,000 records  
3. `finish()` fails silently but reschedules anyway
4. Next batch starts with offset 0 again (state not preserved)
5. **Infinite loop processing the same 2,000 records forever**

## Action Items

1. **Check how many jobs actually ran**:
   ```sql
   SELECT COUNT(Id) FROM AsyncApexJob 
   WHERE ApexClass.Name = 'DynamicPartitionProcessor'
   AND CreatedDate = TODAY
   ```

2. **Check if there are stuck/running jobs**:
   ```sql
   SELECT COUNT(Id) FROM AsyncApexJob 
   WHERE ApexClass.Name = 'DynamicPartitionProcessor'
   AND Status IN ('Queued', 'Processing', 'Preparing')
   ```

3. **Abort any running jobs** (emergency_stop.apex)

4. **Deploy V2** which fixes the state preservation issue

---

**Bottom Line**: You should only be using ~4,000 API calls for 2M records, not 440k. If you're really using 440k, there's likely an infinite loop bug in the old version that V2 fixes.




