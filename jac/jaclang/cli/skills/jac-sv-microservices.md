---
name: jac-sv-microservices
description: Splitting a Jac backend into microservices with the [scale.microservices.routes] table - the service cut in jac.toml (written by `jac scale split`), plain imports that lower to HTTP RPC stubs between server modules, provider discovery (JAC_SV_<MOD>_URL, auto-spawn), remote walker spawns, boundary types, streaming pass-through, the gateway mode. Load when one server module must call another deployed as its own service. Pair with `jac-sv-endpoints`, `jac-sv-deploy` (k8s), `jac-sv-streaming` (SSE across services).
---

Services are declared in ONE place: the `[scale.microservices.routes]` table in `jac.toml`. Each key is a module that runs as its own service process (or pod) behind the gateway; the value is its public route prefix (`""` derives `/<module-slug>`). `jac scale split <module>` writes an entry for you. There is NO discovery from source - no import form declares a service, and a module absent from the table is an ordinary in-process import.

Once a module is in the cut, **plain imports of it lower to RPC stubs automatically**: the provider is never loaded into the consumer's process; calling `add(1, 2)` issues `POST /function/add` against the provider's URL, and the source still reads like a normal import. The same code runs as a monolith (empty routes table), a one-command local cluster, or N Kubernetes deployments - the split lives in config, not source.

```
# jac.toml
[scale.microservices.routes]
math_service = ""            # "" derives the route (/math_service); fine for internal-only services

# math_service.jac (provider - a plain server module)
obj DivResult {
    has result: float | None = None,
        error: str = "";
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

# calculator_service.jac (consumer - a plain import; math_service is in the cut)
import from math_service { add, DivResult }

def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = add(result, n);    # HTTP call per iteration (verified live)
    }
    return result;
}
```

```bash
jac scale split math_service                    # writes the routes entry
jac start calculator_service.jac --port 8002    # consumer auto-starts math_service
curl -X POST http://localhost:8002/function/sum_list \
  -H "Content-Type: application/json" -d '{"numbers":[1,2,3,4,5]}'
```

**Server-to-server stubs are SYNCHRONOUS** - call them like local functions, no `await` (the stub blocks on the HTTP hop and resolves directly to the typed result). This is the opposite of client-to-service stubs, which are async and must be awaited (`jac-fullstack-patterns`).

**Cross-service calls need `def:pub` / `walker:pub`** - that is the cross-space contract. A non-pub call compiles fine, then fails at runtime with `sv-to-sv RPC 'math_service.secret_op' failed: Unauthorized` (plain/`:priv` endpoints are JWT-gated; the hop forwards the inbound `Authorization` header but anonymous chains have none). Verified live.

**The routes table is part of the program.** Adding a module to it changes how its imports compile (in-process -> RPC) on the next build; removing it fuses the services back into one process. Modules in the cut are server-anchored by definition - their placement never needs pinning (`jac-codespaces`).

## Discovery chain (first match wins)

1. **Test client** - `sv_client.register_test_client(module, client)` routes calls in-process for tests (`import from jaclang.runtimelib { sv_client }`; call `clear_test_clients()` between tests).
2. **Registered URL** - `sv_client.register(module, url)` programmatically.
3. **`JAC_SV_<UPPERCASED_MODULE>_URL` env var** - the production knob. Module name = exactly the routes-table key, upper-cased (hyphens→underscores): `JAC_SV_MATH_SERVICE_URL=http://localhost:8001`.
4. **Auto-spawn** - the built-in scale subsystem starts the provider as a sibling at `jac start` time.

Auto-spawn rules: siblings bind **127.0.0.1 only** (single-host mode - unreachable from other machines); ports **18000-18999 are reserved** for them (pick your own `--port` outside that range); the provider `.jac` must sit in the directory you ran `jac start` from (default file `<routes-key>.jac`; override with `[scale.microservices.services.<name>] file = "other.jac"`); a `jac.toml` must exist in the cwd; transitive deps come up too (A→B→C). Startup is **fail-fast**: any provider that can't come up (missing file, syntax error, slow health check) crashes the consumer at startup, not at first request.

