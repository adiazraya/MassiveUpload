// Schedule Hourly Orchestrator - Runs every hour, 24/7
System.debug('Scheduling Hourly Orchestrator...');

// Cancel any existing
List<CronTrigger> existing = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE '%Hourly Orchestrator%'
];
for (CronTrigger job : existing) {
    System.abortJob(job.Id);
}

// Schedule for every hour
List<Id> jobIds = new List<Id>();
for (Integer hour = 0; hour < 24; hour++) {
    String cronExp = '0 0 ' + hour + ' * * ?';
    String jobName = 'Hourly Orchestrator - Hour ' + hour;
    Id jobId = System.schedule(jobName, cronExp, new HourlyOrchestrator());
    jobIds.add(jobId);
}

System.debug('✅ Scheduled 24 hourly orchestrator jobs');
System.debug('These will check progress and start batches as needed');




