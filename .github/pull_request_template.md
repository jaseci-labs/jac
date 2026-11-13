## **Description**

## Validation

Record the tested commit, compiler/runtime, exact commands and results. Required
CI must pass on the final PR head; approval-required or missing checks are pending.

For a bug fix, show that the regression fails before the fix and passes afterward.
For persistence or retry changes, assert durable database state and body/callback
execution counts under injected failures before and after commit, including nested
and independent sessions. A diagnostic that asserts the defect is a reproduction,
not a passing regression. Include relevant idempotency and integration checks.
