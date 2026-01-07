// Simple check - is it still running?
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Opportunities: ' + count);

List<AsyncApexJob> active = [
    SELECT Status FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND Status IN ('Processing', 'Queued')
];
System.debug('Active jobs: ' + active.size());

List<CronTrigger> scheduled = [
    SELECT NextFireTime FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];
System.debug('Scheduled: ' + scheduled.size());
if (scheduled.size() > 0) {
    System.debug('Next run: ' + scheduled[0].NextFireTime);
}

List<Opportunity> recent = [
    SELECT LastModifiedDate FROM Opportunity
    ORDER BY LastModifiedDate DESC LIMIT 1
];
if (!recent.isEmpty()) {
    Long minsAgo = (Datetime.now().getTime() - recent[0].LastModifiedDate.getTime()) / 60000;
    System.debug('Last update: ' + minsAgo + ' min ago');
    
    if (active.size() == 0 && scheduled.size() == 0 && minsAgo > 10) {
        System.debug('❌ STOPPED!');
    } else if (active.size() > 0 || scheduled.size() > 0) {
        System.debug('✅ RUNNING');
    }
}




