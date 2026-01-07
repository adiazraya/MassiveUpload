# Massive Data Loading from Salesforce Data Cloud to Core

## Technical Implementation Guide

**Version:** 1.0  
**Status:** Production-Ready  
**GitHub Repository:** [MassiveUpload Solution](https://github.com/your-org/massive-upload)  
**Last Updated:** January 2026

---

## Table of Contents

1. [Introduction](#introduction)
2. [The Business Challenge](#the-business-challenge)
3. [Technical Challenges](#technical-challenges)
4. [Solution Architecture](#solution-architecture)
5. [Implementation Approaches](#implementation-approaches)
6. [Production Implementation Guide](#production-implementation-guide)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Performance Optimization](#performance-optimization)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [External Documentation](#external-documentation)
11. [Support and Maintenance](#support-and-maintenance)
12. [Conclusion](#conclusion)

---

## Introduction

### Overview

In modern enterprise environments, organizations increasingly need to materialize large datasets from Salesforce Data Cloud into Salesforce Core for operational use. This document presents a production-ready solution for reliably loading millions of records while maintaining high success rates and minimizing system impact.

### Purpose

This guide provides:
- Architectural patterns for large-scale data loading
- Proven strategies for managing record locking and concurrency
- Implementation guidance with reusable components
- Best practices for production deployment
- Monitoring and maintenance procedures

### Scope

While this solution was initially developed for loading Opportunity records, the architecture and components are designed to be object-agnostic. The patterns and code can be adapted for any Salesforce object requiring bulk data loading from Data Cloud, including:
- Accounts
- Contacts
- Cases
- Custom objects
- Any object with parent-child relationships

---

## The Business Challenge

### General Business Need

Modern enterprises face several common scenarios requiring large-scale data movement:

1. **Data Cloud Materialization**: Organizations using Data Cloud for analytics need to materialize aggregated or enriched data back into Salesforce Core for operational processes.

2. **System Migration**: Moving data between Salesforce orgs or from external systems requires efficient, reliable bulk loading.

3. **Batch Processing**: Periodic data updates, enrichment processes, or calculated fields may need to update millions of records.

4. **Data Synchronization**: Keeping Data Cloud insights synchronized with operational records in real-time or near real-time.

### Key Requirements

Any large-scale data loading solution must address:

- **Volume**: Handle millions of records efficiently
- **Reliability**: Achieve high success rates (>95%)
- **Performance**: Complete processing within acceptable timeframes
- **Observability**: Provide real-time monitoring and progress tracking
- **Recoverability**: Support graceful failure handling and restart capabilities
- **Scalability**: Scale linearly with data volume

### Specific Use Case: Opportunity Loading

**Scenario**: An organization needs to load 2 million opportunity records from Data Cloud to Salesforce Core.

**Complexity Factors**:
- Multiple opportunities share the same Account (parent relationship)
- Account records are locked when child opportunities are created/updated
- Concurrent processing can cause lock contention
- Validation rules and triggers add processing overhead
- Data Cloud query performance at scale

**Success Criteria**:
- Load 2 million records with >95% success rate
- Complete processing within 8-12 hours
- Minimize impact on org performance
- Provide real-time progress monitoring
- Support graceful restart on failure

---

## Technical Challenges

### Challenge 1: Record Locking and Concurrency

**Problem**: 
When multiple bulk operations attempt to create or update child records (e.g., Opportunities) that share the same parent record (e.g., Account), Salesforce locks the parent record. This causes the classic `UNABLE_TO_LOCK_ROW` error.

**Why It Happens**:
- Salesforce uses row-level locking to maintain data integrity
- Parent records are locked when child records are modified
- With thousands of opportunities per account, concurrent batches frequently conflict
- Lock duration depends on batch size, triggers, and validation rules

**Mitigation Strategies**:
1. **Reduce Batch Size**: Smaller batches (250-500 records) reduce lock duration and probability of conflicts
2. **Add Delays**: Introduce deliberate delays (20-30 seconds) between batch executions
3. **Partition Data**: Split data into non-overlapping partitions processed sequentially or with staggered starts
4. **Optimize Triggers**: Review and optimize triggers on affected objects to reduce lock time
5. **Strategic Scheduling**: Process during off-hours when org activity is minimal

### Challenge 2: Bulk API Rate Limits and Quotas

**Problem**:
Salesforce imposes API call limits and concurrent request limits that can throttle or block large-scale operations.

**Considerations**:
- 24-hour rolling API limit (varies by edition)
- Concurrent Bulk API job limits
- Query row limits from Data Cloud
- Request timeout constraints

**Mitigation Strategies**:
1. **API Call Planning**: Calculate total API calls needed (records / batch size)
2. **Monitor Usage**: Track API consumption in real-time
3. **Throttling Logic**: Implement automatic throttling when approaching limits
4. **Off-Peak Processing**: Schedule during periods of low API usage
5. **Bulk API 2.0**: Leverage modern API with better performance characteristics

### Challenge 3: Data Consistency and Pagination

**Problem**:
Traditional OFFSET-based pagination can lead to duplicates or missed records when dealing with millions of records, especially if data changes during processing.

**Issues with OFFSET**:
- Performance degrades with large offsets
- Data mutations during processing cause shifts
- Inconsistent results across queries
- Not supported reliably by all Data Cloud objects

**Mitigation Strategies**:
1. **ExternalId-Based Pagination**: Use WHERE clauses with ordered ExternalId fields
2. **Cursor-Based Approach**: Track last processed ID and query for records greater than cursor
3. **Immutable Snapshots**: Query against stable data snapshots when possible
4. **Idempotent Operations**: Use upsert with external IDs to handle duplicates gracefully

### Challenge 4: Governor Limits in Apex

**Problem**:
Salesforce Apex has per-transaction governor limits that constrain how much work can be done in a single execution context.

**Key Limits**:
- SOQL queries: 100 per transaction
- DML statements: 150 per transaction
- Callouts: 100 per transaction
- CPU time: 60,000ms
- Heap size: 12MB

**Mitigation Strategies**:
1. **Batch Apex**: Use stateful batch processing to maintain state across transactions
2. **Queueable Jobs**: Chain queueable jobs for delayed execution
3. **Scheduled Apex**: Use scheduler for time-based partition starts
4. **Minimize Queries**: Consolidate queries and avoid queries in loops
5. **Efficient Code**: Optimize algorithms to reduce CPU and memory usage

### Challenge 5: Error Handling and Recovery

**Problem**:
With millions of records and hours of processing, transient failures are inevitable. The system must handle failures gracefully and provide recovery mechanisms.

**Common Failure Scenarios**:
- Network timeouts
- Temporary lock contention
- API rate limiting
- Data validation failures
- System maintenance windows

**Mitigation Strategies**:
1. **Retry Logic**: Implement intelligent retry with exponential backoff
2. **Progress Tracking**: Persist state to enable restart from failure point
3. **Error Logging**: Capture detailed error information for analysis
4. **Circuit Breakers**: Stop processing after repeated failures
5. **Manual Recovery**: Provide tools to identify and reprocess failed records

---

## Solution Architecture

### High-Level Architecture

The solution employs a partitioned, staged processing approach with intelligent retry logic:

```
┌─────────────────────────────────────────────────────────────────┐
│                    SALESFORCE DATA CLOUD                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │         Source Data (Millions of Records)                  │ │
│  │  Partitioned by ExternalId ranges:                        │ │
│  │  • Partition 0: ID range 1                                │ │
│  │  • Partition 1: ID range 2                                │ │
│  │  • Partition N: ID range N                                │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ CDP Query API
                            │ (ExternalId-based pagination)
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              SALESFORCE CORE - ORCHESTRATION LAYER               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │          Partition Scheduler (Staggered Starts)            │ │
│  │  • Partition 0: Start immediately                          │ │
│  │  • Partition 1: Start + 1.5 hours                         │ │
│  │  • Partition N: Start + (N * 1.5) hours                   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            │                                      │
│                            ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │      Stateful Batch Processor (Self-Chaining)             │ │
│  │  • Query 500 records from Data Cloud                      │ │
│  │  • Build CSV content                                      │ │
│  │  • Submit to Bulk API 2.0                                 │ │
│  │  • Implement retry with exponential backoff               │ │
│  │  • Update progress tracking                               │ │
│  │  • Chain to next batch with delay                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            │                                      │
│                            ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Delay Mechanism (Queueable)                      │ │
│  │  • Natural Salesforce batch delay: 10-20s                 │ │
│  │  • Queueable job delay: 10-15s                            │ │
│  │  • Total delay: 20-30s between batches                    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                            │                                      │
│                            │ Bulk API 2.0                         │
│                            ▼                                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │      Salesforce Bulk API 2.0 (Parallel Mode)              │ │
│  │  • Create job (upsert by External ID)                     │ │
│  │  • Upload CSV batch                                       │ │
│  │  • Close job for async processing                         │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              SALESFORCE CORE - TARGET OBJECT                     │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Target Records (Millions Created/Updated)        │ │
│  │  • Upserted by External ID                                │ │
│  │  • High success rate (>95%)                               │ │
│  │  • Progress tracked in real-time                          │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

#### 1. Partitioned Processing

**Rationale**: 
Dividing the dataset into logical partitions (typically 400,000-500,000 records each) provides:
- Isolated failure domains (one partition failure doesn't affect others)
- Parallel processing capability (with controlled stagger)
- Easier progress monitoring
- Simplified restart logic

**Implementation**:
Partitions are based on ExternalId ranges, ensuring no overlap and complete coverage.

#### 2. Staggered Execution

**Rationale**:
Starting partitions at staggered intervals (1.5-2 hour delays) reduces:
- Concurrent access to shared parent records
- Lock contention probability
- API rate limit pressure
- Overall system load

**Trade-off**:
Longer total processing time (7-8 hours vs 5-6 hours) for significantly higher success rates.

#### 3. Small Batch Sizes (500 records)

**Rationale**:
Smaller batches reduce:
- Lock duration on parent records
- Probability of concurrent access
- Impact of individual batch failures
- Memory and CPU usage per transaction

**Trade-off**:
More API calls and slightly longer processing time, but dramatically improved success rates.

#### 4. Exponential Backoff Retry

**Rationale**:
Progressive retry delays (2s → 5s → 10s) allow:
- Locks to be released naturally
- System resources to stabilize
- Avoidance of "thundering herd" problems
- Higher ultimate success rates

**Industry Standard**:
Exponential backoff is a well-established pattern for distributed systems and API interactions.

#### 5. Bulk API 2.0 Parallel Mode

**Rationale**:
Bulk API 2.0 offers:
- Simpler JSON-based interface (vs XML in API 1.0)
- Better performance characteristics
- Modern asynchronous processing
- Improved error reporting

**Note**: While Bulk API 2.0 doesn't support serial concurrency mode, we control concurrency at the application level through partitioning and delays.

---

## Implementation Approaches

Throughout the development and testing phases, we explored multiple approaches to address the challenges of large-scale data loading. This section documents the various strategies attempted and the lessons learned.

### Approach 1: Simple Batch Processing

**Strategy**: Process all records in a single batch job with large batch sizes (2000 records).

**Outcomes**:
- Excessive lock contention due to high concurrency
- Low success rates due to parent record conflicts
- Difficult to monitor and restart

**Lessons Learned**:
- Batch size has significant impact on lock contention
- Large batches increase probability of concurrent parent access
- Governor limits constrain single-batch approaches at scale

**When to Use**: Small datasets (<10,000 records) with low lock risk

### Approach 2: Reduced Batch Size

**Strategy**: Reduce batch size to 500 records while maintaining continuous processing.

**Outcomes**:
- Dramatic improvement in success rates
- Reduced lock duration per batch
- Better governor limit management
- Still experienced some lock contention

**Lessons Learned**:
- Batch size of 500 provides good balance between performance and reliability
- Smaller batches alone don't eliminate all lock issues
- Additional strategies needed for parent-child relationships

**When to Use**: Moderate datasets (10K-100K records) with moderate lock risk

### Approach 3: Bulk API 1.0 Serial Mode

**Strategy**: Switch to Bulk API 1.0 to leverage serial concurrency mode.

**Outcomes**:
- Serial mode provides strict sequential processing
- Different internal processing model than API 2.0
- Performance characteristics varied from expectations
- More complex XML-based API

**Lessons Learned**:
- Serial mode doesn't guarantee better results due to internal Salesforce processing
- API 1.0 has more complex interface (XML vs JSON)
- Bulk API 2.0 Parallel with application-level concurrency control performs better

**When to Use**: Specific scenarios where serial processing is explicitly required

### Approach 4: Partitioned Processing with Delays

**Strategy**: 
- Partition data into 5 segments (400K records each)
- Add deliberate delays between batch executions (20-30 seconds)
- Stagger partition starts (1.5 hours apart)

**Outcomes**:
- Significant reduction in concurrent processing
- Minimal parent record overlap between partitions
- High success rates achieved
- Longer total processing time but acceptable

**Lessons Learned**:
- Strategic delays are crucial for lock mitigation
- Partition size of 400K-500K works well
- Stagger timing should match partition processing duration
- Trade-off between speed and reliability is worthwhile

**When to Use**: Large datasets (>100K records) with high lock risk

### Approach 5: Intelligent Retry Logic

**Strategy**: Implement exponential backoff retry with progressive delays.

**Initial Approach** - Immediate Retry:
- Retry failed batches immediately
- Limited improvement as locks may still exist

**Refined Approach** - Exponential Backoff:
- First retry: Wait 2 seconds
- Second retry: Wait 5 seconds  
- Third retry: Wait 10 seconds
- Abandon after 3 retries

**Outcomes**:
- Dramatic improvement in success rates
- Locks have time to clear between retries
- Reduced "retry storm" effects
- Industry best practice implementation

**Lessons Learned**:
- Timing of retries is as important as number of retries
- Exponential backoff allows system to stabilize
- 2-3 retries with backoff optimal for most scenarios

**When to Use**: All large-scale data loading scenarios

### Approach 6: ExternalId-Based Pagination

**Strategy**: Use WHERE clauses with ExternalId comparisons instead of OFFSET.

**Traditional OFFSET Approach**:
```sql
SELECT * FROM Object LIMIT 500 OFFSET 1000
```
Problems: Inconsistent with data changes, performance degradation

**ExternalId Approach**:
```sql
SELECT * FROM Object 
WHERE ExternalId > 'lastProcessedId'
ORDER BY ExternalId
LIMIT 500
```

**Outcomes**:
- No duplicates regardless of data changes
- Consistent performance at any offset
- Reliable for millions of records
- State easily tracked and recovered

**Lessons Learned**:
- ExternalId pagination essential for large datasets
- Requires proper indexing on ExternalId field
- Must track last processed ID for restart capability

**When to Use**: All scenarios with large datasets or long-running processes

---

## Production Implementation Guide

### Prerequisites

Before deploying the solution, ensure:

1. **Salesforce Environment**:
   - Data Cloud enabled and configured
   - Bulk API 2.0 access (included in most editions)
   - Sufficient API limits (calculate: records / 500 = calls needed)
   - Target object has External ID field

2. **Data Preparation**:
   - Source data in Data Cloud with queryable object
   - External ID field populated and unique
   - Data Cloud object indexed on External ID
   - Test query performance (<5 seconds for 500 records)

3. **Permissions**:
   - API Enabled permission
   - View All Data permission
   - Modify All Data permission (or object-level CRUD)
   - Data Cloud Query access

### Step 1: Deploy Custom Objects

Deploy the progress tracking object:

```bash
# Clone repository
git clone https://github.com/your-org/massive-upload.git
cd massive-upload

# Deploy custom object
sfdx force:source:deploy -p force-app/main/default/objects/DataCloudPartition__c -u YourOrgAlias
```

**DataCloudPartition__c Fields**:
- Name (Text): Partition identifier
- PartitionId__c (Number): Numeric partition ID
- TotalProcessed__c (Number): Records processed count
- TotalBulkAPICalls__c (Number): API calls made
- Status__c (Picklist): Running / Completed / Failed

### Step 2: Deploy Apex Classes

Deploy all processor classes:

```bash
# Deploy all Apex classes
sfdx force:source:deploy -p force-app/main/default/classes -u YourOrgAlias
```

**Classes Deployed**:
1. `DynamicPartitionProcessorV2` - Core batch processor
2. `DelayedBatchStarterV2` - Delay mechanism  
3. `PartitionScheduler` - Scheduled partition starter
4. `OpportunityBulkAPIUploader` - Data wrapper (customize for your object)
5. Supporting utility classes

### Step 3: Calculate Partition Boundaries

Determine your ExternalId range and partition count:

```apex
// Example: 2M records, 5 partitions = 400K per partition
Integer totalRecords = 2000000;
Integer partitionCount = 5;
Integer recordsPerPartition = totalRecords / partitionCount;

// Generate boundaries
List<String> boundaries = new List<String>();
for (Integer i = 0; i <= partitionCount; i++) {
    Integer recordNum = (i * recordsPerPartition) + 1;
    String externalId = 'PREFIX' + String.valueOf(recordNum).leftPad(7, '0');
    boundaries.add(externalId);
}
```

**Partition Sizing Guidelines**:
- 100K-500K records: 1-2 partitions
- 500K-1M records: 2-3 partitions
- 1M-2M records: 3-5 partitions
- 2M-5M records: 5-10 partitions
- 5M+ records: 10-20 partitions

### Step 4: Customize for Your Object

Modify the processor for your specific object:

```apex
// In DynamicPartitionProcessorV2.cls

// 1. Update Data Cloud query (line ~45)
String sqlQuery = 
    'SELECT "YourExternalId__c", "Field1__c", "Field2__c" ' +
    'FROM "YourDataCloudObject__dlm" ' +
    'WHERE "YourExternalId__c" > \'' + lastProcessedId + '\' ' +
    'AND "YourExternalId__c" <= \'' + rangeEnd + '\' ' +
    'ORDER BY "YourExternalId__c" ' +
    'LIMIT ' + RECORDS_PER_BATCH;

// 2. Update data parsing (lines ~72-96)
String externalId = (String) values[0];
String field1 = (String) values[1];
// ... parse your fields

// 3. Update CSV building (lines ~277-289)
String csv = 'External_ID__c,Field1__c,Field2__c\n';
for (YourData record : records) {
    csv += record.externalId + ',' +
           escapeCsvField(record.field1) + ',' +
           escapeCsvField(record.field2) + '\n';
}

// 4. Update Bulk API job creation (line ~306)
req.setBody('{"object":"YourObject__c",' +
           '"externalIdFieldName":"External_ID__c",' +
           '"contentType":"CSV","operation":"upsert","lineEnding":"LF"}');
```

### Step 5: Test with Sample Data

Always test with a small dataset first:

```apex
// Test with 1000 records
DynamicPartitionProcessorV2 testBatch = new DynamicPartitionProcessorV2(
    0,                          // partitionId
    'TestPartition_0',          // name
    'PREFIX0000001',            // start
    'PREFIX0001000'             // end
);
Database.executeBatch(testBatch, 1);
```

Monitor the test:
```apex
// Check progress
DataCloudPartition__c progress = [
    SELECT TotalProcessed__c, Status__c 
    FROM DataCloudPartition__c 
    WHERE Name = 'TestPartition_0'
];

// Check results
Integer created = [SELECT COUNT() FROM YourObject__c WHERE CreatedDate = TODAY];
```

**Success Criteria for Test**:
- No exceptions in debug logs
- Progress record updates correctly
- Target records created
- Success rate >95%

### Step 6: Configure Production Parameters

Update configuration constants in `DynamicPartitionProcessorV2`:

```apex
// Optimal configuration
private static final Integer RECORDS_PER_BATCH = 500;
private static final Integer MAX_BATCHES = 800;  // Adjust for partition size
private static final Integer MAX_RETRIES = 3;
private static final List<Integer> RETRY_DELAYS = new List<Integer>{2000, 5000, 10000};
```

**Parameter Tuning**:

| Scenario | Batch Size | Delay | Stagger | Retries |
|----------|-----------|-------|---------|---------|
| Low lock risk | 750-1000 | 15-20s | 1h | 2-3 |
| Medium lock risk | 500-750 | 20-30s | 1.5h | 3 |
| High lock risk | 250-500 | 30-45s | 2h | 3-4 |

### Step 7: Deploy Monitoring Scripts

Copy monitoring scripts to your project:

```bash
# From GitHub repository
cp scripts/check_progress.apex ./
cp scripts/monitor.sh ./
chmod +x monitor.sh
```

Test monitoring:
```bash
sfdx force:apex:execute -f check_progress.apex -u YourOrgAlias
```

### Step 8: Execute Production Load

Create and execute the startup script:

```apex
// start_production_load.apex
System.debug('Starting production data load...');

// Clean up any previous runs
delete [SELECT Id FROM DataCloudPartition__c];
List<CronTrigger> oldJobs = [SELECT Id FROM CronTrigger 
                              WHERE CronJobDetail.Name LIKE 'Partition%'];
for (CronTrigger ct : oldJobs) {
    System.abortJob(ct.Id);
}

// Define partition boundaries
List<String> boundaries = new List<String>{
    'PREFIX0000001',  // Partition 0 start
    'PREFIX0400001',  // Partition 1 start  
    'PREFIX0800001',  // Partition 2 start
    'PREFIX1200001',  // Partition 3 start
    'PREFIX1600001',  // Partition 4 start
    'PREFIX2000000'   // Partition 4 end
};

// Create progress records
List<DataCloudPartition__c> progressRecords = new List<DataCloudPartition__c>();
for (Integer i = 0; i < 5; i++) {
    progressRecords.add(new DataCloudPartition__c(
        Name = 'Partition_' + i,
        PartitionId__c = i,
        TotalProcessed__c = 0,
        TotalBulkAPICalls__c = 0,
        Status__c = 'Pending'
    ));
}
insert progressRecords;

// Start partition 0 immediately
DynamicPartitionProcessorV2 batch0 = new DynamicPartitionProcessorV2(
    0, 'Partition_0', boundaries[0], boundaries[1]
);
Database.executeBatch(batch0, 1);
System.debug('✓ Partition 0 started');

// Schedule partitions 1-4 with 1.5-hour stagger
Datetime now = System.now();
for (Integer i = 1; i < 5; i++) {
    Integer delayMinutes = i * 90;  // 90 minutes = 1.5 hours
    Datetime scheduleTime = now.addMinutes(delayMinutes);
    
    String cronExp = 
        scheduleTime.second() + ' ' +
        scheduleTime.minute() + ' ' +
        scheduleTime.hour() + ' ' +
        scheduleTime.day() + ' ' +
        scheduleTime.month() + ' ? ' +
        scheduleTime.year();
    
    PartitionScheduler scheduler = new PartitionScheduler(
        i, 'Partition_' + i, boundaries[i], boundaries[i+1]
    );
    
    System.schedule('Partition_' + i, cronExp, scheduler);
    System.debug('✓ Partition ' + i + ' scheduled for ' + scheduleTime);
}

System.debug('Production load started successfully!');
```

Execute:
```bash
sfdx force:apex:execute -f start_production_load.apex -u YourOrgAlias
```

### Step 9: Monitor Execution

Monitor progress every 15-30 minutes:

```bash
# Using provided script
./monitor.sh

# Or manually
sfdx force:apex:execute -f check_progress.apex -u YourOrgAlias
```

**Key Metrics to Monitor**:
- Records processed per partition
- Current success rate
- Active batch job count
- API usage percentage
- Error patterns in logs

### Step 10: Post-Execution Validation

After completion, validate results:

```apex
// Verify completion
List<DataCloudPartition__c> partitions = [
    SELECT Name, TotalProcessed__c, Status__c
    FROM DataCloudPartition__c
    ORDER BY PartitionId__c
];

Integer totalProcessed = 0;
Boolean allComplete = true;
for (DataCloudPartition__c p : partitions) {
    totalProcessed += p.TotalProcessed__c.intValue();
    if (p.Status__c != 'Completed') {
        allComplete = false;
    }
    System.debug(p.Name + ': ' + p.TotalProcessed__c + ' records (' + p.Status__c + ')');
}

// Check target object
Integer created = [SELECT COUNT() FROM YourObject__c WHERE CreatedDate = TODAY];

// Calculate success rate
Decimal successRate = (Decimal.valueOf(created) / Decimal.valueOf(totalProcessed)) * 100;
System.debug('Success Rate: ' + successRate.setScale(2) + '%');

if (successRate >= 95) {
    System.debug('✓ SUCCESS: Production load completed successfully');
} else {
    System.debug('⚠ WARNING: Success rate below target, investigate failures');
}
```

---

## Monitoring and Observability

### Real-Time Monitoring

**Progress Tracking Query**:
```sql
SELECT Name, PartitionId__c, TotalProcessed__c, 
       TotalBulkAPICalls__c, Status__c, LastModifiedDate
FROM DataCloudPartition__c
WHERE Name LIKE 'Partition_%'
ORDER BY PartitionId__c
```

**Active Job Monitoring**:
```sql
SELECT Id, ApexClass.Name, Status, JobItemsProcessed, 
       TotalJobItems, NumberOfErrors, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name IN ('DynamicPartitionProcessorV2', 
                         'DelayedBatchStarterV2')
AND Status IN ('Processing', 'Queued', 'Preparing')
ORDER BY CreatedDate DESC
```

**Scheduled Job Status**:
```sql
SELECT Id, CronJobDetail.Name, NextFireTime, 
       PreviousFireTime, State
FROM CronTrigger
WHERE CronJobDetail.Name LIKE 'Partition%'
ORDER BY NextFireTime
```

### Debug Log Analysis

The solution uses emoji indicators for quick log scanning:

- ✅ `SUCCESS` - Operation completed successfully
- ❌ `ERROR` - Operation failed
- 🔄 `RETRY` - Retry attempt being made
- ⏳ `WAITING` - Backoff delay in progress
- ⚠️ `WARNING` - Non-critical issue
- 📤 `UPLOAD` - Data being sent to Bulk API
- ⏹️ `STOP` - Processing stopped (normal or error)

**Key Log Messages**:
```
✅ Job {jobId} with 500 records
✅ RETRY SUCCESS: Job {jobId} (retry 2)
❌ ERROR: Job creation failed
🔄 Scheduling retry 2/3 (after 5s delay)
⏳ Exponential backoff: waiting 5s before retry 2
📤 Bulk API 2.0: 500 records, 45678 bytes (attempt 1)
⏹️ Partition_0 stopping: reached end of range
```

### Success Rate Calculation

Monitor real-time success rate:

```apex
// Calculate current success rate
Integer totalProcessed = 0;
for (DataCloudPartition__c p : [SELECT TotalProcessed__c FROM DataCloudPartition__c]) {
    totalProcessed += p.TotalProcessed__c != null ? p.TotalProcessed__c.intValue() : 0;
}

Integer totalCreated = [SELECT COUNT() FROM YourObject__c WHERE CreatedDate = TODAY];
Decimal successRate = (Decimal.valueOf(totalCreated) / Decimal.valueOf(totalProcessed)) * 100;

System.debug('Current Success Rate: ' + successRate.setScale(2) + '%');

// Project final results
if (totalProcessed >= 10000) {
    Integer totalRecords = 2000000;  // Your target
    Integer projectedCreated = (Integer)(totalRecords * (successRate / 100));
    System.debug('Projected Final: ' + projectedCreated + ' records');
}
```

### Performance Metrics

Track key performance indicators:

```apex
// Throughput calculation
DataCloudPartition__c p = [SELECT TotalProcessed__c, CreatedDate, LastModifiedDate 
                            FROM DataCloudPartition__c WHERE Name = 'Partition_0'][0];

Long elapsedMs = p.LastModifiedDate.getTime() - p.CreatedDate.getTime();
Integer records = p.TotalProcessed__c.intValue();
Decimal recordsPerMinute = (Decimal.valueOf(records) / Decimal.valueOf(elapsedMs)) * 60000;
Decimal recordsPerHour = recordsPerMinute * 60;

System.debug('Throughput: ' + recordsPerMinute.setScale(0) + ' records/minute');
System.debug('Throughput: ' + recordsPerHour.setScale(0) + ' records/hour');

// Estimate completion
Integer remaining = 400000 - records;  // Partition size
Decimal remainingMinutes = remaining / recordsPerMinute;
Datetime estimatedComplete = System.now().addMinutes(remainingMinutes.intValue());
System.debug('Estimated Completion: ' + estimatedComplete.format());
```

---

## Performance Optimization

### Optimization Strategy Matrix

When facing performance or reliability issues, apply these strategies:

| Issue | Mitigation Strategy | Expected Impact |
|-------|-------------------|-----------------|
| **Low Success Rate (<90%)** | Reduce batch size to 250-350 | +5-10% success |
| | Increase delay to 30-45s | +3-5% success |
| | Increase partition stagger to 2h | +2-4% success |
| | Add additional retry attempt | +2-3% success |
| **Lock Errors (UNABLE_TO_LOCK_ROW)** | Reduce batch size by 50% | Significant reduction |
| | Double delay between batches | Moderate reduction |
| | Increase partition count by 2x | Moderate reduction |
| | Review and optimize triggers | Variable impact |
| **Slow Processing** | Increase batch size (if success rate high) | 20-40% faster |
| | Reduce partition stagger | 15-25% faster |
| | Optimize Data Cloud queries | 10-20% faster |
| | Run during off-peak hours | 10-15% faster |
| **API Limit Issues** | Increase batch size (fewer calls) | Proportional reduction |
| | Add throttling logic | Prevents hitting limits |
| | Schedule across multiple days | Spreads usage |
| **Memory/CPU Limits** | Reduce batch size | Proportional reduction |
| | Simplify CSV building logic | 5-10% reduction |
| | Remove unnecessary debug statements | 2-5% reduction |

### Configuration Tuning Guide

**Start with Recommended Configuration**:
```apex
RECORDS_PER_BATCH = 500
MAX_RETRIES = 3
RETRY_DELAYS = [2000, 5000, 10000]
PARTITION_COUNT = 5 (for 2M records)
STAGGER_HOURS = 1.5
```

**If Success Rate < 90%**:
1. Reduce `RECORDS_PER_BATCH` to 250
2. Increase `STAGGER_HOURS` to 2.0
3. Add delay mechanism (if not already present)
4. Increase `MAX_RETRIES` to 4

**If Success Rate 90-95%**:
1. Increase `RETRY_DELAYS` to [3000, 7000, 15000]
2. Add one more partition (reduce partition size)
3. Verify triggers are optimized

**If Success Rate >98% and Want Faster Processing**:
1. Increase `RECORDS_PER_BATCH` to 750
2. Reduce `STAGGER_HOURS` to 1.0
3. Reduce `PARTITION_COUNT` by 1

### Object-Specific Optimizations

**High Lock Risk Objects** (Opportunity, Contact, Case):
- Use smaller batches (250-500)
- Longer stagger times (1.5-2 hours)
- More partitions (5-10 for 2M records)
- Maximum retries (3-4)

**Low Lock Risk Objects** (Account, standalone custom objects):
- Use larger batches (750-1000)
- Shorter stagger times (30-60 minutes)
- Fewer partitions (2-3 for 2M records)
- Standard retries (2-3)

**Objects with Complex Triggers**:
- Reduce batch size to minimize lock time
- Consider temporarily disabling non-critical triggers
- Increase retry counts
- Monitor CPU time usage

---

## Troubleshooting Guide

### Common Issues and Resolutions

#### Issue: Low Success Rate

**Symptoms**:
- Success rate below 90%
- Frequent `UNABLE_TO_LOCK_ROW` errors
- Many records failing despite retries

**Diagnostic Steps**:
1. Check concurrent processes in org
2. Review trigger complexity on target object
3. Analyze which records are failing (same accounts?)
4. Check API usage and remaining limits

**Resolution Steps**:
1. **Reduce Batch Size**: Lower `RECORDS_PER_BATCH` from 500 to 250
2. **Increase Delays**: Modify `DelayedBatchStarterV2` to add longer delay
3. **Add Partitions**: Split data into more, smaller partitions
4. **Optimize Triggers**: Review and optimize any triggers on target object
5. **Schedule Better**: Run during off-peak hours

**Prevention**:
- Always test with representative data volume
- Monitor trigger execution times
- Profile lock patterns during testing

#### Issue: Partition Not Starting

**Symptoms**:
- Scheduled partition never begins
- No batch jobs appear in AsyncApexJob
- Partition status remains 'Pending'

**Diagnostic Steps**:
1. Check scheduled jobs: `SELECT * FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Partition%'`
2. Verify CRON expression is valid
3. Check system scheduled job limits
4. Review debug logs for scheduler execution

**Resolution Steps**:
1. **Verify Schedule**: Ensure NextFireTime is in the future
2. **Check Limits**: Verify you haven't hit scheduled job limits (100 max)
3. **Manual Start**: If urgent, manually start the partition:
   ```apex
   DynamicPartitionProcessorV2 batch = new DynamicPartitionProcessorV2(
       1, 'Partition_1', 'START_ID', 'END_ID'
   );
   Database.executeBatch(batch, 1);
   ```
4. **Recreate Schedule**: Abort existing job and recreate with new schedule

#### Issue: Partition Stops Prematurely

**Symptoms**:
- Partition shows 'Completed' but processed less than expected
- Missing records in target object
- No errors in logs

**Diagnostic Steps**:
1. Check stop conditions: empty batches, batch limit, range end
2. Verify Data Cloud query returns expected count
3. Review `lastProcessedId` value
4. Check for exceptions in finish() method

**Resolution Steps**:
1. **Identify Stop Reason**: Look for stop debug messages (⏹️)
2. **Adjust Limits**: Increase `MAX_BATCHES` if hit batch limit
3. **Fix Query**: Ensure Data Cloud query works correctly
4. **Resume Processing**: Start new partition from last processed ID:
   ```apex
   String lastId = [SELECT LastProcessedId__c FROM DataCloudPartition__c 
                     WHERE Name = 'Partition_0'][0].LastProcessedId__c;
   DynamicPartitionProcessorV2 resume = new DynamicPartitionProcessorV2(
       0, 'Partition_0_Resume', lastId, 'END_ID'
   );
   // Copy state from stopped partition
   resume.totalProcessed = /* previous value */;
   resume.totalBulkAPICalls = /* previous value */;
   Database.executeBatch(resume, 1);
   ```

#### Issue: API Limits Exceeded

**Symptoms**:
- Error: "API limit exceeded"
- Processing stops unexpectedly
- Cannot start new batches

**Resolution Steps**:
1. **Check Usage**: Review Setup → System Overview → API Usage
2. **Wait if Needed**: Limits reset on 24-hour rolling window
3. **Adjust Configuration**: Increase batch size to reduce calls
4. **Throttle Processing**: Add logic to pause when approaching limits
5. **Spread Over Time**: Use longer partition staggers to distribute calls

#### Issue: Duplicate Records Created

**Symptoms**:
- More records in target than source
- Same External ID appears multiple times

**Diagnostic Steps**:
1. Query for duplicates: 
   ```sql
   SELECT External_ID__c, COUNT(*) 
   FROM YourObject__c 
   GROUP BY External_ID__c 
   HAVING COUNT(*) > 1
   ```
2. Check if pagination logic uses OFFSET (should use ExternalId)
3. Verify partition boundaries don't overlap

**Resolution Steps**:
1. **Fix Pagination**: Ensure using ExternalId-based WHERE clause, not OFFSET
2. **Check Boundaries**: Verify partition ranges don't overlap
3. **Clean Duplicates**: Delete duplicates keeping most recent:
   ```apex
   // Find and delete older duplicates
   Map<String, YourObject__c> latestByExtId = new Map<String, YourObject__c>();
   for (YourObject__c obj : [SELECT Id, External_ID__c, CreatedDate 
                              FROM YourObject__c ORDER BY CreatedDate DESC]) {
       if (!latestByExtId.containsKey(obj.External_ID__c)) {
           latestByExtId.put(obj.External_ID__c, obj);
       }
   }
   // Delete records not in the latest map...
   ```

### Recovery Procedures

#### Complete Restart

When you need to start over completely:

```apex
// 1. Stop all running jobs
for (CronTrigger ct : [SELECT Id FROM CronTrigger 
                        WHERE CronJobDetail.Name LIKE 'Partition%']) {
    System.abortJob(ct.Id);
}

// 2. Delete progress records
delete [SELECT Id FROM DataCloudPartition__c];

// 3. Optionally delete created records (if test)
delete [SELECT Id FROM YourObject__c WHERE CreatedDate = TODAY];

// 4. Re-run startup script
// Execute start_production_load.apex
```

#### Resume from Failure

When a partition fails and you want to resume:

```apex
// 1. Get last state
DataCloudPartition__c partition = [
    SELECT PartitionId__c, TotalProcessed__c, TotalBulkAPICalls__c, 
           LastProcessedId__c
    FROM DataCloudPartition__c
    WHERE Name = 'Partition_2'
][0];

// 2. Create new processor
DynamicPartitionProcessorV2 resume = new DynamicPartitionProcessorV2(
    partition.PartitionId__c.intValue(),
    'Partition_2_Resume',
    partition.LastProcessedId__c,
    'ORIGINAL_END_ID'
);

// 3. Restore state
resume.totalProcessed = partition.TotalProcessed__c.intValue();
resume.totalBulkAPICalls = partition.TotalBulkAPICalls__c.intValue();

// 4. Resume processing
Database.executeBatch(resume, 1);
```

#### Process Failed Records Only

To retry only records that failed:

```apex
// 1. Identify failed External IDs
Set<String> processedIds = new Set<String>();
for (YourObject__c obj : [SELECT External_ID__c FROM YourObject__c 
                          WHERE CreatedDate = TODAY]) {
    processedIds.add(obj.External_ID__c);
}

// 2. Query source for all IDs in range
// 3. Find difference (failed IDs)
// 4. Create targeted batch to process only failed records
// (Implementation depends on your specific scenario)
```

---

## External Documentation

### Salesforce Official Documentation

**Bulk API 2.0**:
- [Bulk API 2.0 Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/)
- [Bulk API Limits](https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_platform_bulkapi.htm)
- [Bulk API Best Practices](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/asynch_api_best_practices.htm)

**Data Cloud**:
- [Data Cloud Query API](https://developer.salesforce.com/docs/atlas.en-us.c360a_api.meta/c360a_api/)
- [Data Cloud ANSI SQL Support](https://developer.salesforce.com/docs/atlas.en-us.c360a_api.meta/c360a_api/c360a_api_ansi_sql_support.htm)
- [Connect API CDP Query](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_CdpQuery_static_methods.htm)

**Batch Apex**:
- [Batch Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch.htm)
- [Apex Governor Limits](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm)
- [Stateful Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm#apex_batch_interface_state)

**Queueable Apex**:
- [Queueable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm)
- [Chaining Queueable Jobs](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_control_queueable.htm)

**Scheduled Apex**:
- [Scheduled Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm)
- [CRON Expression Syntax](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm#apex_scheduler_cron)

### Community Resources

**Trailhead Modules**:
- [Asynchronous Apex](https://trailhead.salesforce.com/content/learn/modules/asynchronous_apex)
- [Large Data Volumes](https://trailhead.salesforce.com/content/learn/modules/large-data-volumes)
- [Data Integration Specialist](https://trailhead.salesforce.com/content/learn/superbadges/superbadge_integration)

**Salesforce Stack Exchange**:
- [UNABLE_TO_LOCK_ROW Solutions](https://salesforce.stackexchange.com/questions/tagged/lock)
- [Bulk API Questions](https://salesforce.stackexchange.com/questions/tagged/bulk-api)
- [Batch Apex Patterns](https://salesforce.stackexchange.com/questions/tagged/batch-apex)

**GitHub Examples**:
- [Apex Recipes](https://github.com/trailheadapps/apex-recipes)
- [Apex Enterprise Patterns](https://github.com/apex-enterprise-patterns)

### Industry Best Practices

**Exponential Backoff**:
- [Google Cloud Best Practices](https://cloud.google.com/iot/docs/how-tos/exponential-backoff)
- [AWS Best Practices for Retries](https://docs.aws.amazon.com/general/latest/gr/api-retries.html)
- [Martin Fowler on Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)

**Distributed Systems**:
- [Designing Data-Intensive Applications](https://dataintensive.net/) (Book)
- [Building Microservices](https://samnewman.io/books/building_microservices/) (Book)

---

## Support and Maintenance

### Ongoing Monitoring

**Daily Health Checks**:
- Review API usage trends
- Monitor success rates
- Check for stuck partitions
- Review error patterns in logs
- Verify data consistency

**Weekly Reviews**:
- Analyze performance trends
- Review configuration effectiveness
- Update documentation with learnings
- Archive old debug logs
- Clean up completed partition records

**Monthly Maintenance**:
```apex
// Clean up old partition records
delete [SELECT Id FROM DataCloudPartition__c WHERE CreatedDate < LAST_N_DAYS:30];

// Archive successful batch records
// Review and optimize triggers
// Update external ID indexing if needed
```

### Performance Degradation Response

If success rates drop below target:

**Immediate Actions**:
1. Check for org-wide issues (other processes, maintenance)
2. Review recent deployments (new triggers, validation rules)
3. Verify API limits aren't exhausted
4. Check Data Cloud query performance

**Configuration Adjustments**:
1. Reduce batch size by 25-50%
2. Increase delay between batches
3. Add more partitions
4. Extend partition stagger time

**Code Reviews**:
1. Profile trigger execution times
2. Review validation rule complexity
3. Check for inefficient queries
4. Optimize CSV building logic

### Scaling Guidelines

**Scaling to 5M Records**:
- Increase partitions to 10 (500K each)
- Extend stagger to 2 hours
- Expected duration: 12-15 hours
- Same success rate expected

**Scaling to 10M Records**:
- Increase partitions to 20 (500K each)
- Consider 2-day processing window
- Monitor API usage closely
- May need dedicated processing window

**Scaling Beyond 10M**:
- Use 1M record chunks
- Process over multiple days
- Implement throttling logic
- Coordinate with Salesforce support
- Consider parallel org processing

### Code Repository Management

**GitHub Repository Structure**:
```
massive-upload/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/
│           │   ├── DynamicPartitionProcessorV2.cls
│           │   ├── DelayedBatchStarterV2.cls
│           │   ├── PartitionScheduler.cls
│           │   └── ...
│           └── objects/
│               └── DataCloudPartition__c/
├── scripts/
│   ├── start_production_load.apex
│   ├── check_progress.apex
│   └── monitor.sh
├── docs/
│   ├── README.md
│   ├── IMPLEMENTATION_GUIDE.md
│   └── TROUBLESHOOTING.md
├── sfdx-project.json
└── README.md
```

**Version Control Best Practices**:
- Tag stable releases (v1.0, v1.1, etc.)
- Maintain CHANGELOG.md
- Document configuration changes
- Include sample data for testing
- Provide deployment instructions

**Contribution Guidelines**:
- Submit pull requests for improvements
- Include test results with changes
- Update documentation
- Follow Apex coding standards
- Add inline comments for complex logic

### Support Escalation

**Level 1 - Self-Service**:
- Review this documentation
- Check troubleshooting guide
- Search Salesforce Stack Exchange
- Review debug logs

**Level 2 - Internal Team**:
- Consult with Salesforce admin team
- Review with architects
- Engage development team
- Analyze error patterns

**Level 3 - Salesforce Support**:
- Open support case if platform issue suspected
- Provide detailed error logs
- Share configuration details
- Include performance metrics

**When to Engage Salesforce Support**:
- Suspected platform bugs
- Consistent API timeouts
- Unusual lock behavior
- Data Cloud query issues
- Performance degradation across org

---

## Conclusion

### Summary

This document has presented a comprehensive solution for loading millions of records from Salesforce Data Cloud to Core with high reliability. The architecture leverages:

- **Partitioned Processing**: Dividing data into manageable segments
- **Staggered Execution**: Reducing concurrent processing conflicts
- **Intelligent Retry Logic**: Exponential backoff for transient failures
- **Small Batch Sizes**: Minimizing lock duration and contention
- **ExternalId Pagination**: Ensuring data consistency at scale
- **Real-Time Monitoring**: Tracking progress and identifying issues

### Key Success Factors

The solution achieves high success rates through:

1. **Architectural Patterns**: Proven distributed systems patterns applied to Salesforce
2. **Comprehensive Error Handling**: Graceful degradation and recovery
3. **Observability**: Rich logging and monitoring capabilities
4. **Flexibility**: Configurable parameters for different scenarios
5. **Production-Ready Code**: Battle-tested, well-documented components

### Applicability

While developed for Opportunity loading, this solution applies broadly to:

- Any Salesforce object with External ID
- Parent-child relationship scenarios
- High-volume data migration projects
- Periodic data synchronization processes
- Data Cloud materialization use cases

### Production Readiness

The solution provides:

- ✅ **Proven Architecture**: Built on industry best practices
- ✅ **Comprehensive Documentation**: Complete implementation guidance
- ✅ **Reusable Components**: Object-agnostic design
- ✅ **Monitoring Tools**: Real-time observability
- ✅ **Recovery Procedures**: Graceful failure handling
- ✅ **Scalability**: Tested from 100K to multi-million records

### Continuous Improvement

We encourage users to:

- Share learnings and improvements via GitHub
- Contribute optimizations and enhancements
- Report issues and edge cases
- Provide feedback on documentation
- Extend for new use cases

### Final Recommendations

For successful implementation:

1. **Start Small**: Test with sample data first
2. **Monitor Actively**: Watch the first production run closely
3. **Document Changes**: Record configuration decisions
4. **Iterate**: Adjust parameters based on results
5. **Share Knowledge**: Contribute back to the community

### Next Steps

1. Review this documentation thoroughly
2. Clone the GitHub repository
3. Deploy to a sandbox environment
4. Test with representative data
5. Customize for your specific objects
6. Execute production deployment
7. Monitor and optimize as needed

---

**Thank you for using this solution!**

We're committed to helping organizations successfully load massive datasets into Salesforce with high reliability and performance.

**GitHub Repository**: [https://github.com/your-org/massive-upload](https://github.com/your-org/massive-upload)

**Questions or Issues**: Please open a GitHub issue or contribute improvements via pull request.

**Status**: ✅ Production-Ready  
**Version**: 1.0  
**License**: MIT  
**Maintained By**: Your Organization's Development Team

---

*This solution represents best practices as of January 2026. Always refer to current Salesforce documentation for the latest platform capabilities and limits.*

