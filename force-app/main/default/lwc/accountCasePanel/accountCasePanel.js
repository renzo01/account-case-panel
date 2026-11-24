import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getCases from '@salesforce/apex/CasePanelController.getCases';
import getCounters from '@salesforce/apex/CasePanelController.getCounters';
import getPicklistOptions from '@salesforce/apex/CasePanelController.getPicklistOptions';
import closeCase from '@salesforce/apex/CasePanelController.closeCase';
import { reduceErrors } from 'c/errorUtils';

const COLUMNS = [
    {
        label: 'Case Number',
        fieldName: 'caseUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'CaseNumber' },
            target: '_self'
        }
    },
    { label: 'Subject', fieldName: 'Subject', type: 'text', wrapText: true },
    { label: 'Status', fieldName: 'Status', type: 'text' },
    { label: 'Priority', fieldName: 'Priority', type: 'text' },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Close Case', name: 'close' }]
        }
    }
];

const EMPTY_COUNTERS = { openCount: 0, closedCount: 0, openHighPriorityCount: 0 };

export default class AccountCasePanel extends LightningElement {
    columns = COLUMNS;
    cases = [];
    counters = EMPTY_COUNTERS;
    statusOptions = [];
    priorityOptions = [];
    statusFilter = '';
    priorityFilter = '';
    isLoading = false;
    errorMessage = '';

    _recordId;
    _wiredCounters;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadCases();
        }
    }

    @wire(getCounters, { accountId: '$recordId' })
    wiredCounters(result) {
        this._wiredCounters = result;
        if (result.data) {
            this.counters = result.data;
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = reduceErrors(result.error);
        }
    }

    @wire(getPicklistOptions)
    wiredOptions({ data, error }) {
        if (data) {
            this.statusOptions = this.toOptions('All statuses', data.statuses);
            this.priorityOptions = this.toOptions('All priorities', data.priorities);
        } else if (error) {
            this.errorMessage = reduceErrors(error);
        }
    }

    get openCount() {
        return this.counters.openCount;
    }

    get closedCount() {
        return this.counters.closedCount;
    }

    get openHighPriorityCount() {
        return this.counters.openHighPriorityCount;
    }

    get filteredCases() {
        return this.cases.filter((record) => {
            const matchesStatus = !this.statusFilter || record.Status === this.statusFilter;
            const matchesPriority = !this.priorityFilter || record.Priority === this.priorityFilter;
            return matchesStatus && matchesPriority;
        });
    }

    get hasCases() {
        return this.cases.length > 0;
    }

    get hasFilteredCases() {
        return this.filteredCases.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.hasFilteredCases;
    }

    get emptyTitle() {
        return this.hasCases ? 'No Cases match your filters' : 'No Cases for this Account yet';
    }

    get emptyMessage() {
        return this.hasCases
            ? 'Try clearing the Status or Priority filter.'
            : 'When a Case is created for this Account it will show up here.';
    }

    get hasActiveFilters() {
        return Boolean(this.statusFilter || this.priorityFilter);
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    async loadCases() {
        if (!this._recordId) {
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await getCases({ accountId: this._recordId });
            this.cases = result.map((record) => ({
                ...record,
                caseUrl: `/lightning/r/Case/${record.Id}/view`
            }));
        } catch (error) {
            this.cases = [];
            this.errorMessage = reduceErrors(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
    }

    handlePriorityChange(event) {
        this.priorityFilter = event.detail.value;
    }

    clearFilters() {
        this.statusFilter = '';
        this.priorityFilter = '';
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName !== 'close') {
            return;
        }
        if (row.Status === 'Closed') {
            this.showToast('Already closed', `Case ${row.CaseNumber} is already closed.`, 'info');
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Close Case',
            message: `Close Case ${row.CaseNumber} — “${row.Subject || 'No subject'}”? This action changes its Status to Closed.`,
            theme: 'warning',
            variant: 'headerless'
        });

        if (!confirmed) {
            return;
        }
        await this.closeCase(row);
    }

    async closeCase(row) {
        this.isLoading = true;
        try {
            await closeCase({ caseId: row.Id });
            await this.loadCases();
            if (this._wiredCounters) {
                await refreshApex(this._wiredCounters);
            }
            this.showToast('Case closed', `Case ${row.CaseNumber} was closed successfully.`, 'success');
        } catch (error) {
            this.errorMessage = '';
            this.showToast('We could not close the Case', reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRetry() {
        this.errorMessage = '';
        await this.loadCases();
        if (this._wiredCounters) {
            await refreshApex(this._wiredCounters);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    toOptions(emptyLabel, values) {
        return [{ label: emptyLabel, value: '' }].concat(
            (values || []).map((value) => ({ label: value, value }))
        );
    }
}
