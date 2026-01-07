// SIMPLE COUNT CHECK - Run this every minute
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Current count: ' + count);
System.debug('Expected: 465410 (465400 + 10)');
System.debug('Diff from 465400: ' + (count - 465400));

if (count > 465400) {
    System.debug('✅ SUCCESS! ' + (count - 465400) + ' new opps created!');
} else {
    System.debug('⏳ Still processing... check again in 1 minute');
}





