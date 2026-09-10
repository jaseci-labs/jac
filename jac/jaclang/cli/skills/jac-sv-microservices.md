---
name: jac-sv-microservices
description: Connect service apps through awaited bridges and typed errors. Use for cross-app calls, fleet execution, outbox behavior, or service discovery.
---

Services are declared with `[apps.<name>]`, `kind = "service"`, and a required
`entry-point` relative to the project root. An import through another app's
entry forms a bridge. Ordinary helper imports inherit the current app context;
directory layout does not create an app boundary.

Once a module belongs to another app, **plain imports of its walkers and `def:pub` functions lower to typed-async bridge stubs**: the provider is never loaded as the consumer's own code; `await add(1, 2)` calls the `math` app (in-process when colocated, `POST /function/add` when it runs apart), and the source still reads like a normal import. Same code, three topologies: colocated (`jac run <app>`), local fleet (`--fleet`), deployed fleet (`jac scale deploy`). **The boundary is structural, the topology is profile.**

```
# jac.toml
[project]
name = "calc"
default-app = "calculator"

[apps.calculator]
kind = "service"
entry-point = "calculator_service"

[apps.math]                     # service entry: math_service.jac
kind = "service"
entry-point = "math_service"

# math_service.jac (provider - owned by the math app)
obj DivResult {
    has result: float | None = None,
        error: str = "";
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

# calculator_service.jac (consumer - a plain import; math owns the target)
import from math_service { add, DivResult }

async def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = await add(result, n);    # bridged call, one per iteration
    }
    return result;
}
```

```bash
jac check                                       # the workspace gate: one program per app + orphan sweep
jac run --port 8002                             # default-app; math is COLOCATED in this process
jac run --port 8002 --fleet                     # math as its own local process behind the gateway
curl -X POST http://localhost:8002/function/sum_list \
  -H "Content-Type: application/json" -d '{"numbers":[1,2,3,4,5]}'
```

**Bridge stubs are ASYNC in every context** - server-to-server as much as client-to-server. `result = add(1, 2)` without `await` is `E1042` from `jac check` (the type is a coroutine). Make the enclosing `def`/`can` `async`.

**The bridge surface is walkers + `def:pub`.** A plain `def` is private to its app; importing it from another app is `E5106` at compile time (and a 404 `BridgeRejected` if you get past the checker some other way). `:priv` endpoints are JWT-gated; the hop forwards the inbound `Authorization` header but an anonymous chain has none.

**Shared source and state.** Ordinary shared modules compile in each importing
app's context. To give several consumers access to one server's state, declare a
service entry and expose public functions or walkers. `default-app` selects the
CLI default, and placement pins select codespaces; neither assigns an owner.

**The app graph is a DAG.** Consumer → provider edges are recorded per import; a cycle is `E5104` on the import that closes it. Providers boot first.

## Failures: the BridgeError family (awaited calls)

`import from jaclang.server.bridge { BridgeError, BridgeUnavailable, BridgeTimeout, BridgeRejected }` - each carries `app`, `name`, `detail`, `status`:

- `BridgeUnavailable` - no route to the provider (not colocated, not registered, no `JAC_APP_<APP>_URL`, connection refused)
- `BridgeTimeout` - the provider did not answer within `rpc_timeout`
- `BridgeRejected` - 4xx: unknown / non-pub element, unauthorized, bad arguments
- `BridgeError` - anything else (5xx); base class of the three above

Exception parity with an in-process spawn: the same `try { ... } except BridgeUnavailable { ... }` works colocated, in a fleet, and deployed. Client code gets the same four classes from `@jac/runtime`.

## Un-awaited = deferred (the outbox)

A bridged **walker spawn in statement position that is not awaited** is not dropped - it lowers to `Stub._deferred(**kwargs)`: written to the outbox inside the caller's request, delivered by a background worker with exponential backoff (8 attempts, then `dead`), at-least-once with an idempotency key (`X-Jac-Idempotency-Key`; default = hash of app + walker + args; receiver dedupes). **Never raises at the call site.** Use it for notifications, audit records, recounts - anything that must happen eventually but not inside this request.

```
walker:pub post_and_notify {
    has text: str;
    async can run with Root entry {
        posted = await create_tweet(content=self.text);   # need the answer: await (raises on failure)
        notify_followers(tweet_id=posted.id);             # fire-and-forget: outbox, at-least-once
        report posted;
    }
}
```

Explicit key when args alone are not identity: `import from jaclang.server { outbox }; outbox.enqueue("billing", "Charge", {...}, idempotency_key=f"charge:{order_id}")`. Storage: the project's Postgres store when configured, else `.jac/data/outbox.sqlite`. `outbox.dead_letters()` lists the dead.

**ACID within an app per request, eventual across apps.** Reads go to the owner (owner-read); `[apps.<consumer>.scale] read_cache = true` opts into caching effect-free provider reads, invalidated on any effectful call to that provider.

## Discovery chain (first match wins)

