/**
 * Scheduler to continue Queueable chain with 2-minute delay
 */
public class DataCloudQueueableScheduler implements Schedulable {
    private Integer currentOffset;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer maxRecords;
    
    public DataCloudQueueableScheduler(Integer offset, Integer processed, Integer bulkCalls, Integer maxRecs) {
        this.currentOffset = offset;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = bulkCalls;
        this.maxRecords = maxRecs;
    }
    
    public void execute(SchedulableContext context) {
        // Enqueue next Queueable
        System.enqueueJob(new DataCloudQueueableProcessor(
            currentOffset,
            totalProcessed,
            totalBulkAPICalls,
            maxRecords
        ));
        
        // Self-destruct
        try {
            System.abortJob(context.getTriggerId());
        } catch (Exception e) { }
    }
}




