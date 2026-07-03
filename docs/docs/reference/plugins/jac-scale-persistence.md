# Scale -- Data & Storage

> Part of the [Scale subsystem](jac-scale.md).

## Storage

Jac provides a built-in storage abstraction for file and blob operations. The core runtime ships with a local filesystem implementation, and jac-scale can override it with cloud storage backends -- all through the same `store()` builtin.

### The `store()` Builtin

The recommended way to get a storage instance is the `store()` builtin. It requires no imports and is automatically hookable by plugins:

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
import from http { UploadFile }
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

Storage is configured in `jac.toml` under the `[plugins.scale.storage]` section or via environment variables.

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
[plugins.scale.storage]
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

## Direct Database Access (kvstore)

Direct database operations without graph layer abstraction. Supports MongoDB (document queries), Firestore (Firebase-style document CRUD), and Redis (key-value with TTL/atomic ops).

```jac
import from jaclang.scale.persistence.lib { kvstore }

with entry {
    mongo_db = kvstore(db_name='my_app', db_type='mongodb');
    firestore_db = kvstore(db_name='my_app', db_type='firestore');
    redis_db = kvstore(db_name='cache', db_type='redis');
}
```

**Parameters:** `db_name` (str), `db_type` ('mongodb'|'firestore'|'redis'), `uri` (str|None - priority: explicit → env vars → jac.toml)

### Firestore Configuration

```toml
[plugins.scale.database]
type = "firestore"
project_id = "my-firebase-project"
```

Or via environment variable:

```bash
export FIREBASE_PROJECT_ID="my-firebase-project"
# Subsystem override (optional):
# export FIRESTORE_PROJECT_ID="my-firebase-project"
```

`FIREBASE_PROJECT_ID` is the shared fallback for Auth SSO, Firestore, and Storage. Subsystem-specific vars override it when set.

---

## MongoDB Operations

**Common Methods:** `get()`, `set()`, `delete()`, `exists()`
**Query Methods:** `find_one()`, `find()`, `insert_one()`, `insert_many()`, `update_one()`, `update_many()`, `delete_one()`, `delete_many()`, `find_by_id()`, `update_by_id()`, `delete_by_id()`, `find_nodes()`

**Example:**

```jac
import from jaclang.scale.persistence.lib { kvstore }

with entry {
    db = kvstore(db_name='my_app', db_type='mongodb');

    db.insert_one('users', {'name': 'Alice', 'role': 'admin', 'age': 30});
    alice = db.find_one('users', {'name': 'Alice'});
    admins = list(db.find('users', {'role': 'admin'}));
    older = list(db.find('users', {'age': {'$gt': 28}}));

    db.update_one('users', {'name': 'Alice'}, {'$set': {'age': 31}});
    db.delete_one('users', {'name': 'Bob'});

    db.set('user:123', {'status': 'active'}, 'sessions');
}
```

**Query Operators:** `$eq`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$ne`, `$and`, `$or`

### Querying Persisted Nodes (`find_nodes`)

Query persisted graph nodes by type with MongoDB filters. Returns deserialized node instances.

```jac
with entry{
    db = kvstore(db_name='jac_db', db_type='mongodb');
    young_users = list(db.find_nodes('User', {'age': {'$lt': 30}}));
    admins = list(db.find_nodes('User', {'role': 'admin'}));
}
```

**Parameters:** `node_type` (str), `filter` (dict, default `{}`), `col_name` (str, default `'_anchors'`)

---

## Firestore Operations

**Common Methods:** `get()`, `set()`, `delete()`, `exists()`
**Query Methods:** `find_one()`, `find()`, `insert_one()`, `insert_many()`, `update_one()`, `update_many()`, `delete_one()`, `delete_many()`, `find_by_id()`, `update_by_id()`, `delete_by_id()`

**Example:**

```jac
import from jaclang.scale.lib { kvstore }

