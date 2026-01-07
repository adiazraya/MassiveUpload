/**
 * Batch processor to load opportunities from Data Cloud using SmartDataDiscovery API
 * Queries ExtOpportunities__dlm and sends to Salesforce via Bulk API
 * 
 * Usage:
 *   String query = 'SELECT externalid__c, stagename__c, amount__c, account__c, name__c, closedate__c FROM ExtOpportunities__dlm ORDER BY externalid__c';
 *   DataCloudOpportunityBatchLoader loader = new DataCloudOpportunityBatchLoader(query, 10000);
 *   Database.executeBatch(loader, 1); // Process 1 batch at a time (each batch = 10K records = 1 Bulk API call)
 */
public class DataCloudOpportunityBatchLoader implements Database.Batchable<String>, Database.AllowsCallouts {
    
    private String baseQuery;
    private Integer recordsPerBatch; // How many records to get from Data Cloud per batch
    private Integer totalBatches;
    
    /**
     * Constructor
     * @param query - SQL query for Data Cloud (without LIMIT/OFFSET)
     * @param batchSize - Number of records per batch (recommend 10000 for Bulk API optimization)
     */
    public DataCloudOpportunityBatchLoader(String query, Integer batchSize) {
        this.baseQuery = query;
        this.recordsPerBatch = batchSize != null ? batchSize : 10000;
    }
    