## Walker imports = spawn-and-execute

A `walker:pub` can cross the boundary too - but **constructing it runs it remotely**. There is no unexecuted remote walker: `Greet(name="x")` POSTs `/walker/Greet`, executes on the provider, and returns the finished instance with `reports` populated.

```
# math_service is in [scale.microservices.routes]; Greet is walker:pub there
import from math_service { Greet }

walker:pub TriggerGreet {
    has who: str;
    can run with Root entry {
        rg: any = Greet(name=self.who);    # remote spawn, already executed
        report rg.reports[0];
    }
}
```

Keyword args map to `has` fields; `isinstance(rg, Greet)` works. This is server-to-server only - a browser client cannot import a walker; wrap it in a `def:pub` server-side for client callers.

## Boundary types

**Cross the wire:** `obj` types (recursively hydrated - list them in the import alongside the function/walker), `enum`s (by name), primitives, `list[T]`, `dict[K, V]`, `None`.
**Streams cross live:** calling a provider's streaming endpoint (`-> Generator`) through the stub returns a LIVE generator - iterate and re-yield to forward frames unbuffered (the gateway pattern in `jac-sv-streaming`).
**Don't:** node/edge anchors, closures, file/DB handles. Pass `jid(node)` strings and re-resolve with `jobj` on the other side.

Failures surface at the call site as `RuntimeError`: `sv-to-sv RPC '<module>.<func>' failed: <reason>` (functions) / `sv-to-sv walker spawn '<module>.<walker>' failed: <reason>` (walkers). Catch where you want graceful degradation; transport failures are retried with backoff behind a per-provider circuit breaker.

## Gateway mode (many services)

`jac scale split <module>` (per service; `jac setup microservice --add <file>` also works) fills `[scale.microservices.routes]` in `jac.toml`; `jac start` on the project root then brings the whole stack up behind one API gateway - one public port, one unified `/docs`, one `/metrics`. `X-Trace-Id` is minted at the edge and threaded through every RPC hop. Key knob: per-service `rpc_timeout` (`[scale.microservices.services.NAME] rpc_timeout = 120.0`) defaults to **10s - bump to 120-300 for LLM-backed workers** or the gateway times out long generations. With `jac start --scale` in this mode, every pod gets its peers' `JAC_SV_<MOD>_URL` auto-injected (in-cluster service DNS) - don't set them by hand; `--dry-run` previews the plan.

## Pitfalls

- **404/`Unauthorized` on a cross-service call** = the provider symbol isn't `:pub`. First thing to check.
- **Calls run in-process when you expected RPC** = the provider module isn't in `[scale.microservices.routes]`. The cut is declared there and only there - run `jac scale split <module>` and rebuild.
- **`ModuleNotFoundError: No module named '<provider>'` at consumer startup** = auto-spawn couldn't find the provider source in the cwd. Co-locate the services (or set `[scale.microservices.services.<name>].file`), or set `JAC_SV_<MOD>_URL` to a provider running elsewhere.
- **`Error: No jac.toml found`** - `jac start <relative-path>` needs a `jac.toml` in the cwd.
- **`{"detail": "Invalid anchor id ..."}` 500s** = stale persisted anchors after a schema change - stop, `rm -rf .jac/data/`, restart (not service-specific; full story in `jac-sv-persistence`).
- Auto-spawn waits ~15s for the sibling's health check - on slow machines or cold caches it can fail-fast spuriously. Start the provider yourself and use `JAC_SV_<MOD>_URL` (this also gives you separate logs per service).
- Auto-spawn port collisions (something else squatting in 18000-18999) break discovery the same way - pin the provider URL explicitly (`JAC_SV_ANALYTICS_URL=http://127.0.0.1:18999 jac start ...`) instead of fighting the spawner.
- Multi-host = env-var wiring, always. Auto-spawned siblings can never serve another machine.
- Service module names must not collide with builtin gateway segments (`api`, `walker`, `function`, `health`, ...) - `jac scale split` rejects them with a rename suggestion.
