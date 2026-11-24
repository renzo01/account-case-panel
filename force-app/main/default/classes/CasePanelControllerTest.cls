@IsTest
private class CasePanelControllerTest {
    private static final String STATUS_NEW = 'New';
    private static final String STATUS_WORKING = 'Working';
    private static final String STATUS_ESCALATED = 'Escalated';
    private static final String STATUS_CLOSED = 'Closed';
    private static final String PRIORITY_HIGH = 'High';
    private static final String PRIORITY_MEDIUM = 'Medium';
    private static final String PRIORITY_LOW = 'Low';

    @TestSetup
    static void setupData() {
        Account withCases = new Account(Name = 'Acme Support');
        Account withoutCases = new Account(Name = 'Empty Account');
        insert new List<Account>{ withCases, withoutCases };

        List<Case> cases = new List<Case>();
        cases.add(buildCase(withCases.Id, STATUS_NEW, PRIORITY_HIGH, 'Printer offline'));
        cases.add(buildCase(withCases.Id, STATUS_NEW, PRIORITY_MEDIUM, 'Password reset'));
        cases.add(buildCase(withCases.Id, STATUS_NEW, PRIORITY_LOW, 'Billing question'));
        cases.add(buildCase(withCases.Id, STATUS_WORKING, PRIORITY_HIGH, 'Login failure'));
        cases.add(buildCase(withCases.Id, STATUS_WORKING, PRIORITY_MEDIUM, 'Slow dashboard'));
        cases.add(buildCase(withCases.Id, STATUS_WORKING, PRIORITY_LOW, 'Address change'));
        cases.add(buildCase(withCases.Id, STATUS_ESCALATED, PRIORITY_HIGH, 'Data loss'));
        cases.add(buildCase(withCases.Id, STATUS_ESCALATED, PRIORITY_MEDIUM, 'Integration error'));
        cases.add(buildCase(withCases.Id, STATUS_CLOSED, PRIORITY_HIGH, 'Resolved outage'));
        cases.add(buildCase(withCases.Id, STATUS_CLOSED, PRIORITY_MEDIUM, 'Resolved invoice'));
        cases.add(buildCase(withCases.Id, STATUS_CLOSED, PRIORITY_LOW, 'Resolved typo'));
        insert cases;

        Test.setCreatedDate(cases[0].Id, Datetime.now().addDays(-9));
        Test.setCreatedDate(cases[1].Id, Datetime.now().addDays(-8));
        Test.setCreatedDate(cases[2].Id, Datetime.now().addDays(-7));
        Test.setCreatedDate(cases[3].Id, Datetime.now().addDays(-6));
        Test.setCreatedDate(cases[4].Id, Datetime.now().addDays(-5));
    }

    @IsTest
    static void returnsCasesNewestFirst() {
        Account account = getAccountWithCases();

        Test.startTest();
        List<Case> result = CasePanelController.getCases(account.Id);
        Test.stopTest();

        System.assertEquals(11, result.size(), 'All Cases of the Account should be returned');
        for (Integer i = 1; i < result.size(); i++) {
            System.assert(
                result[i - 1].CreatedDate >= result[i].CreatedDate,
                'Cases must be ordered newest first'
            );
        }
    }

    @IsTest
    static void returnsOnlyCasesFromTheRequestedAccount() {
        Account empty = [SELECT Id FROM Account WHERE Name = 'Empty Account' LIMIT 1];

        Test.startTest();
        List<Case> result = CasePanelController.getCases(empty.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'The empty Account should return no Cases');
    }

    @IsTest
    static void returnsEmptyListForNullAccount() {
        Test.startTest();
        List<Case> result = CasePanelController.getCases(null);
        CasePanelController.Counters counters = CasePanelController.getCounters(null);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'A null Account should return an empty list');
        System.assertEquals(0, counters.openCount, 'Open counter should be zero');
        System.assertEquals(0, counters.closedCount, 'Closed counter should be zero');
        System.assertEquals(0, counters.openHighPriorityCount, 'High priority counter should be zero');
    }

    @IsTest
    static void limitsTheListToFiftyCases() {
        Account bulkAccount = new Account(Name = 'Bulk Account');
        insert bulkAccount;

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 55; i++) {
            cases.add(buildCase(bulkAccount.Id, STATUS_NEW, PRIORITY_MEDIUM, 'Bulk case ' + i));
        }
        insert cases;

        Test.startTest();
        List<Case> result = CasePanelController.getCases(bulkAccount.Id);
        Test.stopTest();

        System.assertEquals(50, result.size(), 'The component must not load more than 50 Cases');
    }

    @IsTest
    static void countersIgnoreFiltersAndSplitByStatus() {
        Account account = getAccountWithCases();

        Test.startTest();
        CasePanelController.Counters counters = CasePanelController.getCounters(account.Id);
        Test.stopTest();

        System.assertEquals(8, counters.openCount, 'Open Cases should exclude the three closed ones');
        System.assertEquals(3, counters.closedCount, 'Closed Cases should match the seeded data');
        System.assertEquals(4, counters.openHighPriorityCount, 'Open high priority Cases should be four');
    }

    @IsTest
    static void picklistOptionsComeFromTheOrg() {
        Test.startTest();
        CasePanelController.PicklistOptions options = CasePanelController.getPicklistOptions();
        Test.stopTest();

        System.assert(options.statuses.size() > 0, 'Status values should be read from the describe');
        System.assert(options.priorities.size() > 0, 'Priority values should be read from the describe');
        System.assert(options.statuses.contains(STATUS_NEW), 'Status values should include New');
        System.assert(options.priorities.contains(PRIORITY_HIGH), 'Priority values should include High');
    }

    @IsTest
    static void closingACaseUpdatesStatusAndCounters() {
        Account account = getAccountWithCases();
        Case openCase = [
            SELECT Id
            FROM Case
            WHERE AccountId = :account.Id AND Status != :STATUS_CLOSED AND Priority = :PRIORITY_HIGH
            LIMIT 1
        ];

        CasePanelController.Counters beforeCounters = CasePanelController.getCounters(account.Id);

        Test.startTest();
        CasePanelController.closeCase(openCase.Id);
        Test.stopTest();

        Case updated = [SELECT Status FROM Case WHERE Id = :openCase.Id];
        CasePanelController.Counters afterCounters = CasePanelController.getCounters(account.Id);

        System.assertEquals(STATUS_CLOSED, updated.Status, 'The Case should be closed');
        System.assertEquals(
            beforeCounters.openCount - 1,
            afterCounters.openCount,
            'Open counter should decrease by one'
        );
        System.assertEquals(
            beforeCounters.closedCount + 1,
            afterCounters.closedCount,
            'Closed counter should increase by one'
        );
        System.assertEquals(
            beforeCounters.openHighPriorityCount - 1,
            afterCounters.openHighPriorityCount,
            'Open high priority counter should decrease by one'
        );
    }

    @IsTest
    static void closingACaseWithoutIdFailsWithFriendlyMessage() {
        Test.startTest();
        try {
            CasePanelController.closeCase(null);
            System.assert(false, 'An AuraHandledException was expected');
        } catch (AuraHandledException e) {
            System.assertEquals('A Case id is required.', e.getMessage(), 'The error should be readable');
        }
        Test.stopTest();
    }

    private static Account getAccountWithCases() {
        return [SELECT Id FROM Account WHERE Name = 'Acme Support' LIMIT 1];
    }

    private static Case buildCase(Id accountId, String status, String priority, String subject) {
        return new Case(
            AccountId = accountId,
            Status = status,
            Priority = priority,
            Subject = subject,
            Origin = 'Phone'
        );
    }
}
