public without sharing class sfsScheduleInvocable {

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Schedule appointment using the provided scheduling policy to be used as invocable
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   inputs          List of inputs
     * @return  List<Output>    List of outputs
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @InvocableMethod(label='Schedule Appointment' description='Use this action to schedule an appointment using the service appointment ID and scheduling policy ID') 
    public static List<Outputs> schedule(List<Inputs> inputs) {
        Inputs input = inputs[0];
        Outputs output = new Outputs();

        try {
            sfsScheduling scheduling = new sfsScheduling(input.serviceAppointmentId, input.schedulingPolicyId);
            output.serviceTerritoryTimeZone = scheduling.serviceAppointmentTimeZone.getID();

            FSL.ScheduleResult result = scheduling.scheduleAppointment();
            if (result == null){
                output.isScheduled = false;
            } else {
                output.isScheduled = true;
                output.serviceAppointment = result.Service;
                output.serviceResource = result.Resource;
            }
        } catch (Exception e) {
            output.isScheduled = false;
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

        @InvocableVariable(label='True if the service appointment was scheduled' description='True if the service appointment was successfully scheduled.')
        public Boolean isScheduled;

        @InvocableVariable(label='Service Appointment' description='The service appointment details as a result of scheduling.')
        public ServiceAppointment serviceAppointment;

        @InvocableVariable(label='Service Resource' description='The service resource details of the resource assigned to the service appointment.')
        public ServiceResource serviceResource;

        @InvocableVariable(label='Error Message' description='The details of any exceptions that were raised while scheduling the service appointment.')
        public String errorMessage;        
    }      

}