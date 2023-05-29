import { LightningElement, api, wire } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import SPNAME_FIELD from '@salesforce/schema/FSL__Scheduling_Policy__c.Name';

import clonePolicy from '@salesforce/apex/sfsSchedulingPolicyUtil.clonePolicy';

export default class SfsCloneSchedulingPolicy extends NavigationMixin(LightningElement) {

    @api recordId;

    fieldValues = {
        schedulingPolicyName: ''
    };

    showSpinner = false;

    @wire(getRecord, 
        { 
            recordId: '$recordId', 
            fields: [SPNAME_FIELD] 
        }
    )
    schedulingPolicy;  
    
    get policyName(){
        this.fieldValues.schedulingPolicyName = getFieldValue(this.schedulingPolicy.data, SPNAME_FIELD) + ' CLONE';
        return this.fieldValues.schedulingPolicyName;
    }

    handle_InputFieldChange(event){
        console.log(`Change event on ${event.target.name} with value ${event.detail.value}`);
        this.fieldValues[event.target.name] = event.detail.value;
        console.log('New value: ' + this.fieldValues[event.target.name]);
    }

    handle_ClonePolicy(){
        console.log('Cloning scheduling policy with id: ' + this.recordId + ' and new name: ' + this.fieldValues.schedulingPolicyName);
        this.showSpinner = true;
        clonePolicy(
            {
                schedulingPolicyId: this.recordId,
                policyName: this.fieldValues.schedulingPolicyName
            }
        )
        .then(result => {
            console.log('Scheduling Policy cloned successfully with Id: ' + result);
            this.showSpinner = false;
            this.closeQuickActionModal();
            this.showtToast('Cloning Scheduling Policy', 'Scheduling Policy cloned successfully!', 'success');
            this.navigateToRecord(result);

         })
         .catch(error => {
            console.log(this.formatErrors(error));
            this.showSpinner = false;
            this.showtToast('Cloning Scheduling Policy','An error occured during cloning: ' + this.formatErrors(error), 'error');
         });
    }

    handle_Cancel(){
        this.closeQuickActionModal();
    }

    closeQuickActionModal(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showtToast(title, msg, variant){
        let event = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant,
        });
        this.dispatchEvent(event);
    }    

    navigateToRecord(toRecordId){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: toRecordId,
                objectApiName: 'FSL__Scheduling_Policy__c',
                actionName: 'view'
            }
        });
    }

    formatErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }
    
        return (
            errors
                // Remove null/undefined items
                .filter((error) => !!error)
                // Extract an error message
                .map((error) => {
                    // UI API read errors
                    if (Array.isArray(error.body)) {
                        return error.body.map((e) => e.message);
                    }
                    // Page level errors
                    else if (
                        error?.body?.pageErrors &&
                        error.body.pageErrors.length > 0
                    ) {
                        return error.body.pageErrors.map((e) => e.message);
                    }
                    // Field level errors
                    else if (
                        error?.body?.fieldErrors &&
                        Object.keys(error.body.fieldErrors).length > 0
                    ) {
                        const fieldErrors = [];
                        Object.values(error.body.fieldErrors).forEach(
                            (errorArray) => {
                                fieldErrors.push(
                                    ...errorArray.map((e) => e.message)
                                );
                            }
                        );
                        return fieldErrors;
                    }
                    // UI API DML page level errors
                    else if (
                        error?.body?.output?.errors &&
                        error.body.output.errors.length > 0
                    ) {
                        return error.body.output.errors.map((e) => e.message);
                    }
                    // UI API DML field level errors
                    else if (
                        error?.body?.output?.fieldErrors &&
                        Object.keys(error.body.output.fieldErrors).length > 0
                    ) {
                        const fieldErrors = [];
                        Object.values(error.body.output.fieldErrors).forEach(
                            (errorArray) => {
                                fieldErrors.push(
                                    ...errorArray.map((e) => e.message)
                                );
                            }
                        );
                        return fieldErrors;
                    }
                    // UI API DML, Apex and network errors
                    else if (error.body && typeof error.body.message === 'string') {
                        return error.body.message;
                    }
                    // JS errors
                    else if (typeof error.message === 'string') {
                        return error.message;
                    }
                    // Unknown error shape so try HTTP status text
                    return error.statusText;
                })
                // Flatten
                .reduce((prev, curr) => prev.concat(curr), [])
                // Remove empty strings
                .filter((message) => !!message)
        );
    }
    

}