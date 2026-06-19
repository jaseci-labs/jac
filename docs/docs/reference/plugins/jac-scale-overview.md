# What jac-scale Actually Does (and How It Fits Together)

If you've built a Jac app with `jac start`, you've already used the built-in HTTP server that turns your `def:pub` functions and walkers into REST endpoints. That server is fine for prototyping; it uses SQLite for persistence and runs on a single process.

jac-scale is the plugin that replaces that built-in server with a production stack. Same `jac start` command, same application code, different runtime underneath. Here's what it wires in and how the pieces connect.

## The Server Layer

jac-scale swaps the built-in HTTP handler for **FastAPI**. Your `def:pub` functions become `POST /function/<name>` endpoints and walkers become `POST /walker/<name>`. You don't write route decorators or request handlers; the plugin inspects your Jac module at startup and registers everything automatically.

You get Swagger docs at `/docs` and a graph visualizer at `/graph` out of the box. If you need WebSocket support (for streaming walker results, for example), that's built in too.

## Tiered Memory

This is the core architectural decision in jac-scale. Graph nodes and edges flow through three layers:

- **L1 (in-memory)**: A per-request dictionary. Fast, but dies with the process.
- **L2 (Redis)**: Shared cache across pods. Survives process restarts, handles session data, and serves as the pub/sub backbone for cross-pod cache invalidation.
- **L3 (MongoDB)**: Durable storage. Every graph anchor that's connected to a user's root eventually lands here.

When a request reads a node, the runtime checks L1 first, then L2, then L3. Writes go to L1 immediately and flush to L2/L3 at commit time. This means most reads during a single request hit memory, not the database.

The cross-pod invalidation piece is worth noting: when one pod writes a node, it publishes an eviction message over Redis pub/sub. Other pods drop that node from their L1 cache so the next read fetches fresh data. This is how you run multiple replicas without stale reads.

## Authentication and User Isolation

Every authenticated user gets their own root node. When a request comes in with a valid JWT, the runtime resolves `root` to that user's personal graph. Unauthenticated requests (on `def:pub` endpoints) land on a shared guest root.

The auth system supports:

- **Username/password** registration and login with JWT tokens
- **SSO providers**: Google, GitHub, and Apple are built in. The SSO flow handles account creation, token minting, and identity linking.
- **Password reset and email verification** via one-time tokens
- **Audit logging** for security-sensitive operations (login attempts, token creation, SSO flows)

User data is stored in an identity-based model: a user can have multiple identities (username, email, phone, SSO accounts) linked to a single graph root.

## Event Streaming

jac-scale includes a pub/sub event system with two backends:

```jac
import from jac_scale.events.publisher { publish }
import from jac_scale.events.subscriber { subscribe }
import from jac_scale.events.broker { Event }

# Publishing an event from anywhere
publish("order.created", Event(data={"order_id": "123", "total": 59.99}));

# Subscribing to a topic
@subscribe("order.created")
def handle_order(event: Event) -> None {
    print(event.event_type, event.data);
}
```

- **LocalEventStream**: In-memory, single-process. No setup needed, good for development.
- **RedisEventStream**: Uses Redis Streams for durability and cross-pod delivery. Events survive restarts, consumers track offsets, and failed messages land in a dead-letter topic.

The implementation picks the right backend automatically based on whether a Redis connection is available. You enable it in `jac.toml`:

```toml
[plugins.scale.events]
enabled = true
```

## Scheduling

Walkers and functions can be scheduled to run on intervals or cron expressions. The scheduler integrates with APScheduler and stores job state in the database so schedules survive restarts.

## Webhooks

If your app needs to receive webhooks from external services (payment providers, GitHub, etc.), jac-scale provides registration and signature verification:

```jac
# Register a webhook endpoint
# Verify signatures, parse payloads, route to handlers
```

## Kubernetes Deployment

This is the `--scale` in `jac start --scale`. When you add that flag, jac-scale:

1. Builds a Docker image of your Jac application
2. Generates Kubernetes manifests
3. Auto-provisions Redis and MongoDB pods with persistent volumes
4. Deploys your app with health checks and service discovery
5. Configures horizontal pod autoscaling (HPA)

The default autoscaler is CPU-based HPA. If you need event-driven scaling (scale on queue depth, scale to zero), you can switch to KEDA:

```toml
[plugins.scale]
autoscaler_engine = "keda"
```

## Microservices

For larger applications, jac-scale supports splitting your app into multiple services:

- A **service registry** tracks what's running and where
- A **gateway** routes requests to the right service and exposes a unified OpenAPI doc
- `sv import` lets one Jac service call another via RPC (this spawns a separate server process)
- A **process manager** and **local deployer** handle service lifecycle

## Admin Portal

jac-scale ships an admin UI (built with Tailwind) that gives you:

- Kubernetes workload management
- Deploy health monitoring
- LLM telemetry (tracking model usage, latency, costs)
- Log viewer
- Network diagnostics
- Trace viewer

## Storage

For file/blob storage, there's an S3 integration for uploading and serving files.

## What the Developer Experience Looks Like

The key design goal is that your application code doesn't change between local development and production deployment. A minimal example:

```jac
node Todo {
    has title: str, done: bool = False;
}

def:pub add_todo(title: str) -> Todo {
    todo = Todo(title=title);
    root ++> todo;
    return todo;
}

def:pub get_todos -> list[Todo] {
    return [root-->][?:Todo];
}
```

Running this locally:

```bash
jac start main.jac
# SQLite persistence, single process, no auth
```

Running this in production:

```bash
jac start main.jac --scale
# FastAPI + Redis + MongoDB + K8s + auth + autoscaling
```

Same code. The plugin handles the infrastructure gap.

## What jac-scale Is Not

It's worth being clear about what this plugin doesn't do:

- **It's not a general-purpose web framework.** You don't write middleware, route handlers, or request/response objects. The API surface is determined by your `def:pub` functions and walkers.
- **It's not database-agnostic.** MongoDB is the primary persistence backend. There's ongoing work on a Postgres plugin and a Firestore backend (currently a stub), but MongoDB is what ships today.
- **It's not a CDN or static hosting solution.** The client-side story (serving built frontends) is handled by jac-client, not jac-scale.

## Installing

```bash
pip install jac-scale
```

Or install everything at once:

```bash
pip install jaseci
```

The `jaseci` meta-package bundles `jaclang`, `byllm`, `jac-client`, `jac-scale`, `jac-super`, and `jac-mcp` together.

---

*jac-scale is part of the [Jaseci](https://github.com/Jaseci-Labs/jaseci) ecosystem. For the full plugin reference, see the [jac-scale documentation](https://docs.jaseci.org/reference/plugins/jac-scale/).*
