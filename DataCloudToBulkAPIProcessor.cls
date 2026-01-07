/**
 * Queries 2M records from Data Cloud ExtOpportunities__dlm using CDP Query API
 * Processes in batches of 40K and sends to Bulk API in chunks of 10K
 * 
 * Usage in Execute Anonymous:
 *   DataCloudToBulkAPIProcessor processor = new DataCloudToBulkAPIProcessor();
 *   processor.processAllRecords();
 */
public class DataCloudToBulkAPIProcessor {
    
    private static final Integer BULK_API_CHUNK_SIZE = 10000;
    private Integer totalRecordsProcessed = 0;
    private Integer totalBulkAPICallsMade = 0;
    
    /**
     * Main method - Call this to start processing all 2M records
     * Queries Data Cloud in batches, processes, and sends to Bulk API
     */
    public void processAllRecords() {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DATA CLOUD TO BULK API PROCESSOR - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Start Time: ' + System.now());
        
        try {
            // Build initial query
            String sqlQuery = 
                'SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c ' +
                'FROM ExtOpportunities__dlm ' +
                'ORDER BY externalid__c';
            
            System.debug('SQL Query: ' + sqlQuery);
            
            // Create query input
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            // Execute first query
            System.debug('→ Executing initial CDP query...');
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            // Process first batch
            processBatch(queryOutput);
            
            // Continue with pagination if there are more records
            while (String.isNotBlank(queryOutput.nextBatchId)) {
                System.debug('────────────────────────────────────────────────────────');
                System.debug('→ Fetching next batch using nextBatchId: ' + queryOutput.nextBatchId);
                
                // Get next batch
                queryOutput = ConnectApi.CdpQuery.nextBatchAnsiSqlV2(queryOutput.nextBatchId);
                
                // Process this batch
                processBatch(queryOutput);
            }
            
            System.debug('════════════════════════════════════════════════════════');
            System.debug('DATA CLOUD TO BULK API PROCESSOR - COMPLETE');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Total Records Processed: ' + totalRecordsProcessed);
            System.debug('Total Bulk API Calls Made: ' + totalBulkAPICallsMade);
            System.debug('End Time: ' + System.now());
            System.debug('════════════════════════════════════════════════════════');
            
        } catch (Exception e) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('ERROR IN PROCESSOR');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            System.debug('════════════════════════════════════════════════════════');
            
            throw e;
        }
    }
    
    /**
     * Process a single batch from Data Cloud
     * Converts to OpportunityData and sends to Bulk API in 10K chunks
     */
    private void processBatch(ConnectApi.CdpQueryOutputV2 queryOutput) {
        if (queryOutput == null || queryOutput.data == null) {
            System.debug('⚠ No data in batch');
            return;
        }
        
        System.debug('────────────────────────────────────────────────────────');
        System.debug('Processing CDP Query Batch');
        System.debug('Rows in batch: ' + queryOutput.rowCount);
        System.debug('────────────────────────────────────────────────────────');
        
        // Data is in rows
        List<ConnectApi.CdpQueryV2Row> rows = queryOutput.data;
        System.debug('✓ Retrieved ' + rows.size() + ' rows');
        
        // Convert to OpportunityData objects
        List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        Integer successCount = 0;
        Integer errorCount = 0;
        
        for (ConnectApi.CdpQueryV2Row row : rows) {
            try {
                // Serialize and deserialize to get the data as a Map
                String rowJson = JSON.serialize(row);
                Map<String, Object> rowMap = (Map<String, Object>) JSON.deserializeUntyped(rowJson);
                
                String externalId = (String) rowMap.get('externalid__c');
                String stageName = (String) rowMap.get('stagename__c');
                Object amountObj = rowMap.get('amount__c');
                Decimal amount = amountObj != null ? Decimal.valueOf(String.valueOf(amountObj)) : 0;
                String accountId = (String) rowMap.get('account__c');
                String name = (String) rowMap.get('name__c');
                Object closeDateObj = rowMap.get('closedate__c');
                
                // Parse close date
                Date closeDate = parseCloseDate(closeDateObj);
                
                // Create OpportunityData
                OpportunityBulkAPIUploader.OpportunityData oppData = 
                    new OpportunityBulkAPIUploader.OpportunityData(
                        externalId, stageName, amount, accountId, name, closeDate
                    );
                
                oppDataList.add(oppData);
                successCount++;
                
            } catch (Exception e) {
                errorCount++;
                System.debug('  ✗ Error converting row: ' + e.getMessage());
            }
        }
        
        totalRecordsProcessed += successCount;
        
        System.debug('✓ Converted ' + successCount + ' records');
        if (errorCount > 0) {
            System.debug('⚠ Failed to convert ' + errorCount + ' records');
        }
        System.debug('  Running total: ' + totalRecordsProcessed + ' records');
        
        // Split into 10K chunks and send to Bulk API
        if (!oppDataList.isEmpty()) {
            sendToBulkAPI(oppDataList);
        }
    }
    
    /**
     * Split records into 10K chunks and create Bulk API jobs
     */
    private void sendToBulkAPI(List<OpportunityBulkAPIUploader.OpportunityData> oppDataList) {
        System.debug('→ Sending to Bulk API...');
        
        // Split into chunks of 10K
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = 
            splitIntoChunks(oppDataList, BULK_API_CHUNK_SIZE);
        
        System.debug('  Split into ' + chunks.size() + ' chunks of up to 10K records');
        
        Integer chunkNum = 0;
        for (List<OpportunityBulkAPIUploader.OpportunityData> chunk : chunks) {
            chunkNum++;
            
            try {
                System.debug('  → Chunk ' + chunkNum + ': ' + chunk.size() + ' records');
                
                // Create Bulk API batch job
                OpportunityBulkAPIBatch bulkBatch = new OpportunityBulkAPIBatch(chunk);
                Id batchJobId = Database.executeBatch(bulkBatch, 50000);
                
                totalBulkAPICallsMade++;
                
                System.debug('  ✓ Bulk API job created: ' + batchJobId);
                
            } catch (Exception e) {
                System.debug('  ✗ Error creating Bulk API job for chunk ' + chunkNum + ': ' + e.getMessage());
            }
        }
        
        System.debug('✓ Total Bulk API calls so far: ' + totalBulkAPICallsMade);
    }
    
    /**
     * Parse close date from various formats
     */
    private Date parseCloseDate(Object closeDateObj) {
        if (closeDateObj == null) {
            return Date.today().addDays(30);
        }
        
        try {
            String dateStr = String.valueOf(closeDateObj);
            
            // Handle ISO date format (YYYY-MM-DD)
            if (dateStr.contains('-')) {
                List<String> parts = dateStr.split('-');
                if (parts.size() >= 3) {
                    Integer year = Integer.valueOf(parts[0]);
                    Integer month = Integer.valueOf(parts[1]);
                    // Handle potential time component
                    String dayPart = parts[2];
                    if (dayPart.contains(' ') || dayPart.contains('T')) {
                        dayPart = dayPart.split('[\\s T]')[0];
                    }
                    Integer day = Integer.valueOf(dayPart);
                    return Date.newInstance(year, month, day);
                }
            }
            
            // Default if parsing fails
            return Date.today().addDays(30);
            
        } catch (Exception e) {
            System.debug('    ⚠ Could not parse date: ' + closeDateObj + ' - using default');
            return Date.today().addDays(30);
        }
    }
    
    /**
     * Split list into chunks of specified size
     */
    private List<List<OpportunityBulkAPIUploader.OpportunityData>> splitIntoChunks(
        List<OpportunityBulkAPIUploader.OpportunityData> records, 
        Integer chunkSize
    ) {
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = 
            new List<List<OpportunityBulkAPIUploader.OpportunityData>>();
        
        List<OpportunityBulkAPIUploader.OpportunityData> currentChunk = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        for (OpportunityBulkAPIUploader.OpportunityData record : records) {
            currentChunk.add(record);
            if (currentChunk.size() >= chunkSize) {
                chunks.add(currentChunk);
                currentChunk = new List<OpportunityBulkAPIUploader.OpportunityData>();
            }
        }
        
        // Add remaining records
        if (!currentChunk.isEmpty()) {
            chunks.add(currentChunk);
        }
        
        return chunks;
    }
}

