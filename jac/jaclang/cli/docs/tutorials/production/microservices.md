# Service Apps

> **Concept:** [Scale invariance](../../reference/plugins/jac-scale.md#the-scale-invariance-contract): one process and a fleet of services are deployment shapes of the same program text. The boundary is structural, the topology is profile.

A Jac project can run as a single process or as several independently-deployed services, with no source changes between the two. The unit is the **app**: an `[apps.<name>]` table in `jac.toml` with `kind = "service"` makes a module its own service app, and every import of what that app owns compiles to a typed-async **bridge stub** instead of loading the provider into the consumer's process. Calls become RPCs you `await`, but the source still reads like a normal import -- because it *is* a normal import. Both `def:pub` functions and walkers cross the boundary: functions translate to `POST /function/<name>`, walkers to `POST /walker/<name>` plus a return-side rehydration that hands the consumer back a real walker instance with `reports` populated.

This tutorial walks through splitting a tiny project into two apps, running the whole thing from one command (colocated, then as a local fleet), watching the round-trip happen over real HTTP, deferring a spawn through the outbox, and then covers testing and production deployment.

> **Prerequisites**
>
> - Completed: [Local API Server](local.md)
> - Time: ~20 minutes
> - Reference: [Service Apps](../../reference/plugins/jac-scale-http.md#service-apps-cross-app-bridging) in the Scale reference · [Workspaces & Apps](../../reference/apps.md)

---

## Overview

Two apps, one boundary between them. The consumer imports the provider with a regular import, but because the provider is its own app, every call out to it crosses the boundary -- in-process when the two are colocated, `POST /function/<name>` over the wire when they are not. The consumer never loads the provider's code as its own.

```mermaid
graph LR
    Client["Client<br/>(curl, browser)"] -- "POST /function/sum_list" --> Calc["calculator app<br/>port 8002"]
    Calc -- "await add(...) x5" --> Math["math app<br/>colocated, or its own process"]
    Math -- "result" --> Calc
    Calc -- "result" --> Client
```

---

## 1. Set Up the Workspace

Create a project and declare both apps. `jac create --app` writes the tables for you; here they are spelled out so you can see what an app *is*:

```bash
mkdir calc-demo && cd calc-demo
cat > jac.toml <<'EOT'
[project]
name = "calc-demo"
version = "0.1.0"
default-app = "calculator"

[apps.calculator]
kind = "service"
entry-point = "calculator_service"

[apps.math]
kind = "service"
entry-point = "math_service"
EOT
```

Both apps are **file-rooted**: no `path`, so each claims exactly its entry file and nothing else. `default-app` makes a bare `jac run` mean `jac run calculator`. Each serving app answers under its route, `/api/<name>` unless you set `route` -- and two apps claiming the same route is a config error.

> **Why two apps and not one?** One app is one transaction boundary and one process by default. Splitting `math` out means its walkers and functions run on *its* server, the `calculator` app bridges to them, and whether the two share a process is now a run-time choice (`--fleet`) rather than a rewrite. See [the consistency model](../../reference/apps.md#the-consistency-model).

---

## 2. Create the Provider

`math_service.jac` exposes three public functions and one boundary type.

```jac
# math_service.jac -- the entry file of [apps.math]
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

The `def:pub` modifier is what puts a function on the app's **bridge surface**: only public functions get registered as `/function/<name>` endpoints, and a consumer that imports anything else is refused at compile time (`E5106`). `DivResult` is a boundary type -- it crosses the wire as JSON and gets re-hydrated on the consumer side.

---

## 3. Create the Consumer

`calculator_service.jac` imports from the provider with a plain import and uses the imported functions like ordinary local calls -- awaited, because a bridged call is a coroutine.

```jac
# calculator_service.jac -- the entry file of [apps.calculator]
import from math_service { add, multiply, divide, DivResult }

async def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = await add(result, n);  # bridged to the math app
    }
    return result;
}

async def:pub dot_product(a: list[int], b: list[int]) -> int {
    result = 0;
    for i in range(len(a)) {
        result = await add(result, await multiply(a[i], b[i]));
    }
    return result;
}

async def:pub safe_divide(a: float, b: float) -> DivResult {
    return await divide(a, b);  # boundary type round-trips
}
```

Read this file as if `add`, `multiply`, and `divide` were local functions with one difference: the `await`. Nothing in the import says "remote" -- the compiler classifies the import by the **owner** of what it names. `math_service.jac` belongs to the `math` app, the importer belongs to `calculator`, so the import is a bridge and the stubs are coroutines. Forget the `await` and `jac check` says so:

```text
error[E1042]: Expected int, but got Coroutine[Any, Any, int] -- this call returns a coroutine that was not awaited
```

Check the workspace before running it:

```bash
jac check
```

With no paths, `jac check` compiles one program per app (each diagnostic prefixed `[calculator]` / `[math]` when there is anything to say) and sweeps any file no app reached.

---

## 4. Run the Workspace

From the `calc-demo` directory, start the default app:

```bash
jac run --port 8002
```

That is all. The consumer's service apps are brought up **before** it serves the first request. By default they are **colocated**: the `math` app's entry module is loaded into the same process and registered as a local provider, so `await add(...)` runs in-process -- no sockets, but still through the bridge, still awaited, still a cut. One command, one process, the whole workspace.

To run the apps apart on your machine, ask for a **fleet**:

```bash
jac run --port 8002 --fleet
```

Now `math` is its own local process behind the `calculator` app's gateway, and the same `await add(...)` is a `POST /function/add` over loopback. Transitive providers come along either way: if `math` bridged to a third app, that app would be colocated or started too. Startup is **fail-fast**: if any service app fails to come up (missing entry file, syntax error, port in use), the served app exits at startup with the underlying error -- at deploy time, not at first request.

### Which topology a local run picks

`[apps]` describes the cut; the topology is a run-time choice:

| Command | Topology |
|---------|----------|
| `jac run` | One process: the service apps are colocated in the served app's process (with vite and HMR under `--dev`) |
| `jac run --fleet` | Gateway + one local process per service app; the served app is the fleet's root member and runs behind the gateway |
| `jac run --dev --fleet` | The same fleet, dev client included: the root member runs vite and HMR behind the gateway |
| `[scale.gateway] colocate = false` | Every local run is a fleet, as if `--fleet` were passed |

In a fleet run the served app owns the project root: `/`, `/cl/<page>`, `/static/client.js` and any client-side route the fleet does not claim reach it through the gateway (in `--dev` at its vite dev server, with its own API as the fallback, so a client dev server that dies costs HMR, not the site). Root ownership needs a root member that actually serves a client, so a deployed gateway pod is unaffected and keeps serving the client bundle its image staged.

`/cl/<page>` is not exclusive: it stays a discovery family, with the root member asked first and a page it does not serve still reaching the service app that does.

Because the root member compiles the client, it starts and finishes booting before the rest of the fleet -- a module another member analyzed first reaches the client backend with its calls unresolved. The service apps then start in parallel behind it; `[scale.gateway] app_boot_timeout` bounds that wait, and a headless fleet skips it entirely.

A service app still compiling never costs the fleet its routes either: the gateway keeps asking for its `/openapi.json` until it is healthy, and never caches what it said before then.

`jac run --show` prints one plan row per app (`app`, `kind`, `entry`, `action`, `client`, `route`) without running anything.

---

## 5. Watch the Round-Trip

From a second terminal, exercise the consumer:

```bash
# Cross-app: 5 add() calls under the hood
curl -X POST http://localhost:8002/function/sum_list \
  -H "Content-Type: application/json" \
  -d '{"numbers":[1,2,3,4,5]}'
```

```json
{"ok":true,"type":"response","data":{"result":15,"reports":[]},"error":null,"meta":{"extra":{"http_status":200}}}
```

In fleet mode the consumer's terminal shows the `sum_list` call followed by five `POST /function/add` lines from the `math` process -- one per iteration of the loop -- before the outer `sum_list` closes out:

```text
Executing function 'sum_list' with params: {'numbers': [1, 2, 3, 4, 5]}
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
127.0.0.1 - "POST /function/add HTTP/1.1" 200 -
  127.0.0.1:52652 - "POST /function/sum_list HTTP/1.1" 200
```

That is the proof: the consumer's loop is fanning out to the provider on each iteration, over real HTTP. Run it colocated and the five lines vanish while the result stays identical -- the topology changed, the program did not.

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

`def:pub` is one of two shapes that can cross the boundary; the other is a walker. A walker imported from another app becomes a remote spawn: the consumer-side stub class accepts the walker's `has` fields as keyword arguments, spawns it on the provider (`POST /walker/<name>` when apart), and -- awaited -- returns the executed walker with its fields and `reports` populated, the same shape you'd get from a local spawn.

Add a walker to `math_service.jac`:

```jac
walker Greet {
    has name: str;
    can greet with Root entry {
        report f"hello, {self.name}";
    }
}
```

Then in `calculator_service.jac`, list `Greet` alongside the functions and use it from one of the consumer's own walkers:

```jac
import from math_service { add, multiply, divide, Greet, DivResult }

walker:pub TriggerGreet {
    has who: str;
    async can run with Root entry {
        rg = await Greet(name=self.who);   # spawn on the math app
        report rg.reports[0];              # "hello, <who>"
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

In fleet mode the provider log shows the cross-app hop: `POST /walker/Greet 200`. The consumer's `Greet(name=self.who)` reads exactly like a local construction; the compiler swaps it for a bridged spawn at compile time.

A few things to know:

- **Spawn semantics, not construction.** Locally, `Greet(name="x")` only constructs a walker; you still need `spawn` to run it. Across the boundary there's no useful concept of an unexecuted remote walker, so instantiating a bridged walker is **spawn-and-execute** and, awaited, always yields a post-execution instance.
- **Walkers are on the bridge surface as declared; functions need `def:pub`.** A `def` without `:pub` is private to its app and a consumer that imports it gets `E5106`.
- **Boundary types still flow through.** A walker that emits an `obj` value via `report` comes back as that type, not as a raw dict, as long as the type is also listed in the import.
- **Same observability as functions.** Walker calls share the per-provider circuit breaker, retries, and `X-Trace-Id` propagation with function calls.

### Fire and Forget: the Outbox

Sometimes the consumer does not need the answer -- a notification, an audit record, a recount that can lag. Spawn the bridged walker as a **statement and do not await it**:

```jac
walker:pub RecordVisit {
    has who: str;
    can run with Root entry {
        Greet(name=self.who);     # un-awaited, statement position: deferred delivery
        report "recorded";
    }
}
```

This is not a dropped coroutine. An un-awaited cross-app spawn lowers to a **deferred** spawn: it is written to the outbox inside this request (same transaction where the store allows), and a background worker delivers it to the `math` app with exponential backoff -- at least once, with an idempotency key (`X-Jac-Idempotency-Key`) the receiver dedupes on, so a retry after a lost acknowledgement does not run the walker twice. After eight failed attempts the entry is dead-lettered (`outbox.dead_letters()`). The call site **never raises**: the caller's request commits whether or not `math` is reachable right now.

That is the consistency model in two lines: `await` when you need the answer inside this request (ACID within an app), plain statement when you need it to happen eventually (eventual across apps). See [Deferred delivery](../../reference/plugins/jac-scale-http.md#deferred-delivery-the-outbox) for keys and storage.

### When the Bridge Fails

An awaited call that cannot complete raises one of the `BridgeError` family from `jaclang.server.bridge` -- `BridgeUnavailable` (no route to the provider), `BridgeTimeout`, `BridgeRejected` (4xx: not `pub`, unauthorized, bad arguments), or `BridgeError` (anything else) -- each with `app`, `name`, `detail` and `status`. Catch where you want graceful degradation:

```jac
import from jaclang.server.bridge { BridgeError, BridgeUnavailable }

async def:pub sum_or_zero(numbers: list[int]) -> int {
    try {
        return await sum_list(numbers);
    } except BridgeUnavailable {
        return 0;                      # math is down; degrade
    } except BridgeError as e {
        raise RuntimeError(f"math failed: {e.detail}");
    }
}
```

Exception parity with an in-process spawn is the contract: the same `try` works whether `math` is colocated, a sibling process, or a pod two clusters away.

---

## 6. Test the Boundary In-Process

When you write tests for the consumer, you do not want them to hit a real provider over HTTP. Instead, register an in-process test client (a `JacTestClient`) for each provider **app**, and the consumer's bridged calls route through it directly -- no sockets, no port allocation, no background threads.

The core pattern is three lines:

```jac
import from jaclang.server { sv_client }

with entry {
    sv_client.clear_test_clients();
    sv_client.register_test_client("math", math_test_client);
    # ...the consumer's bridge stubs into the math app now go through math_test_client
}
```

The key is the **app name** (`"math"`), exactly as in `[apps.math]`. Always call `sv_client.clear_test_clients()` between tests to avoid bleed-over from a previous test's registrations.

`JacTestClient.from_file` builds a whole app in-process from its entry file; the [Testing section](../../reference/plugins/jac-scale-http.md#testing) of the Scale reference has the full harness, and the cross-app test suite in the compiler tree (`jac/tests/compiler/test_cross_app_import.jac` with its `fixtures/apps/` workspace) shows what the compiler guarantees at each seam.

---

## 7. Going to Production

Colocated and `--fleet` cover one host. Once your apps live on **different hosts** you tell each consumer where its providers are with the `JAC_APP_<APP>_URL` environment variable: the app name upper-cased (non-alphanumerics become `_`), and the value takes precedence over colocation.

### Local Multi-Process

Before jumping to containers, you can test the multi-host flow on your own machine by running each app as its own `jac run` and wiring the consumer with an env var.

Open two terminals, both in the `calc-demo` directory.

**Terminal 1 -- start the provider:**

```bash
jac run math --port 8001
```

**Terminal 2 -- start the consumer pointed at the provider URL:**

```bash
JAC_APP_MATH_URL=http://localhost:8001 jac run calculator --port 8002
```

Hitting `/function/sum_list` on port 8002 now produces the same round-trip as before, except the provider logs appear in Terminal 1. This is the stepping stone to a real multi-host deployment: the env var is the only thing pointing the consumer at the provider, and swapping `localhost` for a cluster DNS name or public hostname is the only change you make when you deploy.

### Kubernetes

`jac scale deploy` **always deploys a fleet**: every serving app becomes its own Deployment + Service + HPA + PodDisruptionBudget, the deployed app hosts the gateway pod that fronts each service app at its route (`/api/math`, ...), and every pod gets its peers' `JAC_APP_<APP>_URL` injected, pointing at the in-cluster Service DNS (`math` → `math-service.<namespace>.svc.cluster.local`). Providers boot before consumers, in the order of the app graph the compiler recorded. `[scale.gateway] colocate` is ignored on deploy.

```bash
jac scale deploy
```

Per-app settings -- replicas, resources, `rpc_timeout` (bump to 120-300s for LLM-backed apps), `http_activation`, extra `env` -- live in each app's overlay:

```toml
[apps.math.scale]
rpc_timeout = 120.0
hpa = { enabled = true, min = 2, max = 10, cpu_target = 60 }

[apps.calculator.scale]
replicas = 2
```

The gateway's own knobs live under `[scale.gateway]` -- and the whole error envelope, tracing and drain story with them:

| Concern | Config | Default |
|---------|--------|---------|
| Colocate service apps under `jac run` | `colocate = true` | true (`--fleet` overrides) |
| Graceful shutdown | `[serve.timeouts] drain = 10.0` | 10s |
| Per-app bridged-call timeout | `[apps.NAME.scale] rpc_timeout = 120.0` | 10s |
| Boot-time per-app /healthz wait | `boot_health_timeout = 60.0` | 60s |
| Boot-time overall startup window | `boot_max_wait = 90` | 90s |
| Root member's head start (it compiles the client, so it boots alone) | `app_boot_timeout = 900.0` | 900s, a stall budget: the clock resets while it is still writing to its log |
| Background recovery health-check cadence | `health_monitor_interval = 10.0` | 10s (2s while anything is unhealthy) |
| CORS | `[scale.gateway.cors] allow_origins = [...]` | open (`["*"]`); set to `[]` to disable |
| Rate limiting | `[scale.gateway.rate_limit] enabled = true, per_ip_rpm = 600, per_user_rpm = 120` | disabled |
| Centralised logs (Loki + Alloy) | `[scale.gateway.logs] enabled = true` | disabled -- see [Centralised Logs](../../reference/plugins/jac-scale-kubernetes.md#centralised-logs) |

The gateway exposes a standard error envelope (`{ok, error: {code, message, service?, trace_id}, meta}`) across every failure path; `X-Trace-Id` is minted if absent and threaded through every hop. WebSockets (`/ws/*`) and SSE / chunked responses flow through the gateway transparently. On `SIGTERM` (or `jac scale stop`), each app flips a drain flag (new requests get `503` with `Retry-After: 1`) and the server waits up to `[serve.timeouts] drain` for in-flight requests to complete before exiting. Mirrors K8s `terminationGracePeriodSeconds`.

For the full deploy pipeline (image building, ingress, autoscaling, secrets, shared volumes), see the [Kubernetes tutorial](kubernetes.md) and [Service Apps in Kubernetes](../../reference/plugins/jac-scale-kubernetes.md#service-apps-in-kubernetes).

### Previewing a deploy with `--dry-run`

`jac scale deploy` builds, pushes and applies. `jac scale deploy --dry-run` does the same planning step in under a second, lints the config, and prints a per-app summary of what would be applied. Nothing is built, pushed, or applied.

```bash
jac scale deploy --dry-run
```

Output (default, card view):

```text
=== jac scale plan: dry-run ===
Cluster:    <active-kube-context>    Namespace: calc-demo
check: no errors or warnings

Apps (3)

  calculator
    image:     calc-demo:v1.0
    replicas:  2  (HPA: 2 -> 10 @ 70% CPU)
    resources: cpu 100m -> 500m    mem 128Mi -> 256Mi
    port:      8000
    route:     /api/calculator  (via gateway)
    pdb:       maxUnavailable=1

  math
    image:     calc-demo:v1.0
    replicas:  2  (HPA: 2 -> 10 @ 60% CPU)
    resources: cpu 50m -> 200m     mem 64Mi -> 128Mi
    port:      8000
    route:     /api/math  (via gateway)

  __gateway__
    image:     calc-demo:v1.0
    replicas:  1
    resources: cpu 50m -> 200m     mem 64Mi -> 128Mi
    port:      8000

Totals
  3 deployments, 3 services, 2 HPAs, 3 PDBs

To see the raw YAML manifests, re-run with --show-yaml
```

The `__gateway__` entry has `replicas: 1` and no HPA line -- the default, and a single point of failure for all external traffic. See [Gateway High Availability](../../reference/plugins/jac-scale-kubernetes.md#gateway-high-availability) for how to give it a second replica under `[scale.gateway]`.

The summary line at the top tells you whether the plan is deployable: `check: no errors or warnings` is safe to apply; `! N warnings` is advisory; `X N errors` blocks the apply with exit code 2. Errors and warnings appear inline on the app card they belong to. Use `--dry-run` whenever you edit `jac.toml` (apps, routes, resources, ingress, secrets, HPA, PDB), add or remove an app, or want a reviewer to see the plan in a PR. For the raw YAML stream, add `--show-yaml`:

```bash
jac scale deploy --dry-run --show-yaml | sed -n '/^---$/,$p' > planned.yaml
diff <(kubectl get -n calc-demo deployment,service,hpa,pdb,ingress -o yaml) planned.yaml
```

---

## Common Pitfalls

If an endpoint reports an invalid anchor, check its ID, the selected app and store, and recent schema changes. Run `jac guide jac-debugging --section diagnose-state-and-cache-errors` for the diagnostic sequence. Preserve existing data until you have identified the cause and chosen a repair.

- **`E1042` on a call that looks local.** The imported element is owned by another app, so the stub is a coroutine: `await` it and make the enclosing function or ability `async`.
- **`E5106` on an import.** The consumer names something that is not on the provider's bridge surface. Mark the function `def:pub`, or move it into shared code (a module under no app root) if both apps need it in-process.
- **`E5104`.** Your apps bridge in a circle. Move the shared piece into shared code, or merge the apps.
- **`BridgeUnavailable: app 'math' is not registered`.** The provider is neither colocated (no `[apps.math]` in this workspace) nor reachable (no `JAC_APP_MATH_URL`) at the first awaited call.
- **`BridgeRejected` with status 401.** `:priv` endpoints are JWT-gated; the hop forwards the inbound `Authorization` header, but an anonymous chain has none. Keep the cross-app surface on `def:pub` / walkers.
- **`Error: No jac.toml found`.** `jac run <app>` needs the workspace's `jac.toml` in the current directory or an ancestor.

---

## What You Built

Two apps that read like a single program. The split happened at *declaration* time -- one `[apps.math]` table -- and the topology at *run* time: the same `calculator_service.jac` runs unchanged whether `math` is colocated in its process, a sibling process behind the gateway, a separate `jac run` on another host, or a Kubernetes Deployment two clusters away.

## Next Steps

- [Service Apps reference](../../reference/plugins/jac-scale-http.md#service-apps-cross-app-bridging) for the discovery chain, the `BridgeError` family, the outbox, and the `sv_client` API.
- [Workspaces & Apps](../../reference/apps.md) for membership, ownership, the app DAG, per-app config, and the flagship layout (a web app, a mobile app, a CLI and two service apps over one `core/`).
- [Kubernetes tutorial](kubernetes.md) for the full deployment pipeline.
- [Backend Integration](../fullstack/backend.md) for the client-to-server flavor of the bridge, where a browser client calls a server.
