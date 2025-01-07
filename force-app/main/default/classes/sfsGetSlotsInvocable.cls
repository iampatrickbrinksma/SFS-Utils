public without sharing class sfsGetSlotsInvocable {

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots for appointment booking as invocable
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   inputs          List<Inputs> containing the scheduling policy and appointment Ids
     * @return  List<Outputs>   List of outputs containing the service resource Id and if the appointment is scheduled
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @InvocableMethod(label='Get Appointment Booking Slots' description='Use this action to retrieve available time slots using the service appointment, operating hours and scheduling policy as input.') 
    public static List<Outputs> getAppointmentBookingSlots(List<Inputs> inputs) {
        Inputs input = inputs[0];
        Outputs output = new Outputs();

        try {
            sfsSchedulingUtil.getServiceAppointment(input.serviceAppointmentId);
            TimeZone serviceTerritoryTimeZone = sfsSchedulingUtil.getTimeZone();
            List<sfsSchedulingUtil.sfsTimeSlot> slots = sfsSchedulingUtil.getAppointmentBookingSlots(
                input.serviceAppointmentId, 
                input.schedulingPolicyId, 
                input.operatingHoursId, 
                serviceTerritoryTimeZone, 
                input.exactAppointments, 
                input.sortBy == null ? 'grade' : input.sortBy
            );
            if (slots.isEmpty()){
                output.slotsFound = false;
            } else {
                output.slotsFound = true;
                output.slots = JSON.serialize(slots);
            }
            output.serviceTerritoryTimeZone = serviceTerritoryTimeZone.getID();
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
        @InvocableVariable(label='Service Appointment Id' description='The single ID of a Service Appointment record.' required=true)
        public Id serviceAppointmentId;

        @InvocableVariable(label='Scheduling Policy Id' description='The single ID of a Scheduling Policy record.' required=true)
        public Id schedulingPolicyId;

        @InvocableVariable(label='Operating Hours Id' description='The single ID of an Operating Hours record.' required=true)
        public Id operatingHoursId;

        @InvocableVariable(label='Exact Appointments' description='Specifies whether the result uses exact appointments (true) or an arrival window (false).')
        public Boolean exactAppointments; 

        @InvocableVariable(label='Sort slots by grade or starttime' description='The way the available time slots are ranked, either by "grade" or by "starttime".')
        public String sortBy; 
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Output params for the invocable method
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public class Outputs {

        @InvocableVariable(label='Service Territory Time Zone' description='Slots are provided in UTC format. This is the display name of the time zone of the service territory.')
        public String serviceTerritoryTimeZone;

        @InvocableVariable(label='Available slots in JSON format' description='A list of available time slots found including the start time, end time and grade.')
        public String slots;

        @InvocableVariable(label='Indicator if slots were found' description='True if no available time slots were found.')
        public Boolean slotsFound;

        @InvocableVariable(label='Error Message' description='The details of an error in case an exception occurred while retrieving available time slots.')
        public String errorMessage;        
    }       

}