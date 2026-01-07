/**
 * Scheduler to start batch after 2-minute delay
 * Used by DelayedBatchStarter
 */
public class DelayedBatchScheduler implements Schedulable {
    private Integer currentOffset;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer maxRecords;
    
    public DelayedBatchScheduler(Integer offset, Integer processed, Integer bulkCalls, Integer maxRecs) {
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
        
        // Self-destruct: abort this scheduled job after execution
        try {
            System.abortJob(context.getTriggerId());
        } catch (Exception e) {
            // Job might already be complete
        }
    }
}