    /**
     * Start method - Calculate how many batches needed
     */
    public Iterable<String> start(Database.BatchableContext BC) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DATA CLOUD OPPORTUNITY LOADER - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + BC.getJobId());
        System.debug('Base Query: ' + baseQuery);
        System.debug('Records per batch: ' + recordsPerBatch);
        System.debug('Timestamp: ' + System.now());
        
        List<String> batchIdentifiers = new List<String>();
        
        try {
            // Get Data Cloud connection
            ConnectApi.SmartDataDiscovery.DatacloudConnection connection = 
                ConnectApi.SmartDataDiscovery.getDatacloudConnection();
            
            System.debug('✓ Data Cloud connection obtained: ' + connection.connectionId);
            
            // Get total count
            String countQuery = 'SELECT COUNT(*) as total_count FROM ExtOpportunities__dlm';
            System.debug('→ Executing count query: ' + countQuery);
            
            ConnectApi.SmartDataDiscovery.QueryResult countResult = 
                ConnectApi.SmartDataDiscovery.query(connection.connectionId, countQuery);
            
            Integer totalRecords = 0;
            if (countResult != null && countResult.data != null && !countResult.data.isEmpty()) {
                Object countObj = countResult.data[0].values.get('total_count');
                totalRecords = countObj != null ? Integer.valueOf(countObj) : 0;
            }
            
            System.debug('✓ Total records in Data Cloud: ' + totalRecords);
            
            // Calculate number of batches needed
            totalBatches = totalRecords > 0 ? 
                Math.ceil(Decimal.valueOf(totalRecords) / Decimal.valueOf(recordsPerBatch)).intValue() : 0;
            
            System.debug('✓ Will process in ' + totalBatches + ' batches');
            
            // Create batch identifiers (0, 1, 2, ...)
            for (Integer i = 0; i < totalBatches; i++) {
                batchIdentifiers.add(String.valueOf(i));
            }
            
        } catch (Exception e) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('ERROR in start method');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('════════════════════════════════════════════════════════');
        }
        
        System.debug('════════════════════════════════════════════════════════');
        System.debug('START method complete - ' + batchIdentifiers.size() + ' batches to process');
        System.debug('════════════════════════════════════════════════════════');
        
        return batchIdentifiers;
    }
    
    /**
     * Execute method - Process each batch
     */
    public void execute(Database.BatchableContext BC, List<String> scope) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('EXECUTE - Processing batch(es)');
        System.debug('Scope size: ' + scope.size());
        System.debug('════════════════════════════════════════════════════════');
        
        for (String batchNumber : scope) {
            processBatch(Integer.valueOf(batchNumber));
        }
    }
    
    /**
     * Process a single batch - query Data Cloud and send to Bulk API
     */
    private void processBatch(Integer batchNumber) {
        System.debug('────────────────────────────────────────────────────────');
        System.debug('Processing Batch #' + batchNumber);
        System.debug('────────────────────────────────────────────────────────');
        
        try {
            // Get Data Cloud connection
            ConnectApi.SmartDataDiscovery.DatacloudConnection connection = 
                ConnectApi.SmartDataDiscovery.getDatacloudConnection();
            
            // Calculate OFFSET for this batch
            Integer offset = batchNumber * recordsPerBatch;
            
            // Build paginated query
            String paginatedQuery = baseQuery + 
                ' LIMIT ' + recordsPerBatch + 
                ' OFFSET ' + offset;
            
            System.debug('→ Query: ' + paginatedQuery);
            
            // Execute Data Cloud query
            ConnectApi.SmartDataDiscovery.QueryResult result = 
                ConnectApi.SmartDataDiscovery.query(connection.connectionId, paginatedQuery);
            
            if (result == null || result.data == null || result.data.isEmpty()) {
                System.debug('✓ No data returned for batch ' + batchNumber);
                return;
            }
            
            System.debug('✓ Retrieved ' + result.data.size() + ' records from Data Cloud');
            
            // Convert Data Cloud results to OpportunityData
            List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
                new List<OpportunityBulkAPIUploader.OpportunityData>();
            
            Integer successCount = 0;
            Integer errorCount = 0;
            
            for (ConnectApi.SmartDataDiscovery.QueryResultRow row : result.data) {
                try {
                    // Extract fields from Data Cloud
                    String externalId = (String) row.values.get('externalid__c');
                    String stageName = (String) row.values.get('stagename__c');
                    Object amountObj = row.values.get('amount__c');
                    Decimal amount = amountObj != null ? Decimal.valueOf(String.valueOf(amountObj)) : 0;
                    String accountId = (String) row.values.get('account__c');
                    String name = (String) row.values.get('name__c');
                    Object closeDateObj = row.values.get('closedate__c');
                    
                    // Parse close date
                    Date closeDate = parseDateField(closeDateObj);
                    
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
                    successCount++;
                    
                } catch (Exception e) {
                    errorCount++;
                    System.debug('  ✗ Error converting row: ' + e.getMessage());
                }
            }
            
            System.debug('✓ Converted ' + successCount + ' records successfully');
            if (errorCount > 0) {
                System.debug('⚠ Failed to convert ' + errorCount + ' records');
            }
            
            // Send to Bulk API if we have data
            if (!oppDataList.isEmpty()) {
                System.debug('→ Sending ' + oppDataList.size() + ' records to Bulk API...');
                
                OpportunityBulkAPIBatch bulkBatch = new OpportunityBulkAPIBatch(oppDataList);
                Id bulkJobId = Database.executeBatch(bulkBatch, 50000);
                
                System.debug('✓ Bulk API job created: ' + bulkJobId);
                System.debug('  Records: ' + oppDataList.size());
            }
            
        } catch (Exception e) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('ERROR processing batch ' + batchNumber);
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            System.debug('════════════════════════════════════════════════════════');
        }
        
        System.debug('────────────────────────────────────────────────────────');
        System.debug('Batch #' + batchNumber + ' complete');
        System.debug('────────────────────────────────────────────────────────');
    }
    
    /**
     * Parse date field from Data Cloud (handles various formats)
     */
    private Date parseDateField(Object dateObj) {
        if (dateObj == null) {
            return Date.today().addDays(30);
        }
        
        try {
            String dateStr = String.valueOf(dateObj);
            
            // Try parsing as ISO date (YYYY-MM-DD)
            if (dateStr.contains('-')) {
                List<String> parts = dateStr.split('-');
                if (parts.size() >= 3) {
                    Integer year = Integer.valueOf(parts[0]);
                    Integer month = Integer.valueOf(parts[1]);
                    Integer day = Integer.valueOf(parts[2].substring(0, Math.min(2, parts[2].length())));
                    return Date.newInstance(year, month, day);
                }
            }
            
            // If parsing fails, use default
            return Date.today().addDays(30);
            
        } catch (Exception e) {
            System.debug('  ⚠ Could not parse date: ' + dateObj + ' - using default');
            return Date.today().addDays(30);
        }
    }
    
    /**
     * Finish method
     */
    public void finish(Database.BatchableContext BC) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DATA CLOUD OPPORTUNITY LOADER - FINISH');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + BC.getJobId());
        System.debug('Completion Time: ' + System.now());
        
        // Query batch job info
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob 
            WHERE Id = :BC.getJobId()
        ];
        
        System.debug('Final Status: ' + job.Status);
        System.debug('Batches Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
        System.debug('Errors: ' + job.NumberOfErrors);
        System.debug('════════════════════════════════════════════════════════');
        System.debug('All Data Cloud batches processed!');
        System.debug('Check Setup → Apex Jobs for Bulk API job progress');
        System.debug('════════════════════════════════════════════════════════');
    }
}








