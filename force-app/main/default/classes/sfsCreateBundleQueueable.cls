
/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class that creates Bundles using the Appointment Bundling REST APIs and conditionally
* starts optimization once completed
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsCreateBundleQueueable implements Queueable, Database.AllowsCallouts {

    private Map<Integer, List<Id>> bundles;         // Prepared bundle information
    private Id bundlePolicyId;                      // Appointment Bundling Policy Id
    private Integer maxBundlesPerQueueable;         // Max bundles created per queueable to avoid governor limits
    private Boolean startOptimizationOnComplete;    // Start optimization once all bundles are created
    private Id schedulingPolicyId;                  // Scheduling policy Id to use for optimization after bundling
    private List<Id> serviceTerritoryIds;           // Service territory Ids to run optimization for after bundling
    private Date optHorizonStartDate;               // Start date of optimization horizon
    private Integer optHorizonLengthInDays;         // Optimization horizon length in days
    private Boolean optAllTaskMode;                 // Optimization: true = all appointments, false = only unscheduled appointments
    private String optFilterByFieldApiName;         // Only optimize appointments for which this checkbox field = true

    // Constructor
    public sfsCreateBundleQueueable(
        Map<Integer, List<Id>> bundles, 
        Id bundlePolicyId, 
        Integer maxBundlesPerQueueable,
        Boolean startOptimizationOnComplete,
        Id schedulingPolicyId,
        List<Id> serviceTerritoryIds,
        Date optHorizonStartDate,
        Integer optHorizonLengthInDays,
        Boolean optAllTaskMode,
        String optFilterByFieldApiName
    ) 
    {
        this.bundles = bundles;
        this.bundlePolicyId = bundlePolicyId;
        this.maxBundlesPerQueueable = maxBundlesPerQueueable;
        this.startOptimizationOnComplete = startOptimizationOnComplete;
        this.schedulingPolicyId = schedulingPolicyId;
        this.serviceTerritoryIds = serviceTerritoryIds;
        this.optHorizonStartDate = optHorizonStartDate;
        this.optHorizonLengthInDays = optHorizonLengthInDays;
        this.optAllTaskMode = optAllTaskMode;
        this.optFilterByFieldApiName = optFilterByFieldApiName;
    }

    // Queueable execution
    public void execute(QueueableContext ctx){
        // If no bundles are provided, determine next step
        if (bundles == null || (bundles != null && bundles.isEmpty())) nextStep();

        try {
            // Keep track of nr of bundles created as part of this queueable
            Integer nrOfBundlesCreated = 0;
            // Create a bundle for each prepared bundle
            for (Integer bundleKey : bundles.keySet()){
                List<Id> saIds = bundles.get(bundleKey);
                if (saIds != null && !saIds.isEmpty()){
                    sfsAppointmentBundlingAPI bundleAPI = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.BUNDLE, bundlePolicyId, saIds);
                    sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bundleAPI.run();
                    Id bundleId = res.bundleId;
                    if (bundleId != null) bundles.remove(bundleKey);
                } else {
                    bundles.remove(bundleKey);
                }

                // If max nr of bundles have been created, determine next step
                nrOfBundlesCreated++;
                if (nrOfBundlesCreated >= maxBundlesPerQueueable) break;
            }
            // Determine next step
            nextStep();
        } catch (CalloutException e){
            // callout limit reached, chain next queueable
            chainNextJob();
        }
    }

    // Determine next step
    private void nextStep(){
        if (bundles.isEmpty()){
            // Only start optimization when asked to
            if (!startOptimizationOnComplete) return;

            // If all bundles have been processed, start optimization
            sfsOptimizationRequestUtilQueueable q = new sfsOptimizationRequestUtilQueueable(
                serviceTerritoryIds, 
                schedulingPolicyId,
                optHorizonStartDate,
                optHorizonLengthInDays, 
                optAllTaskMode, 
                optFilterByFieldApiName
            );
            System.enqueueJob(q);            
        } else {
            // if more bundles need to be created
            // enqueue the same job again
            chainNextJob();
        }
    }

    // Start the next queueable to process the remaining bundles
    private void chainNextJob(){
        sfsCreateBundleQueueable q = new sfsCreateBundleQueueable(
            bundles, 
            bundlePolicyId, 
            maxBundlesPerQueueable,
            startOptimizationOnComplete,
            schedulingPolicyId,
            serviceTerritoryIds,
            optHorizonStartDate,
            optHorizonLengthInDays,
            optAllTaskMode,
            optFilterByFieldApiName
        );
        System.enqueueJob(q);
    }
}