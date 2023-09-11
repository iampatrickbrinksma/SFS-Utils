/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class start optimization in Salesforce Field Service
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsOptimizationRequestUtilQueueable  implements Queueable, Database.AllowsCallouts {

    private List<Id> serviceTerritoryIds;   // List of Service Territory Ids to include in Optimization
    private Id schedulingPolicyId;          // Scheduling Policy Id
    private Date startDate;                 // Start date for optimization horizon
    private Integer horizonInDays;          // How many days to optimization
    private Boolean allTasksMode;           // True = all appointments, False = Only unscheduled appointments
    private String filterByFieldApiName;    // Only optimize appointments with this Boolean field = true

    // Constructor
    public sfsOptimizationRequestUtilQueueable(
        List<Id> serviceTerritoryIds, 
        Id schedulingPolicyId, 
        Date startDate, 
        Integer horizonInDays, 
        Boolean allTasksMode, 
        String filterByFieldApiName
    )
    {
        this.serviceTerritoryIds = serviceTerritoryIds;
        this.schedulingPolicyId = schedulingPolicyId;
        this.startDate = startDate;
        this.horizonInDays = horizonInDays;
        this.allTasksMode = allTasksMode;
        this.filterByFieldApiName = filterByFieldApiName;
    }

    public void execute(QueueableContext ctx){
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
        oaas.optimize(oaasRequest);  
    }

}