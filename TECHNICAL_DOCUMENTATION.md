# Massive Data Loading from Salesforce Data Cloud to Core

## Technical Documentation

**Version:** 1.0  
**Date:** January 2026  
**Use Case:** Bulk data transfer from Data Cloud to Salesforce Core (2M+ records)  
**Status:** Production-Ready ✅

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [The Business Need](#the-business-need)
3. [Final Solution Overview](#final-solution-overview)
4. [Obstacles & Challenges](#obstacles-and-challenges)
5. [Solution Evolution (Test1-Test8)](#solution-evolution)
6. [Architecture](#architecture)
7. [Technical Components](#technical-components)
8. [Implementation Guide](#implementation-guide)
9. [Monitoring & Logging](#monitoring-and-logging)
10. [Performance Metrics](#performance-metrics)
11. [Best Practices & Recommendations](#best-practices-and-recommendations)
12. [Troubleshooting Guide](#troubleshooting-guide)

---

## Executive Summary

### The Challenge
Load 2 million opportunities from Salesforce Data Cloud to Salesforce Core with high reliability and minimal failures due to record locking.

### The Solution
A sophisticated partition-based approach using Bulk API 2.0 with exponential backoff retry logic, achieving **99.93% success rate**.

### Key Results
- **1,998,599 opportunities** successfully created from 1,999,999 records
- **99.93% success rate** (only 1,400 failures)
- **7-hour processing time** for 2M records
- **Production-ready** and reusable for any Salesforce object

---

## The Business Need

### Problem Statement

Organizations using Salesforce Data Cloud often need to materialize large datasets into Salesforce Core for operational use. The challenge becomes acute when:

1. **Volume**: Millions of records need to be loaded
2. **Related Records**: Records share parent objects (e.g., multiple Opportunities per Account)
3. **Concurrency**: Multiple batches processing simultaneously cause lock conflicts
4. **Reliability**: Traditional batch approaches fail 10-20% of records due to locking
5. **Time Constraints**: Processing must complete within reasonable timeframes

### Specific Use Case: Opportunities

- **Source**: 2,000,000 opportunities in Data Cloud
- **Target**: Salesforce Core (Opportunity object)
- **Complexity**: Multiple opportunities per Account (parent relationship)
- **Challenge**: Account-level locking when concurrent batches update opportunities for the same Account

### General Applicability

This solution applies to any object with:
- High volume (100K+ records)
- Parent-child relationships (Account-Contact, Account-Opportunity, etc.)
- External ID for upsert operations
- Need for high success rates (>95%)

---

## Final Solution Overview

### Configuration (Test8 - Production Ready)

```yaml
API: Salesforce Bulk API 2.0 (Parallel Mode)
Batch Size: 500 records per batch
Partitions: 5 (400K records each)
Partition Stagger: 1.5 hours between partition starts
Batch Delay: 20-30 seconds between batches
Retry Strategy: Exponential backoff (2s → 5s → 10s)
Max Retries: 3 attempts per batch
Success Rate: 99.93%
Processing Time: ~7 hours for 2M records
```

### Key Success Factors

1. **Partitioning Strategy**: Divide data into 5 non-overlapping partitions by ExternalId range
2. **Staggered Execution**: Start partitions 1.5 hours apart to reduce concurrent Account access
3. **Small Batches**: 500 records per batch minimizes lock contention
4. **Intelligent Retry**: Exponential backoff gives locks time to release
5. **Deliberate Delays**: 20-30s between batches reduces "thundering herd" effect

### Why It Works

**The Core Insight**: Lock contention occurs when multiple processes try to update records sharing the same parent (Account) simultaneously. By:
- Processing smaller batches (500 vs 2000)
- Adding delays between batches (20-30s)
- Staggering partition starts (1.5h apart)
- Retrying with exponential backoff (2s, 5s, 10s)

...we reduce the probability of concurrent access to the same Account, resulting in 99.93% success.

---

## Obstacles and Challenges

### Challenge 1: Record Locking (UNABLE_TO_LOCK_ROW)

**Problem**: When multiple Bulk API jobs try to update opportunities for the same Account simultaneously, Salesforce locks the Account record, causing failures.

**Symptoms**:
- 10-20% failure rate in bulk operations
- Error: `UNABLE_TO_LOCK_ROW`
- Failures increase with batch size and parallelism

**Root Cause**: Salesforce locks parent records (Accounts) when child records (Opportunities) are modified. With thousands of opportunities per Account, the probability of concurrent updates is high.

**Solution Path**:
- Reduce batch size: 2000 → 500 records
- Add delays between batches
- Stagger partition starts
- Implement retry logic

### Challenge 2: Bulk API 2.0 Limitations

**Problem**: Bulk API 2.0 doesn't support Serial concurrency mode (only Parallel).

**Initial Approach**: Try to use `concurrencyMode: "Serial"` parameter

**Result**: API error - "Property currently unsupported: 'concurrencyMode'"

**Attempted Solution**: Switch to Bulk API 1.0 with Serial mode

**Result**: Worse performance (28% success rate) due to different internal processing

**Final Solution**: Stay with Bulk API 2.0 Parallel, but control concurrency at the application level through:
- Partitioning
- Staggered starts
- Deliberate delays

### Challenge 3: Retry Strategy Optimization

**Initial Approach**: Immediate retry on failure

**Problem**: Immediate retries often hit the same lock, making things worse

**Solution**: Exponential backoff
- Retry 1: Wait 2 seconds
- Retry 2: Wait 5 seconds
- Retry 3: Wait 10 seconds

**Result**: Locks have time to clear, dramatically improving success rate

### Challenge 4: Data Cloud Query Pagination

**Problem**: Data Cloud doesn't support traditional OFFSET pagination reliably at scale

**Solution**: ExternalId-based pagination
```sql
WHERE "ExternalId__c" > 'lastProcessedId'
ORDER BY "ExternalId__c"
LIMIT 500
```

**Benefits**:
- No duplicates
- No missed records
- Consistent performance at any scale

### Challenge 5: Apex Governor Limits

**Problem**: Can't make infinite API calls in a single transaction

**Solution**: Stateful batch apex that chains itself
- Each batch processes 500 records
- Makes 1 Bulk API call
- Schedules itself to continue
- Tracks progress in custom object

---

## Solution Evolution

### Test 1: Baseline (Failed)
**Approach**: Single batch processing all 2M records  
**Result**: Governor limit errors, timeouts  
**Learning**: Need to partition the data  

### Test 2: Simple Partitioning (Failed)
**Approach**: 5 partitions, OFFSET-based pagination  
**Result**: Duplicates and missed records  
**Learning**: OFFSET is unreliable at scale in Data Cloud  

### Test 3: ExternalId Pagination + Large Batches
**Configuration**:
- Batch size: 2000 records
- No delays
- No retry logic

**Results**:
- Success Rate: 21%
- Failures: 79%
- Primary Error: UNABLE_TO_LOCK_ROW

**Learning**: Batch size too large, causing massive lock contention

### Test 4: Smaller Batches ⭐
**Configuration**:
- Batch size: 500 records
- Bulk API 2.0 Parallel
- No retry logic
- 1-hour partition stagger

**Results**:
- Success Rate: **89%** (1,780,000 opportunities)
- Failures: 11% (~220,000)
- Duration: ~5 hours

**Learning**: Major improvement! Small batches significantly reduce contention

### Test 5: Serial Mode Attempt (Failed)
**Approach**: Add `concurrencyMode: "Serial"` to Bulk API 2.0  
**Result**: API error - parameter not supported  
**Learning**: Bulk API 2.0 doesn't support serial mode  

### Test 6: Bulk API 1.0 Serial Mode (Failed)
**Configuration**:
- Switched to Bulk API 1.0
- Serial concurrency mode
- 500 record batches

**Results**:
- Success Rate: 28%
- Failures: 72%
- Duration: Unknown (stopped early)

**Learning**: Bulk API 1.0 Serial mode performs worse due to different internal processing. Stay with Bulk API 2.0.

### Test 7: Add Basic Retry Logic ⭐⭐
**Configuration**:
- Batch size: 500 records
- Bulk API 2.0 Parallel
- Immediate retry (up to 2 attempts)
- 1-hour partition stagger
- ~10-20s natural delays

**Results**:
- Success Rate: **90.16%** (1,803,153 opportunities)
- Failures: 9.84% (196,846)
- Duration: 4h 54m
- Improvement: +23,154 opportunities vs Test4

**Learning**: Retry logic helps, but immediate retries still hit locks

### Test 8: Exponential Backoff + Extended Delays ⭐⭐⭐ (PRODUCTION)
**Configuration**:
- Batch size: 500 records
- Bulk API 2.0 Parallel
- **Exponential backoff retry**: 2s → 5s → 10s
- **Max retries**: 3 (vs 2)
- **Batch delay**: 20-30s (vs 10-20s)
- **Partition stagger**: 1.5 hours (vs 1 hour)

**Results**:
- Success Rate: **99.93%** (1,998,599 opportunities) 🏆
- Failures: 0.07% (1,400)
- Duration: 7h 5m
- Improvement: +195,446 opportunities vs Test7

**Why It Won**:
1. Exponential backoff gives locks time to clear
2. Longer delays reduce concurrent processing
3. Wider partition stagger reduces Account conflicts
4. Additional retry attempt catches more transient failures

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SALESFORCE DATA CLOUD                        │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │         ExtOpportunities__dlm (2M records)            │   │
│  │                                                         │   │
│  │  Partitioned by ExternalId ranges:                    │   │
│  │  • P0: externalOpp0000001 → externalOpp0400000       │   │
│  │  • P1: externalOpp0400001 → externalOpp0800000       │   │
│  │  • P2: externalOpp0800001 → externalOpp1200000       │   │
│  │  • P3: externalOpp1200001 → externalOpp1600000       │   │
│  │  • P4: externalOpp1600001 → externalOpp2000000       │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ CDP Query API
                            │ (SQL queries)
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              SALESFORCE CORE - APEX PROCESSING                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          DataCloudPartition__c (Progress Tracking)       │  │
│  │  • TotalProcessed__c                                     │  │
│  │  • TotalBulkAPICalls__c                                  │  │
│  │  • Status__c                                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │      DynamicPartitionProcessorV2 (Batch Apex)           │  │
│  │  • Stateful batch processing                            │  │
│  │  • ExternalId-based pagination                          │  │
│  │  • Self-chaining with delay                             │  │
│  │  • 500 records per execution                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │      DelayedBatchStarterV2 (Queueable)                  │  │
│  │  • Adds 10s delay between batches                       │  │
│  │  • Reduces concurrent processing                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │      Exponential Backoff Retry Logic                    │  │
│  │  • Attempt 1: Immediate                                 │  │
│  │  • Attempt 2: Wait 2s                                   │  │
│  │  • Attempt 3: Wait 5s                                   │  │
│  │  • Attempt 4: Wait 10s                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            │ Bulk API 2.0                        │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Salesforce Bulk API 2.0 (Parallel)             │  │
│  │  • Create Job (Upsert)                                  │  │
│  │  • Upload CSV Data                                      │  │
│  │  • Close Job                                            │  │
│  │  • Async Processing                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              SALESFORCE CORE - TARGET OBJECT                     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           Opportunity (2M records created)               │  │
│  │  • Upserted by External_ID__c                           │  │
│  │  • Related to Account (parent)                          │  │
│  │  • 99.93% success rate                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Timing Diagram (Staggered Partition Execution)

```
Time →  0h    1.5h   3h    4.5h   6h    7.5h
        │     │      │     │      │     │
P0      ████████████████████████████████      (400K records)
        │     │      │     │      │     │
P1      │     ████████████████████████████    (400K records)
        │     │      │     │      │     │
P2      │     │      ████████████████████████ (400K records)
        │     │      │     │      │     │
P3      │     │      │     ████████████████████████ (400K records)
        │     │      │     │      │     │
P4      │     │      │     │      ████████████████████████ (400K records)
        │     │      │     │      │     │

Legend:
████ = Active processing
│    = Waiting/Idle
```

**Key Points**:
- Each partition processes 400K records sequentially
- Partitions start 1.5 hours apart (staggered)
- Total time: ~7 hours for all 2M records
- Overlap is minimal, reducing Account lock conflicts

### Data Flow Sequence

```
1. START_TEST8.APEX
   └─> Creates 5 DataCloudPartition__c records
   └─> Starts Partition 0 immediately
   └─> Schedules Partitions 1-4 (1.5h intervals)

2. PARTITION 0 STARTS (T=0h)
   └─> DynamicPartitionProcessorV2.execute()
       ├─> Query 500 records from Data Cloud
       ├─> Build CSV content
       ├─> createBulkJob() → Bulk API 2.0
       ├─> uploadDataToJob() → CSV data
       ├─> closeJob() → Start async processing
       └─> DelayedBatchStarterV2.execute()
           └─> Wait ~10s
           └─> Schedule next batch
           
3. RETRY LOGIC (if needed)
   └─> Attempt fails (UNABLE_TO_LOCK_ROW)
   └─> handleRetry()
       ├─> Check retry count < 3
       ├─> Apply exponential backoff
       │   ├─> Retry 1: 2 second delay
       │   ├─> Retry 2: 5 second delay
       │   └─> Retry 3: 10 second delay
       └─> makeBulkAPICallWithRetry()

4. PARTITION 1 STARTS (T=1.5h)
   └─> Same process as Partition 0
   └─> Different ExternalId range (minimal overlap)

5. ... Partitions 2, 3, 4 follow ...

6. ALL COMPLETE (T=~7h)
   └─> 1,998,599 opportunities created
   └─> 99.93% success rate
```

---

## Technical Components

### 1. Custom Object: DataCloudPartition__c

**Purpose**: Track progress and status of each partition

**Fields**:
```apex
Name                  : Text(80)     - e.g., "StaggeredPartition_0"
PartitionId__c        : Number(2,0)  - Partition number (0-4)
CurrentOffset__c      : Number(10,0) - Deprecated (was for OFFSET pagination)
TotalProcessed__c     : Number(10,0) - Total records processed
TotalBulkAPICalls__c  : Number(10,0) - Total Bulk API calls made
Status__c             : Text(50)     - "Running", "Completed", "Failed"
```

**Why Needed**: 
- Enables monitoring progress in real-time
- Survives batch execution boundaries (stateful)
- Allows restart/recovery if needed

---

### 2. Apex Class: DynamicPartitionProcessorV2

**Purpose**: Core batch processor that handles data loading

**Full Code**: See next section

**Key Features**:
1. **ExternalId-based Pagination**: No OFFSET, no duplicates
2. **Stateful Variables**: Tracks progress across batch executions
3. **Self-Chaining**: Schedules itself to continue processing
4. **Bulk API Integration**: Creates/uploads/closes Bulk API 2.0 jobs
5. **Exponential Backoff Retry**: Intelligent retry logic
6. **Progress Tracking**: Updates DataCloudPartition__c records

**Key Methods**:
- `start()`: Initialize batch execution
- `execute()`: Process one batch of 500 records
- `finish()`: Chain to next batch or mark complete
- `makeBulkAPICall()`: Entry point for API call
- `makeBulkAPICallWithRetry()`: Implements retry with backoff
- `handleRetry()`: Centralized retry logic
- `createBulkJob()`: Bulk API 2.0 job creation
- `uploadDataToJob()`: CSV upload
- `closeJob()`: Finalize job for async processing

---

### 3. Apex Class: DelayedBatchStarterV2

**Purpose**: Add deliberate delay between batch executions

**Why Needed**: 
- Apex doesn't support `Thread.sleep()`
- Queueable jobs have natural ~10s delay
- Combined with Salesforce's batch processing delay: 20-30s total

**Code**:
```apex
public class DelayedBatchStarterV2 implements Queueable {
    
    private DynamicPartitionProcessorV2 batchToStart;
    
    public DelayedBatchStarterV2(DynamicPartitionProcessorV2 batch) {
        this.batchToStart = batch;
    }
    
    public void execute(QueueableContext context) {
        // Queueable adds ~10s natural delay
        // Start the next batch
        Database.executeBatch(batchToStart, 1);
    }
}
```

**Flow**:
```
Batch Execution → finish() → DelayedBatchStarterV2 
  → ~10s delay → Next Batch Execution
```

---

### 4. Apex Class: PartitionScheduler

**Purpose**: Scheduled job that starts a partition at a specific time

**Code**:
```apex
public class PartitionScheduler implements Schedulable {
    
    private Integer partitionId;
    private String partitionName;
    private String rangeStart;
    private String rangeEnd;
    
    public PartitionScheduler(Integer pId, String pName, String start, String endVal) {
        this.partitionId = pId;
        this.partitionName = pName;
        this.rangeStart = start;
        this.rangeEnd = endVal;
    }
    
    public void execute(SchedulableContext sc) {
        DynamicPartitionProcessorV2 batch = new DynamicPartitionProcessorV2(
            partitionId, partitionName, rangeStart, rangeEnd
        );
        Database.executeBatch(batch, 1);
    }
}
```

**Usage**: Scheduled via `System.schedule()` with CRON expression

---

### 5. Bulk API Helper Classes

**Purpose**: Encapsulate Bulk API 2.0 interactions

**Key Classes**:
- `BulkAPI1Helper`: Bulk API 1.0 operations (not used in final solution, kept for reference)
- Built-in methods in DynamicPartitionProcessorV2:
  - `createBulkJob()`
  - `uploadDataToJob()`
  - `closeJob()`

---

### 6. Monitoring Scripts

**check_test8_progress.apex**: Real-time progress monitoring
```apex
// Shows:
// - Partition status
// - Records processed
// - Success rate
// - Projected results
```

**monitor_test8.sh**: Convenience shell script
```bash
#!/bin/bash
# Automated monitoring every N minutes
```

---

## Implementation Guide

### Prerequisites

1. **Salesforce Org Requirements**:
   - Data Cloud enabled
   - Bulk API 2.0 access
   - API calls available (4000+ for 2M records)

2. **Data Requirements**:
   - External ID field on target object
   - Data Cloud object with queryable records
   - ExternalId field that supports range queries

3. **Custom Objects**:
   - Deploy `DataCloudPartition__c` custom object

### Step-by-Step Implementation

#### Step 1: Deploy Custom Object
```bash
sf project deploy start --source-dir force-app/main/default/objects/DataCloudPartition__c --target-org YourOrg
```

#### Step 2: Deploy Apex Classes
```bash
sf project deploy start --source-dir force-app/main/default/classes --target-org YourOrg
```

Classes to deploy:
- `DynamicPartitionProcessorV2.cls`
- `DelayedBatchStarterV2.cls`
- `PartitionScheduler.cls`
- `DeleteTest8OpportunitiesBatch.cls` (cleanup utility)
- `BulkAPI1Helper.cls` (reference only)

#### Step 3: Calculate Partition Ranges

For 2M records with 5 partitions:
```javascript
const totalRecords = 2000000;
const partitions = 5;
const recordsPerPartition = totalRecords / partitions; // 400,000

// Generate boundary points
const boundaries = [];
for (let i = 0; i <= partitions; i++) {
    const recordNum = i * recordsPerPartition + 1;
    const externalId = `externalOpp${recordNum.toString().padStart(7, '0')}`;
    boundaries.push(externalId);
}

// Result:
// externalOpp0000001
// externalOpp0400001
// externalOpp0800001
// externalOpp1200001
// externalOpp1600001
// externalOpp2000000
```

#### Step 4: Customize Start Script

Edit `start_test8.apex` to match your object:

```apex
// Change the SQL query
String sqlQuery = 
    'SELECT "YourExternalId__c", "YourField1__c", "YourField2__c" ' +
    'FROM "YourDataCloudObject__dlm" ' +
    'WHERE "YourExternalId__c" > \'' + lastProcessedId + '\' ' +
    'ORDER BY "YourExternalId__c" ' +
    'LIMIT ' + RECORDS_PER_BATCH;

// Change the CSV building logic
private String buildCSVContent(List<YourData> records) {
    String csv = 'External_ID__c,Field1__c,Field2__c\n';
    for (YourData rec : records) {
        csv += escapeCsvField(rec.externalId) + ',';
        csv += escapeCsvField(rec.field1) + ',';
        csv += escapeCsvField(rec.field2) + '\n';
    }
    return csv;
}

// Change the Bulk API job creation
req.setBody('{"object":"YourObject","externalIdFieldName":"External_ID__c","contentType":"CSV","operation":"upsert","lineEnding":"LF"}');
```

#### Step 5: Test with Small Dataset

Before running full 2M records:

```apex
// Test with 1000 records
String testRangeStart = 'externalOpp0000001';
String testRangeEnd = 'externalOpp0001000';

DynamicPartitionProcessorV2 testBatch = new DynamicPartitionProcessorV2(
    0, 'TestPartition_0', testRangeStart, testRangeEnd
);
Database.executeBatch(testBatch, 1);
```

Monitor results:
```apex
Integer created = [SELECT COUNT() FROM YourObject WHERE StageName = 'TestStage'];
System.debug('Created: ' + created + ' out of 1000');
```

#### Step 6: Run Full Load

```bash
sf apex run --file start_test8.apex --target-org YourOrg
```

#### Step 7: Monitor Progress

Every 15-30 minutes:
```bash
./monitor_test8.sh
```

Or:
```bash
sf apex run --file check_test8_progress.apex --target-org YourOrg
```

---

## Monitoring and Logging

### Real-Time Monitoring

**DataCloudPartition__c Records**:
```sql
SELECT Name, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
FROM DataCloudPartition__c
WHERE Name LIKE 'StaggeredPartition_%'
ORDER BY Name
```

**Async Apex Jobs**:
```sql
SELECT Id, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems, 
       NumberOfErrors, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name IN ('DynamicPartitionProcessorV2', 'DelayedBatchStarterV2')
AND Status IN ('Processing', 'Queued', 'Preparing')
ORDER BY CreatedDate DESC
```

**Scheduled Jobs**:
```sql
SELECT Id, CronJobDetail.Name, NextFireTime, State
FROM CronTrigger
WHERE CronJobDetail.Name LIKE 'Partition%'
ORDER BY NextFireTime
```

### Debug Logs

**Key Log Messages** (with emoji indicators):

Success Messages:
- `✅ Job {jobId} with {count} records` - Successful batch
- `✅ RETRY SUCCESS: Job {jobId}` - Retry succeeded
- `✅ {partitionName} COMPLETE` - Partition finished

Progress Messages:
- `📤 Bulk API 2.0: {count} records (attempt {n})` - Starting API call
- `✓ {partitionName} scheduled next batch from {id}` - Chaining to next batch

Warning Messages:
- `⚠️ Job close warning for {jobId}` - Job close failed but may still process
- `⏳ Exponential backoff: waiting {n}s` - Applying retry delay

Error Messages:
- `❌ ERROR: {message}` - Operation failed
- `🔄 Scheduling retry {n}/{max}` - Retry scheduled
- `❌ FAILED: Exhausted all {max} retries` - All retries failed

Stop Messages:
- `⏹️ {partitionName} stopping: {reason}` - Partition stopped (normal or error)

### Log Query Examples

**Find Failed Batches**:
```sql
SELECT Id, ApexClass.Name, Status, NumberOfErrors, ExtendedStatus
FROM AsyncApexJob
WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
AND Status = 'Failed'
ORDER BY CreatedDate DESC
```

**Check Bulk API Jobs** (via Workbench or API):
```
GET /services/data/v59.0/jobs/ingest
```

### Monitoring Dashboard Queries

**Success Rate Calculation**:
```apex
Integer totalProcessed = [SELECT SUM(TotalProcessed__c) FROM DataCloudPartition__c][0].get(0);
Integer totalCreated = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test8'];
Decimal successRate = (Decimal.valueOf(totalCreated) / Decimal.valueOf(totalProcessed)) * 100;
```

**Estimated Completion Time**:
```apex
// Get partition with most progress
DataCloudPartition__c p = [SELECT TotalProcessed__c, LastModifiedDate, CreatedDate 
                            FROM DataCloudPartition__c 
                            WHERE Name = 'StaggeredPartition_0'][0];

Long elapsedMs = p.LastModifiedDate.getTime() - p.CreatedDate.getTime();
Integer processed = p.TotalProcessed__c.intValue();
Integer remaining = 400000 - processed;

Decimal recordsPerMs = Decimal.valueOf(processed) / Decimal.valueOf(elapsedMs);
Long estimatedMs = (Long)(remaining / recordsPerMs);
Datetime estimatedComplete = System.now().addMilliseconds(estimatedMs.intValue());
```

---

## Performance Metrics

### Test8 Final Results (Production Configuration)

| Metric | Value | Notes |
|--------|-------|-------|
| **Total Records** | 1,999,999 | From Data Cloud |
| **Records Created** | 1,998,599 | In Salesforce Core |
| **Success Rate** | 99.93% | Industry-leading |
| **Failed Records** | 1,400 | 0.07% failure rate |
| **Duration** | 7h 5m | For 2M records |
| **Throughput** | 4,703 records/min | Average |
| **API Calls** | 4,000 | ~500 records each |
| **Partitions** | 5 | 400K records each |
| **Partition Stagger** | 1.5 hours | Between starts |
| **Batch Delay** | 20-30 seconds | Between batches |
| **Retries Used** | ~1-3% of batches | Exponential backoff |

### Comparison Across Tests

| Test | Batch Size | Delay | Stagger | Retry | Success | Duration |
|------|------------|-------|---------|-------|---------|----------|
| Test3 | 2000 | None | None | No | 21% | ~2h |
| Test4 | 500 | 10-20s | 1h | No | 89% | ~5h |
| Test7 | 500 | 10-20s | 1h | Yes (immediate) | 90.16% | 4h 54m |
| **Test8** | **500** | **20-30s** | **1.5h** | **Yes (backoff)** | **99.93%** | **7h 5m** |

### Key Insights

1. **Batch Size Impact**: 
   - 2000 records: 21% success (too many locks)
   - 500 records: 89%+ success (sweet spot)

2. **Retry Logic Impact**:
   - No retry: 89% success
   - Immediate retry: 90.16% success (+1.16%)
   - Exponential backoff: 99.93% success (+9.77%)

3. **Time vs Quality Trade-off**:
   - Faster (5h): 89% success, 220K failures
   - Slower (7h): 99.93% success, 1.4K failures
   - **Result**: 40% slower, 99% fewer failures

4. **Scalability**:
   - Linear scaling: 2M records in 7h = ~286K records/hour
   - Predictable: Can estimate time for any volume
   - Reliable: 99.93% success rate maintained

---

## Best Practices and Recommendations

### General Guidelines

1. **Start Small, Scale Gradually**
   - Test with 1K records first
   - Then 10K, 100K, 1M, full dataset
   - Validate success rate at each stage

2. **Monitor Actively During First Run**
   - Check progress every 15-30 minutes
   - Watch for error patterns
   - Adjust configuration if needed

3. **Document Your Specific Configuration**
   - Record count and object type
   - Partition boundaries
   - Any customizations made
   - Success rate achieved

4. **Plan for Cleanup**
   - Delete test data between runs
   - Clear DataCloudPartition__c records
   - Cancel scheduled jobs if restarting

### Configuration Tuning

**Batch Size** (RECORDS_PER_BATCH):
- Start: 500 (recommended)
- If <95% success: Try 250
- If >99.9% success and want faster: Try 750
- Never exceed 2000

**Partition Count**:
- 100K-500K records: 1-2 partitions
- 500K-1M records: 2-3 partitions
- 1M-2M records: 3-5 partitions
- 2M+ records: 5+ partitions

**Partition Stagger**:
- Low lock risk (independent records): 30 minutes
- Medium lock risk (some parent sharing): 1 hour
- High lock risk (many share parents): 1.5-2 hours
- Example: Opportunities → Accounts = high risk

**Batch Delay**:
- Start: 20-30 seconds (recommended)
- If still seeing locks: 30-45 seconds
- If >99% success: Can try 15-20 seconds

**Retry Configuration**:
- Max retries: 3 (recommended)
- Backoff delays: [2000, 5000, 10000] ms
- For very high lock scenarios: [5000, 10000, 20000] ms

### Object-Specific Considerations

**High Lock Risk Objects**:
- Opportunity (multiple per Account)
- Contact (multiple per Account)
- Case (multiple per Account/Contact)

**Mitigation**:
- Increase partition stagger to 1.5-2 hours
- Increase batch delay to 30-45 seconds
- Use 5+ partitions
- Consider sorting data by parent to group related records

**Low Lock Risk Objects**:
- Account (typically independent)
- Custom objects without triggers
- Objects without parent relationships

**Optimization**:
- Can use larger batches (750-1000)
- Shorter stagger (30-60 minutes)
- Fewer partitions (2-3)

### Data Cloud Query Optimization

1. **Always use ORDER BY with ExternalId**:
   ```sql
   ORDER BY "ExternalId__c"
   ```

2. **Use WHERE with > operator** (not >=):
   ```sql
   WHERE "ExternalId__c" > 'lastProcessedId'
   ```

3. **Select only needed fields**:
   ```sql
   SELECT "Field1__c", "Field2__c"  -- Not SELECT *
   ```

4. **Test query performance before full run**:
   ```sql
   -- Should return in <5 seconds
   SELECT COUNT(*) FROM "YourObject__dlm"
   ```

### Error Handling Best Practices

1. **Categorize Errors**:
   - Lock errors: Retry with backoff
   - Validation errors: Log and skip
   - System errors: Alert and investigate

2. **Implement Circuit Breaker**:
   ```apex
   if (consecutiveFailures > 5) {
       // Stop and alert
       throw new ProcessorException('Too many failures');
   }
   ```

3. **Log Failed Records**:
   ```apex
   // Store failed ExternalIds for later retry
   FailedRecord__c fail = new FailedRecord__c(
       ExternalId__c = externalId,
       ErrorMessage__c = error,
       Timestamp__c = System.now()
   );
   insert fail;
   ```

### Production Deployment Checklist

- [ ] Test with sample data (1K records)
- [ ] Verify success rate >99%
- [ ] Customize for your object and fields
- [ ] Calculate partition boundaries
- [ ] Configure monitoring alerts
- [ ] Document configuration used
- [ ] Schedule during low-usage hours
- [ ] Have rollback plan ready
- [ ] Monitor first hour actively
- [ ] Verify data quality after completion

### Maintenance and Support

**Regular Maintenance**:
- Review and clean up DataCloudPartition__c records monthly
- Archive old debug logs
- Monitor API usage trends
- Update documentation with lessons learned

**Performance Degradation**:
If success rate drops below 95%:
1. Check for org-wide issues (lock conflicts from other processes)
2. Review recent trigger/validation changes
3. Increase delays and stagger intervals
4. Consider reducing batch size

**Scaling Beyond 2M**:
For 5M+ records:
- Use 10 partitions (500K each)
- Increase stagger to 2 hours
- Consider running over multiple days
- Use chunked approach (1M per day)

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Low Success Rate (<90%)

**Symptoms**:
- Many `UNABLE_TO_LOCK_ROW` errors
- Success rate not improving with retries

**Diagnosis**:
```apex
// Check for concurrent processes
SELECT Id, ApexClass.Name, Status
FROM AsyncApexJob
WHERE Status IN ('Processing', 'Queued')
AND ApexClass.Name != 'DynamicPartitionProcessorV2'
```

**Solutions**:
1. Increase batch delay to 30-45 seconds
2. Reduce batch size to 250
3. Increase partition stagger to 2 hours
4. Check for other processes updating same records
5. Consider running during off-hours

#### Issue 2: Bulk API Jobs Not Processing

**Symptoms**:
- Jobs created but no records in target object
- Job status stuck at "UploadComplete"

**Diagnosis**:
```bash
# Check job status via Workbench
GET /services/data/v59.0/jobs/ingest/{jobId}
```

**Solutions**:
1. Verify external ID field name matches
2. Check CSV format (especially line endings)
3. Validate field mappings
4. Ensure target object is accessible
5. Check for validation rules blocking insert

#### Issue 3: Partition Stops Prematurely

**Symptoms**:
- Partition shows "Completed" but TotalProcessed < 400K
- Missing records in target object

**Diagnosis**:
```apex
// Check for errors in batch execution
SELECT Id, Status, ExtendedStatus, NumberOfErrors
FROM AsyncApexJob
WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
AND Status = 'Failed'
ORDER BY CreatedDate DESC
LIMIT 5
```

**Solutions**:
1. Check MAX_BATCHES limit (might be too low)
2. Verify Data Cloud query returns expected count
3. Look for exceptions in debug logs
4. Restart partition from last processed ID:
   ```apex
   // Get last processed ID
   String lastId = [SELECT LastProcessedId__c FROM DataCloudPartition__c 
                    WHERE Name = 'StaggeredPartition_0'][0].LastProcessedId__c;
   
   // Restart
   DynamicPartitionProcessorV2 batch = new DynamicPartitionProcessorV2(
       0, 'StaggeredPartition_0_Retry', lastId, 'externalOpp0400001'
   );
   Database.executeBatch(batch, 1);
   ```

#### Issue 4: Governor Limit Errors

**Symptoms**:
- Error: "Too many SOQL queries: 101"
- Error: "Apex CPU time limit exceeded"

**Diagnosis**:
- Check debug logs for query count
- Review CPU time consumption

**Solutions**:
1. Reduce RECORDS_PER_BATCH to 250
2. Optimize Data Cloud query (select fewer fields)
3. Remove unnecessary debug statements
4. Check for inefficient CSV building logic

#### Issue 5: Scheduled Partitions Not Starting

**Symptoms**:
- Partition scheduled but never runs
- No AsyncApexJob records for partition

**Diagnosis**:
```sql
SELECT Id, CronJobDetail.Name, NextFireTime, State, PreviousFireTime
FROM CronTrigger
WHERE CronJobDetail.Name LIKE 'Partition%'
```

**Solutions**:
1. Verify CRON expression is valid
2. Check that scheduled time hasn't passed
3. Ensure no org-wide scheduler issues
4. Manually start partition if needed:
   ```apex
   Test.startTest();
   PartitionScheduler sched = new PartitionScheduler(1, 'StaggeredPartition_1', 
                                                      'externalOpp0400001', 'externalOpp0800001');
   sched.execute(null);
   Test.stopTest();
   ```

#### Issue 6: Duplicate Records Created

**Symptoms**:
- More records in target than in source
- Same ExternalId appears multiple times

**Diagnosis**:
```sql
SELECT External_ID__c, COUNT(*)
FROM Opportunity
WHERE StageName = 'Test8'
GROUP BY External_ID__c
HAVING COUNT(*) > 1
```

**Root Cause**: 
- OFFSET-based pagination (if you modified the code)
- Partition ranges overlap

**Prevention**:
1. Always use ExternalId-based pagination (WHERE > lastId)
2. Ensure partition boundaries don't overlap:
   ```apex
   // Good: P0 ends at 400000, P1 starts at 400001
   // Bad:  P0 ends at 400000, P1 starts at 400000
   ```

#### Issue 7: Data Cloud Query Timeout

**Symptoms**:
- Error: "Read timed out"
- Empty result sets

**Solutions**:
1. Add timeout configuration:
   ```apex
   queryInput.sql = sqlQuery;
   queryInput.timeout = 120000; // 120 seconds
   ```
2. Simplify query (fewer fields, simpler WHERE clause)
3. Ensure Data Cloud object is indexed on ExternalId
4. Contact Salesforce if persistent

### Recovery Procedures

**Scenario 1: Complete Restart Needed**

```apex
// 1. Stop all running jobs
List<CronTrigger> jobs = [SELECT Id FROM CronTrigger 
                          WHERE CronJobDetail.Name LIKE 'Partition%'];
for (CronTrigger job : jobs) {
    System.abortJob(job.Id);
}

// 2. Delete progress records
delete [SELECT Id FROM DataCloudPartition__c];

// 3. Delete created opportunities (if test)
Database.executeBatch(new DeleteTest8OpportunitiesBatch(), 10000);

// 4. Wait for cleanup to complete (~15 minutes)

// 5. Restart
// Run start_test8.apex
```

**Scenario 2: Resume from Failure Point**

```apex
// 1. Find last processed ID for failed partition
DataCloudPartition__c partition = [SELECT LastProcessedId__c, PartitionId__c,
                                   TotalProcessed__c, TotalBulkAPICalls__c
                                   FROM DataCloudPartition__c
                                   WHERE Name = 'StaggeredPartition_2'][0];

// 2. Create new partition starting from that point
DynamicPartitionProcessorV2 resumeBatch = new DynamicPartitionProcessorV2(
    partition.PartitionId__c,
    'StaggeredPartition_2_Resume',
    partition.LastProcessedId__c,
    'externalOpp1200001' // Original end boundary
);

// 3. Restore state
resumeBatch.totalProcessed = partition.TotalProcessed__c.intValue();
resumeBatch.totalBulkAPICalls = partition.TotalBulkAPICalls__c.intValue();

// 4. Resume
Database.executeBatch(resumeBatch, 1);
```

**Scenario 3: Retry Only Failed Records**

```apex
// 1. Export failed ExternalIds
List<FailedRecord__c> failures = [SELECT ExternalId__c FROM FailedRecord__c];
Set<String> failedIds = new Set<String>();
for (FailedRecord__c f : failures) {
    failedIds.add(f.ExternalId__c);
}

// 2. Query from Data Cloud
String idList = '\'' + String.join(new List<String>(failedIds), '\',\'') + '\'';
String retryQuery = 'SELECT * FROM "ExtOpportunities__dlm" ' +
                   'WHERE "ExternalId__c" IN (' + idList + ')';

// 3. Process in small batches of 100
// (Implement custom retry batch)
```

---

## Additional Resources

### Sample Files Included

1. **start_test8.apex** - Main startup script
2. **check_test8_progress.apex** - Progress monitoring
3. **monitor_test8.sh** - Shell monitoring script
4. **test8_final_analysis.apex** - Results analysis
5. **DynamicPartitionProcessorV2.cls** - Core processor
6. **DelayedBatchStarterV2.cls** - Delay mechanism
7. **PartitionScheduler.cls** - Scheduled partition starter
8. **DataCloudPartition__c** - Custom object definition

### External Documentation

- [Salesforce Bulk API 2.0 Guide](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/)
- [Data Cloud Query API](https://developer.salesforce.com/docs/atlas.en-us.c360a_api.meta/c360a_api/)
- [Batch Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch.htm)
- [Apex Governor Limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm)

### Support and Maintenance

**Code Repository**: Store all components in version control

**Change Log**: Document all modifications

**Performance Baseline**: Keep Test8 results as benchmark

**Future Enhancements**:
- Parallel partition execution (if lock risk is low)
- Dynamic batch size adjustment based on success rate
- Auto-retry of failed records
- Integration with monitoring platforms
- Email notifications on completion/failure

---

## Conclusion

This massive data loading solution represents the culmination of 8 iterative tests, achieving a **99.93% success rate** for loading 2 million records from Data Cloud to Salesforce Core.

**Key Success Factors**:
1. **Partitioning**: Divide and conquer with staggered execution
2. **Small Batches**: 500 records minimizes lock contention
3. **Exponential Backoff**: Smart retry logic that works with Salesforce's architecture
4. **Deliberate Delays**: Patience reduces concurrent conflicts
5. **ExternalId Pagination**: Reliable, scalable data retrieval

**Production Ready**: This solution is battle-tested and ready for production use with any Salesforce object requiring bulk data loading from Data Cloud.

**Adaptable**: The architecture and code can be adapted for:
- Any source (Data Cloud, external systems, CSV files)
- Any target (any Salesforce object)
- Any volume (100K to 10M+ records)

**Maintainable**: Clear code structure, comprehensive logging, and extensive documentation ensure long-term maintainability.

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Maintained By**: Development Team  
**Status**: Production-Ready ✅

