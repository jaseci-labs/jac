# Scale -- Data & Storage

> Part of the [Scale subsystem](jac-scale.md).

## Storage

Jac provides a built-in storage abstraction for file and blob operations. The core runtime ships with a local filesystem implementation, and jac-scale can override it with cloud storage backends -- all through the same `store()` builtin.

### The `store()` Builtin

The recommended way to get a storage instance is the `store()` builtin. It requires no imports and is automatically backed by the active persistence provider (jac-scale when installed, otherwise core's local storage):

```jac
# Get a storage instance (no imports needed)
glob storage = store();

# With custom base path
glob storage = store(base_path="./uploads");

# With all options
glob storage = store(base_path="./uploads", create_dirs=True);
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `base_path` | `str` | `"./storage"` | Root directory for all files |
| `create_dirs` | `bool` | `True` | Create base directory if it doesn't exist |

Without jac-scale, `store()` returns a `LocalStorage` instance. With jac-scale installed, it returns a configuration-driven backend (reading from `jac.toml` and environment variables).

### Storage Interface

All storage instances provide these methods:

| Method | Signature | Description |
|--------|-----------|-------------|
| `upload` | `upload(source, destination, metadata=None) -> str` | Upload a file (from path or file object) |
| `download` | `download(source, destination=None) -> bytes\|None` | Download a file (returns bytes if no destination) |
| `delete` | `delete(path) -> bool` | Delete a file or directory |
| `exists` | `exists(path) -> bool` | Check if a path exists |
| `list_files` | `list_files(prefix="", recursive=False)` | List files (yields paths) |
| `get_metadata` | `get_metadata(path) -> dict` | Get file metadata (size, modified, created, is_dir, name) |
| `copy` | `copy(source, destination) -> bool` | Copy a file within storage |
| `move` | `move(source, destination) -> bool` | Move a file within storage |
| `get_url` | `get_url(path, expires_in=3600) -> str` | Get a public or pre-signed URL for a file |

### Usage Example

```jac
import from jaclang.runtimelib.serving.datatypes { UploadFile }
import from uuid { uuid4 }

glob storage = store(base_path="./uploads");

walker :pub upload_file {
    has file: UploadFile;
    has folder: str = "documents";

    can process with Root entry {
        unique_name = f"{uuid4()}.dat";
        path = f"{self.folder}/{unique_name}";

        # Upload file
        storage.upload(self.file.file, path);

        # Get metadata
        metadata = storage.get_metadata(path);

        report {
            "success": True,
            "storage_path": path,
            "size": metadata["size"]
        };
    }
}

walker :pub list_files {
    has folder: str = "documents";
    has recursive: bool = False;

    can process with Root entry {
        files = [];
        for path in storage.list_files(self.folder, self.recursive) {
            metadata = storage.get_metadata(path);
            files.append({
                "path": path,
                "size": metadata["size"],
                "name": metadata["name"]
            });
        }
        report {"files": files};
    }
}
```

### S3-Compatible Cloud Storage

`jac-scale` enables seamless integration with S3-compatible object storage. When configured, the `store()` builtin returns an `S3Storage` instance instead of the default local one.

#### Configuration

Storage is configured in `jac.toml` under the `[scale.storage]` section or via environment variables.

| `jac.toml` key | Env Variable | Description | Default |
|----------------|--------------|-------------|---------|
| `type` | `JAC_STORAGE_TYPE` | Storage backend: `local` or `s3` | `local` |
| `bucket` | `JAC_STORAGE_S3_BUCKET` | S3 bucket name | None |
| `region` | `JAC_STORAGE_S3_REGION` | S3 region | `us-east-1` |
| `prefix` | `JAC_STORAGE_S3_PREFIX` | Optional prefix (directory) for all keys | `""` |
| `endpoint_url`| `JAC_STORAGE_S3_ENDPOINT_URL` | Custom endpoint for non-AWS providers | None |
| `public_read` | `JAC_STORAGE_S3_PUBLIC_READ` | If `true`, returns direct public URLs | `false` |

**Example `jac.toml`:**

```toml
[scale.storage]
type = "s3"
bucket = "my-app-uploads"
region = "us-east-1"
public_read = false
```

### Generating URLs

The `get_url()` method provides a standardized way to expose files to the internet or internal services.

- **LocalStorage**: Returns a `file://` URI to the absolute path of the file.
- **S3Storage (Private)**: Returns a secure **pre-signed URL** that expires after the specified time (default: 1 hour).
- **S3Storage (Public)**: If `public_read = true`, returns a direct, permanent public URL.

```jac
with entry {
    storage = store();

    # Generate a URL that expires in 10 minutes (600 seconds)
    # For S3, this is a pre-signed URL.
    url = storage.get_url("profile-photos/user1.jpg", expires_in=600);
}

walker :pub download_file {
    has path: str;

    can process with Root entry {
        if not storage.exists(self.path) {
            report {"error": "File not found"};
            return;
        }
        content = storage.download(self.path);
        report {"content": content, "size": len(content)};
    }
}
```

### Configuration

Configure storage in `jac.toml`:

```toml
[storage]
type = "local"           # Storage backend type
base_path = "./storage"  # Base directory for files
create_dirs = true       # Auto-create directories
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `type` | string | `"local"` | Storage backend (`local`, `s3`) |
| `base_path` | string | `"./storage"` | Base path for file storage |
| `create_dirs` | boolean | `true` | Automatically create directories |

**Environment Variables:**

| Variable | Description |
|----------|-------------|
| `JAC_STORAGE_TYPE` | Storage type (overrides jac.toml) |
| `JAC_STORAGE_PATH` | Base directory (overrides jac.toml) |
| `JAC_STORAGE_CREATE_DIRS` | Auto-create directories (`"true"`/`"false"`) |

Configuration priority: environment variables > `jac.toml` > defaults.

### StorageFactory (Advanced)

For advanced use cases, you can use `StorageFactory` directly instead of the `store()` builtin:

```jac
import from jaclang.scale.storage.factory { StorageFactory }

# Create with explicit type and config
glob config = {"base_path": "./my-files", "create_dirs": True};
glob storage = StorageFactory.create("local", config);

# Create using jac.toml / env var / defaults
glob default_storage = StorageFactory.get_default();
```

---

## Graph Traversal API

### Traverse Endpoint

```bash
POST /traverse
```

### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `source` | str | Starting node/edge ID | root |
| `depth` | int | Traversal depth | 1 |
| `detailed` | bool | Include archetype context | false |
| `node_types` | list | Filter by node types | all |
| `edge_types` | list | Filter by edge types | all |

### Example

```bash
curl -X POST http://localhost:8000/traverse \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "depth": 3,
    "node_types": ["User", "Post"],
    "detailed": true
  }'
