---
name: jac-sv-microservices
description: Splitting a Jac backend into microservices with `sv import` - compile-time HTTP client stubs between server modules, provider discovery (JAC_SV_<MOD>_URL, auto-spawn), remote walker spawns, boundary types, streaming pass-through, the gateway mode. Load when one server module must call another deployed as its own service. Pair with `jac-sv-endpoints`, `jac-sv-deploy` (k8s), `jac-sv-streaming` (SSE across services).
---

`sv import from <module> { ... }` between two **server** modules does not load the provider into the consumer's process. The compiler generates HTTP client stubs: calling `add(1, 2)` issues `POST /function/add` against the provider's URL; the source still reads like a normal import. The same code runs as a monolith, a one-command local cluster, or N Kubernetes deployments - the split happens at deploy time, not source time.

```jac
# math_service.jac (provider)
obj DivResult {
    has result: float | None = None,
        error: str = "";
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

# calculator_service.jac (consumer)
sv import from math_service { add, DivResult }

def:pub sum_list(numbers: list[int]) -> int {
    result = 0;
    for n in numbers {
        result = add(result, n);    # HTTP call per iteration (verified live)
    }
    return result;
}
```

```bash
jac start calculator_service.jac --port 8002    # consumer auto-starts math_service
curl -X POST http://localhost:8002/function/sum_list \
  -H "Content-Type: application/json" -d '{"numbers":[1,2,3,4,5]}'
```

**sv-to-sv function stubs are SYNCHRONOUS** - call them like local functions, no `await` (the stub blocks on the HTTP hop and resolves directly to the typed result). This is the opposite of cl-to-sv stubs, which are async and must be awaited (`jac-fullstack-patterns`).

**Providers MUST be `def:pub` / `walker:pub`.** Non-pub symbols are not callable across the boundary - the stub compiles fine, then the call fails at runtime with `sv-to-sv RPC 'math_service.secret_op' failed: Unauthorized` (plain/`:priv` endpoints are JWT-gated; the hop forwards the inbound `Authorization` header but anonymous chains have none). Verified live.

## Discovery chain (first match wins)

1. **Test client** - `sv_client.register_test_client(module, client)` routes calls in-process for tests (`import from jaclang.runtimelib { sv_client }`; call `clear_test_clients()` between tests).
2. **Registered URL** - `sv_client.register(module, url)` programmatically.
3. **`JAC_SV_<UPPERCASED_MODULE>_URL` env var** - the production knob. Module name = exactly what follows `sv import from`, upper-cased (hyphens→underscores): `JAC_SV_MATH_SERVICE_URL=http://localhost:8001`.
4. **Auto-spawn** - the built-in scale subsystem starts the provider as a sibling at `jac start` time.

Auto-spawn rules: siblings bind **127.0.0.1 only** (single-host mode - unreachable from other machines); ports **18000-18999 are reserved** for them (pick your own `--port` outside that range); the provider `.jac` must sit in the directory you ran `jac start` from; a `jac.toml` must exist in the cwd; transitive deps come up too (A→B→C). Startup is **fail-fast**: any provider that can't come up (missing file, syntax error, slow health check) crashes the consumer at startup, not at first request.

## Walker imports = spawn-and-execute

A `walker:pub` can cross the boundary too - but **constructing it runs it remotely**. There is no unexecuted remote walker: `Greet(name="x")` POSTs `/walker/Greet`, executes on the provider, and returns the finished instance with `reports` populated.

```jac
sv import from math_service { Greet }      # walker:pub on the provider

walker:pub TriggerGreet {
    has who: str;
    can run with Root entry {
        rg: any = Greet(name=self.who);    # remote spawn, already executed
        report rg.reports[0];
    }
}
```

Keyword args map to `has` fields; `isinstance(rg, Greet)` works. This is sv-to-sv only - a browser client cannot import a walker; wrap it in a `def:pub` server-side for cl-to-sv.

## Boundary types

**Cross the wire:** `obj` types (recursively hydrated - list them in the `sv import` alongside the function/walker), `enum`s (by name), primitives, `list[T]`, `dict[K, V]`, `None`.
**Streams cross live:** calling a provider's streaming endpoint (`-> Generator`) through the stub returns a LIVE generator - iterate and re-yield to forward frames unbuffered (the gateway pattern in `jac-sv-streaming`).
**Don't:** node/edge anchors, closures, file/DB handles. Pass `jid(node)` strings and re-resolve with `jobj` on the other side.

Failures surface at the call site as `RuntimeError`: `sv-to-sv RPC '<module>.<func>' failed: <reason>` (functions) / `sv-to-sv walker spawn '<module>.<walker>' failed: <reason>` (walkers). Catch where you want graceful degradation; transport failures are retried with backoff behind a per-provider circuit breaker.

## Gateway mode (many services)

`jac setup microservice --add <file>` (per service) writes `[plugins.scale.microservices]` plumbing into `jac.toml`; `jac start` on the project root then brings the whole stack up behind one API gateway - one public port, one unified `/docs`, one `/metrics`. `X-Trace-Id` is minted at the edge and threaded through every sv hop. Key knob: per-service `rpc_timeout` (`[plugins.scale.microservices.services.NAME] rpc_timeout = 120.0`) defaults to **10s - bump to 120-300 for LLM-backed workers** or the gateway times out long generations. With `jac start --scale` in this mode, every pod gets its peers' `JAC_SV_<MOD>_URL` auto-injected (in-cluster service DNS) - don't set them by hand; `--dry-run` previews the plan.

## Pitfalls

- **404/`Unauthorized` on a cross-service call** = the provider symbol isn't `:pub`. First thing to check.
- **`ModuleNotFoundError: No module named '<provider>'` at consumer startup** = auto-spawn couldn't find the provider source in the cwd. Co-locate the services or set `JAC_SV_<MOD>_URL` to a provider running elsewhere.
- **`Error: No jac.toml found`** - `jac start <relative-path>` needs a `jac.toml` in the cwd.
- **`{"detail": "Invalid anchor id ..."}` 500s** = stale persisted anchors after a schema change - stop, `rm -rf .jac/data/`, restart (not sv-specific; full story in `jac-sv-persistence`).
- Auto-spawn waits ~15s for the sibling's health check - on slow machines or cold caches it can fail-fast spuriously. Start the provider yourself and use `JAC_SV_<MOD>_URL` (this also gives you separate logs per service).
- Auto-spawn port collisions (something else squatting in 18000-18999) break discovery the same way - pin the provider URL explicitly (`JAC_SV_ANALYTICS_URL=http://127.0.0.1:18999 jac start ...`) instead of fighting the spawner.
- Multi-host = env-var wiring, always. Auto-spawned siblings can never serve another machine.
