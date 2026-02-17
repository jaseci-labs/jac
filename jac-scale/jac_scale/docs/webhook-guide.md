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
verify_signature = true
api_key_expiry_days = 365
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `signature_header` | string | `"X-Webhook-Signature"` | HTTP header name containing the HMAC signature. |
| `verify_signature` | boolean | `true` | Whether to verify HMAC signatures on incoming requests. |
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
    "expiry_days": 30
}
```

**Response:**

```json
{
    "api_key": "eyJhbGciOiJIUzI1NiIs...",
    "api_key_id": "a1b2c3d4e5f6...",
    "name": "My Webhook Key",
    "created_at": "2024-01-15T10:30:00Z",
    "expires_at": "2024-02-14T10:30:00Z"
}
```

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
2. **`X-Webhook-Signature`**: HMAC-SHA256 signature of the request body

### Generating the Signature

The signature is computed as: `HMAC-SHA256(request_body, api_key)`

#### cURL Example

```bash
API_KEY="eyJhbGciOiJIUzI1NiIs..."
PAYLOAD='{"payment_id":"PAY-12345","amount":99.99,"currency":"USD"}'
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$API_KEY" | cut -d' ' -f2)

curl -X POST "http://localhost:8000/webhook/PaymentReceived" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -H "X-Webhook-Signature: $SIGNATURE" \
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
| `X-Webhook-Signature` | Yes* | HMAC-SHA256 signature (*if `verify_signature` is enabled) |