with entry {
    db = kvstore(db_name='my_app', db_type='firestore');

    db.insert_one('users', {'name': 'Alice', 'role': 'admin', 'age': 30});
    db.insert_one('users', {'name': 'Bob', 'role': 'user', 'age': 25});

    alice = db.find_one('users', {'name': 'Alice'});
    admins = list(db.find('users', {'role': 'admin'}));
    older = list(db.find('users', {'age': {'$gte': 25}}));

    todo = db.insert_one('todos', {'title': 'Buy milk', 'done': False});
    db.update_by_id('todos', todo.inserted_id, {'$set': {'done': True}});
    done_todos = list(db.find('todos', {'done': True}));
}
```

**Supported filter operators:** `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$and`

**Notes:**

- Firestore collections are namespaced internally as `{db_name}__{col_name}`.
- Querying by `_id` inside `find()` / `find_one()` is not supported; use `get()`, `find_by_id()`, `update_by_id()`, or `delete_by_id()`.
- `find_nodes()` is intentionally not available for Firestore; Jac graph persistence remains on SQLite / MongoDB.

---

## Redis Operations

**Common Methods:** `get()`, `set()`, `delete()`, `exists()`
**Redis Methods:** `set_with_ttl()`, `expire()`, `incr()`, `scan_keys()`, `set_nx_with_ttl()`, `delete_if_equals()`

**Example:**

```jac
import from jaclang.scale.persistence.lib { kvstore }

with entry {
    cache = kvstore(db_name='cache', db_type='redis');

    cache.set('session:user123', {'user_id': '123', 'username': 'alice'});
    cache.set_with_ttl('temp:token', {'token': 'xyz'}, ttl=60);
    cache.set_with_ttl('cache:profile', {'name': 'Alice'}, ttl=3600);

    cache.incr('stats:views');
    sessions = cache.scan_keys('session:*');
    cache.expire('session:user123', 1800);
}
```

**Note:** Database-specific methods raise `NotImplementedError` on wrong database type.

---

## Distributed Locks (Redis only)

When a jac-scale app runs with multiple replicas behind a load balancer, two pods can land on the same shared resource (an EFS-backed file, an external API rate limit, a row in a downstream database) at the same instant. Python's `threading.Lock` only serializes inside one process, so it cannot prevent the race. The kvstore exposes two primitives that together build a correct cross-pod mutex on top of Redis.

### Acquire: `set_nx_with_ttl(key, value, ttl)`

Atomically sets the key only if it does not already exist, with an automatic expiration. Maps to Redis `SET key value NX EX ttl`. Returns `True` if the caller acquired the lock, `False` if another caller already holds it.

The TTL is mandatory: if the holder crashes without releasing, Redis frees the lock automatically after `ttl` seconds, so an orphan never blocks the cluster forever.

### Release: `delete_if_equals(key, expected_value)`

Atomically deletes the key only when its current value matches `expected_value`. Implemented with a server-side Lua script so the GET and DEL run as one operation. Returns `True` if deleted, `False` otherwise.

Pair `delete_if_equals` with `set_nx_with_ttl` and a unique fence token: a slow holder whose TTL expired during a long operation will not delete a lock another caller has since acquired, since the values no longer match.

### Cross-pod mutex pattern

```jac
import os;
import time;
import from uuid { uuid4 }
import from jaclang.scale.persistence.lib { kvstore }

glob _kv = kvstore(db_name='myapp', db_type='redis');

