# Quick Start Guide

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

This guide will help you quickly get up and running with Jac Cloud, with step-by-step instructions designed for beginners.

## Your First Jac Cloud Server in 30 Seconds

Transform any Jac application into a cloud API server with a single command:

```bash
# Basic usage - this is all you need to start!
jac serve main.jac

# With custom host and port (optional)
jac serve main.jac --host 0.0.0.0 --port 8080 --reload
```

## Development Mode

- `--reload`
  - Enable auto-reload. Uvicorn supports two versions of auto-reloading behavior enabled by this option. Default: `False`.
- `--watch path/to/dir1,path/to/dir2`
  - Select which path/s (comma separated) to watch for changes for auto-reload. Requires `--reload` to work. Defaults to main jac directory

---

Once started, your API will be available at:

- **API Endpoint**: `http://localhost:8000`
- **Interactive Documentation**: `http://localhost:8000/docs`

## Understanding Walker Endpoints

### What Happens Automatically

Jac Cloud automatically converts your walker declarations into REST API endpoints. By default, each walker creates two endpoint groups:

| Endpoint Type | URL Pattern | Description |
|--------------|-------------|-------------|
| **Root Entry** | `/walker/{walker_name}` | Executes on the root |
| **Node Entry** | `/walker/{walker_name}/{node_id}` | Executes on a specific node |

### Want to Disable Auto-Generation?

To disable automatic endpoint generation, set the environment variable:

```bash
export DISABLE_AUTO_ENDPOINT=True
```

## Configuring Your Walkers

### Basic Configuration

Control endpoint behavior using the `__specs__` object within your walker:

```jac
walker my_walker {
    has data: str;

    # This is where you configure your endpoint behavior
    obj __specs__ {
        static has methods: list = ["get", "post"];   # Supports both GET and POST
        static has auth: bool = False;                # No authentication required
        static has as_query: list = ["data"];         # "data" will be a query parameter
        static has private: bool = True;              # Skip auto endpoint generation from walker
    }
}
```

## Configuration Reference

### Core Settings (Most Common)

| **Setting** | **Type** | **Description** | **Default** |
|-------------|----------|-----------------|-------------|
| `methods` | `list[str]` | Allowed HTTP methods: `"get"`, `"post"`, `"put"`, `"delete"`, etc. | `["post"]` |
| `as_query` | `str \| list[str]` | Fields to treat as query parameters. Use `"*"` for all fields | `[]` |
| `auth` | `bool` | Whether endpoint requires authentication | `true` |
| `path` | `str` | If it starts with `/`, it will be the complete path. Otherwise, it will be prefixed with `/walker` (for walkers) or /`webhook/walker` (for webhooks). If not specified, it defaults to the walker's name with its respective prefix. | N/A |
| `private` | `bool` | Skip walker in auto-generation | `false` |

### Advanced Settings

| **Setting** | **Type** | **Description** | **Default** |
|-------------|----------|-----------------|-------------|
| `entry_type` | `str` | `"NODE"`, `"ROOT"`, or `"BOTH"` | `"BOTH"` |
| `webhook` | `dict` | [Webhook configuration](webhook.md) | `None` |
| `schedule` | `dict` | [Scheduler configuration](scheduler.md) | `None` |

### Documentation Settings

| **Setting** | **Type** | **Description** | **Default** |
|-------------|----------|-----------------|-------------|
| `response_model` | `Any` | Type for response serialization and validation | `None` |
| `tags` | `list[str \| Enum]` | API tags for grouping in Swagger UI | `None` |
| `status_code` | `int` | Default response status code | `None` |
| `summary` | `str` | Brief endpoint description | `None` |
| `description` | `str` | Detailed endpoint description (supports Markdown) | `None` |
| `response_description` | `str` | Description for the default response | `"Successful Response"` |
| `responses` | `dict[int \| str, dict]` | Additional responses that could be returned | `None` |
| `deprecated` | `bool` | Mark endpoint as deprecated | `None` |
| `include_in_schema` | `bool` | Include endpoint in generated OpenAPI schema | `True` |
| `response_class` | `Type[Response]` | Response class to use for this endpoint | `JSONResponse` |
| `name` | `str` | Internal name for the path operation | `None` |
| `openapi_extra` | `dict[str, Any]` | Extra metadata for OpenAPI schema | `None` |

## Examples for Beginners

### Basic Endpoint Example - Time Service

Let's create a simple endpoint that returns the current time. For this example, we create a walker named `public_info` which provides one rest method `get` at the url `http://localhost:8000/walker/public_info`. The ability `get_current_time` will return the current timestamp in ISO format via the use of the `report` statement.

