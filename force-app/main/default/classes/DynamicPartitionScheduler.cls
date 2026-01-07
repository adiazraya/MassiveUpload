/**
 * Scheduler for Dynamic Partitioning
 * Runs the daily sync using dynamic ExternalId-based partitions
 */
public class DynamicPartitionScheduler implements Schedulable {
    
    public void execute(SchedulableContext context) {
        System.debug('=== Dynamic Partition Scheduler Starting ===');
        
        try {
            // Get min/max ExternalId from Data Cloud
            ConnectApi.CdpQueryInput minMaxInput = new ConnectApi.CdpQueryInput();
            minMaxInput.sql = 'SELECT MIN("ExternalId__c") as min_id, MAX("ExternalId__c") as max_id FROM "ExtOpportunities__dlm"';
            ConnectApi.CdpQueryOutputV2 minMaxOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(minMaxInput);
            
            String minId = '';
            String maxId = '';
            
            if (minMaxOutput != null && !minMaxOutput.data.isEmpty()) {
                String rowJson = JSON.serialize(minMaxOutput.data[0]);
                List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
                minId = (String) values[0];
                maxId = (String) values[1];
            }
            
            System.debug('Range: ' + minId + ' to ' + maxId);
            
            // Get range points by sampling at intervals
            List<String> rangePoints = new List<String>();
            rangePoints.add(minId);
            
            Integer intervalSize = 200000; // ~2M / 10
            for (Integer i = 1; i < 10; i++) {
                Integer offset = i * intervalSize;
                ConnectApi.CdpQueryInput pointInput = new ConnectApi.CdpQueryInput();
                pointInput.sql = 'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                                 'ORDER BY "ExternalId__c" LIMIT 1 OFFSET ' + offset;
                
                try {
                    ConnectApi.CdpQueryOutputV2 pointOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(pointInput);
                    if (pointOutput != null && !pointOutput.data.isEmpty()) {
                        String pointJson = JSON.serialize(pointOutput.data[0]);
                        List<Object> pointValues = (List<Object>) JSON.deserializeUntyped(pointJson);
                        rangePoints.add((String) pointValues[0]);
                    }
                } catch (Exception e) {
                    System.debug('Error sampling point ' + i + ': ' + e.getMessage());
                }
            }
            
            rangePoints.add(maxId + 'Z');
            
            // Clean up old progress
            delete [SELECT Id FROM DataCloudPartition__c];
            
            // Create progress records
            List<DataCloudPartition__c> progressRecords = new List<DataCloudPartition__c>();
            for (Integer i = 0; i < 10; i++) {
                progressRecords.add(new DataCloudPartition__c(
                    Name = 'DynamicPartition' + i,
                    PartitionId__c = i,
                    CurrentOffset__c = 0,
                    TotalProcessed__c = 0,
                    TotalBulkAPICalls__c = 0,
                    Status__c = 'Initialized'
                ));
            }
            insert progressRecords;
            
            // Start batches
            for (Integer i = 0; i < 10; i++) {
                String partitionName = 'DynamicPartition' + i;
                String rangeStart = rangePoints[i];
                String rangeEnd = rangePoints[i + 1];
                
                DynamicPartitionProcessor batch = new DynamicPartitionProcessor(
                    i, partitionName, rangeStart, rangeEnd
                );
                
                Database.executeBatch(batch, 1);
                System.debug('Started ' + partitionName + ': ' + rangeStart + ' to ' + rangeEnd);
            }
            
            System.debug('=== All 10 partitions started ===');
            
        } catch (Exception e) {
            System.debug('ERROR in scheduler: ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
}