def with_repo_lock(repo_id: str, action: str) -> dict {
    fence = str(uuid4());
    payload = {'fence': fence, 'pod': os.environ.get('HOSTNAME', 'local')};

    # Acquire: retry up to ~25s, give up if contention persists.
    deadline = time.time() + 25.0;
    acquired = False;
    while time.time() < deadline {
        if _kv.set_nx_with_ttl(f'repo_lock:{repo_id}', payload, ttl=30) {
            acquired = True;
            break;
        }
        time.sleep(0.2);
    }
    if not acquired {
        return {'success': False, 'error': 'lock contention timeout'};
    }

    try {
        return run_protected_op(repo_id, action);
    } finally {
        # Release: compare-and-delete. Safe even if our TTL already expired
        # and another pod owns the key now; the value mismatch makes it a no-op.
        _kv.delete_if_equals(f'repo_lock:{repo_id}', payload);
    }
}
```

### Cluster-wide debounce

`set_nx_with_ttl` also collapses N pods running the same periodic task into a single execution per window. No release needed: the TTL is the window length.

```jac
def maybe_run_periodic_task(task_id: str) -> bool {
    payload = {'pod': os.environ.get('HOSTNAME', 'local'), 'ts': time.time()};
    if _kv.set_nx_with_ttl(f'task_dbnce:{task_id}', payload, ttl=60) {
        run_task(task_id);
        return True;
    }
    return False;  # Another pod already ran it within the last 60s.
}
```

This is the right pattern for autosave debouncing, leader-only reconciliation cycles, and any other "exactly once per window across the cluster" requirement.

### When to use which

| Need | Primitive | Release |
|---|---|---|
| Mutual exclusion (only one caller in the cluster runs the protected block) | `set_nx_with_ttl` + retry on `False` | `delete_if_equals` with a unique fence token |
| Debounce (throttle to one execution per window across the cluster) | `set_nx_with_ttl` once, no retry | None: let TTL expire |
| Leader election (one pod holds a long-lived role) | `set_nx_with_ttl` with renewing TTL | `delete_if_equals` on graceful shutdown |

`set_nx_with_ttl` and `delete_if_equals` raise `NotImplementedError` on MongoDB; distributed-lock semantics require Redis.

---

## Event Streaming

Optional event-streaming broker for emitting and consuming events between jac code and external systems. Off by default. Provides durable log, consumer groups, replayable offsets via `start_from`, and at-least-once delivery with retries and a DLQ.

Two implementations ship in-tree:

- **`LocalEventStream`** (in-memory): single-process, no persistence. Used automatically when no Redis URL is configured. Right for dev workstations, tests, and single-pod deployments.
- **`RedisEventStream`** (Redis Streams): durable, cross-pod. Used automatically when a Redis URL resolves and the `[data]` extra is installed.

You don't pick the broker; selection happens at startup based on what's available.

### Enabling

Add the section to `jac.toml`. Master switch is `enabled`; everything else has working defaults.

```toml
[plugins.scale.events]
enabled = true
# Optional. If unset, falls back to [plugins.scale.database].redis_url; if neither
# resolves, the in-memory LocalEventStream is used.
url = "redis://localhost:6379/0"
consumer_group = "jac-scale"
serializer = "json"

[plugins.scale.events.retry]
max_attempts = 3
backoff_seconds = [1, 5, 30]
dead_letter_suffix = ".dlq"
```

To use Redis Streams you need `redis` in the project venv -- configure `[scale.database]` (Redis) and run `jac install`. Without it, scale silently uses `LocalEventStream` and logs a warning at startup.

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

`@subscribe` accepts optional `group=` and `retry=` arguments to override the defaults from `jac.toml`, plus `start_from=` to control where a brand-new consumer group begins reading. Default is `"latest"` (only events produced after the group is created); pass `"earliest"` to replay everything still retained, or a broker-specific position token (e.g. a Redis stream id like `"1700000000000-0"`) to resume from a specific offset. `start_from` is a one-time bookmark: existing groups always resume from their stored position and ignore this argument.

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
| `url` | `null` | Redis URL. If unset, falls back to `[plugins.scale.database].redis_url`. If neither is set or the `redis` extra is missing, `LocalEventStream` (in-memory) is used. |
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

- Each subscription spawns one daemon thread named `jac-scale-broker-<topic>-<group>` (Redis) or `jac-scale-local-<topic>-<group>` (Local). Inspect via standard threading tools.
- Delivery metadata is exposed as first-class fields on `Event`: `event.delivery_id`, `event.delivery_topic`, `event.delivery_group`. Handlers that need them for idempotency keys, structured logging, or dedup can read them directly without importing broker-specific constants. The fields are broker-managed: producers leave them `None`, the broker sets them on `consume()` / push delivery, and they are not serialized to the wire.
- Startup logs `Events broker enabled (kind={local|redis}, subscriptions=N)` so it is easy to confirm wiring at a glance.
- The wire format is CloudEvents 1.0 valid (`specversion`, `type`, `data`, `id`, `source`, `time`, plus `trace_id` and `headers` as extensions), so strict CE consumers (Argo Events, Knative Eventing, CE-aware Kafka tooling) accept it.

---

## Database and Dashboards

### Auto-Provisioning

On the first `jac start app.jac --scale`, jac-scale automatically deploys Redis and MongoDB as Kubernetes StatefulSets with persistent storage. Subsequent deployments only update the application - databases remain untouched.

**What gets provisioned:**

- **MongoDB** - StatefulSet with PersistentVolumeClaim (graph persistence, `kvstore` backend)
- **Redis** - Deployment with persistent storage (cache layer, session management)
- **Application Deployment** - Your Jac app pod(s)
- **NGINX Ingress Controller** - Single NodePort entry point; routes traffic to ClusterIP services by path
- **Services** - ClusterIP services for all components (all traffic goes through the Ingress)
- **ConfigMaps** - Application configuration

| TOML Key | Default | Description |
|----------|---------|-------------|
| `mongodb_enabled` | `true` | Auto-provision MongoDB StatefulSet |
| `redis_enabled` | `true` | Auto-provision Redis Deployment |
| `mongodb_root_username` | `admin` | MongoDB root username - stored as a K8s Secret, injected via `secretKeyRef` |
| `mongodb_root_password` | `password` | MongoDB root password - stored as a K8s Secret, injected via `secretKeyRef` |
| `redis_username` | `admin` | Redis auth username - stored as a K8s Secret, injected via `secretKeyRef` |
| `redis_password` | `password` | Redis auth password - stored as a K8s Secret, injected via `secretKeyRef` |

Credentials are never hardcoded in pod specs. They are stored as Kubernetes `Secret` resources (`{app}-mongodb-secret`, `{app}-redis-secret`) and referenced via `valueFrom.secretKeyRef` - `kubectl describe pod` shows the secret name and key, not the actual value.

**To disable (use an external database instead):**

```toml
[plugins.scale.kubernetes]
mongodb_enabled = false   # Don't deploy MongoDB - use MONGODB_URI instead
redis_enabled = false     # Don't deploy Redis - use REDIS_URL instead

