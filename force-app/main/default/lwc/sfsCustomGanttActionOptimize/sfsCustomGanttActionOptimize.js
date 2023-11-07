import { LightningElement, api, wire } from 'lwc';

// GraphQL support
import { gql, graphql } from "lightning/uiGraphQLApi";

// User Id
import userId from "@salesforce/user/Id";

// Schema
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import SA_OBJECT from "@salesforce/schema/ServiceAppointment";

// Apex Method
import startOptimization from "@salesforce/apex/sfsCustomGanttActionOptimize.startOptimization";

// Custom Labels
import customLabels from "./customLabels";

export default class SfsCustomGanttActionOptimize extends LightningElement {

    // URL GET parameters passed to the LWC from the Visualforce page
    // These parameters are provided by the Custom Gantt Actions
    // See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/fsl_dev_code_samples_dispatcher.htm
    // For this component only "start" and "end" are actually used
    @api recordId;
    @api services;
    @api stm;
    @api type;
    @api start;
    @api end;

    // Custom Settings properties passed to the LWC from the Visualforce page
    // to control the behaviour of the component
    @api schedulingPolicy;
    @api filterByFieldApiName;
    @api filterByFieldsApiNames;
    @api disableAllTaskMode;

    // Custom labels
    LABELS = customLabels;    

    // Service Appointment Object Information
    // Used to retrieve the object's label and if a filter by field is provided the field label
    saObjectInfo;

    // Default option for the AllTaskMode
    allTaskModeOption = 'true';

    // The properties "start" and "end" are passed in String format (MM-DD-YYYY)
    // so we convert them and store them in this object for easy access
    dateRange = [];

    // GraphQL query resuls
    _policyResult;
    _stResult;

    // Scheduling Policy combobox
    policyOptions = [];
    policyId;
    _policyInday = [];

    // Service Territories checkbox group
    stOptions = [];

    // filter by field value
    filterByField;
    filterByFieldDisabled = false;

    // Loading spinner
    showSpinner = false;

    // Error handling
    // Using the ldsUtils and errorPanel from the LWC-Recipes
    // See https://github.com/trailheadapps/lwc-recipes
    errors;
    errorFriendlyMsg = this.LABELS.lblFriendlyErrorMsg;
    disableTryAgain = false;

    connectedCallback(){
        // Convert string to Date for date pickers
        this.dateRange.startDate = this.convertStringToDate(this.start);
        this.dateRange.endDate = this.convertStringToDate(this.end);
    }   

    // Retrieve object info for Service Appointment object
    @wire(getObjectInfo, { objectApiName: SA_OBJECT })
    SetObjectInfo(result){
        const { data, errors } = result;
        if (data){
            this.saObjectInfo = data;
            // If the Filter By checkbox field provided via a custom setting does not exist, throw error
            if (this.filterByFieldApiName !== undefined && this.filterByFieldApiName !== ''){
                if (this.saObjectInfo.fields[this.filterByFieldApiName]?.label === undefined){
                    this.disableTryAgain = true;
                    this.errors = new Error( this.LABELS.lblFilterFieldErrorMsg.replace('$1', this.filterByFieldApiName).replace('$2', this.saObjectInfo.label) );
                // If the Filter By checkbox field provided via a custom setting is not a checkbox
                } else if (this.saObjectInfo.fields[this.filterByFieldApiName].dataType !== 'Boolean'){
                    this.disableTryAgain = true;
                    this.errors = new Error( this.LABELS.lblFilterFieldTypeErrorMsg.replace('$1', this.filterByFieldApiName).replace('$2', this.saObjectInfo.label) );
                }
            }
        } else if (errors) {
            this.errors = errors;
        }
    };

    get filterByFieldsLabel(){
        if (this.saObjectInfo)
            return this.LABELS.lblFilterFields.replace('$1', this.saObjectInfo.label);
    }