```

---

## Async Walkers

```jac
walker async_processor {
    has items: list;

    async can process with Root entry {
        results = [];
        for item in self.items {
            result = await process_item(item);
            results.append(result);
        }
        report results;
    }
}
```

---

## Event Streaming

Optional event-streaming broker for emitting and consuming events between jac code and external systems. Off by default. Provides durable log, consumer groups, replayable offsets via `start_from`, and at-least-once delivery with retries and a DLQ.

Two implementations ship in-tree:

- **`LocalEventStream`** (in-memory): single-process, no persistence. Used automatically when no database URL is configured. Right for dev workstations, tests, and single-pod deployments.
- **`PgEventStream`** (Postgres): durable, cross-pod, backed by the same database that holds the graph. Used automatically when a database URL resolves (`[scale.events].url`, `[scale.database].url`, or `JAC_DB_URL`).

You don't pick the broker; selection happens at startup based on what's available.

### Enabling

Add the section to `jac.toml`. Master switch is `enabled`; everything else has working defaults.

```toml
[scale.events]
enabled = true
# Optional. If unset, falls back to [scale.database].url / JAC_DB_URL; if
# neither resolves, the in-memory LocalEventStream is used.
url = "postgresql://user:pass@localhost:5432/jac"
consumer_group = "jac-scale"
serializer = "json"

