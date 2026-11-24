# Account Case Panel — Salesforce LWC Technical Challenge

Lightning Web Component for the Account record page that lists, summarizes, filters and closes the Account's Cases.

## What it does

- **Counters** (R3): open, closed and open high-priority totals for the whole Account. They ignore the filters and refresh after a Case is closed.
- **Case list** (R2): `lightning-datatable` with Case Number, Subject, Status, Priority and Created Date, newest first. The Case Number opens the record. Maximum 50 rows.
- **Filters** (R4): Status and Priority built from the org describe — no hardcoded values. Filtering happens in the browser, without a reload.
- **Close a Case** (R5): row action, confirmation dialog, Status set to `Closed`, toast, and both list and counters refreshed.
- **States** (R6): spinner while loading, empty state, readable error message with a Retry button.

## Project structure

```
force-app/main/default/
├── classes/
│   ├── CasePanelController.cls          # Apex API: cases, counters, picklists, close
│   └── CasePanelControllerTest.cls      # Real assertions, bulk and edge cases
└── lwc/
    ├── accountCasePanel/                # LWC bundle (record page target)
    └── errorUtils/                      # Shared error message helper
scripts/apex/seedData.apex               # Sample data for the demo
```

## Setup

```bash
# 1. Authenticate a Developer Edition org
sf org login web --alias case-panel --set-default

# 2. Deploy
sf project deploy start --source-dir force-app

# 3. Run the tests
sf apex run test --tests CasePanelControllerTest --result-format human --wait 10

# 4. Load sample data (prints the two Account ids)
sf apex run --file scripts/apex/seedData.apex

# 5. Add the component
#    Account record page → Edit Page → drag "Account Case Panel" → Save → Activate
```

## Key decisions

1. **Apex for data, browser for filtering.** The component loads at most 50 Cases once; filters run in memory. One query instead of one per filter change, and filtering stays instant.
2. **Counters in a single aggregate query.** `GROUP BY IsClosed, Priority` returns every bucket at once, so the three totals cost one SOQL statement.
3. **`WITH USER_MODE` + `with sharing`.** Object and field permissions are enforced by the platform instead of manual checks, and record access follows the running user's sharing rules.
4. **Picklists from the describe.** `Case.Status` and `Case.Priority` are read at runtime, so admins can change values without a deployment.
5. **Imperative load, wire for counters.** The list needs an explicit refresh after closing a Case; counters use `@wire` plus `refreshApex`.
6. **Friendly errors.** DML exceptions are converted to `AuraHandledException` messages and the UI never shows a raw stack trace.

## What I would do with more time

- Server-side pagination or infinite loading for Accounts with thousands of Cases.
- Column sorting on the datatable.
- Lightning Message Service so other components react to a Case being closed.
- A CI pipeline that runs `sf project deploy validate` and the Apex tests on every push.
- Custom Labels for user-facing text (translatable).
- `lightning-datatable` inline edit for Status, with optimistic UI.
