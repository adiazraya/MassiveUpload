// When was last opportunity modified?
List<Opportunity> recent = [
    SELECT External_ID__c, LastModifiedDate 
    FROM Opportunity
    ORDER BY LastModifiedDate DESC 
    LIMIT 1
];

if (recent.isEmpty()) {
    System.debug('No opportunities found!');
} else {
    Datetime lastMod = recent[0].LastModifiedDate;
    Long minsAgo = (Datetime.now().getTime() - lastMod.getTime()) / 60000;
    
    System.debug('Last modified: ' + lastMod.format('HH:mm:ss'));
    System.debug('Minutes ago: ' + minsAgo);
    System.debug('External ID: ' + recent[0].External_ID__c);
    
    if (minsAgo > 30) {
        System.debug('⚠️ Over 30 min - process likely stuck!');
    } else if (minsAgo > 10) {
        System.debug('⚠️ Over 10 min - might be stuck');
    } else {
        System.debug('✅ Recent - process is working');
    }
}




