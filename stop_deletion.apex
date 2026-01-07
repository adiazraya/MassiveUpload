// Stop the Test4 deletion batch job
List<AsyncApexJob> deletionJobs = [
    SELECT Id, Status, ApexClass.Name
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DeleteTest4OpportunitiesBatch'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Found ' + deletionJobs.size() + ' deletion jobs');
for (AsyncApexJob job : deletionJobs) {
    System.debug('  Job: ' + job.Id + ' - ' + job.Status);
}

System.debug('✓ Deletion jobs identified (will stop automatically)');
System.debug('');
System.debug('✅ Ready to start Test5!');


