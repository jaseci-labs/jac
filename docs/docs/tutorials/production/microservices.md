# Microservices with `sv import`

A Jac codebase can run as a single monolith or as several independently-deployed microservices, with no source changes between the two. The trick is the `sv import` keyword: when both the importer and the importee are server-context modules, the compiler generates an HTTP client stub for the imported symbol instead of pulling the provider into the consumer's process. Calls become RPCs over the wire, but the source still reads like a normal import. Both `def:pub` functions and `walker:pub` archetypes are supported -- functions translate to `POST /function/<name>`, walkers to `POST /walker/<name>` plus a return-side rehydration that hands the consumer back a real walker instance with `reports` populated.

This tutorial walks through splitting a tiny app into two services, running the whole thing from one command, watching the round-trip happen over real HTTP, and then covers testing and multi-host production deployment.

> **Prerequisites**
>
> - Completed: [Local API Server](local.md)
> - Time: ~20 minutes
> - Reference: [Microservice Interop in jac-scale](../../reference/plugins/jac-scale.md#microservice-interop-sv-to-sv)

---

## Overview

Two services, one HTTP boundary between them. The consumer's `sv import` looks identical to a regular import, but every call out to the provider is a `POST /function/<name>` over the wire. The consumer never loads the provider's code into its own memory.

The default single-host deployment runs the whole app from one `jac start` command: the consumer brings the provider up automatically before serving the first request.

```mermaid
graph LR
    Client["Client<br/>(curl, browser)"] -- "POST /function/sum_list" --> Calc["calculator_service<br/>port 8002"]
    Calc -- "POST /function/add (x5)" --> Math["math_service<br/>auto-started sibling"]
    Math -- "result" --> Calc
    Calc -- "result" --> Client
```

---

## 1. Set Up the Project

Create a working directory with a `jac.toml` so `jac start` recognizes it as a project. The two services live side by side in the same directory.

```bash
mkdir microservices-demo && cd microservices-demo
cat > jac.toml <<'EOF'
[project]
name = "microservices-demo"
version = "0.1.0"
EOF
```

> **Why `jac.toml`?** `jac start <relative-path>` requires a `jac.toml` in the current directory. Without one, you get `Error: No jac.toml found`. The services also need to live in the same directory so the consumer can find and auto-start the provider at runtime, so a shared project layout is the simplest path.

---

## 2. Create the Provider

`math_service.jac` exposes three public functions and one boundary type.

```jac
# math_service.jac
obj DivResult {
    has result: float | None = None,
        error: str = "";
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

def:pub multiply(a: int, b: int) -> int {
    return a * b;
}

def:pub divide(a: float, b: float) -> DivResult {
    if b == 0.0 {
        return DivResult(error="division by zero");
    }
    return DivResult(result=a / b);
}
```

The `def:pub` modifier is required: only public functions get registered as `/function/<name>` endpoints, and the consumer's generated stub will 404 against anything else. `DivResult` is a boundary type -- it crosses the wire as JSON and gets re-hydrated on the consumer side.

---

## 3. Create the Consumer

`calculator_service.jac` imports from the provider with `sv import` and uses the imported functions like ordinary local calls.

```jac
# calculator_service.jac
sv import from math_service { add, multiply, divide, DivResult }

def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = add(result, n);  # HTTP call to math_service
    }
    return result;
}

def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        result = add(result, multiply(a[i], b[i]));
    }
    return result;
}

def:pub safe_divide(a: float, b: float) -> DivResult {
    return divide(a, b);  # boundary type round-trips
}
```

Read this file as if `add`, `multiply`, and `divide` were local functions. The compiler swaps them out for HTTP stubs at compile time, but the call site does not change.

---

## 4. Run the App

From the `microservices-demo` directory, start the consumer:

```bash
jac start calculator_service.jac --port 8002
```

That is all. The consumer finds every service it `sv import`s from (`math_service`, in this case) and brings them up automatically inside the same process before serving the first request. Transitive dependencies come along for free: if `math_service` itself had an `sv import`, that provider would also be auto-started. One command, whole cluster.

Startup is **fail-fast**: if any service fails to come up (missing source file, syntax error, port in use), the consumer crashes at startup with the underlying error. You find out at deploy time, not at first request.

A couple of things to know about the auto-started services:

- **They are loopback-only.** Auto-started services bind `127.0.0.1`, not `0.0.0.0`, so they cannot serve traffic to other hosts. Single-command mode is a supported deployment for **single-host** setups. When your providers live on different hosts, see [Section 7: Going to Production](#7-going-to-production).
- **Avoid ports 18000-18999 for your own `--port` flags.** That range is reserved for auto-started sibling services, and a manual port in that range can collide with a future auto-start. Pick something in the 8000s for explicit external ports.

---

## 5. Watch the Round-Trip

From a second terminal, exercise the consumer:

```bash
# Cross-service: 5 add() calls under the hood
curl -X POST http://localhost:8002/function/sum_list \
  -H "Content-Type: application/json" \
  -d '{"numbers":[1,2,3,4,5]}'
```

```json
{"ok":true,"type":"response","data":{"result":15,"reports":[]},"error":null,"meta":{"extra":{"http_status":200}}}
```

Back in the consumer's terminal you will see the consumer's `sum_list` call followed by five `POST /function/add` lines from the auto-started `math_service` sibling -- one per iteration of the loop -- before the outer `sum_list` closes out:

```text
Executing function 'sum_list' with params: {'numbers': [1, 2, 3, 4, 5]}
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
  127.0.0.1:52652 - "POST /function/sum_list HTTP/1.1" 200
```

That is the proof: the consumer's loop is fanning out to the provider on each iteration, over real HTTP. The auto-started sibling is a separate server inside the same process, not a function call.

### Boundary Type Round-Trip

`safe_divide` returns a `DivResult` from the provider, which the consumer hands back to its own caller. The compiler generates a matching wrapper on the consumer side that serializes and deserializes the type across the wire, so callers see a normal `DivResult` on both sides of the boundary.

```bash
curl -X POST http://localhost:8002/function/safe_divide \
  -H "Content-Type: application/json" \
  -d '{"a":10.0,"b":2.0}'
```

```json
{"ok":true,"type":"response","data":{"result":{"_jac_type":"DivResult","_jac_id":"...","_jac_archetype":"archetype","error":"","result":5.0},"reports":[]},"error":null,"meta":{"extra":{"http_status":200}}}
```

```bash
curl -X POST http://localhost:8002/function/safe_divide \
  -H "Content-Type: application/json" \
  -d '{"a":10.0,"b":0.0}'
```

```json
{"ok":true,"type":"response","data":{"result":{"_jac_type":"DivResult","_jac_id":"...","_jac_archetype":"archetype","error":"division by zero","result":null},"reports":[]},"error":null,"meta":{"extra":{"http_status":200}}}
```

Both error and success cases survive the boundary intact. The `_jac_type` metadata lets the consumer's runtime hand the caller a real `DivResult` instance, not a raw dict; `_jac_id` and `_jac_archetype` are envelope bookkeeping the runtime uses to hydrate the object on the other side.

### Walker Imports

`def:pub` is one of two shapes that can cross the sv boundary; the other is `walker:pub`. A walker imported through `sv import` becomes a remote spawn: the consumer-side stub class accepts the walker's `has` fields as keyword arguments, fires off a `POST /walker/<name>` over the wire, and returns the executed walker with its fields and `reports` populated -- the same shape you'd get from a local spawn.

Add a walker to `math_service.jac`:

```jac
walker:pub Greet {
    has name: str;
    can greet with Root entry {
        report f"hello, {self.name}";
    }
}
```

Then in `calculator_service.jac`, list `Greet` alongside the functions and use it from one of the consumer's own walkers:

```jac
sv import from math_service { add, multiply, divide, Greet, DivResult }

walker:pub TriggerGreet {
    has who: str;
    can run with Root entry {
        rg = Greet(name=self.who);   # POST /walker/Greet on the provider
        report rg.reports[0];        # "hello, <who>"
    }
}
```

Hit it the same way you'd hit any walker endpoint:

```bash
curl -X POST http://localhost:8002/walker/TriggerGreet \
  -H "Content-Type: application/json" \
  -d '{"who":"world"}'
```

```json
{"ok":true,"type":"response","data":{"result":{"_jac_type":"TriggerGreet","_jac_id":"...","_jac_archetype":"walker","reports":[],"who":"world"},"reports":["hello, world"]},"error":null,"meta":{"extra":{"http_status":200}}}
```

The provider log shows the cross-service hop: `POST /walker/Greet 200`. The consumer's `Greet(name=self.who)` call site reads exactly like a local construction; the compiler swaps it for an HTTP spawn at compile time.

A few things to know:

- **Spawn semantics, not construction.** Locally, `Greet(name="x")` only constructs a walker; you still need `spawn` to run it. Across the boundary there's no useful concept of an unexecuted remote walker, so instantiating a sv-imported walker is **spawn-and-execute** and always returns a post-execution instance.
- **`walker:pub` only.** Private walkers don't get an endpoint. The same 404 you'd see for non-public functions also fires for non-public walkers.
- **Boundary types still flow through.** A walker that emits an `obj` value via `report` comes back as that type, not as a raw dict, as long as the type is also listed in the `sv import`.
- **Same observability as functions.** Walker calls share the per-provider circuit breaker, retries, and `X-Trace-Id` propagation with function calls. See the [jac-scale reference](../../reference/plugins/jac-scale.md#walker-imports) for the full contract.

---

## 6. Test the Boundary In-Process

When you write tests for the consumer, you do not want them to hit a real provider over HTTP. Instead, register an in-process `TestClient` for each provider, and the consumer's calls route through it directly -- no sockets, no port allocation, no background threads.

The core pattern is three lines:

```jac
import from jaclang.runtimelib { sv_client }

with entry {
    sv_client.clear_test_clients();
    sv_client.register_test_client("math_service", math_test_client);
    # ...the consumer's sv-imported calls into math_service now go through math_test_client
}
```

Always call `sv_client.clear_test_clients()` between tests to avoid bleed-over from a previous test's registrations.

The pieces left unshown here -- building a `TestClient` over a consumer and provider from the same source tree -- require hands-on use of the jac-scale server-construction APIs and are currently more verbose than the tutorial should be. The sv-to-sv test suite in the jac-scale source tree has a worked example that copies fixtures into a temp directory and stands both sides up end-to-end. Start there if you need a ready-to-run harness.

---

## 7. Going to Production

Single-command mode is great for a single host, but once your services live on **different hosts** you need to tell each consumer where its providers actually are. The mechanism is the `JAC_SV_<UPPERCASED_MODULE>_URL` environment variable: when set, it takes precedence over auto-start and points the consumer at the URL you provide. The module name is exactly what you wrote after `sv import from`, upper-cased.

### Local Multi-Process

Before jumping to containers, you can test the multi-process flow on your own machine by running each service as its own `jac start` and wiring the consumer with an env var.

Open two terminals, both in the `microservices-demo` directory.

**Terminal 1 -- start the provider:**

```bash
jac start math_service.jac --port 8001
```

**Terminal 2 -- start the consumer pointed at the provider URL:**

```bash
JAC_SV_MATH_SERVICE_URL=http://localhost:8001 \
    jac start calculator_service.jac --port 8002
```

Hitting `/function/sum_list` on port 8002 now produces the same round-trip as single-command mode, except the provider logs appear in Terminal 1 instead of being interleaved with the consumer's output. This is the stepping stone to a real multi-host deployment: the env var is the only thing pointing the consumer at the provider, and swapping `localhost` for a cluster DNS name or public hostname is the only change you make when you deploy.

### Kubernetes

```yaml
# inventory-service: provider
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
spec:
  template:
    spec:
      containers:
      - name: inventory-service
        image: my-registry/inventory-service:latest
        ports:
        - containerPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
spec:
  selector:
    app: inventory-service
  ports:
  - port: 8000
---
# order-service: consumer, points at inventory-service via cluster DNS
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      containers:
      - name: order-service
        image: my-registry/order-service:latest
        env:
        - name: JAC_SV_INVENTORY_SERVICE_URL
          value: "http://inventory-service.default.svc.cluster.local:8000"
```

Hyphens in module names become underscores in the env var name; dots stay as dots.

For the full Kubernetes deployment story (image building, ingress, autoscaling), see the [Kubernetes tutorial](kubernetes.md) -- it applies here unchanged, you just deploy each service separately and wire them with env vars.

### Microservice Mode + Gateway

For projects with more than a handful of services, `jac-scale` ships a microservice mode that puts a single API gateway in front of all of them. `jac setup microservice` writes the plumbing into `jac.toml` and `jac start` on the project root brings the whole stack up -- one public port, one unified `/docs`, one `/metrics` endpoint, one shared anchor store. The same source still runs as a monolith when microservice mode is disabled.

The gateway exposes a standard error envelope (`{ok, error: {code, message, service?, trace_id}, meta}`) across every failure path (proxy, passthrough, aggregation). Drop-in observability: `X-Trace-Id` is minted if absent and threaded through every `sv` RPC hop. The following knobs all live under `[plugins.scale.microservices]` and are emitted as commented reference blocks by `jac setup microservice`:

| Concern | Config | Default |
|---------|--------|---------|
| Graceful shutdown | `drain_timeout_seconds = 10` | 10s |
| Per-service RPC timeout | `[...services.NAME] rpc_timeout = 120.0` | 10s |
| CORS | `[...cors] allow_origins = [...]` | open (`["*"]`); set to `[]` to disable |
| Rate limiting | `[...rate_limit] enabled = true, per_ip_rpm = 600, per_user_rpm = 120` | disabled |

WebSockets (`/ws/*`) and SSE / chunked responses flow through the gateway transparently -- no config. On `SIGTERM` (or `jac scale stop`), each service flips a drain flag (new requests get `503` with `Retry-After: 2`) and uvicorn waits up to `drain_timeout_seconds` for in-flight requests to complete before exiting. Mirrors K8s `terminationGracePeriodSeconds`.

The gateway reference lives at [`jac-scale/jac_scale/microservices/docs.md`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac-scale/jac_scale/microservices/docs.md) in the jac-scale source tree.

---

## Common Pitfalls

- **`{"detail":"Invalid anchor id ..."}` 500s.** Stale anchor data persisted from a previous run with a different schema. Stop the server, `rm -rf .jac/data/`, and restart. Not specific to sv-to-sv; any `def:pub` call can hit this after a schema change.
- **Consumer crashes at startup with `ModuleNotFoundError: No module named '<provider>'`.** Automatic startup could not find the provider source in the directory you ran `jac start` from. Either move all services into the same project directory and run `jac start` from there, or set `JAC_SV_<MODULE>_URL` to point at a provider already running elsewhere.
- **Cross-service call returns 404.** The provider function is not declared `def:pub`, or the walker is not declared `walker:pub`. Only public symbols are exposed at the HTTP boundary.
- **`Error: No jac.toml found`.** `jac start <relative-path>` requires a `jac.toml` in the current directory. Run `jac create` (or just create an empty one), or pass an absolute path.
- **Cross-service errors raise an exception.** Network failures, missing services, and error responses from the provider all surface at the call site as an exception. Function-call failures use the message `sv-to-sv RPC '<module>.<func>' failed: <reason>`; walker-spawn failures use `sv-to-sv walker spawn '<module>.<walker>' failed: <reason>`. Catch at the boundaries where you want graceful degradation.

---

## What You Built

Two services that read like a single program. The split happens at deploy time, not source time -- the same `calculator_service.jac` runs unchanged whether `math_service` is a module in the same process, a sibling thread, a separate `jac start`, or a Kubernetes Deployment two clusters away.

## Next Steps

- [Microservice Interop reference](../../reference/plugins/jac-scale.md#microservice-interop-sv-to-sv) for the resolution chain, `sv_client` API, and plugin hook details.
- [Kubernetes tutorial](kubernetes.md) for the full deployment pipeline that packages each service into its own image.
- [Backend Integration](../fullstack/backend.md) for the cl-to-sv flavor of `sv import`, where a browser client calls a server.