    get filterByFields(){
        if (this.saObjectInfo){
            if (typeof this.filterByFieldApiName === 'string' && this.filterByFieldApiName.length > 0){
                this.filterByField = this.filterByFieldApiName;
                this.filterByFieldDisabled = true;
                return [ { label: this.saObjectInfo.fields[this.filterByFieldApiName].label, value: this.filterByFieldApiName } ];
            } else if (this.filterByFieldsApiNames === undefined || this.filterByFieldsApiNames === '') return;
            const fields = this.filterByFieldsApiNames.split(',');
            if (fields.length > 0){
                // Validate if fields exist
                const validatedFields = [];
                fields.forEach((field) => {
                    if (this.saObjectInfo.fields[field] && this.saObjectInfo.fields[field].dataType === 'Boolean'){
                        validatedFields.push( { label: this.saObjectInfo.fields[field].label, value: field } );
                    }
                });
                return validatedFields;
            }
        }
    }

    // AllTaskMode combobox options
    get allTaskModeOptions(){
        return [
            { label: this.LABELS.lblAll, value: 'true' },
            { label: this.LABELS.lblUnscheduled, value: 'false' }
        ];
    }

    // Capture AllTaskMode combobox update
    handleAllTaskModeChange(event){
        this.allTaskModeOption = event.detail.value;
    }    

    // Return true if AllTaskMode combobox was set to "All"
    get allTaskMode(){
        return this.allTaskModeOption === 'true';
    }

    // Wire for Service Territory data
    // The Dispatcher Console user settings are used to determine which STs are visible on the Gantt
    @wire(graphql, {
        query: gql`
            query ServiceTerritoryQry($userId: ID) {
                uiapi {
                    query {
                        FSL__User_Setting_Territory__c( 
                            where: { FSL__User_Setting__r: { FSL__User__c: { eq: $userId} } },    
                            orderBy: { FSL__Service_Territory__r: { Name: { order: ASC } } }
                                
                            ) {
                            edges {
                                node {
                                    FSL__Service_Territory__r {
                                        Id
                                        Name {
                                            value
                                        }
                                        FSL__O2_Enabled__c {
                                            value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }            
        `,
        variables: "$stVars"
    })
    STQueryResults( result ) {
        const { data, errors } = result;
        // Build object that contains the ST information
        // The "checked" property is to keep track which checkboxes are checked
        const _stOptions = [];
        if (data){
            data.uiapi.query.FSL__User_Setting_Territory__c.edges.map((edges) => {
                let stName = edges.node.FSL__Service_Territory__r.Name.value + (edges.node.FSL__Service_Territory__r.FSL__O2_Enabled__c.value === true ? ' *' : '');
                _stOptions.push( 
                    { 
                        label: stName,
                        value: edges.node.FSL__Service_Territory__r.Id,
                        o2: edges.node.FSL__Service_Territory__r.FSL__O2_Enabled__c.value,
                        checked: false
                    }
                )
            });
            this.stOptions = _stOptions;
        }
        if (errors){
            this.errors = errors;
        }
        this._stResult = result;
    }     
    
    // Variables for the GraphQL query
    get stVars(){
        return {
            userId: userId
        }
    }

    // When a service territory checkbox is updated
    handleSTChange(event){
        const _stOptions = this.stOptions.map((element) => {
            if (element.value === event.target.name){
                element.checked = event.target.checked;
            }
            return element;
        });
        this.stOptions = _stOptions;
    }

    // From the service territory checkbox options object
    // return the service territory ids which have been selected
    get stIds(){
        let _stIds = [];
        this.stOptions.forEach((element) => {
            if (element.checked) _stIds.push(element.value);
        });
        return _stIds;
    }

