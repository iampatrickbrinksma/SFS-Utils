public with sharing class sfsAppointmentInsightsInvocable {

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Get appointment insights using the provided scheduling policy to be used as invocable
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   inputs          List of inputs
     * @return  List<Output>    List of outputs
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @InvocableMethod(label='Service Appointment Insights' description='Use this action to get insights why a service appointment could not be scheduled using the service appointment ID and scheduling policy ID') 
    public static List<Outputs> getAppointmentInsights(List<Inputs> inputs) {
        Inputs input = inputs[0];
        Outputs output = new Outputs();

        try {
            sfsScheduling scheduling = new sfsScheduling(input.serviceAppointmentId, input.schedulingPolicyId);
            output.serviceTerritoryTimeZone = scheduling.serviceAppointmentTimeZone.getID();
            sfsScheduling.sfsAppointmentInsights insights = scheduling.getAppointmentInsights();
            output.appointmentInsights = JSON.serialize(insights);

        } catch (Exception e) {
            output.errorMessage = e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getCause() + ' ' + e.getStackTraceString();
        }

        return new List<Outputs>{output};
        
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Input params for the invocable method
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    public class Inputs {
        
        @InvocableVariable(label='Service Appointment Id' description='The ID of the service appointment Id that will be scheduled.' required=true)
        public Id serviceAppointmentId;

        @InvocableVariable(label='Scheduling Policy Id' description='The ID of a scheduling policy used when scheduling the service appointment.' required=true)
        public Id schedulingPolicyId;
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Output params for the invocable method
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public class Outputs {

        @InvocableVariable(label='Service Territory Time Zone' description='The time zone of the service territory of the service appointment.')
        public String serviceTerritoryTimeZone;

        @InvocableVariable(label='Appointment Insights' description='Appointment insights providing details why a service appointment can not be scheduled.')
        public String appointmentInsights;

        @InvocableVariable(label='Error Message' description='The details of any exceptions that were raised while scheduling the service appointment.')
        public String errorMessage;        
    }      


}