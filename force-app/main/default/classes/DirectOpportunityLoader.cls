/**
 * Direct Batch Apex to load 2M opportunities from source object
 * Bypasses Flow - processes records in true batches
 */
public class DirectOpportunityLoader implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private String sourceObjectQuery;
    private static final Integer RECORDS_PER_BULK_API_CALL = 10000;
    
    /**
     * Constructor - specify your source object query
     * Example: 'SELECT External_Id__c, Stage__c, Amount__c, Account__c, Name__c, Close_Date__c FROM Source_Object__c'
     */
    public DirectOpportunityLoader(String query) {
        this.sourceObjectQuery = query;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DIRECT OPPORTUNITY LOADER - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Query: ' + sourceObjectQuery);
        return Database.getQueryLocator(sourceObjectQuery);
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Processing batch - Records: ' + scope.size());
        System.debug('════════════════════════════════════════════════════════');
        
        List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        // Convert source records to OpportunityData
        for (sObject record : scope) {
            try {
                // Adjust these field names to match your source object
                String externalId = String.valueOf(record.get('External_Id__c'));
                String stageName = String.valueOf(record.get('Stage__c'));
                Decimal amount = (Decimal)record.get('Amount__c');
                String accountId = String.valueOf(record.get('Account__c'));
                String name = String.valueOf(record.get('Name__c'));
                Date closeDate = (Date)record.get('Close_Date__c');
                
                if (closeDate == null) {
                    closeDate = Date.today().addDays(30);
                }
                
                OpportunityBulkAPIUploader.OpportunityData oppData = 
                    new OpportunityBulkAPIUploader.OpportunityData(
                        externalId, stageName, amount, accountId, name, closeDate
                    );
                oppDataList.add(oppData);
                
            } catch (Exception e) {
                System.debug('Error processing record: ' + e.getMessage());
            }
        }
        
        System.debug('Converted ' + oppDataList.size() + ' records');
        
        // Split into chunks and make Bulk API calls
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = 
            splitIntoChunks(oppDataList, RECORDS_PER_BULK_API_CALL);
        
        System.debug('Split into ' + chunks.size() + ' chunks of 10K');
        
        Integer chunkNum = 0;
        for (List<OpportunityBulkAPIUploader.OpportunityData> chunk : chunks) {
            chunkNum++;
            System.debug('Processing chunk ' + chunkNum + ' (' + chunk.size() + ' records)');
            
            try {
                OpportunityBulkAPIBatch singleBatch = new OpportunityBulkAPIBatch(chunk);
                Database.executeBatch(singleBatch, 50000);
                System.debug('✓ Chunk ' + chunkNum + ' submitted to Bulk API');
            } catch (Exception e) {
                System.debug('✗ Error in chunk ' + chunkNum + ': ' + e.getMessage());
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('DIRECT OPPORTUNITY LOADER - COMPLETE');
        System.debug('════════════════════════════════════════════════════════');
    }
    
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

