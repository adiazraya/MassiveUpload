/**
 * Loads opportunities from Data Cloud (CDP) using ConnectAPI
 * Processes in chunks and sends to Bulk API
 * 
 * Data Cloud Object: ExtOpportunities__dlm
 * 
 * Usage:
 *   DataCloudOpportunityLoader loader = new DataCloudOpportunityLoader();
 *   loader.processAllRecords();
 */
public class DataCloudOpportunityLoader {
    
    private static final Integer QUERY_LIMIT = 50000; // Data Cloud query limit
    private static final Integer BULK_API_BATCH_SIZE = 10000;
    
    /**
     * Main method to process all records from Data Cloud
     * Call this from Execute Anonymous or Scheduled Apex
     */
    public void processAllRecords() {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DATA CLOUD OPPORTUNITY LOADER - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Timestamp: ' + System.now());
        
        Integer totalProcessed = 0;
        Integer offset = 0;
        Boolean hasMoreRecords = true;
        Integer batchNumber = 0;
        
        while (hasMoreRecords) {
            batchNumber++;
            System.debug('────────────────────────────────────────────────────────');
            System.debug('Processing Data Cloud Query Batch #' + batchNumber);
            System.debug('Offset: ' + offset);
            
            try {
                // Query Data Cloud
                List<OpportunityBulkAPIUploader.OpportunityData> oppData = 
                    queryDataCloud(offset, QUERY_LIMIT);
                
                if (oppData.isEmpty()) {
                    System.debug('✓ No more records to process');
                    hasMoreRecords = false;
                    break;
                }
                
                System.debug('✓ Retrieved ' + oppData.size() + ' records from Data Cloud');
                totalProcessed += oppData.size();
                
                // Split into chunks and send to Bulk API
                sendToBulkAPI(oppData);
                
                // Check if we got fewer records than the limit (means we're done)
                if (oppData.size() < QUERY_LIMIT) {
                    System.debug('✓ Received fewer than limit - this is the last batch');
                    hasMoreRecords = false;
                } else {
                    offset += oppData.size();
                }
                
            } catch (Exception e) {
                System.debug('════════════════════════════════════════════════════════');
                System.debug('ERROR in batch #' + batchNumber);
                System.debug('════════════════════════════════════════════════════════');
                System.debug('Error Type: ' + e.getTypeName());
                System.debug('Error Message: ' + e.getMessage());
                System.debug('Stack Trace: ' + e.getStackTraceString());
                System.debug('════════════════════════════════════════════════════════');
                
                // Decide whether to continue or stop
                // For now, we'll stop on error
                hasMoreRecords = false;
            }
        }
        
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DATA CLOUD OPPORTUNITY LOADER - COMPLETE');
        System.debug('Total records processed: ' + totalProcessed);
        System.debug('Total batches: ' + batchNumber);
        System.debug('════════════════════════════════════════════════════════');
    }
    
    /**
     * Query Data Cloud using ConnectAPI
     */
    private List<OpportunityBulkAPIUploader.OpportunityData> queryDataCloud(Integer offset, Integer limitRows) {
        System.debug('→ Querying Data Cloud...');
        System.debug('  Offset: ' + offset + ', Limit: ' + limitRows);
        
        List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        // Build ANSI SQL query for Data Cloud
        String sqlQuery = 
            'SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c ' +
            'FROM ExtOpportunities__dlm ' +
            'ORDER BY externalid__c ' +
            'LIMIT ' + limitRows + ' ' +
            'OFFSET ' + offset;
        
        System.debug('  SQL Query: ' + sqlQuery);
        
        try {
            // Execute Data Cloud query using ConnectAPI
            // According to documentation: queryAnsiSql(String sql)
            String queryOutput = ConnectApi.CdpQuery.queryAnsiSql(sqlQuery);
            
            System.debug('  Query Status: ' + (queryOutput != null ? 'Success' : 'Failed'));
            
            if (String.isNotBlank(queryOutput)) {
                // Parse the results
                oppDataList = parseQueryResults(queryOutput);
                System.debug('  ✓ Parsed ' + oppDataList.size() + ' records');
            } else {
                System.debug('  ✗ No data returned from query');
            }
            
        } catch (Exception e) {
            System.debug('  ✗ Error querying Data Cloud: ' + e.getMessage());
            throw e;
        }
        
        return oppDataList;
    }
    
