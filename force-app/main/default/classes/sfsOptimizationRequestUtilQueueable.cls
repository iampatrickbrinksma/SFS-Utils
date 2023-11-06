/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class start optimization in Salesforce Field Service in a Queueable context
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

        sfsOptimizationRequestUtil.optimize(
            serviceTerritoryIds, 
            schedulingPolicyId, 
            startDate, 
            horizonInDays, 
            allTasksMode, 
            filterByFieldApiName
        );
 
    }

}