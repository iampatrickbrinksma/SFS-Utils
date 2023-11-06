/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Controller class for the sfsCustomGanttActionOptimize LWC
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsCustomGanttActionOptimize {

    // Custom exception
    public class CustomGanttActionOptimizeException extends Exception{}

    // Start optimization
    @AuraEnabled(cacheable=false)
    public static Id startOptimization(
        List<Id> serviceTerritoryIds, 
        Id schedulingPolicyId, 
        Date startDate, 
        Date endDate, 
        Boolean allTasksMode, 
        String filterByFieldApiName    
    ){
        Id optReqId;
        // Validate input
        if (serviceTerritoryIds != null && !serviceTerritoryIds.isEmpty() && 
            schedulingPolicyId != null && startDate != null && endDate != null)
        {
            // Construct start to start at midnight and finish
            Date startDay = Date.newInstance(startDate.year(), startDate.month(), startDate.day());
            Date endDay = Date.newInstance(endDate.year(), endDate.month(), endDate.day());
            Time earlyTime = Time.newInstance(0, 0, 0, 0);
            Datetime start = Datetime.newInstance(startDay, earlyTime);
            Datetime finish = Datetime.newInstance(EndDay, earlyTime);

            // Create OAAS request
            FSL.OAASRequest oaasRequest = new FSL.OAASRequest();
            oaasRequest.allTasksMode = allTasksMode; // true = all SAs, false = unscheduled SAs
            oaasRequest.filterFieldAPIName = filterByFieldApiName;
            oaasRequest.start = start;
            oaasRequest.finish = finish;
            oaasRequest.includeServicesWithEmptyLocation = false;
            oaasRequest.locations = serviceTerritoryIds;
            oaasRequest.schedulingPolicyID = schedulingPolicyId;

            // Start optimization
            FSL.OAAS oaas = new FSL.OAAS();
            optReqId = oaas.optimize(oaasRequest);   
        } else {
            // throw correct error
            if (serviceTerritoryIds == null || serviceTerritoryIds.isEmpty()){
                throw new CustomGanttActionOptimizeException('Please select at least one service territory!');
            } else if (startDate == null || endDate == null){
                throw new CustomGanttActionOptimizeException('Please provide a valid start and end date!');
            }
        } 
        return optReqId;
    }       

}