    // Wire for Scheduling Policy data
    @wire(graphql, {
        query: gql`
            query SchedulingPolicyQry {
                uiapi {
                    query {
                        FSL__Scheduling_Policy__c (
                            orderBy: { Name: { order: ASC } }
                        ) {
                            edges {
                                node {
                                    Id
                                    Name {
                                        value
                                    }
                                    FSL__Daily_Optimization__c {
                                        value
                                    }
                                }
                            }
                        }
                    }
                }
            }            
        `,
    })
    PolicyQueryResults( result ) {
        const { data, errors } = result;
        // Build the combobox options
        const _policyOptions = [];
        if (data){
            data.uiapi.query.FSL__Scheduling_Policy__c.edges.map((edges) => {
                _policyOptions.push( { label: edges.node.Name.value, value: edges.node.Id } );
                // If a default scheduling policy name was provided via custom setting
                // make sure that one is the selected one
                if (edges.node.Name.value.toLowerCase() === this.schedulingPolicy.toLowerCase()){
                    this.policyId = edges.node.Id;
                }
                // Keep track of which policy is an In Day optimization policy
                this._policyInday[edges.node.Id] = edges.node.FSL__Daily_Optimization__c.value;
            });
            // If the default policy provided was not found, throw an error
            if(this.schedulingPolicyDisabled && this.policyId === undefined){
                this.disableTryAgain = true;
                this.errors = new Error( this.LABELS.lblPolicyMissingErrorMsg.replace('$1', this.schedulingPolicy) );
            // If no default policy was provided, make sure the first one is selected
            } else if (!this.policyId && Object.keys(_policyOptions).length > 0){
                this.policyId = _policyOptions[Object.keys(_policyOptions)[0]].value;
            }
            this.policyOptions = _policyOptions;
        }
        if (errors){
            this.errors = errors;
        }
        this._policyResult = result;
    }    

    // Return if the scheduling policy is an In-Day Optimization policy
    get inDayEnabled(){
        return this._policyInday[this.policyId];
    }

    // Disable the scheduling policy combobox if a default policy
    // was provided via the custom setting
    get schedulingPolicyDisabled(){
        return this.schedulingPolicy !== '';
    }

    // When policy combobox is updated
    handlePolicyChange(event){
        this.policyId = event.detail.value;
    }    

    // When one of the date pickers is updated
    handleDateRange(event){
        this.dateRange[event.target.name] = event.detail.value;
    }

    // Start optimization
    handleOptimize(){
        console.log(this.filterByField);
        // Throw error if no service territories were selected
        if (this.stIds === undefined || this.stIds.length === 0){
            this.errors = new Error( this.LABELS.lblServiceTerritoryErrorMsg );
            return;
        } else if ((this.dateRange.startDate === undefined || this.dateRange.startDate instanceof Date) || 
            (this.dateRange.endDate === undefined || this.dateRange.endDate instanceof Date))
        {
            this.errors = new Error( this.LABELS.lblDateRangeErrorMsg );
            return;    
        } else {
            if (this.dateRange.startDate > this.dateRange.endDate){
                this.errors = new Error( this.LABELS.lblDateRangeErrorMsg );
                return;                    
            }
        }
        // Call Apex method to start Optimization
        this.showSpinner = true;
        startOptimization({
            serviceTerritoryIds: this.stIds,
            schedulingPolicyId: this.policyId,
            startDate: this.dateRange.startDate,
            endDate: this.dateRange.endDate,
            allTasksMode: this.allTaskMode, 
            filterByFieldApiName: this.filterByField
        })
        .then((result) => {
            // Once optimization is started, close the Custom Gantt Action modal
            this.closeModal(result);
        })
        .catch((error) => {
            this.errors = error;
        })
        .finally(() => {
            this.showSpinner = false;
        });
    }

    // Dispatch an event to have the Visualforce page close the customt gantt action modal
    closeModal(details){
        this.dispatchEvent(
            new CustomEvent(
                'closeganttmodal',
                {
                    detail: details
                }
            )
        );        
    }

    // When the Try Again button is available and clicked
    handleClearError(){
        this.errors = undefined;
        this.errorFriendlyMsg = this.LABELS.lblFriendlyErrorMsg;
    }

    // Convert string into a date, format is MM-DD-YYYY
    // Return the ISO String for the date pickers
    convertStringToDate(dateString){
        const dateParts = dateString.split('-');
        let dt = new Date(parseInt(dateParts[2]), parseInt(dateParts[0]) - 1, parseInt(dateParts[1]));
        return dt.toISOString();
    }

}