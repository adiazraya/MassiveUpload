// Queue Test5 deletion
Integer test5Count = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test5'];
System.debug('Deleting ' + test5Count + ' Test5 opportunities...');
Database.executeBatch(new DeleteTest5OpportunitiesBatch(), 10000);
System.debug('✓ Deletion queued (~' + Math.ceil(test5Count / 10000.0) + ' minutes)');
System.debug('⏳ Once complete, Test7 can start');


