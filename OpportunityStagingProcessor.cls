/**
 * Batch Apex to process staged opportunity records from Flow
 * 
 * Flow writes to Staging Object → This batch reads and processes via Bulk API
 * 
 * Usage:
 *   OpportunityStagingProcessor processor = new OpportunityStagingProcessor();
 *   Database.executeBatch(processor, 10000);
 */
public class OpportunityStagingProcessor implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private String stagingObjectQuery;
    private static final Integer RECORDS_PER_BULK_API_CALL = 10000;
    
    /**
     * Constructor with default query
     * Processes all unprocessed staging records
     */
    public OpportunityStagingProcessor() {
        // Default query - adjust object and field names as needed
        this.stagingObjectQuery = 
            'SELECT Id, External_Id__c, Stage_Name__c, Amount__c, ' +
            '       Account_Id__c, Opportunity_Name__c, Close_Date__c ' +
            'FROM Opportunity_Staging__c ' +
            'WHERE Processed__c = false ' +
            'ORDER BY CreatedDate';
    }
    
    /**
     * Constructor with custom query
     */
    public OpportunityStagingProcessor(String customQuery) {
        this.stagingObjectQuery = customQuery;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('STAGING PROCESSOR - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + bc.getJobId());
        System.debug('Query: ' + stagingObjectQuery);
        System.debug('Timestamp: ' + System.now());
        
        return Database.getQueryLocator(stagingObjectQuery);
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('STAGING PROCESSOR - EXECUTE');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + bc.getJobId());
        System.debug('Records in scope: ' + scope.size());
        
        List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        List<Id> processedIds = new List<Id>();
        
        // Convert staging records to OpportunityData
        for (sObject stagingRecord : scope) {
            try {
                String externalId = String.valueOf(stagingRecord.get('External_Id__c'));
                String stageName = String.valueOf(stagingRecord.get('Stage_Name__c'));
                Decimal amount = (Decimal)stagingRecord.get('Amount__c');
                String accountId = String.valueOf(stagingRecord.get('Account_Id__c'));
                String name = String.valueOf(stagingRecord.get('Opportunity_Name__c'));
                Date closeDate = (Date)stagingRecord.get('Close_Date__c');
                
                if (closeDate == null) {
                    closeDate = Date.today().addDays(30);
                }
                
                OpportunityBulkAPIUploader.OpportunityData oppData = 
                    new OpportunityBulkAPIUploader.OpportunityData(
                        externalId, stageName, amount, accountId, name, closeDate
                    );
                oppDataList.add(oppData);
                processedIds.add((Id)stagingRecord.get('Id'));
                
            } catch (Exception e) {
                System.debug('✗ Error processing staging record: ' + stagingRecord.get('Id'));
                System.debug('  Error: ' + e.getMessage());
            }
        }
        
        System.debug('✓ Converted ' + oppDataList.size() + ' staging records');
        
        // Send to Bulk API in chunks of 10,000
        List<List<OpportunityBulkAPIUploader.OpportunityData>> chunks = 
            splitIntoChunks(oppDataList, RECORDS_PER_BULK_API_CALL);
        
        System.debug('→ Split into ' + chunks.size() + ' chunks for Bulk API');
        
        Integer chunkNum = 0;
        for (List<OpportunityBulkAPIUploader.OpportunityData> chunk : chunks) {
            chunkNum++;
            System.debug('  Processing chunk ' + chunkNum + ' (' + chunk.size() + ' records)');
            
            try {
                OpportunityBulkAPIBatch bulkBatch = new OpportunityBulkAPIBatch(chunk);
                Id bulkJobId = Database.executeBatch(bulkBatch, 50000);
                System.debug('  ✓ Chunk ' + chunkNum + ' submitted - Bulk Job ID: ' + bulkJobId);
            } catch (Exception e) {
                System.debug('  ✗ Error in chunk ' + chunkNum + ': ' + e.getMessage());
            }
        }
        
        // Mark staging records as processed
        if (!processedIds.isEmpty()) {
            List<sObject> recordsToUpdate = new List<sObject>();
            for (Id recordId : processedIds) {
                sObject record = stagingObjectQuery.contains('Opportunity_Staging__c') ? 
                    new Opportunity_Staging__c(Id = recordId) : 
                    scope[0].getSObjectType().newSObject(recordId);
                record.put('Processed__c', true);
                record.put('Processed_Date__c', System.now());
                recordsToUpdate.add(record);
            }
            
            try {
                update recordsToUpdate;
                System.debug('✓ Marked ' + recordsToUpdate.size() + ' staging records as processed');
            } catch (Exception e) {
                System.debug('✗ Error updating staging records: ' + e.getMessage());
            }
        }
        
        System.debug('════════════════════════════════════════════════════════');
        System.debug('STAGING PROCESSOR - EXECUTE COMPLETE');
        System.debug('════════════════════════════════════════════════════════');
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('STAGING PROCESSOR - FINISH');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Batch Job ID: ' + bc.getJobId());
        System.debug('Completion Time: ' + System.now());
        
        // Check how many records are still unprocessed
        Integer remainingCount = Database.countQuery(
            'SELECT COUNT() FROM Opportunity_Staging__c WHERE Processed__c = false'
        );
        System.debug('Remaining unprocessed records: ' + remainingCount);
        
        if (remainingCount > 0) {
            System.debug('⚠️ Note: ' + remainingCount + ' records still need processing');
            System.debug('   Run the batch again if needed');
        } else {
            System.debug('✓ All staging records processed!');
        }
        
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








