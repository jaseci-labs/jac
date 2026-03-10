# Admin UI Test Specifications

This document outlines test cases for the admin UI client-side code.
These tests require a client-side test framework (e.g., Jest, Vitest) to execute.

## Test Cases

### utils/api.cl.jac - getErrorMessage

**Happy Path:**

- Returns error message when result has `error.message`
  - Input: `{"error": {"message": "User not found"}}`
  - Expected: `"User not found"`

**Edge Cases:**

- Returns fallback when result is None
  - Input: `None`
  - Expected: `"An error occurred"`

- Returns fallback when error is missing
  - Input: `{"data": "success"}`
  - Expected: `"An error occurred"`

- Returns fallback when error.message is missing
  - Input: `{"error": {}}`
  - Expected: `"An error occurred"`

- Returns custom fallback when provided
  - Input: `None, "Custom error"`
  - Expected: `"Custom error"`

**Error Conditions:**

- Handles empty object
  - Input: `{}`
  - Expected: `"An error occurred"`

### constants/users.cl.jac - ROLE_OPTIONS

**Verification:**

- ROLE_OPTIONS contains exactly 2 roles: user, admin
- Each role has both `value` and `label` keys
- Values are lowercase, labels are capitalized

### AlertContext.cl.jac

**Verification:**

- ALERT_DISMISS_MS is 3000 (milliseconds)
- Alert auto-dismisses after ALERT_DISMISS_MS

### ResetPage.cl.jac

**Verification:**

- MIN_PASSWORD_LENGTH is 8
- Password validation rejects strings shorter than 8 characters
- Password validation accepts strings of 8+ characters

### DashboardLayout.cl.jac - PAGE_ROUTES

**Verification:**

- PAGE_ROUTES contains all expected categories: auth, data, ops, config, infra, audit
- Each category maps to correct page components
- Unknown routes return "Page not found" message

## Integration Test Scenarios

### User Management Flow

1. Navigate to Users page
2. Create new user via CreateUserModal
3. Verify user appears in table
4. Edit user via EditUserModal
5. Delete user

### Alert System

1. Trigger success alert
2. Verify alert appears with correct styling
3. Verify alert auto-dismisses after 3 seconds

### SSO Configuration

1. Navigate to SSO page
2. Add new provider
3. Toggle provider status
4. Remove provider
