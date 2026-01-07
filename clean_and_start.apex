// Clean up and start fresh
System.debug('Cleaning up old partition records...');

// Delete ALL partition records
List<DataCloudPartition__c> allPartitions = [SELECT Id FROM DataCloudPartition__c];
if (!allPartitions.isEmpty()) {
    delete allPartitions;
    System.debug('✓ Deleted ' + allPartitions.size() + ' old partition records');
}

System.debug('');
System.debug('Starting fresh orchestrator run...');
HourlyOrchestrator orch = new HourlyOrchestrator();
orch.execute(null);

System.debug('✓ Orchestrator started');
System.debug('Monitor: Setup → Apex Jobs');