[plugins.scale.database]
mongodb_uri = "mongodb://user:pass@external-host:27017"
redis_url = "redis://external-redis:6379"
```

---

### Connection Configuration

Configure database connection URIs via environment variables or `jac.toml`. **Environment variables take priority over `jac.toml`.**

**Option 1 - Environment variables (recommended for secrets):**

| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB connection URI |
| `REDIS_URL` | Redis connection URL |

```env
# .env
MONGODB_URI=mongodb://user:password@host:27017/mydb
REDIS_URL=redis://host:6379/0
```

**Option 2 - `jac.toml`:**

```toml
[plugins.scale.database]
mongodb_uri = "mongodb://localhost:27017"   # External MongoDB URI (skip auto-provisioning)
redis_url = "redis://localhost:6379"        # External Redis URL (skip auto-provisioning)
shelf_db_path = ".jac/data/anchor_store.db"  # SQLite/shelf path for local dev
```

> `MONGODB_URI` and `REDIS_URL` environment variables take precedence over the `jac.toml` values when both are set.

| TOML Key | Default | Description |
|----------|---------|-------------|
| `mongodb_uri`| None | External MongoDB URI. When set, K8s MongoDB StatefulSet is not provisioned. |
| `redis_url`  | None | External Redis URL. When set, K8s Redis is not provisioned. |
| `shelf_db_path` | `.jac/data/anchor_store.db` | Local shelf/SQLite storage path for `jac start` (no K8s) |
| `redis_l1_invalidation_enabled` | `true` | Broadcast/apply cross-pod L1 cache evictions over Redis pub/sub (see [Memory Hierarchy](#cross-pod-l1-invalidation)). |
| `redis_l1_invalidation_channel` | `"jac:anchor:invalidate"` | Pub/sub channel for L1 invalidation messages; all pods sharing a cache must match. |

---

### Dashboard Configuration

Dashboards are **off by default** and must be explicitly enabled in `jac.toml`:

```toml
[plugins.scale.kubernetes]
redis_dashboard  = true   # Deploy RedisInsight UI (default: false)
mongodb_dashboard = true  # Deploy Mongo Express UI (default: false)
```

| `jac.toml` key | Description | Default |
|----------------|-------------|---------|
| `redis_dashboard` | Deploy RedisInsight dashboard UI | `false` |
| `mongodb_dashboard` | Deploy Mongo Express dashboard UI | `false` |
| `loki_enabled` | Deploy Loki + Alloy log pipeline and add Pod Logs dashboard to Grafana | `false` |

#### Dashboard Credentials

When dashboards are enabled, they are served through the NGINX Ingress at fixed subpaths. No separate NodePorts are needed.

| `jac.toml` key | Description | Default |
|----------------|-------------|---------|
| `redis_insight_username` | RedisInsight basic-auth username | `admin` |
| `redis_insight_password` | RedisInsight basic-auth password | `admin` |
| `mongo_express_username` | Mongo Express login username | `admin` |
| `mongo_express_password` | Mongo Express login password | `admin` |

> **Note:** When `redis_dashboard = true`, the `/cache-dashboard` route is always protected by HTTP basic authentication using the credentials above. Change the defaults before deploying to a shared or public cluster.

**Access URLs:**

| Dashboard | URL |
|-----------|-----|
| Redis Insight | `http://localhost:<ingress_node_port>/cache-dashboard/` |
| Mongo Express | `http://localhost:<ingress_node_port>/db-dashboard` |

