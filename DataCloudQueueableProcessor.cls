/**
 * Queueable processor for Data Cloud to Bulk API
 * Processes records in chunks and chains itself to avoid CPU limits
 * 
 * Usage:
 *   DataCloudQueueableProcessor processor = new DataCloudQueueableProcessor();
 *   System.enqueueJob(processor);
 */
public class DataCloudQueueableProcessor implements Queueable, Database.AllowsCallouts {
    
    private static final Integer RECORDS_PER_QUERY = 1000; // Small batch to stay under heap limit
    private static final Integer BULK_API_CHUNK_SIZE = 1000; // Match query size
    
    private String nextBatchId;
    private Integer totalProcessed;
    private Integer totalBulkAPICalls;
    private Integer currentOffset; // Track offset for manual pagination
    
    // Constructor for initial call
    public DataCloudQueueableProcessor() {
        this.nextBatchId = null;
        this.totalProcessed = 0;
        this.totalBulkAPICalls = 0;
        this.currentOffset = 0;
    }
    
    // Constructor for chained calls
    public DataCloudQueueableProcessor(Integer offset, Integer processed, Integer bulkCalls) {
        this.nextBatchId = null;
        this.totalProcessed = processed;
        this.totalBulkAPICalls = bulkCalls;
        this.currentOffset = offset;
    }
    
    public void execute(QueueableContext context) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DATA CLOUD QUEUEABLE PROCESSOR - EXECUTE');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Job ID: ' + context.getJobId());
        System.debug('Current Offset: ' + currentOffset);
        System.debug('Total Processed So Far: ' + totalProcessed);
        System.debug('Total Bulk API Calls So Far: ' + totalBulkAPICalls);
        System.debug('Timestamp: ' + System.now());
        
        try {
            // Query with LIMIT and OFFSET for manual pagination
            System.debug('→ Executing CDP query with LIMIT ' + RECORDS_PER_QUERY + ' OFFSET ' + currentOffset);
            
            String sqlQuery = 
                'SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c ' +
                'FROM ExtOpportunities__dlm ' +
                'ORDER BY externalid__c ' +
                'LIMIT ' + RECORDS_PER_QUERY + ' ' +
                'OFFSET ' + currentOffset;
            
            System.debug('SQL: ' + sqlQuery);
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                System.debug('✓ No more data - Processing complete!');
                System.debug('════════════════════════════════════════════════════════');
                System.debug('FINAL STATS');
                System.debug('Total Records Processed: ' + totalProcessed);
                System.debug('Total Bulk API Calls: ' + totalBulkAPICalls);
                System.debug('════════════════════════════════════════════════════════');
                return;
            }
            
            System.debug('✓ Retrieved ' + queryOutput.data.size() + ' rows');
            
            // Process this batch
            Integer processed = processBatch(queryOutput);
            totalProcessed += processed;
            totalBulkAPICalls++;
            
            System.debug('✓ Processed ' + processed + ' records in this batch');
            System.debug('Running Total - Records: ' + totalProcessed + ', Bulk API Calls: ' + totalBulkAPICalls);
            
            // Chain to next batch if we got a full batch (meaning there might be more)
            if (queryOutput.data.size() >= RECORDS_PER_QUERY) {
                System.debug('→ Chaining to next batch...');
                
                DataCloudQueueableProcessor nextJob = new DataCloudQueueableProcessor(
                    currentOffset + RECORDS_PER_QUERY,
                    totalProcessed,
                    totalBulkAPICalls
                );
                System.enqueueJob(nextJob);
                
                System.debug('✓ Next job queued with offset ' + (currentOffset + RECORDS_PER_QUERY));
            } else {
                System.debug('════════════════════════════════════════════════════════');
                System.debug('ALL PROCESSING COMPLETE!');
                System.debug('════════════════════════════════════════════════════════');
                System.debug('Total Records: ' + totalProcessed);
                System.debug('Total Bulk API Calls: ' + totalBulkAPICalls);
                System.debug('════════════════════════════════════════════════════════');
            }
            
        } catch (Exception e) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('ERROR');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line: ' + e.getLineNumber());
            System.debug('════════════════════════════════════════════════════════');
            
            throw e;
        }
    }
    
    private Integer processBatch(ConnectApi.CdpQueryOutputV2 queryOutput) {
        List<ConnectApi.CdpQueryV2Row> rows = queryOutput.data;
        List<OpportunityBulkAPIUploader.OpportunityData> chunk = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        Integer successCount = 0;
        Integer errorCount = 0;
        
        System.debug('Processing ' + rows.size() + ' rows...');
        
        for (ConnectApi.CdpQueryV2Row row : rows) {
            try {
                // Serialize and deserialize as a List
                String rowJson = JSON.serialize(row);
                List<Object> values = (List<Object>) JSON.deserializeUntyped(rowJson);
                
                if (values == null || values.size() < 6) {
                    errorCount++;
                    continue;
                }
                
                String externalId = (String) values[0];
                String stageName = (String) values[1];
                Object amountObj = values[2];
                String accountId = (String) values[3];
                String name = (String) values[4];
                Object closeDateObj = values[5];
                
                Decimal amount = amountObj != null ? Decimal.valueOf(String.valueOf(amountObj)) : 0;
                Date closeDate = parseCloseDate(closeDateObj);
                
                chunk.add(new OpportunityBulkAPIUploader.OpportunityData(
                    externalId, stageName, amount, accountId, name, closeDate
                ));
                successCount++;
                
            } catch (Exception e) {
                errorCount++;
                if (errorCount <= 3) {
                    System.debug('  ✗ Error: ' + e.getMessage());
                }
            }
        }
        
        // Send to Bulk API
        if (!chunk.isEmpty()) {
            sendChunkToBulkAPI(chunk);
        }
        
        System.debug('✓ Converted: ' + successCount + ', Errors: ' + errorCount);
        return successCount;
    }
    
    private void sendChunkToBulkAPI(List<OpportunityBulkAPIUploader.OpportunityData> chunk) {
        try {
            OpportunityBulkAPIBatch bulkBatch = new OpportunityBulkAPIBatch(chunk);
            Id batchJobId = Database.executeBatch(bulkBatch, 50000);
            System.debug('  → Bulk API job: ' + batchJobId + ' (' + chunk.size() + ' records)');
        } catch (Exception e) {
            System.debug('  ✗ Error creating Bulk API job: ' + e.getMessage());
        }
    }
    
    private Date parseCloseDate(Object closeDateObj) {
        if (closeDateObj == null) {
            return Date.today().addDays(30);
        }
        
        try {
            String dateStr = String.valueOf(closeDateObj);
            if (dateStr.contains('-')) {
                List<String> parts = dateStr.split('-');
                if (parts.size() >= 3) {
                    Integer year = Integer.valueOf(parts[0]);
                    Integer month = Integer.valueOf(parts[1]);
                    String dayPart = parts[2];
                    if (dayPart.contains(' ') || dayPart.contains('T')) {
                        dayPart = dayPart.split('[\\s T]')[0];
                    }
                    Integer day = Integer.valueOf(dayPart);
                    return Date.newInstance(year, month, day);
                }
            }
            return Date.today().addDays(30);
        } catch (Exception e) {
            return Date.today().addDays(30);
        }
    }
}

