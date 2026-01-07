/**
 * PRODUCTION ORCHESTRATOR - PARALLEL VERSION
 * Manages 10 parallel batch processes for 24-hour completion
 * Called by Scheduled Flow every 5 minutes
 */
public class ParallelBatchOrchestrator {
    
    private static final Integer TOTAL_PARTITIONS = 10;
    private static final Integer RECORDS_PER_PARTITION = 200000; // 2M / 10 = 200k each
    
    @InvocableMethod(label='Check and Start Parallel Batches' description='Manages 10 parallel batch processes')
    public static List<Result> checkAndStartParallelBatches() {
        Result result = new Result();
        result.message = '';
        result.partitionsStarted = 0;
        result.partitionsRunning = 0;
        result.partitionsComplete = 0;
        
        try {
            // Check each partition
            for (Integer partitionId = 0; partitionId < TOTAL_PARTITIONS; partitionId++) {
                String partitionName = 'Partition' + partitionId;
                
                // Get or create progress for this partition
                DataCloudPartition__c progress = getProgress(partitionName, partitionId);
                
                // Skip if already complete
                if (progress.Status__c == 'Completed') {
                    result.partitionsComplete++;
                    continue;
                }
                
                // Check if this partition's batch is running
                List<AsyncApexJob> runningBatches = [
                    SELECT Id
                    FROM AsyncApexJob 
                    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
                    AND Status IN ('Processing', 'Queued', 'Preparing')
                    AND JobItemsProcessed < 100 // Simple way to identify which batch
                    LIMIT 100
                ];
                
                // Count how many batches are running across all partitions
                if (runningBatches.size() >= TOTAL_PARTITIONS) {
                    // All slots full, wait for next cycle
                    result.partitionsRunning = runningBatches.size();
                    result.message = 'All ' + TOTAL_PARTITIONS + ' slots full, waiting...';
                    continue;
                }
                
                // Check if this specific partition has a running batch
                // We use a custom field to track partition ID in the batch
                Boolean partitionRunning = false;
                List<AsyncApexJob> recentBatches = [
                    SELECT CreatedDate
                    FROM AsyncApexJob 
                    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
                    AND Status IN ('Processing', 'Queued', 'Preparing')
                    AND CreatedDate > :System.now().addMinutes(-10)
                    LIMIT 1
                ];
                
                if (!recentBatches.isEmpty() && progress.Status__c == 'Running') {
                    result.partitionsRunning++;
                    continue;
                }
                
                // Calculate this partition's offset range
                Integer startOffset = partitionId * RECORDS_PER_PARTITION;
                Integer currentOffset = startOffset + Integer.valueOf(progress.CurrentOffset__c);
                Integer maxOffset = startOffset + RECORDS_PER_PARTITION;
                
                // Check if more records exist in this partition's range
                if (currentOffset >= maxOffset) {
                    progress.Status__c = 'Completed';
                    update progress;
                    result.partitionsComplete++;
                    continue;
                }
                
                // Query Data Cloud to verify records exist
                String sqlQuery = 
                    'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                    'ORDER BY "ExternalId__c" ' +
                    'LIMIT 1 OFFSET ' + currentOffset;
                
                ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
                queryInput.sql = sqlQuery;
                
                ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
                
                if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                    progress.Status__c = 'Completed';
                    update progress;
                    result.partitionsComplete++;
                    continue;
                }
                
                // Start batch for this partition
                DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
                    currentOffset,
                    Integer.valueOf(progress.TotalProcessed__c),
                    Integer.valueOf(progress.TotalBulkAPICalls__c),
                    0
                );
                
                // Store partition info in batch (we'll use a custom approach)
                batch.setPartitionInfo(partitionId, partitionName);
                
                Id batchId = Database.executeBatch(batch, 1);
                
                progress.Status__c = 'Running';
                progress.LastBatchStarted__c = System.now();
                update progress;
                
                result.partitionsStarted++;
                result.message += 'Started ' + partitionName + ' at offset ' + currentOffset + '; ';
            }
            
            // Summary message
            if (result.partitionsComplete == TOTAL_PARTITIONS) {
                result.message = 'ALL COMPLETE! All ' + TOTAL_PARTITIONS + ' partitions finished!';
            } else if (result.partitionsStarted == 0 && result.partitionsRunning > 0) {
                result.message = 'Running: ' + result.partitionsRunning + ', Complete: ' + result.partitionsComplete;
            }
            
        } catch (Exception e) {
            result.message = 'ERROR: ' + e.getMessage();
            System.debug('ParallelBatchOrchestrator error: ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
        
        return new List<Result>{ result };
    }
    
    private static DataCloudPartition__c getProgress(String partitionName, Integer partitionId) {
        List<DataCloudPartition__c> existing = [
            SELECT CurrentOffset__c, TotalProcessed__c, TotalBulkAPICalls__c, 
                   Status__c, LastBatchStarted__c, PartitionId__c
            FROM DataCloudPartition__c
            WHERE Name = :partitionName
            LIMIT 1
        ];
        
        if (!existing.isEmpty()) {
            return existing[0];
        }
        
        // Create initial record for this partition
        DataCloudPartition__c progress = new DataCloudPartition__c(
            Name = partitionName,
            PartitionId__c = partitionId,
            CurrentOffset__c = 0, // Relative to partition start
            TotalProcessed__c = 0,
            TotalBulkAPICalls__c = 0,
            Status__c = 'Initialized'
        );
        insert progress;
        return progress;
    }
    
    public class Result {
        @InvocableVariable(label='Message' description='Status message')
        public String message;
        
        @InvocableVariable(label='Partitions Started' description='Number of partitions started this cycle')
        public Integer partitionsStarted;
        
        @InvocableVariable(label='Partitions Running' description='Number of partitions currently running')
        public Integer partitionsRunning;
        
        @InvocableVariable(label='Partitions Complete' description='Number of partitions completed')
        public Integer partitionsComplete;
    }
}

