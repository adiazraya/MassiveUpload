// Monitor dynamic partitioning progress
Integer oppCount = [SELECT COUNT() FROM Opportunity WHERE External_ID__c LIKE 'externalOpp%'];
System.debug('════════════════════════════════════════════════════════════════');
System.debug('📊 Current: ' + oppCount + ' / 2,000,000 opportunities');
System.debug('Missing: ' + (2000000 - oppCount));
System.debug('');

List<AsyncApexJob> jobs = [
    SELECT Id, Status, CreatedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessor'
    AND Status IN ('Processing', 'Queued', 'Preparing')
    ORDER BY CreatedDate DESC
];

System.debug('Active Jobs: ' + jobs.size());
System.debug('════════════════════════════════════════════════════════════════');




