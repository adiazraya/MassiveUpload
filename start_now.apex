// Start the orchestrator immediately (don't wait for scheduled time)
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING DAILY SYNC NOW');
System.debug('════════════════════════════════════════════════════════════════');

HourlyOrchestrator orch = new HourlyOrchestrator();
orch.execute(null);

System.debug('✓ Orchestrator executed');
System.debug('Check Setup → Apex Jobs to see the batch running');
System.debug('════════════════════════════════════════════════════════════════');




