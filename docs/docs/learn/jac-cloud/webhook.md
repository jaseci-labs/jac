# Webhooks: External API Integration

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## What are Webhooks?

Webhooks are a way for external services to securely call your Jac Cloud application when certain events occur. Unlike regular authenticated walkers (which are associated with a specific user), webhook walkers are directly linked to the root node and are secured with API keys rather than user tokens.

## Key Features

- **Direct Root Access**: Webhooks operate at the root level, not tied to any specific user
- **API Key Management**: Generate, extend, and delete API keys through the API
- **Flexible Authentication**: Support for different API key placement methods (header, query, path, body)
- **Customizable**: You can specify allowed walkers, nodes, and expiration dates for each API key

## Creating a Webhook Walker

To declare a walker as a webhook endpoint, add a `webhook` configuration to the `__specs__` class:

```jac
walker webhook {
    can enter1 with `root entry {
        report here;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "header | query | path | body",  # optional: defaults to header
            "name": "any string"                     # optional: defaults to X-API-KEY
        };
    }
}
```

The `type` field specifies where the API key will be placed in the HTTP request:

- `header`: In the HTTP headers (default)
- `query`: As a query parameter
- `path`: As part of the URL path
- `body`: In the request body

The `name` field is the name of the parameter that will contain the API key.

## Managing API Keys

Jac Cloud provides several endpoints for managing webhook API keys:

![Webhook Management API endpoints](https://github.com/user-attachments/assets/3a01ab35-06b0-4942-8f1f-0c4ae794ce21)

### Generating a New API Key

**Endpoint:** `POST /webhook/generate-key`

**Request Body:**

```python
{
  "name": "webhook1",
  "walkers": ["webhook"],
  "nodes": ["root"],
  "expiration": {
    "count": 60,
    "interval": "days"
  }
}
```

| Parameter  | Description                                                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------- |
| name       | A unique identifier for the webhook key.                                                                                     |
| walkers    | A list of specific walker names that are permitted to use this key. If this list is empty, all walkers are allowed.          |
| nodes      | A list of specific node names that are permitted to be accessed with this key. If this list is empty, all nodes are allowed. |
| expiration | Defines the expiration settings for the webhook key.                                                                         |
| count      | The numerical value for the expiration duration.                                                                             |
| interval   | The unit of time for the expiration duration. Valid values include "seconds", "minutes", "hours", and "days".                |

**Response:**

```python
{
  "id": "672203ee093fd3d208a4b6d4",
  "name": "webhook1",
  "key": "6721f000ee301e1d54c3de3d:1730282478:P4Nrs3DOLIkaw5aYsbIWNzWZZAwEyb20"
}
```

### Listing All API Keys

**Endpoint:** `GET /webhook`

**Response:**

```python
{
  "keys": [
    {
      "id": "672203ee093fd3d208a4b6d4",
      "name": "test",
      "root_id": "6721f000ee301e1d54c3de3d",
      "walkers": ["webhook"],
      "nodes": ["root"],
      "expiration": "2025-12-24T10:01:18.206000",
      "key": "6721f000ee301e1d54c3de3d:1730282478:P4Nrs3DOLIkaw5aYsbIWNzWZZAwEyb20"
    }
  ]
}
```

### Extending an API Key's Expiration

**Endpoint:** `PATCH /webhook/extend/{id}`

**Request Body:**

```python
{
  "count": 60,
  # seconds | minutes | hours | days
  "interval": "days"
}
```

**Response:**

```python
{
  "message": "Successfully Extended!"
}
```

### Deleting API Keys

**Endpoint:** `DELETE /webhook/delete`

**Request Body:**

```python
{
  # list of ids to be deleted
  "ids": ["672203ee093fd3d208a4b6d4"]
}
```

**Response:**

```python
{
  "message": "Successfully Deleted!"
}
```

## Webhook Implementation Examples

Here are examples of different webhook implementations:

### 1. Using Header for API Key (Default)

```jac
walker webhook_by_header {
    can enter1 with `root entry {
        report here;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "header",
            "name": "test-key"
        };
    }
}
```

**Example Request:**

```bash
curl -X 'POST' 'http://localhost:8001/webhook/walker/webhook_by_header' \
  -H 'test-key: YOUR-GENERATED-KEY'
```

### 2. Using Query Parameter for API Key

```jac
walker webhook_by_query {
    can enter1 with `root entry {
        report here;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "query",
            "name": "test_key"
        };
    }
}
```

**Example Request:**

```bash
curl -X 'POST' 'http://localhost:8001/webhook/walker/webhook_by_query?test_key=YOUR-GENERATED-KEY'
```

### 3. Using Path Parameter for API Key

```jac
walker webhook_by_path {
    can enter1 with `root entry {
        report here;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "path",
            "name": "test_key"  # name and the path var should be the same
        }, path: str = "/{test_key}";
    }
}
```

**Example Request:**

```bash
curl -X 'POST' 'http://localhost:8001/webhook/walker/webhook_by_path/YOUR-GENERATED-KEY'
```

### 4. Using Request Body for API Key

```jac
walker webhook_by_body {
    can enter1 with `root entry {
        report here;
    }

    class __specs__ {
        has webhook: dict = {
            "type": "body",
            "name": "test_key"
        };
    }
}
```

**Example Request:**

```bash
curl -X 'POST' 'http://localhost:8001/webhook/walker/webhook_by_body' -d '{"test_key": "YOUR-GENERATED-KEY"}'
```

## Best Practices

1. **Set Appropriate Expirations**: For security, use short-lived keys when possible.
2. **Limit Walker Access**: Specify only the walkers that should be accessible for each key.
3. **Use Specific Node Restrictions**: When possible, limit which nodes can be accessed.
4. **Regularly Rotate Keys**: Create a process to regularly generate new keys and invalidate old ones.
5. **Use Headers by Default**: Header-based API keys are generally more secure than query parameters or body values.

## Common Use Cases

Webhooks are ideal for:

- **Integration with Third-Party Services**: Allow external services to trigger specific actions in your application
- **Scheduled Events**: Receive notifications from scheduling services
- **Notifications**: Handle notifications from payment processors, source control systems, etc.
- **IoT Communication**: Enable secure communication from IoT devices
- **CI/CD Pipelines**: Trigger deployments or other actions from CI/CD systems

## Troubleshooting

If your webhook isn't working:

1. Verify the API key hasn't expired
2. Ensure you're sending the key in the correct location (header, query, path, or body)
3. Check that the parameter name matches your configuration
4. Confirm the walker and node are allowed for the API key
5. Check the logs for any errors

## Next Steps

- Learn about [WebSocket Communication](websocket.md) for real-time bidirectional communication
- Explore [Task Scheduling](scheduler.md) for running walkers on a schedule
- See how to properly [Deploy to Production](deployment.md) with secure webhook configurations
