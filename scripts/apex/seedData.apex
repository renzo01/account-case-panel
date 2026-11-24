// Sample data for the Account Case Panel challenge.
// Creates one Account with 12 Cases (every Status and Priority) and one empty Account.
Account withCases = new Account(Name = 'Acme Support (Challenge)', Industry = 'Technology');
Account emptyAccount = new Account(Name = 'Empty Account (Challenge)', Industry = 'Technology');
insert new List<Account>{ withCases, emptyAccount };

List<Case> cases = new List<Case>();
String[] statuses = new List<String>{ 'New', 'Working', 'Escalated', 'Closed' };
String[] priorities = new List<String>{ 'High', 'Medium', 'Low' };
String[] subjects = new List<String>{
    'Printer offline in the Lima office',
    'Password reset for the billing portal',
    'Invoice shows the wrong currency',
    'Login failure after SSO change',
    'Dashboard loads slowly',
    'Address change request',
    'Data loss after deployment',
    'Integration error with the ERP',
    'Resolved outage on the support line',
    'Resolved duplicate invoice',
    'Resolved typo on the quote template',
    'Escalated: customer waiting for a callback'
};

Integer index = 0;
for (String status : statuses) {
    for (String priority : priorities) {
        cases.add(new Case(
            AccountId = withCases.Id,
            Status = status,
            Priority = priority,
            Origin = 'Phone',
            Subject = subjects[index]
        ));
        index++;
    }
}
insert cases;

System.debug('Account with Cases: ' + withCases.Id);
System.debug('Empty Account: ' + emptyAccount.Id);
System.debug('Cases created: ' + cases.size());