[scale.events.retry]
max_attempts = 3
backoff_seconds = [1, 5, 30]
dead_letter_suffix = ".dlq"
```

The Postgres stream needs no extra packages: the driver is vendored with the runtime. With no database URL, scale uses `LocalEventStream` and logs a warning at startup.

### Publishing

```jac
import from jaclang.scale.events.publisher { publish }
import from jaclang.scale.events.broker { Event }

walker place_order {
    has order_id: int;
    has amount: float;

    can fire with Root entry {
        publish("orders.placed", Event(
            data={"order_id": self.order_id, "amount": self.amount},
            trace_id="trace-1"
        ));
    }
}
```

`publish()` is fire-and-forget. Errors from the broker are logged and swallowed so emit sites do not have to wrap calls in try/except. `event.event_type` auto-defaults to the topic when left empty, so the topic string only needs to appear once at the call site (set `event_type` explicitly only when it differs from the topic).

### Subscribing (push)

```jac
import from jaclang.scale.events.subscriber { subscribe }
import from jaclang.scale.events.broker { Event }

@subscribe("orders.placed")
def on_order_placed(event: Event) -> None {
    print(event.event_type, event.data);
}
```

Handlers register at import time. At server startup, the framework walks the registry and wires each handler into the active broker. A daemon consumer thread is spawned per subscription.

`@subscribe` accepts optional `group=` and `retry=` arguments to override the defaults from `jac.toml`, plus `start_from=` to control where a brand-new consumer group begins reading. Default is `"latest"` (only events produced after the group is created); pass `"earliest"` to replay everything still retained, or a broker-specific position token to resume from a specific offset. `start_from` is a one-time bookmark: existing groups always resume from their stored position and ignore this argument.

```jac
@subscribe("orders.placed", start_from="earliest")
def replay_all(event: Event) -> None {
    print("replaying", event.id);
}
```

### Consuming (pull)

```jac
import from jaclang.scale.events.broker { EventStreamBroker }

