trigger OptimizationRequestTrigger on FSL__Optimization_Request__c (after update) {
    sfsOptimizationRequestUtil.processUpdatedOptimizationRequests(
        Trigger.new, Trigger.oldMap
    );
}