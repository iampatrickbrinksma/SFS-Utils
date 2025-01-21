/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * Class for retrieving time slots, candidates and scheduling actions
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * @author         Patrick Brinksma   <patrick@brinksma.es>
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
 */
public with sharing class sfsScheduling {

    public class sfsSchedulingException extends Exception {}

    // Performance measureing
    sfsPerformanceMeasure perf = new sfsPerformanceMeasure();
    // Service Appointment Id
    private Id saId;
    // Scheduling Policy Id
    private Id spId;
    // Operating Hours Id
    private Id ohId;
    // Sort slots by grade or starttime
    private String sortBy;
    // Indicator to use exact appointments or not
    private Boolean exactAppointments;

    // To keep track of the earliest slot start and latest slot end
    // to know the total horizon of the available time slots
    private Datetime earliestSlotStart;
    private Datetime latestSlotEnd;

    // Service Appointment Information
    private ServiceAppointment sa {
        get {
            if (sa == null) {
                try {
                    sa = [
                        select
                            Id,
                            Duration,
                            DurationType,
                            DurationInMinutes,
                            ServiceTerritoryId,
                            ServiceTerritory.OperatingHours.TimeZone        
                        from 
                            ServiceAppointment
                        where 
                            Id = :this.saId
                    ]; 
                } catch (Exception e) {
                    throw new sfsSchedulingException('Error while retrieving Service Appointment record with Id: ' + saId + ' ' + e.getTypeName() + ' ' + e.getMessage() + ' ' + e.getCause() + ' ' + e.getStackTraceString());
                }
            } 
            return sa;
        }
        private set;
    }   

    // Service appointment duration in minutes
    private Integer saDurationInMinutes {
        get {
            if (saDurationInMinutes == null) {
                saDurationInMinutes = Integer.valueOf(sa.DurationInMinutes);
            }
            return saDurationInMinutes;
        }
        private set;
    }

    // Timezone of the service appointment
    private TimeZone saTimeZone {
        get {
            if (saTimeZone == null) {
                if (sa.ServiceTerritoryId == null) {
                    saTimeZone = UserInfo.getTimeZone();
                } else {
                    saTimeZone = TimeZone.getTimeZone(sa.ServiceTerritory.OperatingHours.TimeZone);
                }
            }
            return saTimeZone;
        }
        private set;
    }

    // Constructor for scheduling
    public sfsScheduling(Id serviceAppointmentId, Id schedulingPolicyId) {
        this.saId = serviceAppointmentId;
        this.spId = schedulingPolicyId;
    }

    // Constructor for getting candidates
    public sfsScheduling(Id serviceAppointmentId, Id schedulingPolicyId, String sortBy) {
        this.saId = serviceAppointmentId;
        this.spId = schedulingPolicyId;
        this.sortBy = sortBy;
    }

    // Constructor for getting slots or combination of get candidates and get slots
    public sfsScheduling(Id serviceAppointmentId, Id schedulingPolicyId, Id operatingHoursId, Boolean exactAppointments, String sortBy) {
        this.saId = serviceAppointmentId;
        this.spId = schedulingPolicyId;
        this.ohId = operatingHoursId;
        this.exactAppointments = exactAppointments;
        this.sortBy = sortBy;
    }    

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve time zone of the service appointment
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  TimeZone    Time zone of the service appointment
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */            
    public TimeZone serviceAppointmentTimeZone {
        get {
            return this.saTimeZone;    
        }
        private set;
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the candidates method and map to arrival windows
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  List<sfsTimeSlot>   List of available time slots and for each time slot a list of resources
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */        
    public List<sfsTimeSlot> getCandidateSlotsWithArrivalWindow() {

        perf.start('getCandidateSlotsWithArrivalWindow');

        // Map of start time slot as Long (getTime()) and the arrival window slot
        Map<Long, sfsTimeSlot> abSlotsMap = new Map<Long, sfsTimeSlot>();
        List<sfsTimeSlot> abSlots;

        // Get available time slots using Candidates to retrieve resources + availability
        Map<Id, List<sfsTimeSlot>> srIdToTimeSlots = getGradedMatrixSlots();

        // If no slots were found, we're done
        if (!srIdToTimeSlots.isEmpty()) {

            // Get the arrival windows definition
            Map<String, List<arrivalWindowSlot>> dayToAWSlots = getArrivalWindowTimeSlots();
            
            perf.start('DetermineValidArrivalWindows');

            // Map of Resource Id to list of arrival windows
            Map<Id, List<sfsTimeSlot>> srIdToAWSlots = new Map<Id, List<sfsTimeSlot>>();

            /**
            * At this point you could filter out any resources by a custom mechanism
            */

            // Retrieve Service Resource details to add to the slot details
            perf.start('GetServiceResourceDetails');
            Map<Id, ServiceResource> srIdToSr = getServiceResourceDetails(srIdToTimeSlots.keySet());
            perf.stop('GetServiceResourceDetails');
            
            // Determine the valid arrival windows for all resources and availability
            for (Id resourceId : srIdToTimeSlots.keySet()) {
                // To store the list of valid arrival window slots for this resource
                List<sfsTimeSlot> srAWSlots = new List<sfsTimeSlot>();
                // List of availability slots for the resource
                List<sfsTimeSlot> resSlots = srIdToTimeSlots.get(resourceId);            
                // Check for every resource availability slot which arrival window slots are valid
                for (sfsTimeSlot resSlot : resSlots) {
                    // Get the arrival window slots for the day of availability
                    List<arrivalWindowSlot> awSlots = dayToAWSlots.get(getDayOfWeek(resSlot.startTime));
                    // Construct the start and end time of the resource's availability for comparison to the arrival window
                    Time avStartTime = Time.newInstance(resSlot.startTime.hour(), resSlot.startTime.minute(), 0, 0);
                    Time avEndTime = Time.newInstance(resSlot.endTime.hour(), resSlot.endTime.minute(), 0, 0);
                    // For every arrival window slot, validate if it's valid
                    for (arrivalWindowSlot awSlot : awSlots) {
                        // Construct the arrival window start and end including date
                        Datetime awStartDateTime = Datetime.newInstance(resSlot.startTime.year(), resSlot.startTime.month(), resSlot.startTime.day(), awSlot.startTime.hour(), awSlot.startTime.minute(), 0);
                        Datetime awEndDateTime = Datetime.newInstance(resSlot.startTime.year(), resSlot.startTime.month(), resSlot.startTime.day(), awSlot.endTime.hour(), awSlot.endTime.minute(), 0);
                        // Use the the number of milliseconds since January 1, 1970, 00:00:00 UTC as the map key
                        Long key = awStartDateTime.getTime();
                        // Validate if the arrival window was already checked!
                        if (abSlotsMap.get(key) == null) {
                            // Validate if the arrival window slot is valid based on availability
                            if (awSlot.isTimeWithinSlot(avStartTime, avEndTime, saDurationInMinutes)) {
                                // Create a new arrival window slot
                                sfsTimeSlot abSlot = new sfsTimeSlot(
                                    convertUTCDateTimeToSlot(awStartDateTime),    
                                    awStartDateTime,
                                    convertUTCDateTimeToSlot(awEndDateTime),
                                    awEndDateTime,
                                    resSlot.grade,
                                    resourceId
                                );
                                abSlot.addResourceGrade(srIdToSr.get(resourceId), resSlot);
                                abSlotsMap.put(key, abSlot);
                                srAWSlots.add(abSlot);
                            }
                        } else {
                            // Add existing arrival window slot to resource map
                            sfsTimeSlot abSlot = abSlotsMap.get(key);
                            abSlot.addResourceGrade(srIdToSr.get(resourceId), resSlot);
                            srAWSlots.add(abSlot);
                        }
                    }
                }
                // Store all arrival windows for the resource
                srIdToAWSlots.put(resourceId, srAWSlots);
            }

            perf.stop('DetermineValidArrivalWindows');

            // Sort slots by start time ascending
            abSlots = abSlotsMap.values();
            abSlots.sort();

        }

        perf.stop('getCandidateSlotsWithArrivalWindow');

        perf.debugResults();

        return abSlots;

    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the candidates method
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  Map<Id, sfsTimeSlot>    Map of Resource Id to Availability
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */        
    public Map<Id, List<sfsTimeSlot>> getGradedMatrixSlots() {

        perf.start('getGradedMatrixSlots');

        Map<Id, List<sfsTimeSlot>> srIdToTimeSlots = new Map<Id, List<sfsTimeSlot>>();

        FSL.GradeSlotsService gradedSlotService;
        FSL.AdvancedGapMatrix resultMatrix;
        Map<Id, FSL.ResourceScheduleData> slotsMap;

        perf.start('FSL.GradeSlotsService.getGradedMatrix');

        // See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_GradeSlotsService.htm
        gradedSlotService = new FSL.GradeSlotsService(this.spId, this.saId);  
        resultMatrix = gradedSlotService.getGradedMatrix(false);

        perf.stop('FSL.GradeSlotsService.getGradedMatrix');

        perf.start('ProcessGradedMatrixSlots');

        // Convert the time slots into a list of slots
        slotsMap = resultMatrix.resourceIDToScheduleData;

        if (!slotsMap.isEmpty()) {
            for (Id resourceId : slotsMap.keySet()) {
                List<sfsTimeSlot> timeSlots = new List<sfsTimeSlot>();
                List<FSL.schedulingOption> options = slotsMap.get(resourceId).SchedulingOptions;
                for (FSL.schedulingOption option : options) {
                    Datetime endTimeUTC = option.Interval.Start.addMinutes(saDurationInMinutes);
                    timeSlots.add(
                        new sfsTimeSlot(
                            convertUTCDateTimeToSlot(option.interval.start),
                            option.Interval.Start,

                            convertUTCDateTimeToSlot(endTimeUTC),
                            endTimeUTC,
                            option.Grade,
                            sortBy
                        )
                    );
                    // Determine the earliest slot start and latest slot end
                    if (earliestSlotStart == null) {
                        earliestSlotStart = option.Interval.Start;
                    } else if (option.Interval.Start < earliestSlotStart) {
                        earliestSlotStart = option.Interval.Start;
                    }
                    if (latestSlotEnd == null) {
                        latestSlotEnd = option.Interval.Finish;
                    } else if (option.Interval.Finish > latestSlotEnd) {
                        latestSlotEnd = option.Interval.Finish;
                    }
                }
                timeSlots.sort();
                srIdToTimeSlots.put(resourceId, timeSlots);
            } 
        }

        perf.stop('ProcessGradedMatrixSlots');

        perf.stop('getGradedMatrixSlots');

        return srIdToTimeSlots;
    }    

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the candidates method
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  Map<Id, sfsTimeSlot>    Map of Resource Id to Availability
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */        
    public Map<Id, List<sfsTimeSlot>> getGradedMatrixSlotsWithResourceName() {
        Map<Id, List<sfsTimeSlot>> slots = getGradedMatrixSlots();
        Map<Id, ServiceResource> srIdToSR = getServiceResourceDetails(slots.keySet());
        for (Id srId : slots.keySet()){
            List<sfsTimeSlot> timeSlots = slots.get(srId);
            for (sfsTimeSlot slot : timeSlots){
                slot.serviceResourceName = srIdtoSR.get(srId).Name;
            }
        }
        return slots;
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve available time slots using the book appointment method
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  List<sfsTimeSlots>      List of available time slots (arrival windows)
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public List<sfsTimeSlot> getAppointmentBookingSlots() {

        perf.start('getAppointmentBookingSlots');

        List<sfsTimeSlot> timeSlots = new List<sfsTimeSlot>();

        List<FSL.AppointmentBookingSlot> bookingSlots;

        perf.start('FSL.AppointmentBookingService.getSlots');

        // See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_AppointmentBookingService.htm#apex_class_FSL_AppointmentBookingService
        bookingSlots = FSL.AppointmentBookingService.getSlots(this.saId, this.spId, this.ohId, this.saTimeZone, this.exactAppointments);  

        perf.stop('FSL.AppointmentBookingService.getSlots');

        perf.start('ProcessAppointmentBookingSlots');

        // Convert the time slots into a list of slots
        if (!bookingSlots.isEmpty()) {
            for (FSL.AppointmentBookingSlot bookingSlot : bookingSlots) {
                timeSlots.add(
                    new sfsTimeSlot(
                        bookingSlot.interval.start,    
                        convertSlotDateTimeToUTC(bookingSlot.interval.start),
                        bookingSlot.interval.finish,
                        convertSlotDateTimeToUTC(bookingSlot.interval.finish),
                        bookingSlot.grade,
                        sortBy
                    )
                );
            }
        }

        timeSlots.sort();

        perf.stop('ProcessAppointmentBookingSlots');

        perf.stop('getAppointmentBookingSlots');

        perf.debugResults();

        return timeSlots;
    }   

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Schedule appointment using the provided scheduling policy that is part of complex work
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  List<FSL.ScheduleResult>    Scheduling results: see https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_ScheduleResult.htm#apex_class_FSL_ScheduleResult
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    public List<FSL.ScheduleResult> scheduleAppointmentChain() {

        perf.start('scheduleAppointmentChain');

        List<FSL.ScheduleResult> scheduleResults = FSL.ScheduleService.scheduleExtended(this.spId, this.saId);

        perf.stop('scheduleAppointmentChain');

        perf.debugResults();   

        return scheduleResults;     
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Schedule appointment using the provided scheduling policy
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  FSL.ScheduleResult      Scheduling results: see https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_ScheduleResult.htm#apex_class_FSL_ScheduleResult
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */ 
    public FSL.ScheduleResult scheduleAppointment() {

        perf.start('scheduleAppointment');
        // If appointment cannot be scheduled, the results are null!
        FSL.ScheduleResult scheduleResult = FSL.ScheduleService.schedule(this.spId, this.saId);

        perf.stop('scheduleAppointment');

        perf.debugResults();    

        return scheduleResult;
    }  

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Get Appointment Insights
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  sfsAppointmentInsightsResult     converted class from the output, see https://developer.salesforce.com/docs/atlas.en-us.252.0.field_service_dev.meta/field_service_dev/apex_class_FSL_AppointmentInsightsResult.htm
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */ 
    public sfsAppointmentInsights getAppointmentInsights() {

        perf.start('getAppointmentInsights');

        FSL.AppointmentInsightsResult appointmentInsightsResult = FSL.ScheduleService.getAppointmentInsights(this.spId, this.saId);
        sfsAppointmentInsights insights = new sfsAppointmentInsights(appointmentInsightsResult);
        perf.stop('getAppointmentInsights');

        perf.debugResults();    

        return insights;
    }      

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve arrival time slots from a given operating hours record
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  Map<String, List<arrivalWindowSlot>>    Map of day of the week to a list of arrival windows
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */      
    private Map<String, List<arrivalWindowSlot>> getArrivalWindowTimeSlots() {

        perf.start('getArrivalWindowTimeSlots');

        Map<String, List<arrivalWindowSlot>> dayToSlots = newMapOfDayToListOfArrivalWindows();

        List<Schema.TimeSlot> ohTimeSlots = [
            select 
                Id, 
                DayOfWeek,
                StartTime,
                EndTime,
                Type
            from 
                TimeSlot
            where 
                OperatingHoursId = :this.ohId
            order by 
                DayOfWeek ASC,
                StartTime ASC
                    
        ];
        
        if (!ohTimeSlots.isEmpty()) {
            Integer tzOffSetInMs = saTimeZone.getOffset(System.now());
            for (Schema.TimeSlot slot : ohTimeSlots) {
                List<arrivalWindowSlot> awSlots = dayToSlots.get(slot.DayOfWeek);
                awSlots.add(
                    new arrivalWindowSlot(
                        slot.StartTime, 
                        slot.StartTime.addMinutes(-tzOffSetInMs),
                        slot.EndTime,
                        slot.EndTime.addMinutes(-tzOffSetInMs)
                    )
                );
                dayToSlots.put(slot.DayOfWeek, awSlots);
            }
        }

        perf.stop('getArrivalWindowTimeSlots');

        return dayToSlots;
    }    

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Retrieve Service Resource details for the set of Service Resource Ids passed in
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   srIds                       Set of Service Resource Ids
     * @return  Map<Id, ServiceResource>    Map of Service Resource Ids to Service Resource records
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */     
    private Map<Id, ServiceResource> getServiceResourceDetails(Set<Id> srIds) {
        return new Map<Id, ServiceResource>([
            SELECT 
                Id, 
                Name, 
                RelatedRecordId
            FROM 
                ServiceResource
            WHERE 
                Id IN :srIds
        ]);

    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Return new instance of a Map of Day of the Week to new List of ArrivalWindowSlot
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  Map<String, List<arrivalWindowSlot>>    Map of Day of the Week to new List of ArrivalWindowSlot
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */    
    private Map<String, List<arrivalWindowSlot>> newMapOfDayToListOfArrivalWindows() {
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
     * Return new instance of a Map of Dates to new List of ArrivalWindowSlot
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @return  Map<Date, List<arrivalWindowSlot>>    Map of Date in UTC to new List of ArrivalWindowSlot
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */    
    private Map<Date, List<arrivalWindowSlot>> newMapOfDatesToListOfArrivalWindows() {
        Date startDate = earliestSlotStart.dateGMT().addDays(-1);
        Date endDate = latestSlotEnd.dateGMT().addDays(1);

        Map<Date, List<arrivalWindowSlot>> datesToSlots = new Map<Date, List<arrivalWindowSlot>>();
        for(Date currentDate = startDate; currentDate <= endDate; currentDate = currentDate.addDays(1)) {
            datesToSlots.put(currentDate, new List<arrivalWindowSlot>());
        }

        return datesToSlots;
    }    

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Return day of the week in String of a DateTime
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   dt          Datetime value
     * @return  String      Day of the week (Monday, Tuesday, etc)
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */    
    private String getDayOfWeek(DateTime dt) {
        return dt.format('EEEE');
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Return day of the week in String of a DateTime
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param   dt          Date value
     * @return  String      Day of the week (Monday, Tuesday, etc)
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */    
    private String getDayOfWeek(Date d) {
        Datetime dt = Datetime.newInstanceGmt(d.year(), d.month(), d.day());
        return dt.format('EEEE');
    }

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Convert the datetime from appointment booking into UTC
     * See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_class_FSL_AppointmentBookingService.htm#apex_class_FSL_AppointmentBookingService
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param    dt                         Datetime in time zone of the service territory
     * @return   Datetime                   Datetime in UTC corrected by service territory timezone
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */
    private Datetime convertSlotDateTimeToUTC(Datetime dt) {
        return dt.addSeconds(saTimeZone.getOffset(dt) / -1000);
    }     
    
    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Convert datetime into UTC based on provided time zone
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param    dt                         Datetime in time zone
     * @param    tz                         Time zone
     * @return   Datetime                   Datetime in UTC corrected by time zone
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */    
    public Datetime convertSlotDateTimeToUTC(Datetime dt, TimeZone tz) {
        return dt.addSeconds(tz.getOffset(dt) / -1000);
    }     

    /**
     * ───────────────────────────────────────────────────────────────────────────────────────────────┐
     * Convert the datetime from UTC to time zone
     * ────────────────────────────────────────────────────────────────────────────────────────────────  
     * @param    dt                         Datetime in UTC
     * @return   Datetime                   Datetime in service territory timezone
     * ───────────────────────────────────────────────────────────────────────────────────────────────┘
     */               
    private Datetime convertUTCDateTimeToSlot(Datetime dt) {
        return dt.addSeconds(saTimeZone.getOffset(dt) / 1000);
    }         

    /**
     * Structure for arrival window time slot
     */
    public class arrivalWindowSlot{
        public Time startTime;
        public Time startTimeUTC;
        public Time endTime;
        public Time endTimeUTC;
        public Integer durationInMinutes;

        public arrivalWindowSlot(Time startTime, Time endTime) {
            this.startTime = startTime;
            this.endTime = endTime;
            this.durationInMinutes = arrivalWindowDurationInMinutes();
        }        

        public arrivalWindowSlot(Time startTime, Time startTimeUTC, Time endTime, Time endTimeUTC) {
            this.startTime = startTime;
            this.startTimeUTC = startTimeUTC;
            this.endTime = endTime;
            this.endTimeUTC = endTimeUTC;
            this.durationInMinutes = arrivalWindowDurationInMinutes();
        }

        public Boolean isTimeWithinSlot(Time avStartTime, Time avEndTime, Integer appointmentDurationInMinutes) {

            System.debug('awStart: ' + startTimeUTC + '\nawEnd: ' + endTimeUTC + '\navStart: ' + avStartTime + '\navEnd: ' + avEndTime);

            Boolean isWithin = true;
            // If availability starts after the arrival window end
            // or if availability ends before the arrival window start
            if (avStartTime >= endTimeUTC || avEndTime <= startTimeUTC) {
                isWithin = false;
            // If availability starts within the arrival window slot
            // and there is no time to complete the job before availability end
            } else if (avStartTime >= startTimeUTC && avStartTime <= endTimeUTC && avStartTime.addMinutes(appointmentDurationInMinutes) > avEndTime) {
                isWithin = false;
            }
            System.debug('isWithin: ' + isWithin);
            return isWithin;
        }

        // Arrival window duration in minutes calculated from the start and end time of the slot
        private Integer arrivalWindowDurationInMinutes() {
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
        // Start datetime of the time slot in UTC
        public Datetime startTimeUTC;
        // End datetime of the time slot
        public Datetime endTime;
        // End datetime of the time slot in UTC
        public Datetime endTimeUTC;
        // Grade of the timeslot
        public Decimal grade;
        // Name of the Service Resource
        public String serviceResourceName;
        // Map of service resource Id to the grade of their slot
        public Map<Id, List<sfsResourceSlot>> resourceToSlots;
        // Indicate which sorting direction is requested
        // Accepted values 'grade' and 'starttime'
        public String sortBy {
            get {
                if (sortBy == null) sortBy = 'grade';
                return sortBy;
            }
            set {
                sortBy = value.toLowerCase();
                if (sortby != 'grade' && sortBy != 'starttime') {
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

        // Constrcutor for basic arrival window, inlcuding UTC, with sorting
        public sfsTimeSlot(Datetime startTime, Datetime startTimeUTC, Datetime endTime, Datetime endTimeUTC, Decimal grade, String sortBy) {
            this.startTime = startTime; 
            this.startTimeUTC = startTimeUTC;
            this.endTime = endTime; 
            this.endTimeUTC = endTimeUTC;
            this.grade = grade; 
            this.sortBy = sortBy;
        }        

        // Constructor for arrival window including a resource grade
        public sfsTimeSlot(ServiceResource sr, sfsTimeSlot slot) {
            this.startTime = slot.startTime; 
            this.endTime = slot.endTime; 
            sfsResourceSlot resSlot = new sfsResourceSlot(sr, slot.grade, slot.startTime, slot.startTimeUTC, slot.endTime, slot.endTimeUTC);
            List<sfsResourceSlot> resSlots = new List<sfsResourceSlot>{resSlot};
            this.resourceToSlots = new Map<Id, List<sfsResourceSlot>>{sr.Id => resSlots};
            this.grade = slot.grade;
        }    

        // Add a resource grade to existing time slots, highest grade is stored at time slot level
        public void addResourceGrade(ServiceResource sr, sfsTimeSlot slot) {
            sfsResourceSlot resSlot = new sfsResourceSlot(sr, slot.grade, slot.startTime, slot.startTimeUTC, slot.endTime, slot.endTimeUTC);
            if (this.resourceToSlots == null) this.resourceToSlots = new Map<Id, List<sfsResourceSlot>>();
            List<sfsResourceSlot> resSlots = this.resourceToSlots.get(sr.Id);
            if (resSlots == null) {
                resSlots = new List<sfsResourceSlot>();
            }
            resSlots.add(resSlot);
            this.resourceToSlots.put(sr.Id, resSlots);
            if (slot.grade > this.grade) this.grade = slot.grade;
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

    /**
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
    * Class store a resource time slot with start, end and grade
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
    */  
    private class sfsResourceSlot {

        public Id serviceResourceId;
        public String serviceResourceName;
        public Id userId;
        public Decimal grade;
        public Datetime startTime;
        public Datetime startTimeUTC;
        public Datetime endTime;
        public Datetime endTimeUTC;

        public sfsResourceSlot(ServiceResource sr, Decimal grade, Datetime startTime, Datetime startTimeUTC, Datetime endTime, Datetime endTimeUTC) {
            this.serviceResourceId = sr.Id;
            this.serviceResourceName = sr.Name;
            this.userId = sr.RelatedRecordId;
            this.grade = grade;
            this.startTime = startTime;
            this.endTime = endTime;
        }

    }

    /**
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
    * Class to represent the FSL.AppointmentInsightsResult output of FSL.ScheduleService.getAppointmentInsights method
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
    */      
    public class sfsAppointmentInsights {

        public Integer blockedSlots;
        public List<sfsBlockingRule> blockingRules;
        public Datetime horizonEndDate;
        public Datetime horizonStartDate;
        public Datetime operationStartTime;
        public Id schedulingPolicyId;
        public Integer resourcesEvaluated;
        public Id serviceAppointmentId;
        public Id serviceTerritoryId;

        public sfsAppointmentInsights(FSL.AppointmentInsightsResult result) {
            this.blockedSlots = result.blockedSlots;
            this.horizonEndDate = result.horizonEndDate;
            this.horizonStartDate = result.horizonStartDate;
            this.operationStartTime = result.operationStartTime;
            this.resourcesEvaluated = result.resourcesEvaluated;
            this.schedulingPolicyId = result.policyId;
            this.serviceAppointmentId = result.serviceAppointmentId;
            this.serviceTerritoryId = result.serviceTerritoryId;
            this.addBlockingRules(result.blockingRules);
        }

        private void addBlockingRules(List<FSL.AppointmentInsightsResult.BlockingRule> rules) {
            this.blockingRules = new List<sfsBlockingRule>();
            Map<String, sfsBlockingRule> rtNameToRule = new Map<String, sfsBlockingRule>();
            for (FSL.AppointmentInsightsResult.BlockingRule rule : rules) {
                rtNameToRule.put(rule.ruleName, new sfsBlockingRule(rule));
            }
            List<FSL__Scheduling_Policy_Work_Rule__c> policyRules = [
                SELECT 
                    FSL__Work_Rule__r.RecordType.DeveloperName,
                    FSL__Work_Rule__r.Name
                FROM 
                    FSL__Scheduling_Policy_Work_Rule__c
                WHERE 
                    FSL__Scheduling_Policy__c = :this.schedulingPolicyId 
                AND
                    FSL__Work_Rule__r.RecordType.DeveloperName IN :rtNameToRule.keySet()
            ];
            for (FSL__Scheduling_Policy_Work_Rule__c policyRule : policyRules) {
                sfsBlockingRule blockingRule = rtNameToRule.get(policyRule.FSL__Work_Rule__r.RecordType.DeveloperName);
                if (blockingRule != null) {
                    blockingRule.policyWorkRuleNames.add(policyRule.FSL__Work_Rule__r.Name);
                }
            }
            this.blockingRules.addAll(rtNameToRule.values());
        }

    }

    /**
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
    * Class to represent the FSL.AppointmentInsightsResult.BlockingRule output of FSL.ScheduleService.getAppointmentInsights method
    * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
    */          
    public class sfsBlockingRule {

        public String ruleName;
        public List<String> policyWorkRuleNames;
        public Integer slotsBlockedByMultipleRules;
        public Integer slotsBlockedByRule;

        public sfsBlockingRule(FSL.AppointmentInsightsResult.BlockingRule blockingRule){
            this.ruleName = blockingRule.ruleName;
            this.policyWorkRuleNames = new List<String>();
            this.slotsBlockedByMultipleRules = blockingRule.slotsBlockedByMultipleRules;
            this.slotsBlockedByRule = blockingRule.slotsBlockedByRule;
        }

    }

}