# Webhook Guide

Jac Scale provides built-in support for webhook endpoints with HMAC-SHA256 signature verification and API key authentication. This guide explains how to create webhook walkers, manage API keys, and integrate with external services.

## Overview

Webhooks allow external services (payment processors, CI/CD systems, messaging platforms, etc.) to send real-time notifications to your Jac application. Jac Scale provides:

- **Dedicated `/webhook/` endpoints** for webhook walkers
- **API key authentication** for secure access
- **HMAC-SHA256 signature verification** to validate request integrity
- **Automatic endpoint generation** based on walker configuration

## 1. Configuration

Webhook configuration is managed via the `jac.toml` file in your project root.

### Basic Configuration

```toml
[plugins.scale.webhook]
signature_header = "X-Webhook-Signature"
timestamp_header = "X-Webhook-Timestamp"
verify_signature = true
replay_tolerance_seconds = 300
max_body_bytes = 1048576
rate_limit_per_minute = 0
api_key_expiry_days = 365
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `signature_header` | string | `"X-Webhook-Signature"` | HTTP header name containing the HMAC signature. |
| `timestamp_header` | string | `"X-Webhook-Timestamp"` | HTTP header name containing the request Unix timestamp. |
| `verify_signature` | boolean | `true` | Whether to verify HMAC signatures (and timestamp freshness) on incoming requests. |
| `replay_tolerance_seconds` | integer | `300` | Max allowed difference between the request timestamp and server time. Requests outside this window are rejected as replays. |
| `max_body_bytes` | integer | `1048576` | Maximum webhook request body size. Larger requests are rejected with `413`. |
| `rate_limit_per_minute` | integer | `0` | Per-key requests allowed per minute (best-effort, per-process). `0` disables the limit; over-limit requests get `429`. |
| `api_key_expiry_days` | integer | `365` | Default expiry period for API keys in days. Set to `0` for permanent keys. |

## 2. Creating Webhook Walkers

To create a webhook endpoint, use the `@restspec(protocol=APIProtocol.WEBHOOK)` decorator on your walker definition.

### Basic Webhook Walker

```jac
@restspec(protocol=APIProtocol.WEBHOOK)
walker PaymentReceived {
    has payment_id: str,
        amount: float,
        currency: str = 'USD';

    can process with Root entry {
        # Process the payment notification
        report {
            "status": "success",
            "message": f"Payment {self.payment_id} received",
            "amount": self.amount,
            "currency": self.currency
        };
    }
}
```

This walker will be accessible at `POST /webhook/PaymentReceived`.

### Minimal Webhook Walker

```jac
@restspec(protocol=APIProtocol.WEBHOOK)
walker WebhookHandler {
    can process with Root entry {
        report {"status": "received", "message": "Webhook processed"};
    }
}
```

### Important Notes

- Webhook walkers are **only** accessible via `/webhook/{walker_name}` endpoints
- They are **not** accessible via the standard `/walker/{walker_name}` endpoint

## 3. API Key Management

Webhook endpoints require API key authentication. Users must first create an API key before calling webhook endpoints.

### Creating an API Key

**Endpoint:** `POST /api-key/create`

**Headers:**

- `Authorization: Bearer <jwt_token>` (required)

**Request Body:**

```json
{
    "name": "My Webhook Key",
    "expiry_days": 30,
    "allowed_walkers": "PaymentReceived,RefundIssued"
}
```

`allowed_walkers` is an optional comma-separated allow-list of webhook
walker names this key may call. Omit it (or leave it empty) for an
unscoped key that may call any webhook walker. A scoped key calling a
walker outside its list is rejected with `403 Forbidden`.

**Response:**

```json
{
    "api_key": "eyJhbGciOiJIUzI1NiIs...",
    "api_key_id": "a1b2c3d4e5f6...",
    "name": "My Webhook Key",
    "created_at": "2024-01-15T10:30:00Z",
    "expires_at": "2024-02-14T10:30:00Z",
    "signing_secret": "9f86d081884c7d659a2feaa0c55ad015..."
}
```

> **Important:** `signing_secret` is returned **only once**, here. Store it
> securely and share it out of band with the calling service. It is used to
> HMAC-sign request bodies and must **never** be sent in a webhook request.
> It is independent of `api_key`; the API key identifies the caller, the
> signing secret proves the request was not forged or tampered with.

### Listing API Keys

**Endpoint:** `GET /api-key/list`

**Headers:**

- `Authorization: Bearer <jwt_token>` (required)

**Response:**

```json
{
    "api_keys": [
        {
            "api_key_id": "a1b2c3d4e5f6...",
            "name": "My Webhook Key",
            "created_at": "2024-01-15T10:30:00Z",
            "expires_at": "2024-02-14T10:30:00Z",
            "active": true
        }
    ]
}
```

### Revoking an API Key

**Endpoint:** `DELETE /api-key/{api_key_id}`

**Headers:**

- `Authorization: Bearer <jwt_token>` (required)

**Response:**

```json
{
    "message": "API key 'a1b2c3d4e5f6...' has been revoked"
}
```

## 4. Calling Webhook Endpoints

Webhook endpoints require two headers for authentication:

1. **`X-API-Key`**: The API key obtained from `/api-key/create`
2. **`X-Webhook-Signature`**: HMAC-SHA256 signature (see below)
3. **`X-Webhook-Timestamp`**: Unix timestamp (seconds) of the request

### Generating the Signature

The signature is computed over the timestamp and body together:

`HMAC-SHA256("<timestamp>." + request_body, signing_secret)`

The `signing_secret` is the value returned once from `/api-key/create`. It is
**not** the API key. The API key is sent in the request to identify the
caller; the signing secret is held only by you and the calling service and
never travels in the request, which is what makes the signature meaningful.

The timestamp is sent in `X-Webhook-Timestamp` and bound into the signature.
The server rejects requests whose timestamp is outside
`replay_tolerance_seconds` of server time, so a captured request cannot be
replayed later.

#### cURL Example

```bash
API_KEY="eyJhbGciOiJIUzI1NiIs..."
SIGNING_SECRET="9f86d081884c7d659a2feaa0c55ad015..."
PAYLOAD='{"payment_id":"PAY-12345","amount":99.99,"currency":"USD"}'
TIMESTAMP=$(date +%s)
SIGNATURE=$(printf '%s.%s' "$TIMESTAMP" "$PAYLOAD" | openssl dgst -sha256 -hmac "$SIGNING_SECRET" | cut -d' ' -f2)

