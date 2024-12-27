public without sharing class sfsScheduleInvocable {

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Schedule appointment using the provided scheduling policy to be used as invocable
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   inputs                  List<Inputs> containing the scheduling policy and appointment Ids
     * @return  List<Output>            List of outputs containing the service resource Id and if the appointment is scheduled
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @InvocableMethod(label='Schedule Appointment' description='Use this action to schedule an appointment using the service appointment ID and scheduling policy ID') 
    public static List<Outputs> schedule(List<Inputs> inputs) {
        Inputs input = inputs[0];
        Outputs output = new Outputs();

        try {
            FSL.ScheduleResult result = sfsSchedulingUtil.scheduleAppointment(input.serviceAppointmentId, input.schedulingPolicyId);
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
        @InvocableVariable(label='Service Appointment Id' description='The single ID of a Service Appointment record.' required=true)
        public Id serviceAppointmentId;

        @InvocableVariable(label='Scheduling Policy Id' description='The single ID of a Scheduling Policy record.' required=true)
        public Id schedulingPolicyId;
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Output params for the invocable method
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public class Outputs {
        @InvocableVariable(label='True if the service appointment was scheduled' description='True if the service appointment was scheduled')
        public Boolean isScheduled;

        @InvocableVariable(label='Service Appointment' description='The Service Appointment record details.')
        public ServiceAppointment serviceAppointment;

        @InvocableVariable(label='Service Resource' description='The Service Resource record details of the assigned resource.')
        public ServiceResource serviceResource;

        @InvocableVariable(label='Error Message' description='The details of an error in case an exception occurred while scheduling the service appointment.')
        public String errorMessage;        
    }      

}