def drain(broker: EventStreamBroker) -> int {
    batch = broker.consume(
        "orders.placed", max_messages=10, timeout_seconds=2.0
    );
    for ev in batch {
        # ... process ev ...
        broker.ack(ev);
    }
    return len(batch);
}
```

`consume()` blocks for up to `timeout_seconds` waiting for at least one event, then returns whatever has arrived (up to `max_messages`). Each event must be acked individually via `ack(event)` or the broker will redeliver it after its visibility timeout. `consume()` accepts the same `start_from=` argument as `subscribe()`; it only affects the first call that creates the consumer group, subsequent calls resume from the stored position.

### Configuration reference

| Key | Default | Description |
|-----|---------|-------------|
| `enabled` | `false` | Master switch. When `false`, all event-streaming calls are no-ops. |
| `url` | `null` | Postgres URL for the event stream. If unset, falls back to `[scale.database].url` / `JAC_DB_URL`. If nothing resolves, `LocalEventStream` (in-memory) is used. |
| `consumer_group` | `jac-scale` | Default consumer group name when `@subscribe` does not specify one. |
| `serializer` | `json` | Wire format. JSON only. |
| `retry.max_attempts` | `3` | Number of delivery attempts before sending to the DLQ topic. |
| `retry.backoff_seconds` | `[1, 5, 30]` | Backoff delays per attempt index, clamped to the last value. |
| `retry.dead_letter_suffix` | `.dlq` | Suffix appended to a topic name to form its dead-letter topic. |

### Reliability semantics

- **At-least-once delivery.** Handlers may run more than once for the same event. Make handlers idempotent, or dedupe on `event.id`.
- **Retry.** A failing handler is retried `retry.max_attempts` times with delays from `retry.backoff_seconds`. The thread sleeps responsively to the broker stop event so shutdowns are not blocked by long backoffs.
- **Dead-letter topic.** After retry exhaustion, the event is published to `<topic><retry.dead_letter_suffix>` and the original is acked so it is not redelivered indefinitely. The DLQ is a regular topic you can `consume()` like any other.
- **Drain on shutdown.** On process exit, consumer threads are signaled to stop and joined under a 10-second deadline.

### Operational notes

- Each subscription spawns one daemon consumer thread per topic/group. Inspect via standard threading tools.
- Delivery metadata is exposed as first-class fields on `Event`: `event.delivery_id`, `event.delivery_topic`, `event.delivery_group`. Handlers that need them for idempotency keys, structured logging, or dedup can read them directly without importing broker-specific constants. The fields are broker-managed: producers leave them `None`, the broker sets them on `consume()` / push delivery, and they are not serialized to the wire.
- Startup logs `Events broker enabled (kind={local|postgres}, subscriptions=N)` so it is easy to confirm wiring at a glance.
- The wire format is CloudEvents 1.0 valid (`specversion`, `type`, `data`, `id`, `source`, `time`, plus `trace_id` and `headers` as extensions), so strict CE consumers (Argo Events, Knative Eventing, CE-aware Kafka tooling) accept it.

---

## The Database

### One store, everywhere

Graph persistence is **Postgres-native** and there is exactly one stack:

- **Local development**: the runtime auto-provisions an embedded Postgres server, one database per project. `jac db status` / `jac db stop` manage it; nothing to install.
- **External server**: set `[scale.database].url` (or the `JAC_DB_URL` env var, which wins) and everything -- graph anchors, identity, scheduler jobs, webhook API keys, the event stream, and the WebSocket broadcast backplane -- runs against that database.
- **Kubernetes**: `jac start app.jac --scale` provisions a Postgres StatefulSet with a PersistentVolumeClaim and injects `JAC_DB_URL` into every pod via a Kubernetes Secret. Subsequent deployments only update the application; the database remains untouched.

| `jac.toml` key (`[scale.database]`) | Default | Description |
|----------|---------|-------------|
| `url` | `null` | Postgres connection URL (`postgresql://user:pass@host:port/db`). Also honored via `JAC_DB_URL`. When set, in-cluster provisioning is skipped (external mode). |
| `deploy_mode` | `"image"` | How the k8s target runs Postgres: `"image"` (official postgres image), `"embedded"` (the app's jac image running `jac db serve`), or implicit external when `url` is set. |
| `postgres_image` | `"postgres:18"` | Image used in `deploy_mode = "image"`. |
| `postgres_storage` | `"2Gi"` | PVC size for the provisioned StatefulSet. |

| `jac.toml` key (`[scale.kubernetes]`) | Default | Description |
|----------|---------|-------------|
| `postgres_enabled` | `true` | Provision Postgres in Kubernetes. Disable when using an external database URL. |

Credentials are never hardcoded in pod specs: the provisioned password lives in a Kubernetes `Secret` (`{app}-postgres-secret`) and pods receive `JAC_DB_URL` via `valueFrom.secretKeyRef`.

### Consistency model

There is no cache tier and no cross-pod invalidation protocol to configure: each request reads and writes inside one `SERIALIZABLE` Postgres transaction, and **the transaction is the single source of truth**. Racing requests converge via abort-and-replay; see [Persistence -> Concurrent writes](../persistence.md#concurrent-writes-check-then-create-and-convergence). Cross-pod signaling (WebSocket broadcasts, event delivery) rides Postgres `LISTEN`/`NOTIFY` on the same database.

The admin dashboard's Ops page (`/admin/ops`) renders a Postgres health card driven by a live `SELECT 1` probe, so a database incident is visible without kubectl.

---

## Builtins

### Root Access

```jac
with entry {
    # Get all roots in memory/database
    roots = allroots();
}
```

### Memory Commit

```jac
with entry {
    # Commit memory to database
    commit();
}
```

---
