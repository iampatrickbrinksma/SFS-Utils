/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * Util class for retrieving time slots, candidates and scheduling actions
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * @author         Patrick Brinksma   <patrick@brinksma.es>
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
 */
public with sharing class sfsSchedulingUtil {

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the candidates method and map arrival windows
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   schedulingPolicyId          Id of the scheduling policy used to retrieve time slots
     * @param   serviceAppointmentId        Id of the service appointment to retrieve time slots for
     * @param   operatingHoursId            Id of the operating hours representing the arrival windows
     * @return  Map<Long, sfsTimeSlot>      Map if start time slot (getTime()) and the arrival window slot
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */        
    public static List<sfsTimeSlot> getCandidateSlotsWithArrivalWindow(Id schedulingPolicyId, Id serviceAppointmentId, Id operatingHoursId, String sortBy){

        sfsPerformanceMeasure.start('getCandidateSlotsWithArrivalWindow');

        // Map of start time slot as Long (getTime()) and the arrival window slot
        Map<Long, sfsTimeSlot> abSlotsMap = new Map<Long, sfsTimeSlot>();
        List<sfsTimeSlot> abSlots;

        // Get available time slots using Candidates to retrieve resources + availability
        Map<Id, List<sfsTimeSlot>> srIdToTimeSlots = getGradedMatrixSlots(schedulingPolicyId, serviceAppointmentId, sortBy);

        // If no slots were found, we're done
        if (!srIdToTimeSlots.isEmpty()){

            // Get duration of the appointment
            Integer appointmentDurationInMinutes = Integer.valueOf(getAppointmentDuration(serviceAppointmentId));

            // Get the arrival windows definition
            Map<String, List<arrivalWindowSlot>> dayToAWSlots = getArrivalWindowTimeSlots(operatingHoursId);
            
            sfsPerformanceMeasure.start('DetermineValidArrivalWindows');

            // Map of Resource Id to list of arrival windows
            Map<Id, List<sfsTimeSlot>> srIdToAWSlots = new Map<Id, List<sfsTimeSlot>>();

            /**
            * At this point you could filter out any resources by a custom mechanism
            */

            // Determine the valid arrival windows for all resources and availability
            for (Id resourceId : srIdToTimeSlots.keySet()){
                // To store the list of valid arrival window slots for this resource
                List<sfsTimeSlot> srAWSlots = new List<sfsTimeSlot>();
                // List of availability slots for the resource
                List<sfsTimeSlot> resSlots = srIdToTimeSlots.get(resourceId);            
                // Check for every availability slot which arrival window slots are valid
                for (sfsTimeSlot resSlot : resSlots){
                    // Get the arrival window slots for the day of availability
                    String dayOfWeek = getDayOfWeek(resSlot.startTime);
                    List<arrivalWindowSlot> awSlots = dayToAWSlots.get(dayOfWeek);
                    // Construct the start and end time of availability for comparison
                    Time avStartTime = Time.newInstance(resSlot.startTime.hour(), resSlot.startTime.minute(), 0, 0);
                    Time avEndTime = Time.newInstance(resSlot.endTime.hour(), resSlot.endTime.minute(), 0, 0);
                    // For every arrival window slot, validate if it's valid
                    for (arrivalWindowSlot awSlot : awSlots){
                        // Construct the arrival window start and end
                        Datetime awStartTime = Datetime.newInstance(resSlot.startTime.year(), resSlot.startTime.month(), resSlot.startTime.day(), awSlot.startTime.hour(), awSlot.startTime.minute(), 0);
                        Datetime awEndTime = Datetime.newInstance(resSlot.startTime.year(), resSlot.startTime.month(), resSlot.startTime.day(), awSlot.endTime.hour(), awSlot.endTime.minute(), 0);
                        // Use the the number of milliseconds since January 1, 1970, 00:00:00 GMT as the map key
                        Long key = awStartTime.getTime();
                        // Validate if the arrival window was already checked!
                        if (abSlotsMap.get(key) == null){
                            // Validate if the arrival window slot is valid based on availability
                            if (awSlot.isTimeWithinSlot(avStartTime, avEndTime, appointmentDurationInMinutes)){
                                // Create a new arrival window slot
                                sfsTimeSlot abSlot = new sfsTimeSlot(
                                    awStartTime,
                                    awEndTime,
                                    resSlot.grade,
                                    resourceId
                                );
                                abSlotsMap.put(key, abSlot);
                                srAWSlots.add(abSlot);
                            }
                        } else {
                            // Add existing arrival window slot to resource map
                            sfsTimeSlot abSlot = abSlotsMap.get(key);
                            abSlot.addResourceGrade(resourceId, resSlot.grade);
                            srAWSlots.add(abSlot);
                        }
                    }
                }
                // Store all arrival windows for the resource
                srIdToAWSlots.put(resourceId, srAWSlots);
            }

            sfsPerformanceMeasure.stop('DetermineValidArrivalWindows');

            // Sort slots by start time ascending
            abSlots = abSlotsMap.values();
            abSlots.sort();

        }

        sfsPerformanceMeasure.stop('getCandidateSlotsWithArrivalWindow');

        sfsPerformanceMeasure.debugResults();

        return abSlots;

    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the candidates method
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   schedulingPolicyId      Id of the scheduling policy used to retrieve time slots
     * @param   serviceAppointmentId    Id of the service appointment to retrieve time slots for
     * @return  Map<Id, sfsTimeSlot>    Map of Resource Id to Availability
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */        
    public static Map<Id, List<sfsTimeSlot>> getGradedMatrixSlots(Id schedulingPolicyId, Id serviceAppointmentId, String sortBy){

        sfsPerformanceMeasure.start('getGradedMatrixSlots');

        Map<Id, List<sfsTimeSlot>> srIdToTimeSlots = new Map<Id, List<sfsTimeSlot>>();

        FSL.GradeSlotsService gradedSlotService;
        FSL.AdvancedGapMatrix resultMatrix;
        Map<Id, FSL.ResourceScheduleData> slotsMap;

        sfsPerformanceMeasure.start('FSL.GradeSlotsService.getGradedMatrix');

        // See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_GradeSlotsService.htm
        gradedSlotService = new FSL.GradeSlotsService(schedulingPolicyId, serviceAppointmentId);  
        resultMatrix = gradedSlotService.getGradedMatrix(false);

        sfsPerformanceMeasure.stop('FSL.GradeSlotsService.getGradedMatrix');

        sfsPerformanceMeasure.start('ProcessGradedMatrixSlots');

        // Convert the time slots into a list of slots
        slotsMap = resultMatrix.resourceIDToScheduleData;

        if (!slotsMap.isEmpty()){
            for (Id resourceId : slotsMap.keySet()){
                List<sfsTimeSlot> timeSlots = new List<sfsTimeSlot>();
                List<FSL.schedulingOption> options = slotsMap.get(resourceId).SchedulingOptions;
                for (FSL.schedulingOption option : options){
                    timeSlots.add(
                        new sfsTimeSlot(
                            option.Interval.Start,
                            option.Interval.Finish,
                            option.Grade,
                            sortBy
                        )
                    );
                }
                timeSlots.sort();
                srIdToTimeSlots.put(resourceId, timeSlots);
            } 
        }

        sfsPerformanceMeasure.stop('ProcessGradedMatrixSlots');

        sfsPerformanceMeasure.stop('getGradedMatrixSlots');

        return srIdToTimeSlots;
    }    

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the book appointment method
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   schedulingPolicyId      Id of the scheduling policy used to retrieve time slots
     * @param   serviceAppointmentId    Id of the service appointment to retrieve time slots for
     * @param   operatingHoursId        Id of the operating hours representing the arrival windows
     * @return  List<sfsTimeSlots>      List of available time slots (arrival windows)
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static List<sfsTimeSlot> getAppointmentBookingSlots(Id serviceAppointmentId, Id schedulingPolicyId, Id operatingHoursId, TimeZone serviceTerritoryTimeZone, Boolean exactAppointments, String sortBy){

        sfsPerformanceMeasure.start('getAppointmentBookingSlots');

        List<sfsTimeSlot> timeSlots = new List<sfsTimeSlot>();

        List<FSL.AppointmentBookingSlot> bookingSlots;

        sfsPerformanceMeasure.start('FSL.AppointmentBookingService.getSlots');

        // See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_AppointmentBookingService.htm#apex_class_FSL_AppointmentBookingService
        bookingSlots = FSL.AppointmentBookingService.getSlots(serviceAppointmentId, schedulingPolicyId, operatingHoursId, serviceTerritoryTimeZone, exactAppointments);  

        sfsPerformanceMeasure.stop('FSL.AppointmentBookingService.getSlots');

        sfsPerformanceMeasure.start('ProcessAppointmentBookingSlots');

        // Convert the time slots into a list of slots
        if (!bookingSlots.isEmpty()){
            for (FSL.AppointmentBookingSlot bookingSlot : bookingSlots){
                timeSlots.add(
                    new sfsTimeSlot(
                        convertSlotDateTime(bookingSlot.interval.start, serviceTerritoryTimeZone),
                        convertSlotDateTime(bookingSlot.interval.finish, serviceTerritoryTimeZone),
                        bookingSlot.grade,
                        sortBy
                    )
                );
            }
        }

        timeSlots.sort();

        sfsPerformanceMeasure.stop('ProcessAppointmentBookingSlots');

        sfsPerformanceMeasure.stop('getAppointmentBookingSlots');

        sfsPerformanceMeasure.debugResults();

        return timeSlots;
    }    

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Schedule appointment using the provided scheduling policy that is part of complex work
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   schedulingPolicyId          Id of the scheduling policy used to retrieve time slots
     * @param   serviceAppointmentId        Id of the service appointment to retrieve time slots for
     * @return  List<FSL.ScheduleResult>    Scheduling results: see https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_ScheduleResult.htm#apex_class_FSL_ScheduleResult
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    public static List<FSL.ScheduleResult> scheduleAppointmentChain(Id serviceAppointmentId, Id schedulingPolicyId){

        sfsPerformanceMeasure.start('scheduleAppointmentChain');

        List<FSL.ScheduleResult> scheduleResults = FSL.ScheduleService.scheduleExtended(schedulingPolicyId, serviceAppointmentId);

        sfsPerformanceMeasure.stop('scheduleAppointmentChain');

        sfsPerformanceMeasure.debugResults();   

        return scheduleResults;     
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Schedule appointment using the provided scheduling policy
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   schedulingPolicyId      Id of the scheduling policy used to retrieve time slots
     * @param   serviceAppointmentId    Id of the service appointment to retrieve time slots for
     * @return  FSL.ScheduleResult      Scheduling results: see https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_ScheduleResult.htm#apex_class_FSL_ScheduleResult
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */ 
    public static FSL.ScheduleResult scheduleAppointment(Id serviceAppointmentId, Id schedulingPolicyId){

        sfsPerformanceMeasure.start('scheduleAppointment');
        // If appointment cannot be scheduled, the results are null!
        FSL.ScheduleResult scheduleResult = FSL.ScheduleService.schedule(schedulingPolicyId, serviceAppointmentId);

        sfsPerformanceMeasure.stop('scheduleAppointment');

        sfsPerformanceMeasure.debugResults();    

        return scheduleResult;
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve arrival time slots from a given operating hours record
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   operatingHoursId                        Id of the operating hours representing the arrival windows
     * @return  Map<String, List<arrivalWindowSlot>>    Map of day of the week to a list of arrival windows
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */      
    private static Map<String, List<arrivalWindowSlot>> getArrivalWindowTimeSlots(Id operatingHoursId){

        sfsPerformanceMeasure.start('getArrivalWindowTimeSlots');

        Map<String, List<arrivalWindowSlot>> dayToSlots = newMapOfDayToListOfArrivalWindows();

        List<Schema.TimeSlot> ohTimeSlots = [
            select 
                Id, 
                DayOfWeek,
                StartTime,
                EndTime,
                Type,
                OperatingHours.TimeZone
            from 
                TimeSlot
            where 
                OperatingHoursId = :operatingHoursId
            order by 
                DayOfWeek ASC,
                StartTime ASC
                    
        ];
        
        if (!ohTimeSlots.isEmpty()){
            TimeZone tz = TimeZone.getTimeZone(ohTimeSlots[0].OperatingHours.TimeZone);
            Integer tzOffSetInMs = tz.getOffset(System.now());
            for (Schema.TimeSlot slot : ohTimeSlots){
                List<arrivalWindowSlot> awSlots = dayToSlots.get(slot.DayOfWeek);
                awSlots.add(
                    new arrivalWindowSlot(
                        slot.StartTime, 
                        slot.StartTime.addMilliseconds(-tzOffSetInMs),
                        slot.EndTime,
                        slot.EndTime.addMilliseconds(-tzOffSetInMs)
                    )
                );
                dayToSlots.put(slot.DayOfWeek, awSlots);
            }
        }

        sfsPerformanceMeasure.stop('getArrivalWindowTimeSlots');

        return dayToSlots;
    }

    private static Map<String, List<arrivalWindowSlot>> newMapOfDayToListOfArrivalWindows(){
        return new Map<String, List<arrivalWindowSlot>>{
            'Monday' => new List<arrivalWindowSlot>(),
            'Tuesday' => new List<arrivalWindowSlot>(),
            'Wednesday' => new List<arrivalWindowSlot>(),
            'Thursday' => new List<arrivalWindowSlot>(),
            'Friday' => new List<arrivalWindowSlot>(),
            'Saturday' => new List<arrivalWindowSlot>(),
            'Sunday' => new List<arrivalWindowSlot>()
        };        
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Return day of the week in String of a DateTime
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   dt          Datetime value
     * @return  String      Day of the week (Monday, Tuesday, etc)
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */    
    private static String getDayOfWeek(DateTime dt){
        return dt.format('EEEE');
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Get the duration of the appointment in minutes. This is needed because the getGradedMatrix
     * method only returns the start time of the slot
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return   Decimal    Duration of the appointment in minutes
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */               
    private static Decimal getAppointmentDuration(Id serviceAppointmentId){
       
        sfsPerformanceMeasure.start('getAppointmentDuration');

        ServiceAppointment sa = [
            select
                Id,
                Duration,
                DurationType
            from 
                ServiceAppointment
            where 
                Id = :serviceAppointmentId
        ];

        sfsPerformanceMeasure.stop('getAppointmentDuration');

        return sa.DurationType == 'Minutes' ? sa.Duration : sa.Duration * 60;
    }  

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Convert the datetime from appointment booking into UTC
     * See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_AppointmentBookingService.htm#apex_class_FSL_AppointmentBookingService
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param    dt                         Datetime in UTC
     * @param    serviceTerritoryTimeZone   Datetime in UTC
     * @return   Datetime                   Datetime in UTC corrected by service territory timezone
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */               
    private static Datetime convertSlotDateTime(Datetime dt, TimeZone serviceTerritoryTimeZone){
        return dt.addSeconds(serviceTerritoryTimeZone.getOffset(dt) / -1000);
    }     
    
    /**
     * Structure for arrival window time slot
     */
    public class arrivalWindowSlot{
        public Time startTime;
        public Time startTimeGmt;
        public Time endTime;
        public Time endTimeGmt;
        public Integer durationInMinutes;

        public arrivalWindowSlot(Time startTime, Time startTimeGmt, Time endTime, Time endTimeGmt){
            this.startTime = startTime;
            this.startTimeGmt = startTimeGmt;
            this.endTime = endTime;
            this.endTimeGmt = endTimeGmt;
            this.durationInMinutes = arrivalWindowDurationInMinutes();
        }

        public Boolean isTimeWithinSlot(Time avStartTime, Time avEndTime, Integer appointmentDurationInMinutes){

            //System.debug('Availability: ' + avStartTime + ' - ' + avEndTime);
            //System.debug('Arrival Window Slot: ' + startTimeGmt + ' - ' + endTimeGmt);
            //System.debug('appointmentDurationInMinutes: ' + appointmentDurationInMinutes);
            
            // If availability starts after the arrival window end
            // or if availability ends before the arrival window start
            if (avStartTime >= endTimeGmt || avEndTime <= startTimeGmt){
                //System.debug('No availability within arrival window slot');
                return false;
            } else
            // If availability starts within the arrival window slot
            // and there is no time to complete the job before availability end
            if (avStartTime >= startTimeGmt && avStartTime <= endTimeGmt && avStartTime.addMinutes(appointmentDurationInMinutes) > avEndTime){
                //System.debug('Availability starts within arrival window slot, but no time to complete job before end of availability');
                return false;
            }

            //System.debug('Valid arrival window slot');
            return true;
        }

        private Integer arrivalWindowDurationInMinutes(){
            return (endTime.hour() * 60 + endTime.minute()) - (startTime.hour() * 60 + startTime.minute());
        }
    }    

    /**
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
    * Class store available time slots in a common format with the ability to sort
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
    */  
    public class sfsTimeSlot implements Comparable {
        // Start datetime of the time slot
        public Datetime startTime;
        // End datetime of the time slot
        public Datetime endTime;
        // Grade of the timeslot
        public Decimal grade;
        // Map of service resource Id to the grade of their slot
        public Map<Id, Decimal> resourceGrade;
        // Indicate which sorting direction is requested
        // Accepted values 'grade' and 'starttime'
        public String sortBy {
            get {
                if (sortBy == null) sortBy = 'grade';
                return sortBy;
            }
            set {
                sortBy = value.toLowerCase();
                if (sortby != 'grade' && sortBy != 'starttime'){
                    sortBy = 'grade';
                }
            }
        }

        // Constructor for basic arrival window with default sorting
        public sfsTimeSlot(Datetime startTime, Datetime endTime, Decimal grade) {
            this.startTime = startTime; 
            this.endTime = endTime; 
            this.grade = grade; 
        }

        // Constrcutor for basic arrival window with sorting
        public sfsTimeSlot(Datetime startTime, Datetime endTime, Decimal grade, String sortBy) {
            this.startTime = startTime; 
            this.endTime = endTime; 
            this.grade = grade; 
            this.sortBy = sortBy;
        }

        // Constructor for arrival window including a resource grade
        public sfsTimeSlot(Datetime startTime, Datetime endTime, Decimal grade, Id resourceId) {
            this.startTime = startTime; 
            this.endTime = endTime; 
            this.resourceGrade = new Map<Id, Decimal>{resourceId => grade};
            this.grade = grade;
        }    

        // Add a resource grade to existing time slots, highest grade is stored at time slot level
        public void addResourceGrade(Id resourceId, Decimal grade){
            this.resourceGrade.put(resourceId, grade);
            if (grade > this.grade) this.grade = grade;
        }

        /**
        * ───────────────────────────────────────────────────────────────────────────────────────────────┐
        * Implementation of the comparTo method for the Comparable interface. Sort by grade descending.
        * ────────────────────────────────────────────────────────────────────────────────────────────────
        * @param   comparTo    Object to compare current instance with
        * ───────────────────────────────────────────────────────────────────────────────────────────────┘
        */      
        public Integer compareTo(Object compareTo) {
            sfsTimeSlot compareToGrade = (sfsTimeSlot)compareTo;
            switch on sortBy.toLowerCase() {
                when 'starttime' {
                    if (startTime == compareToGrade.startTime) return 0;
                    if (startTime > compareToGrade.startTime) return 1;
                }
                when else {
                    if (grade == compareToGrade.grade) return 0;
                    if (grade < compareToGrade.grade) return 1;                        
                }
            }
            return -1;
        }           
    }    

}