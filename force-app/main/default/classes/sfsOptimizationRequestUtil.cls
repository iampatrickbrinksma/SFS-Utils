/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class to process updated optimization request records, and for example start optimization
* once automatic bundling is completed
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsOptimizationRequestUtil {

    // Picklist values
    private static final String STATUS_INPROGESS = 'In Progress';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String TYPE_AUTOMATIC_BUNDLING = 'Automated Bundling';

    // Config settings stored in a custom setting for specific user
    private static Automatic_Bundling_Config__c bundlingConfigForUser {
        get{
            if (bundlingConfigForUser == null){
                bundlingConfigForUser = Automatic_Bundling_Config__c.getInstance();
            }
            return bundlingConfigForUser;
        }
        private set;
    }      

    // Generic method to process updated optimization requests in which the order of execution can be determined
    public static void processUpdatedOptimizationRequests(List<FSL__Optimization_Request__c> newList, Map<Id, FSL__Optimization_Request__c> oldMap){
        processAutomatedBundlingRequests(newList, oldMap);
    }

    // Start optimization
    public static Id optimize(
        List<Id> serviceTerritoryIds, 
        Id schedulingPolicyId, 
        Date startDate, 
        Integer horizonInDays, 
        Boolean allTasksMode, 
        String filterByFieldApiName        
    ){
        // Construct start to start at midnight and finish
        Date startDay = Date.newInstance(startDate.year(), startDate.month(), startDate.day());
        Time earlyTime = Time.newInstance(0, 0, 0, 0);
        Datetime start = Datetime.newInstance(startDay, earlyTime);
        Datetime finish = start.addDays(horizonInDays);

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
        return oaas.optimize(oaasRequest);         
    }

    // Process completed automatic bundling requests
    private static void processAutomatedBundlingRequests(List<FSL__Optimization_Request__c> newList, Map<Id, FSL__Optimization_Request__c> oldMap){

        // If this feature is disabled, stop silently
        if (bundlingConfigForUser == null ||
            (bundlingConfigForUser != null && !bundlingConfigForUser.Start_Optimization_Once_Completed__c))
        {
            return;
        }

        // This feature doesn't support bulk updates of Optimization Requests
        if (newList.isEmpty() || newList.size() > 1) return;

        // Keep track of service territories that were part of automated bundling
        List<Id> stIds = new List<Id>();

        // Single record update
        FSL__Optimization_Request__c optReq = newList[0];

        // Determine if the Automated Bundling optimization request
        // was updated from In Progress to Completed
        if (optReq.FSL__Type__c == TYPE_AUTOMATIC_BUNDLING && 
            optReq.FSL__Status__c == STATUS_COMPLETED && oldMap.get(optReq.Id).FSL__Status__c == STATUS_INPROGESS
        ){
            // Determine which Service Territories were part of the Automated Bundling process
            // and run optimization for them
            List<FSL__Territory_Optimization_Request__c> tors = [select FSL__ServiceTerritory__c from FSL__Territory_Optimization_Request__c where FSL__Optimization_Request__c = :optReq.Id];
            if (!tors.isEmpty()){
                for (FSL__Territory_Optimization_Request__c tor : tors){
                    stIds.add(tor.FSL__ServiceTerritory__c);
                }
                // As we are in an Apex Trigger context, callouts are not possible
                // so Optimization is started in a Queueable context
                sfsOptimizationRequestUtilQueueable q = new sfsOptimizationRequestUtilQueueable(
                    stIds, 
                    bundlingConfigForUser.Scheduling_Policy_Name__c, 
                    System.today().addDays(1), 
                    (Integer)bundlingConfigForUser.Optimization_Horizon_Length_Days__c, 
                    bundlingConfigForUser.Only_Optimize_Unscheduled_Appointments__c, 
                    bundlingConfigForUser.Filter_By_Checkbox_Field_API_Name__c
                );
                System.enqueueJob(q);
            }
        }
    }

}