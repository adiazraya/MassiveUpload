/**
 * Scheduler to start a partition at a specific time
 * Used for staggered startup (1 hour between each partition)
 */
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
        System.debug('🚀 Starting scheduled partition: ' + partitionName);
        
        DynamicPartitionProcessorV2 batch = new DynamicPartitionProcessorV2(
            partitionId, partitionName, rangeStart, rangeEnd
        );
        Database.executeBatch(batch, 1);
        
        System.debug('✅ Partition ' + partitionName + ' started');
    }
}




