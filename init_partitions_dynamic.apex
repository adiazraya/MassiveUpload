// Initialize partitions using lowercase field names (Apex internal representation)
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 INITIALIZING PARALLEL SYNC (10 PARTITIONS)');
System.debug('═══════════════════════════════════════════════════════════════');

try {
    // Delete existing records
    List<DataCloudPartition__c> existing = [SELECT Id FROM DataCloudPartition__c];
    if (!existing.isEmpty()) {
        delete existing;
        System.debug('✓ Deleted ' + existing.size() + ' existing records');
    }
    
    // Create 10 partition records
    List<DataCloudPartition__c> partitions = new List<DataCloudPartition__c>();
    
    for (Integer i = 0; i < 10; i++) {
        String partitionName = 'Partition' + i;
        
        DataCloudPartition__c part = new DataCloudPartition__c();
        part.Name = partitionName;
        part.put('PartitionId__c', i);
        part.put('CurrentOffset__c', 0);
        part.put('TotalProcessed__c', 0);
        part.put('TotalBulkAPICalls__c', 0);
        part.put('Status__c', 'Initialized');
        
        partitions.add(part);
        System.debug('✓ ' + partitionName + ' ready');
    }
    
    insert partitions;
    
    System.debug('');
    System.debug('✅ All 10 partitions created!');
    System.debug('');
    System.debug('Next: Create Scheduled Flow in Setup');
    
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
    System.debug('Line: ' + e.getLineNumber());
}