**Enable dashboards with custom credentials** (RedisInsight + Mongo Express):

```toml
# jac.toml
[plugins.scale.kubernetes]
redis_dashboard          = true
redis_insight_username   = "admin"
redis_insight_password   = "strongpassword"

mongodb_dashboard        = true
mongo_express_username   = "admin"
mongo_express_password   = "strongpassword"
```

---

### Memory Hierarchy

jac-scale uses a tiered memory system:

| Tier | Backend | Purpose |
|------|---------|---------|
| L1 | In-memory | Volatile runtime state |
| L2 | Redis | Cache layer |
| L3 | MongoDB | Persistent storage |

```mermaid
graph TD
    App["Application"] --- L1["L1: Volatile (in-memory)"]
    L1 --- L2["L2: Redis (cache)"]
    L2 --- L3["L3: MongoDB (persistent)"]
```

#### Cross-Pod L1 Invalidation

L1 is an in-process cache: each request gets a fresh, request-scoped L1 that
loads anchors from L3 and serves repeated reads of the same anchor from memory
for the rest of that request. This is what makes a single request fast, but it
also means that while a request holds an anchor in its L1, a **concurrent
request on another pod** can commit a new version of that same anchor to L3.
Without coordination, the first request keeps serving the stale snapshot it
already loaded.

To prevent that, every write broadcasts a small invalidation message over a
**Redis pub/sub channel**. One daemon listener per process subscribes to that
channel and, on each message, flags the named anchor _stale_ in every _other_
live L1 in the process. The listener never mutates a sibling's cache directly;
instead each owning request, on its next read of that anchor, drops its copy and
reloads fresh from L3 -- but **only if the copy is unmodified**. A request that
has its own uncommitted change to that anchor keeps it, so an in-flight write is
never silently discarded. The writer's own L1 is excluded from the broadcast (it
already holds the freshly merged copy), and deletes/quarantines flag everyone.
The listener self-heals across Redis restarts with capped exponential backoff,
and if Redis or the `redis` extra is unavailable the feature simply stays off:
the system degrades to plain per-request L1s with no cross-pod coherence.

This is on by default whenever a Redis URL resolves. Tune it under
`[plugins.scale.database]`:

| `jac.toml` key | Default | Description |
|----------------|---------|-------------|
| `redis_l1_invalidation_enabled` | `true` | Broadcast and apply cross-pod L1 evictions over Redis pub/sub. |
| `redis_l1_invalidation_channel` | `"jac:anchor:invalidate"` | Pub/sub channel used for invalidation messages. All pods sharing a cache must agree on this value. |

L1 invalidation keeps re-reads fresh, but it is a _post-commit_ signal -- it cannot stop two pods that both read an empty `[-->(?:X)]` _before_ either writes from both creating a child (the check-then-create race). That race is closed separately by node-level optimistic concurrency, which converges the loser via replay; see [Persistence -> Concurrent writes: check-then-create](../persistence.md#concurrent-writes-check-then-create-and-convergence).

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
