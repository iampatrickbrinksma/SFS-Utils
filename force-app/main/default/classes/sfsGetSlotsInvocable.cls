public without sharing class sfsGetSlotsInvocable {

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots for appointment booking as invocable
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   inputs          List of inputs
     * @return  List<Outputs>   List of outputs 
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @InvocableMethod(label='Get Appointment Booking Slots' description='Use this action to retrieve available time slots for a service appointment.') 
    public static List<Outputs> getAppointmentBookingSlots(List<Inputs> inputs) {
        Inputs input = inputs[0];
        Outputs output = new Outputs();

        try {
            sfsScheduling scheduling = new sfsScheduling(
                input.serviceAppointmentId, 
                input.schedulingPolicyId, 
                input.operatingHoursId, 
                input.exactAppointments, 
                input.sortBy == null ? 'grade' : input.sortBy
            );
            List<sfsScheduling.sfsTimeSlot> slots = scheduling.getAppointmentBookingSlots();
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
        @InvocableVariable(label='Service Appointment Id' description='The ID of the service appointment Id for which available time slots will be retrieved.' required=true)
        public Id serviceAppointmentId;

        @InvocableVariable(label='Scheduling Policy Id' description='The ID of a scheduling policy used for retrieving available time slots.' required=true)
        public Id schedulingPolicyId;

        @InvocableVariable(label='Operating Hours Id' description='The ID of the operating hours which represent the possible time slots.' required=true)
        public Id operatingHoursId;

        @InvocableVariable(label='Exact Appointments' description='Specifies whether the result uses exact appointments (true) or an arrival window (false).')
        public Boolean exactAppointments; 

        @InvocableVariable(label='Sort slots by grade or starttime' description='The way the available time slots are ranked, either by grade or by start time of the time slots.')
        public String sortBy; 

        @InvocableVariable(label='Original Arrival Window Start' description='The original value of the arrival window start. When provided, this value will be restored after retrieving available time slots.')
        public Datetime originalArrivalWindowStart;         

        @InvocableVariable(label='Original Arrival Window End' description='The original value of the arrival window end. When provided, this value will be restored after retrieving available time slots.')
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

        @InvocableVariable(label='Available slots in JSON format' description='A list of available time slots retrieved including the start time, end time and grade.')
        public String slots;

        @InvocableVariable(label='Indicator if slots were found' description='True if available time slots were retrieved.')
        public Boolean slotsFound;

        @InvocableVariable(label='Error Message' description='The details of the error(s) in case an exception occurred while retrieving available time slots.')
        public String errorMessage;        
    }       

}