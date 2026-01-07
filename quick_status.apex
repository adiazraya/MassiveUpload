// Quick status check
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Current: ' + count);
System.debug('Target: 2,000,000');
System.debug('Gap: ' + (2000000 - count));

List<AsyncApexJob> active = [
    SELECT Status FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued')
];
System.debug('Active jobs: ' + active.size());

List<CronTrigger> scheduled = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];
System.debug('Scheduled jobs: ' + scheduled.size());

List<Opportunity> recent = [
    SELECT LastModifiedDate FROM Opportunity
    ORDER BY LastModifiedDate DESC LIMIT 1
];
if (!recent.isEmpty()) {
    Long minsAgo = (Datetime.now().getTime() - recent[0].LastModifiedDate.getTime()) / 60000;
    System.debug('Last update: ' + minsAgo + ' min ago');
}

if (active.size() == 0 && scheduled.size() == 0) {
    System.debug('❌ STOPPED - Need to restart');
} else {
    System.debug('✅ Still running');
}




