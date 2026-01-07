// Stop all V2 jobs
System.debug('🛑 STOPPING ALL V2 JOBS');

List<AsyncApexJob> jobs = [
    SELECT Id, ApexClass.Name
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('Found ' + jobs.size() + ' jobs to abort');

for (AsyncApexJob job : jobs) {
    System.abortJob(job.Id);
    System.debug('✓ Aborted: ' + job.Id);
}

System.debug('✅ All V2 jobs stopped');




