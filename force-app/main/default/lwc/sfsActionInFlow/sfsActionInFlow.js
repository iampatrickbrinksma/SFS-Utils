import { LightningElement, api } from 'lwc';

export default class SfsActionInFlow extends LightningElement {

    @api
    recordId;

    @api
    frameWidth = '100%';

    @api
    frameHeight = 550;

    @api
    sfsAction = 'Appointment Booking';

    _actionOptions = {
        'Appointment Booking': 'FSL__AppointmentBookingVf',
        'Candidates': 'FSL__GetCandidates',
        'Emergency': 'FSL__EmergencyWizard'
    }

    get frameSrc(){
        return `/apex/${this._actionOptions[this.sfsAction]}?Id=${this.recordId}`;
    }

    get frameStyle(){
        return `border:0px;width:${this.frameWidth};height:${this.frameHeight}px;`;
    }

}