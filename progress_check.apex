// SIMPLE PROGRESS CHECK - Run every 20 minutes
Integer count = [SELECT COUNT() FROM Opportunity];
Integer target = 2000000;
Integer progress = (count * 100) / target;

System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROGRESS UPDATE');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('Current:  ' + String.valueOf(count).leftPad(10) + ' opportunities');
System.debug('Target:   ' + String.valueOf(target).leftPad(10) + ' opportunities');
System.debug('Progress: ' + String.valueOf(progress).leftPad(10) + '%');
System.debug('Remaining: ~' + (target - count) + ' to create');
System.debug('══════════════════════════════════════════════════════════════');

if (count >= target) {
    System.debug('🎉 COMPLETE! Process finished successfully!');
} else if (count > 241400) {
    System.debug('✅ Growing! Keep monitoring every 20 minutes.');
} else {
    System.debug('⏳ Still processing first batch... check again in 5 min');
}