    /**
     * Parse Data Cloud query results into OpportunityData objects
     */
    private List<OpportunityBulkAPIUploader.OpportunityData> parseQueryResults(String queryOutput) {
        List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        if (String.isBlank(queryOutput)) {
            return oppDataList;
        }
        
        // Parse JSON data from Data Cloud
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(queryOutput);
        List<Object> rows = (List<Object>) responseMap.get('data');
        
        for (Object rowObj : rows) {
            try {
                Map<String, Object> row = (Map<String, Object>) rowObj;
                
                // Extract fields from Data Cloud response
                String externalId = (String) row.get('externalid__c');
                String stageName = (String) row.get('stagename__c');
                Object amountObj = row.get('amount__c');
                Decimal amount = amountObj != null ? Decimal.valueOf(String.valueOf(amountObj)) : 0;
                String accountId = (String) row.get('account__c');
                String name = (String) row.get('name__c');
                Object closeDateObj = row.get('closedate__c');
                
                // Parse close date
                Date closeDate;
                if (closeDateObj != null) {
                    String closeDateStr = String.valueOf(closeDateObj);
                    try {
                        // Try parsing as date string (format: YYYY-MM-DD)
                        List<String> dateParts = closeDateStr.split('-');
                        if (dateParts.size() == 3) {
                            closeDate = Date.newInstance(
                                Integer.valueOf(dateParts[0]),
                                Integer.valueOf(dateParts[1]),
                                Integer.valueOf(dateParts[2])
                            );
                        } else {
                            closeDate = Date.today().addDays(30);
                        }
                    } catch (Exception e) {
                        System.debug('    Warning: Could not parse date: ' + closeDateStr);
                        closeDate = Date.today().addDays(30);
                    }
                } else {
                    closeDate = Date.today().addDays(30);
                }
                
                // Create OpportunityData object
                OpportunityBulkAPIUploader.OpportunityData oppData = 
                    new OpportunityBulkAPIUploader.OpportunityData(
                        externalId,
                        stageName,
                        amount,
                        accountId,
                        name,
                        closeDate
                    );
                
                oppDataList.add(oppData);
                
            } catch (Exception e) {
                System.debug('    ✗ Error parsing row: ' + e.getMessage());
                // Continue processing other rows
            }
        }
        
        return oppDataList;
    }
    
    /**
     * Send records to Bulk API in chunks of 10,000
     */
    private void sendToBulkAPI(List<OpportunityBulkAPIUploader.OpportunityData> oppDataList) {
        System.debug('→ Sending to Bulk API...');
        
        // Split into chunks of 10,000
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = 
            splitIntoChunks(oppDataList, BULK_API_BATCH_SIZE);
        
        System.debug('  Split into ' + chunks.size() + ' chunks of ' + BULK_API_BATCH_SIZE);
        
        Integer chunkNum = 0;
        for (List<OpportunityBulkAPIUploader.OpportunityData> chunk : chunks) {
            chunkNum++;
            System.debug('  → Processing chunk ' + chunkNum + ' (' + chunk.size() + ' records)');
            
            try {
                // Create and execute Bulk API batch
                OpportunityBulkAPIBatch bulkBatch = new OpportunityBulkAPIBatch(chunk);
                Id bulkJobId = Database.executeBatch(bulkBatch, 50000);
                
                System.debug('  ✓ Chunk ' + chunkNum + ' submitted - Bulk Job ID: ' + bulkJobId);
                
            } catch (Exception e) {
                System.debug('  ✗ Error in chunk ' + chunkNum + ': ' + e.getMessage());
                // Continue with next chunk
            }
        }
    }
    
    /**
     * Split list into chunks
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
        
        if (!currentChunk.isEmpty()) {
            chunks.add(currentChunk);
        }
        
        return chunks;
    }
}

