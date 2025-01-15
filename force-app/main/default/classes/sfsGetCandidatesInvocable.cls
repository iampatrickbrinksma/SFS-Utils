public with sharing class sfsGetCandidatesInvocable {
    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the candidates method
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   inputs          List of inputs
     * @return  List<Outputs>   List of outputs
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @InvocableMethod(label='Get Candidates' description='Use this action to retrieve available candidates with their available time slots for a service appointment.') 
    public static List<Outputs> getCandidates(List<Inputs> inputs) {
        Inputs input = inputs[0];
        Outputs output = new Outputs();

        try {
            sfsScheduling scheduling = new sfsScheduling(
                input.serviceAppointmentId, 
                input.schedulingPolicyId, 
                input.sortBy == null ? 'grade' : input.sortBy
            );
            Map<Id, List<sfsScheduling.sfsTimeSlot>> slots = scheduling.getGradedMatrixSlotsWithResourceName();
            if (slots.isEmpty()){
                output.slotsFound = false;
            } else {
                output.slotsFound = true;
                output.slots = JSON.serialize(slots);
            }
            output.serviceTerritoryTimeZone = scheduling.serviceAppointmentTimeZone.getID();
            if (input.originalArrivalWindowStart != null && input.originalArrivalWindowEnd != null) {
                update new ServiceAppointment(
                    Id = input.serviceAppointmentId,
                    ArrivalWindowStartTime = scheduling.convertSlotDateTimeToUTC(input.originalArrivalWindowStart, Userinfo.getTimeZone()),
                    ArrivalWindowEndTime = scheduling.convertSlotDateTimeToUTC(input.originalArrivalWindowEnd, Userinfo.getTimeZone())
                );
            }            
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
        @InvocableVariable(label='Service Appointment Id' description='The ID of the service appointment Id for which candidates with their available time slots will be retrieved.' required=true)
        public Id serviceAppointmentId;

        @InvocableVariable(label='Scheduling Policy Id' description='The ID of a scheduling policy used for retrieving candidates and their available time slots.' required=true)
        public Id schedulingPolicyId;

        @InvocableVariable(label='Sort slots by grade or starttime' description='The way the available time slots are ranked, either by grade or by start time of the slots.')
        public String sortBy; 

        @InvocableVariable(label='Original Arrival Window Start' description='The original value of the arrival window start. When provided, this value will be restored after retrieving candidates with their available time slots.')
        public Datetime originalArrivalWindowStart;         

        @InvocableVariable(label='Original Arrival Window End' description='The original value of the arrival window end. When provided, this value will be restored after retrieving candidates with their available time slots.')
        public Datetime originalArrivalWindowEnd;        
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Output params for the invocable method
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public class Outputs {

        @InvocableVariable(label='Service Territory Time Zone' description='The time zone of the service territory of the service appointment.')
        public String serviceTerritoryTimeZone;

        @InvocableVariable(label='Available slots in JSON format' description='A list of candidates including their available time slots found including the start time, end time, grade and name of the candidate.')
        public String slots;

        @InvocableVariable(label='Indicator if slots were found' description='True if available time slots were found.')
        public Boolean slotsFound;

        @InvocableVariable(label='Error Message' description='The details of the error(s) in case an exception was raised while retrieving candidates with their available time slots.')
        public String errorMessage;        
    }       
}