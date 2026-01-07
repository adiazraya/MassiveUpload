/**
 * Queueable class to implement 2-minute delay before starting next batch
 * This prevents concurrent Bulk API jobs from causing record locking
 */
public class DelayedBatchStarter implements Queueable {
    private Integer currentOffset;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer maxRecords;
    private static final Integer DELAY_MILLISECONDS = 120000; // 2 minutes
    
    public DelayedBatchStarter(Integer offset, Integer processed, Integer bulkCalls, Integer maxRecs) {
        this.currentOffset = offset;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = bulkCalls;
        this.maxRecords = maxRecs;
    }
    
    public void execute(QueueableContext context) {
        // Implement 2-minute delay
        Long startTime = System.now().getTime();
        Long currentTime = System.now().getTime();
        
        // Wait loop (note: this consumes CPU time, but Queueable has 60s limit)
        // Alternative: Use Scheduled Job for exact 2-minute delay
        Datetime delayUntil = System.now().addMinutes(2);
        
        // Schedule the next batch to run in 2 minutes
        String cronExp = delayUntil.format('ss mm HH dd MM ? yyyy');
        String jobName = 'DelayedBatch_' + currentOffset + '_' + System.now().getTime();
        
        System.schedule(jobName, cronExp, new DelayedBatchScheduler(
            currentOffset,
            totalProcessed,
            totalBulkAPICalls,
            maxRecords
        ));
    }
}