curl -X POST "http://localhost:8000/webhook/PaymentReceived" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -H "X-Webhook-Signature: $SIGNATURE" \
    -H "X-Webhook-Timestamp: $TIMESTAMP" \
    -d "$PAYLOAD"
```

## 5. Comparison: Webhook vs Regular Walkers

| Feature | Regular Walker (`/walker/`) | Webhook Walker (`/webhook/`) |
|---------|----------------------------|------------------------------|
| Authentication | JWT Bearer token | API Key + HMAC Signature |
| Use Case | User-facing APIs | External service callbacks |
| Access Control | User-scoped | Service-scoped |
| Signature Verification | No | Yes (HMAC-SHA256) |
| Endpoint Path | `/walker/{name}` | `/webhook/{name}` |

## 6. API Reference

### Webhook Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/webhook/{walker_name}` | Execute webhook walker |

### API Key Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api-key/create` | Create a new API key |
| GET | `/api-key/list` | List all API keys for user |
| DELETE | `/api-key/{api_key_id}` | Revoke an API key |

### Required Headers for Webhook Requests

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | Must be `application/json` |
| `X-API-Key` | Yes | API key from `/api-key/create` |
| `X-Webhook-Signature` | Yes* | HMAC-SHA256 of `"<timestamp>." + body` (*if `verify_signature` is enabled) |
| `X-Webhook-Timestamp` | Yes* | Unix timestamp in seconds (*if `verify_signature` is enabled) |
