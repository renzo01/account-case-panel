public with sharing class CasePanelController {
    private static final Integer MAX_CASES = 50;
    private static final String CLOSED_STATUS = 'Closed';
    private static final String HIGH_PRIORITY = 'High';

    public class Counters {
        @AuraEnabled public Integer openCount = 0;
        @AuraEnabled public Integer closedCount = 0;
        @AuraEnabled public Integer openHighPriorityCount = 0;
    }

    public class PicklistOptions {
        @AuraEnabled public List<String> statuses = new List<String>();
        @AuraEnabled public List<String> priorities = new List<String>();
    }

    /**
     * Returns the 50 most recent Cases for an Account, newest first.
     * Not cacheable: the component must reload the list right after closing a Case,
     * and a cached response would bring the old Status back.
     */
    @AuraEnabled
    public static List<Case> getCases(Id accountId) {
        if (accountId == null) {
            return new List<Case>();
        }
        return [
            SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate
            FROM Case
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :MAX_CASES
        ];
    }

    /**
     * Aggregates every Case of the Account in a single query and splits
     * the result in memory: open, closed and open high priority.
     */
    @AuraEnabled(cacheable=true)
    public static Counters getCounters(Id accountId) {
        Counters result = new Counters();
        if (accountId == null) {
            return result;
        }

        for (AggregateResult row : [
            SELECT IsClosed, Priority, COUNT(Id) total
            FROM Case
            WHERE AccountId = :accountId
            WITH USER_MODE
            GROUP BY IsClosed, Priority
        ]) {
            Integer total = (Integer) row.get('total');
            Boolean isClosed = (Boolean) row.get('IsClosed');
            String priority = (String) row.get('Priority');

            if (isClosed) {
                result.closedCount += total;
            } else {
                result.openCount += total;
                if (priority == HIGH_PRIORITY) {
                    result.openHighPriorityCount += total;
                }
            }
        }
        return result;
    }

    /**
     * Reads the Status and Priority values from the org describe,
     * so nothing is hardcoded in the component.
     */
    @AuraEnabled(cacheable=true)
    public static PicklistOptions getPicklistOptions() {
        PicklistOptions options = new PicklistOptions();
        options.statuses = activeValuesFor(Case.Status);
        options.priorities = activeValuesFor(Case.Priority);
        return options;
    }

    /**
     * Closes a single Case. USER_MODE rejects the update when the running
     * user cannot edit the record or the Status field.
     */
    @AuraEnabled
    public static void closeCase(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('A Case id is required.');
        }

        List<Case> records = [
            SELECT Id, Status
            FROM Case
            WHERE Id = :caseId
            WITH USER_MODE
            LIMIT 1
        ];
        if (records.isEmpty()) {
            throw new AuraHandledException(
                'This Case no longer exists or you no longer have access to it.'
            );
        }

        Case record = records[0];
        record.Status = CLOSED_STATUS;

        try {
            Database.update(record, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            throw new AuraHandledException(buildFriendlyMessage(e));
        }
    }

    private static List<String> activeValuesFor(Schema.SObjectField field) {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    private static String buildFriendlyMessage(DmlException e) {
        if (e.getNumDml() > 0 && String.isNotBlank(e.getDmlMessage(0))) {
            return 'We could not close this Case: ' + e.getDmlMessage(0);
        }
        return 'We could not close this Case. Please try again.';
    }
}
