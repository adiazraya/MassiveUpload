/**
 * Scheduler for DataCloudBatchProcessor
 * Used to introduce delays between batch executions to prevent record locking
 */
public class DataCloudBatchScheduler implements Schedulable {
    private Integer currentOffset;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer maxRecords;
    
    public DataCloudBatchScheduler(Integer offset, Integer processed, Integer bulkCalls, Integer maxRecs) {
        this.currentOffset = offset;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = bulkCalls;
        this.maxRecords = maxRecs;
    }
    
    public void execute(SchedulableContext context) {
        // Start the next batch
        DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
            currentOffset,
            totalProcessed,
            totalBulkAPICalls,
            maxRecords
        );
        
        Database.executeBatch(batch, 1);
    }
}




