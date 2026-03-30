# LLM Usage Limits & Rate Limiting

Built-in per-user LLM usage limiting, rate limiting, and budget controls in the jac-scale admin dashboard.

## Overview

When jac-scale is installed, every `byllm` LLM call is intercepted at the `litellm.completion` layer. The system can:

- Cap a user's LLM spend per day, week, or month
- Limit requests per minute (RPM) and tokens per minute (TPM)
- Restrict which models a user can access
- Auto-unblock users when their budget period resets
- Log every LLM call (success or blocked) to a persistent audit log
- Hot-swap the LLM provider API key at runtime without restarting

## Quick Start

### 1. Enable in `jac.toml`

```toml
[plugins.scale.llm_limits]
enabled = true
default_budget_limit = 10       # $10 per period (0 = unlimited)
default_budget_period = "daily"  # "daily" | "weekly" | "monthly"
default_rpm = 60                 # 60 requests per minute (0 = unlimited)
default_tpm = 100000             # 100K tokens per minute (0 = unlimited)
default_allowed_models = []      # empty = all models allowed
enforcement_mode = "strict"      # "strict" = block, "warn" = log only
```

### 2. Start the server

```bash
jac start app.jac
```

On startup you'll see:

```
LLM limits: default limits initialized from config
LLM limits: litellm enforcement wrapper installed (mode=strict)
```

### 3. Manage via Admin Dashboard

Navigate to **Settings > Rate Limits** in the admin dashboard to:

- Set default limits (applied to all users without overrides)
- Add per-user overrides with custom budgets, periods, RPM/TPM, and model restrictions
- View current spend and request counts per user
- Reset usage counters
- Edit or remove user overrides

## Configuration Reference

### `jac.toml` options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | bool | `true` | Enable/disable the entire limits system |
| `default_budget_limit` | float | `0` | Default budget in USD (0 = unlimited) |
| `default_budget_period` | string | `"monthly"` | `"daily"`, `"weekly"`, or `"monthly"` |
| `default_rpm` | int | `0` | Default requests per minute (0 = unlimited) |
| `default_tpm` | int | `0` | Default tokens per minute (0 = unlimited) |
| `default_allowed_models` | list | `[]` | Default allowed model names (empty = all) |
| `enforcement_mode` | string | `"strict"` | `"strict"` blocks calls, `"warn"` logs only |

### Budget Periods

| Period | Resets at |
|--------|-----------|
| `daily` | Next midnight UTC |
| `weekly` | Next Monday midnight UTC |
| `monthly` | 1st of next month midnight UTC |

When a user exceeds their budget, calls are blocked with a message like:

```
Budget limit exceeded ($10.00 / $10.00 daily). Resets at 2026-03-27 00:00 UTC
```

When the reset time arrives, the usage counters reset automatically on the next call -- no admin action needed.

## REST API

All endpoints require admin authentication via `Authorization: Bearer <token>`.

### Limits Management

#### Get default limits

```
GET /admin/llm/limits/default
```

#### Set default limits

```
PUT /admin/llm/limits/default
Content-Type: application/json

{
  "budget_limit": 10.0,
  "budget_period": "daily",
  "rpm_limit": 60,
  "tpm_limit": 100000,
  "allowed_models": ["gpt-4o-mini", "gpt-4o"],
  "enabled": true
}
```

#### List all per-user limits

```
GET /admin/llm/limits?limit=50&offset=0
```

#### Get/Set/Delete user-specific limits

```
GET    /admin/llm/limits/{username}
PUT    /admin/llm/limits/{username}
DELETE /admin/llm/limits/{username}
```

The PUT body is the same shape as the default limits. DELETE removes the user's override so they fall back to defaults.

### Usage Tracking

#### Get usage for all users (current period)

```
GET /admin/llm/usage?limit=50&offset=0
```

#### Get usage for a specific user

```
GET /admin/llm/usage/{username}
```

Response:

```json
{
  "ok": true,
  "data": {
    "username": "alice",
    "period": "2026-03",
    "total_cost": 4.32,
    "total_tokens": 125000,
    "total_requests": 87,
    "request_count_minute": 3,
    "token_count_minute": 1500
  }
}
```

#### Reset usage for a user

```
POST /admin/llm/usage/{username}/reset
```

### API Key Management

Hot-swap the LLM provider API key at runtime without restarting the server.

#### Check current key status

```
GET /admin/llm/config/api-key
```

Response:

```json
{
  "ok": true,
  "data": { "has_key": true, "masked_key": "****ab1c" }
}
```

#### Set a new API key (takes effect immediately)

```
PUT /admin/llm/config/api-key
Content-Type: application/json

{ "api_key": "sk-proj-..." }
```

Every subsequent LLM call will use this key, regardless of what's in `jac.toml` or environment variables.

#### Clear the runtime key (fall back to config/env)

```
DELETE /admin/llm/config/api-key
```

### Key priority chain

```
Admin-set key (runtime)  >  Model instance key  >  jac.toml config  >  Environment variables
```

## How Enforcement Works

```
User Request (JWT auth)
  |
  v
Walker/Function callback
  -> Sets ContextVar: current_request_user = "alice"
  |
  v
byllm calls litellm.completion(model="gpt-4o", ...)
  -> Intercepted by enforcement wrapper
  -> Resolves username from ContextVar (or "__anonymous__")
  -> check_limits("alice", "gpt-4o"):
       1. Model access check -- is gpt-4o in allowed_models?
       2. Budget check -- has alice exceeded $10/day?
          (auto-resets if period expired)
       3. RPM check -- has alice exceeded 60 req/min?
       4. TPM check -- has alice exceeded 100K tok/min?
  -> If blocked: logs attempt, raises exception
  -> If allowed: increments RPM, injects api_key override
  |
  v
Original litellm.completion() executes
  |
  v
Post-call: records cost, tokens, latency to usage counters + audit log
```

## Audit Log

Every LLM call is logged with:

- `username`, `model`, `status` (success/blocked)
- `cost`, `total_tokens`, `prompt_tokens`, `completion_tokens`
- `latency_ms`, `blocked` (bool), `block_reason`
- `period`, `invocation_id`, `caller_name`, `timestamp`

Stored in the `llm_usage_log` MongoDB collection (or in-memory buffer for dev).

## Storage

| Collection | Purpose |
|------------|---------|
| `llm_user_limits` | Per-user limit configurations |
| `llm_user_usage` | Aggregated usage counters per period |
| `llm_usage_log` | Per-call audit log |
| `llm_config` | Runtime config (API key override) |

MongoDB is required for production. Without it, data is stored in-memory and lost on restart. The server logs a warning on startup:

```
WARNING: LLM limits: NO MongoDB configured -- usage data will NOT persist across restarts.
```

## Security Notes

- **Anonymous users**: Unauthenticated requests are tracked as `__anonymous__` and subject to limits
- **Audit trail**: Both successful and blocked calls are logged
- **API key masking**: The GET endpoint only returns the last 4 characters
- **Race conditions**: Under high concurrency, the check-then-increment pattern may allow brief overages at budget boundaries. This is a known tradeoff for low latency.