1. **Local registration** - the provider app is colocated (`sv_client.register_local(app, module)`, what `jac run` does by default). In-process, no sockets, still awaited.
2. **Test client** - `sv_client.register_test_client(app, client)` routes calls in-process for tests (`import from jaclang.server { sv_client }`; `clear_test_clients()` between tests).
3. **Registered URL** - `sv_client.register(app, url, route="")` programmatically (the fleet orchestrator and `jac scale deploy` do this).
4. **`JAC_APP_<APP>_URL` env var** - the production knob for a provider on another host. App name upper-cased, non-alphanumerics → `_`: `JAC_APP_SOCIAL_GRAPH_URL=http://host:8001` (+ `JAC_APP_SOCIAL_GRAPH_ROUTE` for a non-default route).

Everything is keyed by **app name** (the `[apps]` key), never by module stem. Nothing found = `BridgeUnavailable` at the first awaited call.

## Walker imports = spawn-and-execute

A walker can cross the boundary too - but **constructing it spawns it remotely**. There is no unexecuted remote walker: `await Greet(name="x")` spawns `Greet` on the owner app, executes it, and yields the finished instance with `reports` populated. Keyword args map to `has` fields; `isinstance(rg, Greet)` works. Types used in `has` fields / `report` must be imported alongside the walker.

```
import from core.social_graph { Greet }     # core/social_graph.jac is [apps.social_graph]'s entry

walker:pub TriggerGreet {
    has who: str;
    async can run with Root entry {
        rg = await Greet(name=self.who);    # remote spawn, already executed
        report rg.reports[0];
    }
}
```

The same shape works from client apps (`root spawn Greet(...)` in a page or a mobUI screen) - the flagship's `mobile/` and `cli/` apps are both clients of the `social_graph` service app.

## Boundary types

**Cross the wire:** `obj` types (recursively hydrated - list them in the import alongside the function/walker), `enum`s (by name), primitives, `list[T]`, `dict[K, V]`, `None`.
**Streams cross live:** a provider's streaming endpoint (`-> Generator`) through the stub is a LIVE async generator - iterate and re-yield to forward frames unbuffered (`jac-sv-streaming`).
**Don't:** node/edge anchors, closures, file/DB handles. Pass `jid(node)` strings and re-resolve with `jobj` on the other side.

## Topology: colocated, fleet, deployed

- **Colocated (default).** `jac run <app>` loads every service app it bridges to (transitively, providers first) into its own process. One port, one process, the cut still compiled.
- **Local fleet.** `jac run <app> --fleet`, or `[scale.gateway] colocate = false`: each service app is its own local process behind the served app's gateway - one public port, one `/docs`, one `/metrics`, `X-Trace-Id` threaded through every hop; `jac scale status|logs|restart|stop <app>` manage members. Startup is fail-fast (a service that cannot come up crashes the served app at boot).
- **Deployed.** `jac scale deploy` is ALWAYS a fleet: each serving app its own Deployment/Service/HPA/PDB, the served app hosts the gateway, `JAC_APP_<APP>_URL` injected on every pod (in-cluster DNS - don't set them by hand), boot order from the app DAG; `colocate` is ignored. `--dry-run` previews the per-app plan.

Gateway knobs: `[scale.gateway]` (`gateway_port`, `boot_health_timeout`, `boot_max_wait`, `health_monitor_interval`, `cors`, `rate_limit`, `logs`, `tracing`, `shared_volumes`, `colocate`). Per-app knobs: `[apps.<name>.scale]` (`replicas`, resources, `rpc_timeout` - **default 10s, bump to 120-300 for LLM-backed apps**, `http_activation`, `env`, `hpa`, `pdb`, `triggers`, `deployment_overlay`).

## Pitfalls

- **`E1042` on a call you thought was local** = the target is owned by another app. `await` it; make the caller `async`.
- **`E5106` / 404 `BridgeRejected`** = the element isn't on the bridge surface. `def:pub` it, or move it to shared code if both apps need it in-process.
- **Calls run in-process when you expected RPC** = they are colocated (the default) - that IS the bridge, just without sockets. `--fleet` to split; the code does not change.
- **`E2039`** = an app reaching into another app's non-bridge declarations. Use the declared entry for the public API; helper imports are local to the consumer.
- **`BridgeUnavailable: app 'x' is not registered`** = not colocated (no `[apps.x]` in this workspace) and no `JAC_APP_X_URL`.
- **`Error: No jac.toml found`** - `jac run <app>` needs the workspace's `jac.toml` in the cwd or an ancestor.
- **Invalid anchors after a change:** check the reference, selected app/store, and schema migration state. Follow `jac-debugging` and `jac-sv-persistence`; do not infer that an anchor error requires deleting project data.
- Multi-host = env-var wiring, always. Colocated providers can never serve another machine.
- Route collisions (`[apps.a] route` = `[apps.b] route`, or an app route that a page owns) are hard config errors; the default is `/api/<name>`.