```jac
import from datetime {datetime}

# Public endpoint (no authentication)
walker public_info {
    obj __specs__ {
        static has methods: list = ["get"];
        static has auth: bool = False;
    }

    can get_current_time with `root entry{
        report {
            "timestamp": datetime.now().isoformat()
        };
    }
}
```

### Parameterized Endpoint Example - User Search

This example demonstrates how to create an endpoint from a walker that accepts query parameters for searching users. The walker `search_users` will allow users to search for a user by their username.

```jac
# GET endpoint with query parameters
walker search_users {
    has query: str;
    static has users: list = [
        {"username": "alice", "email": "alice@example.com"},
        {"username": "bob", "email": "bob@example.com"}
    ];

    obj __specs__ {
        static has methods: list = ["get"];
        static has as_query: list = ["query"];
        static has auth: bool = False;
    }

    can search_by_name with `root entry{
        for user in self.users {
            if user['username'] == self.query {
                report user;
                return;
            }
        }

        report {
            "error": f"User with username {self.query} not found"
        };
    }
}
```

To test this endpoint, you can use a web browser or a tool like `curl`:

```bash
curl -X 'GET' \
  'http://0.0.0.0:8000/walker/search_users?query=alice' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json'
```

If the user is found, the response will look like this:

```json
{
    "status": 200,
    "reports": [
        {
            "username": "alice",
            "email": "alice@example.com"
        }
    ]
}
```

### File Upload Example

In this example, we will create a walker that allows users to upload a file. The walker `single_file_upload` will accept a single file and return the filename in the response. This shows how the walker can handle post requests with file uploads.

Since jac is a superset of Python, we can use the `UploadFile` type from FastAPI to handle file uploads.

First, we create the upload_file.jac file with the following content:

```jac
# upload_file.jac
import from fastapi { UploadFile }

# Single file upload
walker single_file_upload {
    has file: UploadFile;

    obj __specs__ {
        static has methods: list = ["post"];
        static has auth: bool = False;
    }

    can enter with `root entry {
        report {
            "output": f"Received file: {self.file.filename}"
        };
    }
}

```

Next we can create a test text file named `test.txt` with the content "Hello, Jac Cloud!".

```bash
echo "Hello, Jac Cloud!" > test.txt
```

Now we can test the file upload endpoint using `curl`:

```bash
curl -L -F "file=@test.txt" \
"http://0.0.0.0:8080/walker/single_file_upload" \
```

Successful file upload will return a response like this:

```json
{
    "status": 200,
    "reports": [
        {
            "output": "Received file: test.txt"
        }
    ]
}
```

## Response Format

### What to Expect

All walker endpoints return a standardized JSON response:

```json
{
    "status": 200,
    "reports": [
        "Any reports generated during walker execution"
    ],
    "returns": [
        "Walker return values (optional - requires SHOW_ENDPOINT_RETURNS=true)"
    ]
}
```

### Working with Node and Edge Data

Jac Cloud automatically serializes walker, edge, and node archetypes:

```json
{
    "id": "unique_anchor_reference_id",
    "context": {
        "attribute1": "value1",
        "attribute2": "value2"
    }
}
```

## Data Persistence: Manual Saving and Commits

### **Save**

To save a walker or object to memory (queued for later database commit):

```jac
# Save a walker instance
save(my_walker_instance)

# Save an object instance
save(my_object_instance)
```

### **Commit**

**Commit all in-memory data:**

```jac
commit()  # Saves everything currently in memory to database
```

**Commit specific archetype:**

```jac
commit(archetype)  # Only commits this specific archetype
```

## Helpful Environment Variables

Control Jac Cloud behavior with these environment variables:

- `DISABLE_AUTO_ENDPOINT=True` - Disable automatic endpoint generation
- `SHOW_ENDPOINT_RETURNS=True` - Include walker return values in responses

## Next Steps

Now that you understand the basics, explore these features:

- [Authentication & Permissions](permission.md) - Secure your API
- [Real-time WebSocket Communication](websocket.md) - Add real-time features
- [Task Scheduling](scheduler.md) - Automate recurring tasks
- [Webhook Integration](webhook.md) - Create API integrations
- [Environment Variables](env_vars.md) - Configure your application
- [Logging & Monitoring](logging.md) - Track application performance

## Edge Case: Manually Creating Walker Endpoints

While not recommended, as you typically shouldn't change your API specifications in this manner, Jac Cloud does support manually creating walker endpoints.
This allows for advanced customization if absolutely necessary, but generally, you should rely on the automatic generation and configuration via **specs**.

Example Code snippet:

```
type("NameOfYourWalker", (_.Walker,), {
    "__specs__": your_specs_class,
    ... annotations / additional fields ...
})
```
