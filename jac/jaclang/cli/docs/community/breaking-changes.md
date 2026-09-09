# Breaking Changes

This page documents significant breaking changes in Jac and Jaseci that may affect your existing code or workflows. Use this information to plan and execute updates to your applications.

!!! note
    MTLLM library is now deprecated and replaced by the byLLM package. In all places where `mtllm` was used before, it can be replaced with `byllm`.

---

### Memory profile: `[memory]`, `jac build --native`, and `jac explain` replace `jac nacompile`, `--gc`, `[gc]`, `[build.native]` and the compile-time `JAC_*` variables

The memory axis is one declaration of intent. `[memory] profile = "managed" | "rc" | "nogc"` replaces `[gc] default`; `[memory] enforce` / `exempt` replace `[gc.enforce] modules` / `grandfathered`; `[native] target / opt / debug / threads` replace `[build.native]`; `[placement] default` replaces `[build] default_codespace`. `jac nacompile` is gone: `jac build <file> --native` compiles one self-contained artifact (a binary when the module has `with entry`, a C-ABI library otherwise; `--lib` forces the library), with `--memory`, `--target-triple` and `--debug` as its only knobs. Invariants are no longer flags: `--assert-no-rc` is always on under `nogc`, `--strict` is a property of every native artifact, `--scrub` is `jac clean --cache`. No compile-time environment variable sets behavior; a built binary reads only `JAC_GC=off` and `JAC_THREADS`, and the cycle collector runs by default under `managed`. `jac explain memory | placement | ir` replaces `JAC_RC_STATS`, `JAC_NOGC_DEBUG`, `JAC_NA_DEBUG`-style output, `jac check --placements`, and `JAC_DUMP_IR` / `JAC_DEBUG_IR` / `JAC_SYMMAP`.

| Old | New |
|---|---|
| `jac nacompile file.jac` | `jac build file.jac --native` |
| `--gc cycles / rc / none` | `--memory managed / rc / nogc` |
| `--enforce-nogc`, `--assert-no-rc`, `--strict` | implied by `nogc`; invariants of every native artifact |
| `--shared` | inferred from the absence of `with entry`; `--lib` to force |
| `-t`, `JAC_NATIVE_TARGET`, `[build.native] target` | `--target-triple`, `[native] target` |
| `-g`, `JAC_NATIVE_DEBUG`, `JAC_RC_DEBUG_CODEGEN`, `[build.native] debug`, `rc_debug_codegen` | `--debug`, `[native] debug` |
| `--scrub` | `jac clean --cache` |
| `JAC_OPT_LEVEL`, `[build.native] opt_level` | `[native] opt` |
| `[gc] default`, `[gc.enforce] modules / grandfathered` | `[memory] profile / enforce / exempt` |
| `[build] default_codespace` | `[placement] default` |
| `JAC_RC_STATS`, `JAC_NOGC_DEBUG` | `jac explain memory` |
| `JAC_DUMP_IR`, `JAC_DEBUG_IR`, `JAC_SYMMAP`, `[build.native] dump_ir` | `jac explain ir` |
| `JAC_NO_GC`, `JAC_GC_CYCLES` | run time only: `JAC_GC=off`; collection on by default |
| `JAC_FLOW_THREADS` | `[native] threads`, run-time override `JAC_THREADS` |

---

### Workspaces: `[apps]` replaces `[scale.microservices]`, `client` / `client_kind`, `base_route_app`, `--client` and `JAC_ENV`; Capacitor is deleted ([#8823](https://github.com/jaseci-labs/jac/issues/8823), unreleased)

A project is now a set of **apps** over shared code. Each app is an `[apps.<name>]` table in `jac.toml` with a `kind`, an optional directory `path` (or a file `entry-point` for a file-rooted app), a `platform` and a `route`; everything under no app root is shared. The kind decides the client: `web-app`, `web-static` and `desktop` render the DOM, `mobile` is a React Native mobUI app, and `--platform` is the only per-run override. The app boundary is structural -- it always compiles and type-checks as a cut -- and where the apps run is profile: `jac run <app>` colocates the workspace's service apps in one process, `--fleet` (or `[scale.gateway] colocate = false`) runs them as separate local processes, and `jac scale deploy` always deploys a fleet. A project with no `[apps]` table is one implicit app and its `jac.toml` is unchanged, except that the `mobile` kind names the React Native mobUI app and the Capacitor web-view shell no longer exists. Full reference: [Workspaces & Apps](../reference/apps.md).

The whole old service and client-target surface is gone, not deprecated:

| Old | New |
|---|---|
| `[scale.microservices.routes]` (the service cut) | an `[apps.<name>]` table with `kind = "service"` and the module as `entry-point` (`jac create --app <name> --kind service`) |
| `[scale.microservices.services.<name>.*]` (`replicas`, `rpc_timeout`, `env`, `http_activation`, `hpa`, `pdb`, `triggers`, `deployment_overlay`, ...) | `[apps.<name>.scale.*]` (the same keys, as a per-app overlay) |
| `[scale.microservices]` infra keys (`gateway_port`, `gateway_host`, `drain_timeout_seconds`, `http_forward_timeout`, `boot_health_timeout`, `boot_max_wait`, `health_monitor_interval`, `identity`, `ingress`, `rate_limit`, `cors`, `logs`, `tracing`, `shared_volumes`) | `[scale.gateway]` (same keys) plus the new `colocate = true` |
| `[scale.microservices] enabled` / `routes` / `services` / `client` / `service_files` | gone -- fleet membership is every app whose kind has a server |
| `[[scale.microservices.shared_volumes]] services = [...]` | `[[scale.gateway.shared_volumes]] apps = [...]` |
| `jac scale split <module>` / `jac setup microservice` | `jac create --app <name> --kind service` |
| `JAC_SV_<MODULE>_URL` / `JAC_SV_ROUTES` (module-stem keyed) | `JAC_APP_<APP>_URL` / `JAC_APP_<APP>_ROUTE` (app-name keyed) |
| sv-to-sv stubs: synchronous, keyed by module stem; `RuntimeError("sv-to-sv RPC ... failed")` | typed-async stubs keyed by provider app name -- `await` them (`E1042` otherwise); awaited failures raise `BridgeError` / `BridgeUnavailable` / `BridgeTimeout` / `BridgeRejected` from `jaclang.server.bridge` (and `@jac/runtime`); an un-awaited statement-level walker spawn is a deferred outbox delivery |
| `sv_client.register(module, url)`, `register_test_client(module, client)`, `resolve_url(module)` | the same functions keyed by **app name**, plus `register_local(app, module)` |
| `__jac_provider_module__` on generated walker stubs | `__jac_provider_app__` |
| `Import.is_service_module_stem`, `service_cut.jac`, `cut_digest` | `classify_cross_app_import` (`compiler/driver/boundary_classify.jac`) and `app_fact_digest` |
| `[project] client_kind = "mobui"`, `[apps.<name>] client_kind` | gone: every `mobile` app is mobUI and no other kind is (both keys are parse errors) |
| `[client] target`, `JAC_CLIENT_TARGET`, `[apps.<name>] client`, `--client <target>` on `run` / `build` / `setup` | gone: the kind decides the client. `jac run --platform web mobile` runs a mobile app in a browser (react-native-web); `jac build --as client <app>` builds only an app's client bundle |
| the Capacitor mobile shell (`client = "mobile"`, `jac setup mobile --platform android`, the `android/` and `ios/` project scaffolds, `[client.mobile]`, `JAC_MOBILE_DEV_HOST`, `JAC_MOBILE_SETUP_PLATFORM`, `JAC_MOBILE_VITE_PORT`) | deleted. A web app goes on a phone as a PWA (`[client.pwa]`); a native app is a `mobile` app over the shared core |
| `pwa` as a client target (`jac setup pwa`, `--client pwa`) | a `[client.pwa]` table in `jac.toml` makes the web build a PWA; `jac setup <app>` creates `pwa_icons/` when the table exists |
| `cef` as a client target (`--client cef`, output under `.jac/client/cef/`) | `[desktop] engine = "cef"` on a `desktop` app; both engines build into `.jac/client/desktop/` |
| `[dependencies.npm.react_native]` / `[dependencies.npm.react-native]` | `[dependencies.npm.mobile]` (target-scoped npm tables are keyed by the kind's client name: `web`, `static`, `desktop`, `mobile`) |
| `TargetType`, `get_target_type`, `TargetFactory`, `app_client_target`, `normalize_client_target`, `CLIENT_TARGETS`, `KindSpec.client_target`, `AppConfig.client` / `client_kind` / `effective_client()`, `CompileOptions.client_kind`, `jaclang.project.client_kind`, `JacClientCompiler.compile(..., target_name=...)` | `KindSpec.ui` (`dom` / `mobui`), `kind_ui` / `kind_has_client` / `kind_is_mobui`, `AppConfig.ui()`, `target_for_kind` / `target_for_app` (`client/targets/registry.jac`, four targets: `web`, `static`, `desktop`, `mobile`), `CompileOptions.ui`, `jaclang.project.mobui_scope`, `JacClientCompiler.compile(..., native=True)` |
| `[serve] base_route_app`, `[serve] cl_route_prefix` | gone -- the served app is at `/`, every other client-capable app with a built bundle at `/cl/<app-name>/` |
| `JAC_ENV` | gone -- `--profile`, `JAC_PROFILE`, or `[environment] default_profile` |
| legacy `[plugins.<name>]` tables, `discover_config_files` | gone -- capability tables are top-level (`[byllm]`, `[scale]`, `[client]`, `[mcp]`, `[desktop]`) |
| `plan_project_run`, `resolve_project_kind`, `CompileOptions.project_kind` | `plan_app_run` / `plan_workspace`, `resolve_app_kind`, `CompileOptions.app_kind` + `target_app` |
| `jac run [file]`, `jac build [file]`, `jac test [file]`, `jac setup <target>` | the positional is an **app name or a path**: `jac run web`, `jac build --all`, `jac test mobile`, `jac setup mobile`; no target = `[project] default-app` or the sole app |
| `jac check` on the project root | with no paths: one program per app + an orphan sweep, diagnostics prefixed `[<app>]`; `--app <name>` for one app |
| `examples/mobui/hello`, `examples/mobui/littlex` | deleted; the mobUI example is the flagship's `jac/examples/jaclang_org/mobile` (`jac create <name> --awesome`) |
| `[project] kind = "mobile"` as the Capacitor web-view shell | `mobile` is the React Native mobUI app, with `--platform android`, `ios`, or `web` |
| the enclosing-project kind chain (`_project_kind_chain` in `placement_facts`: a nested `jac.toml` with no `kind` walked every ancestor `jac.toml` for one) | gone -- an app's kind is its `[apps.<name>] kind`, the implicit app's `[project] kind`, or entry-point inference; a nested `jac.toml` under a workspace is its own project and inherits nothing |
| `JacServe.ensure_sv_service(module, base_path)`, `JacServe.sv_service_call(module, fn, args)`, `JacServe.sv_walker_call(module, walker, args, stub_cls)` | removed from the runtime interface -- `jaclang.server.sv_client` (`call`, `spawn_walker`, keyed by provider app name) dispatches to the registered scale transport (`JacScalePlugin.sv_service_call` / `sv_walker_call`, app-keyed) or its own HTTP client |
| `E5087` "Project kind ... has no server" | `E5087` "App kind ... has no server" |

New diagnostics: `E2039`/`W2039` (an app using another app's declaration outside its bridge surface), `E2040`/`W2040` (shared code importing from an app), `E5107` (a server-placed shared module with no single owner), `E5104` (an app dependency cycle), `E5105` (a `.native.jac` variant disagreeing with its base module), `E5106` (bridging to a non-`pub` element). `[project] kind` / `entry-point` alongside `[apps]` is a hard config error (exit 2).

**Impact:** replace every `[scale.microservices.*]` table with `[apps.<name>]` tables and `[scale.gateway]`; add `await` to every server-to-server call across an app boundary (and `async` to the enclosing function); rename `JAC_SV_*` env vars to `JAC_APP_*`; delete `client` and `client_kind` from every app table (a mobile app is `kind = "mobile"` and nothing else); replace `--client web` with `--as client`, `--client pwa` with a `[client.pwa]` table, `--client cef` with `[desktop] engine = "cef"`, and `--client web` on a mobile app with `--platform web`; drop `base_route_app` / `cl_route_prefix` / `[client] target` / `JAC_ENV` from configs and scripts; pass an app name instead of a filename to `run`/`build`/`test`/`setup` in a workspace. Config keys that no longer exist are hard errors, not warnings.

### Regions have dynamic extent on every backend ([#8913](https://github.com/jaseci-labs/jac/issues/8913), unreleased)

`in r { }` now means one thing everywhere: everything constructed while the open is active on the current thread lands in `r`, including allocations made inside helpers the open calls. Native user code used to get lexical extent (only constructor calls written between the braces were arena-allocated; a helper allocated on the RC heap unless it took a `Region` parameter and opened it itself), and the compiler's own kernel modules got dynamic extent through a hidden second implementation keyed on their file paths. Both are gone; the Python backend already behaved this way.

| Old | New |
|---|---|
| `in r { x = helper(); }` allocates `helper`'s result on the heap natively | allocated in `r`, reclaimed at `r`'s drop |
| `in r { xs.append(helper()); }` with `xs` outside the open | `E1307`: a heap-typed call result made under an open is region-rooted unless the callee receives the handle |
| runtime bookkeeping constructed under an open leaks into the region | `managed(T(...))` constructs on the managed heap regardless of the current region |
| `flow for` body under an open inherits nothing | worker threads start with no current region; move a partition in to allocate |
| inferred anonymous regions were native-only | `RegionInferPass` desugars them to real `in Region() { }` opens, so `drop` hooks fire on the Python backend too |

`region_of(x)` is a declared builtin, and the walker growth rule is the same mechanism: ability dispatch enters `region_of(here)`. The native arena is a Jac kernel unit (`runtime/region_native.jac`) linked like the OSP kernel; `__mem_load_i64`, `__mem_store_i64`, `__atomic_xchg_i64`, and `__mem_call_dtor` are reserved intrinsic names.

**Impact:** native code that relied on a helper's allocation outliving an enclosing open must either hoist the call out of the open, pass the handle so the checker ties the result to it, or rebox scalars with `own`. Everything else is a fix of behaviour the docs already promised.

---

### `jac run` absorbs `jac start` and `jac dev`; deploying is `jac scale deploy` ([#8596](https://github.com/jaseci-labs/jac/pull/8596), unreleased)

One verb runs and serves. `jac run` resolves the project kind and executes, serves, or builds accordingly; `--serve` and `--dev` force the serve projections; a named file now resolves the kind too, so `jac run main.jac` in a `web-app` or `service` project serves just like the bare form. `jac start` and `jac dev` are tombstoned -- they hard-error with the replacement spelling. Deployment leaves the serve path entirely: the `--scale` flag is gone and `jac scale deploy [app.jac] [--target T] [--enable-tls] [--dry-run] [--show-yaml]` is the deploy command (with no file it deploys `[project] entry-point`).

| Old | New |
|---|---|
| `jac start app.jac` | `jac run app.jac` (servable kind) or `jac run --serve app.jac` |
| `jac start app.jac --port 3000` | `jac run --port 3000 app.jac` (serve flags precede the file) |
| `jac dev` | `jac run --dev` |
| `jac start --scale` | `jac scale deploy` |
| `--api_port` | `--api-port` |

**Impact:** update scripts and CI to the new spellings. Serve flags must precede the filename (`run` forwards everything after the file to the script). A cross-mode flag is now a hard error instead of a silent no-op: `--port` against a `cli` kind, or `--entry` against a serving kind, names the flag and the kind and exits 1.

---

### Fixed-width numerics are real types with one contract on every lane ([#8544](https://github.com/jaseci-labs/jac/pull/8544), [#8601](https://github.com/jaseci-labs/jac/pull/8601), [#8621](https://github.com/jaseci-labs/jac/pull/8621), unreleased)

`i8 u8 i16 u16 i32 u32 i64 u64 f32 f64` are no longer `int`/`float` with a width hint. One contract holds across `jac check`, the server, client, and native lanes: int literals are range-checked (`E1126`), lossy conversions need the explicit cast `T(x)` or the modular `T.wrap(x)` (`E1127`), operators need unifiable operands (`E1128`), unary minus on unsigned is refused (`E1129`), and sized arithmetic that leaves the range traps with `OverflowError` on every lane (wrapping is opt-in via `T.wrap` and the `wrapping_*` builtins). Values erase to the machine representation -- a plain `int`/`float` on the server, a JS number (`BigInt` at 64 bits) on the client, the machine width natively -- so the ten runtime classes are gone.

**Impact:** passing a plain `int` into a sized parameter (typically extern `i32`/`u64`) now needs the cast (`i32(n)`); `u*` values are genuinely unsigned (`~u8(0) == 255`); `type(x) is i8`, `isinstance(x, u8)`, and `x.__jac_sized__` no longer work (`T(x)`, `T.wrap(x)`, `T.MIN`, `T.MAX` are unchanged). On the wire, an `i64`/`u64` field outside the +/-2^53-1 safe range serializes as a JSON **string** on both lanes; HTTP consumers reading large 64-bit fields must accept either form.

---

### Type checking runs on every compilation ([#8399](https://github.com/jaseci-labs/jac/pull/8399), unreleased)

The gate that skipped type checking is gone: `jac build --no_typecheck`, `[build] typecheck`, `[precommit] typecheck`, and the `type_check` parameters on `JacProgram.compile`/`build` are all removed. Type inference, the checker, and the full analysis suite (static analysis, access, ownership, native and client capability, portability, lint) run for every module that compiles -- including `jac run`, imports, HMR, and publish -- and a module-scoped error blocks code generation for every codespace. The only remaining escape is `jac check --parse_only` (syntax only).

**Impact:** a type error that used to surface only under `jac check` (or become a runtime crash) is now a compile failure everywhere. Drop the removed flags and config keys from scripts and manifests; a missing typeshed tree is now a hard error rather than a silent degradation.

---

### `jac ninja` and `jac ai` are removed ([#8468](https://github.com/jaseci-labs/jac/pull/8468), unreleased)

The fused neovim editor (`jac ninja`) and the built-in terminal coding agent (`jac ai`) are gone, along with the editor tree and the agent's web UI. The launcher and its build tooling are now written in Jac; the binary no longer links neovim.

**Impact:** agent workflows continue through `jac mcp` plus the bundled guides (`jac guide`); editor integration stays on `jac lsp`. There is no replacement terminal-agent verb.

---

### A keyword is never an identifier, and stray backticks are errors ([#8315](https://github.com/jaseci-labs/jac/pull/8315), unreleased)

The rule is now uniform: a keyword token is never an identifier, and the backtick escape is the only way to use one as a name. Every binding position (archetype, ability, enum, global, field, parameter) reports one `E0013` naming the keyword and the escape, so `has skip: int` becomes ``has `skip: int``. Member access is not a binding position: after a dot a keyword is always an attribute, so `x.test` and `sys.exit(0)` parse unescaped (the escaped spelling still works). The reverse is also checked: a backtick on a name that is not a keyword is `E0014` ("remove the backtick"). Exempt because they are not identifiers competing with keywords: the eight special references (`self`, `super`, `root`, `here`, `visitor`, `props`, `init`, `postinit`) and the builtin type names (`int`, `str`, `list`, `type`, `i8` ... `f64`).

**Impact:** code that bound a bare keyword (`has skip: int`, `for match in xs`) now gets a single actionable `E0013` -- add the backtick. Existing escaped spellings are untouched. The complete reserved-word list is in [Foundation > Keywords](../reference/language/foundation.md#5-keywords).

---

### Importing `typing` spellings jac already provides is a hard error ([#8316](https://github.com/jaseci-labs/jac/pull/8316), [#8325](https://github.com/jaseci-labs/jac/pull/8325), [#8344](https://github.com/jaseci-labs/jac/pull/8344), unreleased)

Three escalations close the two-spellings-for-one-type gap. `import from typing { Any }` is `E1122` -- write jac's builtin `any` (the alias form is refused too; module-form `typing.Any` stays legal for reflection). The deprecated container aliases `List`, `Dict`, `Tuple`, `Set`, `FrozenSet`, `Type` are `E1123` -- write the lowercase builtin. And the seventeen ambient typing names (`Callable`, `Sequence`, `Iterable`, `Iterator`, `Mapping`, `TypeVar`, `ClassVar`, `Literal`, `Protocol`, `Generic`, and kin) are `E1125` -- they are already in every module's scope, so delete the import and keep writing the name (`import from typing { Callable as Cb }` stays legal, since the ambient set cannot provide a chosen local name). All three block codegen and name the remedy in the message. `Optional`, `Union`, `cast`, and `TYPE_CHECKING` remain importable.

**Impact:** delete the refused imports; annotations keep working unchanged. Dropping a `typing` import can also let a module lower natively where the unresolved import previously held it back.

---

### `jac test` runs on a built-in runner; pytest is gone from the binary ([#8287](https://github.com/jaseci-labs/jac/pull/8287), unreleased)

`jac test` no longer shells into pytest, and pytest/pytest-xdist/execnet/pluggy/iniconfig are no longer bundled. Collection covers `.jac` files only, workers fork from a warm parent (the default worker count derives from available memory; `JAC_TEST_JOBS` overrides, `0` or `1` runs in-process), and `-x`/`--maxfail` stop within a file.

| Old | New |
|---|---|
| `import pytest` in a `.jac` test | remove -- no longer resolves |
| `pytest.skip(reason)` / `pytest.fail(reason)` | ambient `testskip(reason)` / `testfail(reason)` |
| `pytest.raises(SomeError, match=...)` | ``with testraises(SomeError, `match="pattern") as ei { ... }`` |
| plain `pytest` collecting `.jac` tests | `jac test` (the `pytest11` entry point is removed) |

**Impact:** `.jac` tests migrate mechanically per the table; a project's `test_*.py` files are no longer collected by `jac test`. pytest fixtures and markers have no equivalent (autouse fixtures never actually ran for Jac tests).

---

### `pub` is placement evidence only in project kinds that have a server ([#8211](https://github.com/jaseci-labs/jac/pull/8211), unreleased)

In kinds with a server (`web-app`, `service`, `service-mesh`, `desktop`, `mobile`, and the no-kind default) nothing changes: an evidence-free `def:pub` is still a server endpoint. In a serverless kind (`js-package`) `pub` means export and is not placement evidence, and server evidence there (root access, an FFI extern, `::py::`, a value-level Python import) is now a build error `E5087` naming the kind, instead of a silent server placement that could only fail at runtime.

**Impact:** if a `js-package` genuinely needs a server, declare a `[project] kind` that has one.

---

### Postgres is the one persistence engine; SQLite, MongoDB, and Redis are retired ([#7947](https://github.com/jaseci-labs/jac/pull/7947) in jaclang 0.36.0, [#8002](https://github.com/jaseci-labs/jac/pull/8002) in 0.36.1)

Graph persistence is Postgres at every scale. Locally the runtime provisions a shared embedded Postgres in the per-user cache, with one database per project, booted lazily on first graph use and reached through the runtime's own wire-protocol client; configured for scale, the identical store points at a managed database. The SQLite graph store, the MongoDB and Redis memory tiers, the Firestore datastore path, and the SQLAlchemy scaffolding are deleted (`data.mongo` / `data.redis` / `data.sql` capabilities no longer exist; `storage.firebase` blob storage remains).

| Old | New |
|---|---|
| local `.jac` SQLite store | embedded Postgres, provisioned automatically |
| `[scale.database]` `backend = "mongo"` / `"redis"` | `JAC_DB_URL` / `[scale.database].url` pointing at Postgres |
| `MONGODB_URI` | `JAC_DB_URL="postgresql://..."` |

Two follow-ups sharpen the contract: read paths run without SERIALIZABLE predicate locks (isolation follows declared intent, [#8102](https://github.com/jaseci-labs/jac/pull/8102)), and the deploying process's ambient `JAC_DB_URL` no longer decides a deployed app's database -- deploy intent lives in `[scale.kubernetes]` `database_mode` / `database_url` ([#8209](https://github.com/jaseci-labs/jac/pull/8209)), so an app deployed without explicit intent now gets its own provisioned Postgres.

**Impact:** existing local SQLite data does not migrate automatically; Mongo/Redis-backed deployments must move their data to Postgres. Delete retired backend config; if a deploy relied on ambient `JAC_DB_URL`, state it explicitly with `database_mode = "external"` and `database_url` under `[scale.kubernetes]`.

---

### Serving is one Jac-native HTTP stack; the FastAPI closure is gone ([#7969](https://github.com/jaseci-labs/jac/pull/7969), jaclang 0.36.0)

The server behind `jac run` is the toolchain's own asyncio HTTP engine (`jaclang.server.serving`): router, websockets, SSE, multipart, middleware, auth, and OpenAPI generation, with no web framework behind it. It replaces both prior stacks -- the stdlib threading server and the FastAPI adapter the scale path exec'd -- and `fastapi`, `uvicorn`, `pydantic`, and `httpx` leave the serving dependency closure (`pydantic`/`httpx` remain only as byLLM optional deps; eject still *emits* a FastAPI project, since that is the exit's job). Scale reuses the same engine behind its gateway pods.

**Impact:** endpoint behavior, `/docs`, and auth are unchanged from a caller's perspective. Anything that imported the serving stack's FastAPI app object or relied on starlette's `TestClient` must move to the Jac-native equivalents (`JacTestClient` for in-process testing).

---

### The ambient permission constants are now one ambient `AccessLevel` enum (unreleased)

The four ambient access-level constants - `NoPerm`, `ReadPerm`, `ConnectPerm`, `WritePerm` - are removed. The `AccessLevel` enum they aliased is now itself ambient (no import needed), and its members are the one spelling of access levels everywhere a level is taken:

| Old | New |
|---|---|
| `grant(node, level=ReadPerm)` | `grant(node, level=AccessLevel.READ)` |
| `Jac.allow_root(node, rid, WritePerm)` | `Jac.allow_root(node, rid, AccessLevel.WRITE)` |
| `return WritePerm;` in `__jac_access__` | `return AccessLevel.WRITE;` |
| `NoPerm` / `ConnectPerm` | `AccessLevel.NO_ACCESS` / `AccessLevel.CONNECT` |

This also unifies the vocabulary with the Scale reference's `perm_grant` / `allow_root` API, which already spoke in `NO_ACCESS` / `READ` / `CONNECT` / `WRITE` levels, and it makes the honest hook signature type-check: `def __jac_access__ -> AccessLevel { return AccessLevel.WRITE; }` (the constants were stub-typed `int`, so the checker rejected exactly that form). String (`"WRITE"`) and int returns remain accepted at runtime for policies stored in data, but enum members are the canonical spelling - a typo'd string literal raises `KeyError` at access-check time.

**Impact:** a mechanical 1:1 rename. A bare removed name is now an unresolved-name error at compile time; importing one from `jaclang.runtime.builtin` raises an `AttributeError` that names the replacement member.

---

### All placement spellings removed: `sv`/`cl`/`na` markers, the `.sv.jac`/`.cl.jac` suffixes, and the `variant` directive ([#7772](https://github.com/jaseci-labs/jac/issues/7772), jaclang 0.35)

Placement no longer has any spelling in source code or filenames. The `sv { }` / `cl { }` / `na { }` blocks, the single-statement prefixes (`cl import ...`, `sv def ...`), the `.sv.jac` and `.cl.jac` file suffixes, and the short-lived `variant client;` / `variant native;` module directive are all removed -- marker code is a syntax error, and a leftover suffixed file fails loudly:

```text
the .cl.jac marker was retired -- rename the file to .jac; client placement
is inferred from JSX/npm imports (override via [placement.pins] in jac.toml).
Run 'jac fix placement' to migrate the project.
```

What replaces them:

- **Inference** places every declaration: JSX, browser globals, and npm imports seed client; extern C declarations seed native; python imports and graph archetypes anchor server (the default). Placement propagates from those seeds through symbol references.
- **`[placement.pins]` in `jac.toml`** is the override when a decision must be forced. A module-level `"client"` / `"native"` pin coerces the whole module the way the old suffix did; an element-level pin (`"mod.helper" = "server"`) forces one declaration.
- **`[scale.microservices.routes]`** was the authoritative microservice cut at the time (`jac scale split <module>` wrote an entry); imports of cut members lowered to service RPC automatically -- this replaced the `sv import` boundary marker. (Superseded by `[apps.<name>]` service apps; see the workspaces entry above.)

| Old | New |
|---|---|
| `cl { ... }` block / `cl` prefix | plain code (inferred client) or a `"client"` pin |
| `sv { ... }` block / `sv` prefix | plain code (server is the default) or a `"server"` pin |
| `mod.cl.jac` / `mod.sv.jac` | `mod.jac` (placement inferred; pin the module to coerce it whole) |
| `sv import from .svc { f }` | plain import + a `[scale.microservices.routes]` entry at the time (now an `[apps.<name>]` service app; see above) |
| `variant client;` / `variant native;` | nothing -- placement has no per-file spelling |

**Impact:** run `jac fix placement` -- it strips markers, renames retired suffixed files, preserves service topology into the routes table, and pins any element whose inferred placement differs from its old marker. Review the result with `jac check <entry> --placements`. The placement lockfile briefly introduced alongside this work (`jac.placements.lock`, `jac check --update-placements-lock`) was removed before release: placement is the compiler's business, reviewed on demand, never snapshotted.

---

### The `.na.jac` filename marker retired ([#7770](https://github.com/jaseci-labs/jac/pull/7770), jaclang 0.35)

Native placement is no longer spelled in the filename. A plain `.jac` module becomes native by **inference**: under `[build] default_codespace = "native"` (the default), the placement solver's verdict (`scan_native_blockers` plus an import-closure fixpoint) decides, and a module that prefers native but cannot lower demotes to the server codespace with a note. Native is **forced** per-invocation rather than per-file: `jac nacompile file.jac` and `jac build --as native` coerce the module native outright -- lowering problems stay loud errors instead of demoting -- and `CompileOptions(force_codespace='native')` is the marker's programmatic successor.

This is a **clean break** -- a leftover `.na.jac` file fails loudly everywhere (the compiler, the importer, and `jac nacompile`) with:

```text
the .na.jac marker was retired in 0.35 -- rename the file to .jac
```

| Old | New |
|---|---|
| `mod.na.jac` | `mod.jac` (placement inferred) |
| `jac nacompile mod.na.jac` | `jac nacompile mod.jac` (forces native) |
| `mod.na.impl.jac` | `mod.impl.jac` (the `.na.impl.jac` annex variant no longer exists) |

**Impact:** rename every `*.na.jac` to `*.jac` and rely on inference; where native must be mandatory (AOT binaries, `--shared` libraries, wasm), use `jac nacompile` / `jac build --as native` / `force_codespace='native'`. The `.sv.jac` and `.cl.jac` variants were unchanged by this PR (they were retired separately -- see the entry above); the `.impl.jac` / `.test.jac` annexes are unchanged. One clarification makes the old native-library idiom carry over unchanged: `pub` elements anchor a *standalone* module to the server (endpoint semantics), but a module pulled in as a **native dependency** may freely use `pub` as its C-ABI export marker. The bundled native stdlib (`jaclang/runtime/na_stdlib/`) is native **by location**; its files are plain `.jac`, with per-OS variants as `<name>.<os>.jac` (e.g. `_dirent_native.darwin.jac`).

---

### Legacy syntax removed in one clean break ([#7514](https://github.com/jaseci-labs/jac/issues/7514))

A set of long-deprecated or redundant forms is removed with no deprecation window -- the old spellings are now hard errors:

| Old | New |
|---|---|
| `global x;` / `nonlocal x;` | Removed -- assignment binds to the nearest enclosing binding (see below) |
| `a && b` / `a \|\| b` | `a and b` / `a or b` |
| `def area() -> float abs;` | `def area() -> float abst;` (`abs` is now only the builtin function) |
| `nodes(?:Type, cond)` / `[-->(?:Type)]` | `nodes[?:Type, cond]` / `[-->[?:Type]]` (error **E0048**) |
| `root()` in `.jac` source | bare `root` (error **E0049**) |
| `has x: T by postinit;` | `has x: T postinit;` |
| `for i = 0 to i < 10 by i += 1 { }` | `for i = 0 while i < 10 with i += 1 { }` -- keyword separators (`while` condition, `with` step); the condition may be any expression. `to` is no longer a keyword at all |
| `can foo() { ... }` (function-style) | `def foo() { ... }` (error **E0034**; `can` is only for abilities with `with entry` / `with exit`) |
| `` has `class: str; `` (backticked Python reserved word as field/parameter name) | Rejected at compile time (error **E0067**) -- rename the field |

**New scoping semantics** replace the `global`/`nonlocal` directives: a bare assignment (including `+=`) inside a function binds to the **nearest enclosing binding** -- an enclosing function's local or a module-level `glob` -- and creates a new local only when no such binding exists. Only `glob`-declared variables are implicitly rebindable this way (imports, functions, and archetypes are not). To shadow an outer binding, write a typed declaration (`x: int = 5;`) before the name's first use in the scope; declaring it after the name was already bound in that scope is an error (**E0064**). Loop targets, `except ... as`, and `with ... as` always bind fresh locals. Python's `x += 1`-on-a-global `UnboundLocalError` gotcha is gone, and `glob` remains the only globals keyword.

**Impact:** the rewrites are mechanical (see the table). Deprecation warnings **W0061**/**W0062** no longer exist -- they are superseded by errors **E0048**/**E0049**. Functions inside `def` bodies that relied on `global`/`nonlocal` just delete the directive line -- the assignment already binds to the outer variable. Python **library mode** is unaffected: there `root` is a function imported from `jaclang.lib` and must still be called as `root()`. Identifiers named `to` no longer need backtick escaping.

---

### `region { }` blocks replaced by first-class `Region` handles and `in <handle> { }` opens

Regions are now a complete feature ([#7491](https://github.com/jaseci-labs/jac/issues/7491)): a `Region` is an ownable, sendable, escape-checked allocation extent, opened for allocation with the `in <handle> { ... }` statement. The old `region { ... }` contextual soft keyword is removed; its anonymous replacement is `in Region() { ... }`, and named handles (`r: own Region = Region(); in r { ... }`) add dynamic extent, helper opens through `&Region` parameters, and subgraph transfer across `flow`/`wait`.

This is a **clean break** -- `region { ... }` no longer parses.

| Old | New |
|---|---|
| `region { ... }` | `in Region() { ... }` |

On the native backend the open now bump-allocates into a real arena and reclaims wholesale (dtor-log walk, then one bulk free) at the handle's drop point, so the `E1307` escape rules are correspondingly stricter: heap-typed region values handed to opaque callees, laundered through aug-assigns, or wired into managed topology are now rejected. Scalars copy out freely and `own <expr>` reboxes a scalar or string copy out of the region.

**Impact:** mechanically rewrite `region {` to `in Region() {`. Code that leaked region references through calls or containers now gets `E1307` and needs an `own` rebox, a `&Region` helper signature, or restructuring.

---

### `jac create --list_jacpacks` renamed to `jac create --list`

The flag never listed jacpacks. A `.jacpack` is a distributable bundle you produce with `jac create --pack <dir>` and consume with `jac create --use <path|url>`; the flag instead lists the **project kinds** (used with `--kind`) and **named variants** (used with `--use <name>`) registered in the template registry. The name promised one thing and printed another, and its underscore spelling (`--list_jacpacks`, since `--list-jacpacks` was rejected) made it easy to get wrong.

This is a **clean break** -- there is no deprecated alias, and `--list_jacpacks` now fails with `unrecognized arguments`.

| Old | New |
|---|---|
| `jac create --list_jacpacks` | `jac create --list` |

**Impact:** replace `--list_jacpacks` with `--list` in scripts, CI, and docs. The short form `-l` is unchanged, so `jac create -l` works before and after. Nothing about the `.jacpack` format, `--pack`, or `--use` changes.

### Kubernetes image-build pipeline removed

The deploy no longer builds, tags, or pushes a Docker image. Copying the
project source into the cluster ("no-image") is now the only deploy path, so a
deploy needs no container registry and no registry credentials. (At the time
this landed the deploy was spelled `jac start --scale`; it is now
`jac scale deploy` -- see the entry above.)

Removed, with no replacement:

| Removed | Notes |
|---|---|
| `--build` / `-b` on the deploy command | The flag no longer exists; the deploy verb is the whole deploy |
| `--registry` on the deploy command | Ditto |
| `image_registry`, `docker_image_name` under `[scale.kubernetes]` | Silently ignored if still present in `jac.toml` |
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` in `.env` | No longer read |
| Local-cluster image loading (`kind load docker-image`, `k3d image import`, `minikube docker-env`) | Nothing to load -- pods run a stock base image |

**Impact:** drop `--build` / `--registry` from any CI/CD script, and delete
`image_registry` / `docker_image_name` from `jac.toml`. Pods now boot from a
stock base image (`jaseci/jaclang`, or `python:3.12-slim` as a fallback) and
receive your code as a source bundle on a PVC. If your cluster cannot pull that
base image, set `python_image` under `[scale.kubernetes]` to one it can.

---

### `to cl:` / `to sv:` / `to na:` section markers removed

The module-level colon-section-marker syntax has been removed. A `to cl:` / `to sv:` / `to na:` line used to switch every following statement into the client / server / native context until the next marker or end of file. This is a **clean break** -- writing `to cl:` (or `to sv:` / `to na:`) now fails to parse.

Use the braced block form instead. It compiles to the same node and is now the canonical way to scope a region to a context:

| Old | New |
|---|---|
| `to cl:` <br> `<client stmts>` | `cl { <client stmts> }` |
| `to sv:` <br> `<server stmts>` | `sv { <server stmts> }` (or leave at module top level -- server is the default context) |
| `to na:` <br> `<native stmts>` | `na { <native stmts> }` |

**Impact:** rewrite any `to cl:` / `to sv:` / `to na:` section into the matching braced block, wrapping exactly the statements that belonged to that section. Single-statement prefixes (`cl def:pub foo() {...}`, `sv ...`, `na ...`) and file-extension contexts (`.jac`, `.na.jac`) are unaffected. (At the time, `to` still drove the iter-for loop; `to` has since been removed as a keyword entirely -- see [the clean-break entry above](#legacy-syntax-removed-in-one-clean-break-7514).)

---

### `jac add` merged into `jac install`

The `jac add` verb has been removed; `jac install <pkg>` absorbs it. This is a **clean break** -- `jac add ...` now fails with a pointer to the new spelling.

| Old | New |
|---|---|
| `jac add requests` | `jac install requests` |
| `jac add pytest --dev` | `jac install pytest --dev` |
| `jac add --git <url>` | `jac install --git <url>` |
| `jac add --npm <pkg>` | `jac install --npm <pkg>` |
| `jac add --shadcn <name>` | `jac install --shadcn <name>` |

**Behavior change:** `jac install <pkg>` now **records the dependency in `jac.toml`** (what `jac add` did) instead of installing without tracking. Pass the new `--no-save` flag for the old untracked behavior; `--global` and `--dry-run` continue to never touch `jac.toml`.

**Impact:** update scripts and CI invocations of `jac add` to `jac install`, and add `--no-save` to any `jac install <pkg>` call that relied on jac.toml staying unmodified. `jac remove` and `jac update` are unchanged.

---

### Plugin system removed; `[plugins.*]` config flattened

The pluggy-style plugin/hook system has been removed entirely. The `jac plugins` command, the `JAC_DISABLED_PLUGINS` env var, the `[plugins]` `discovery`/`enabled`/`disabled` keys, and entry-point plugin discovery are all gone. Built-in features (byLLM, scale, the client/desktop framework, MCP, shadcn) are now called directly by core, and **external third-party plugins are no longer supported**.

Feature config moved from the `[plugins.<name>]` namespace to top-level `[<name>]` tables:

| Old | New |
|---|---|
| `[plugins.byllm]` / `[plugins.byllm.model]` | `[byllm]` / `[byllm.model]` |
| `[plugins.scale.database]` | `[scale.database]` |
| `[plugins.client.pwa]` | `[client.pwa]` |

**Impact:** rename any `[plugins.<name>]` sections in existing `jac.toml` files to the top-level form; drop any `[plugins]` enable/disable lists and `jac plugins` invocations from scripts. Everything the built-in features do is always available -- there is nothing to enable. (Older entries below that mention `[plugins.<name>]` config predate this flattening; use the top-level names.)

---

### Project kinds renamed to deliverable-oriented names

The `jac create --kind` / `[project] kind` taxonomy was renamed to describe **what you ship**. The old names are **not** accepted as aliases -- `jac create --kind pypi-package` and a `jac.toml` carrying `kind = "fullstack"` both fail with `Unknown project kind`.

| Old | New |
|---|---|
| `native-app` | `cli-native` |
| `shared-library` | `native-lib` |
| `api-service` | `service` |
| `microservices` | `service-mesh` |
| `pypi-package` | `py-package` |
| `npm-package` | `js-package` |
| `fullstack` | `web-app` |
| `client` | `web-static` |

`cli`, `native-binary`, `desktop`, and `mobile` are unchanged.

**Impact:** update the `kind` value in existing `jac.toml` files and any scripts calling `jac create --kind` with an old name. Behavior of each kind is unchanged -- see the [Build Anything grid](../quick-guide/project-kinds.md) for the current taxonomy.

---

### jac-byllm folded into `jaclang` core

`jac-byllm` is no longer a separate PyPI package or plugin. The `by llm()` feature is now built into `jaclang` core and importable as `jaclang.byllm` (was `byllm`). This is a **clean break** -- there is no backward-compatible `byllm` package or import shim.

**Impact:**

- There is no more `pip install byllm` / `jac install -e jac-byllm`. byLLM ships inside the `jac` binary.
- Code that did `import from byllm...` must change to `import from jaclang.byllm...` (e.g. `import from byllm.lib { Model }` becomes `import from jaclang.byllm.lib { Model }`; `import from byllm.llm { Model }` becomes `import from jaclang.byllm.llm { Model }`).
- byLLM's third-party dependencies (litellm, pillow, ...) are no longer installed via the `byllm` package. Instead they form the `llm` capability: declare `[byllm]` in `jac.toml` and run `jac install`; the capability registry resolves litellm + pillow into the project's `.jac/venv`. Optional runtimes are separate capabilities -- `llm.local` (llama-cpp-python, huggingface_hub), `llm.mcp` (mcp), `llm.video` (opencv). Using a real model without the `llm` capability raises an actionable "run `jac install`" error.

**Unchanged from a user's perspective:** the `by llm()` syntax, `[byllm.*]` config, and the `jac model` CLI behave exactly as before -- only the packaging and import path changed.

---

### jac-scale folded into `jaclang` core

`jac-scale` is no longer a separate PyPI package or plugin. Its serving and deployment subsystem is now built into `jaclang` core and importable as `jaclang.scale` (was `jac_scale`). This is a **clean break** -- there is no backward-compatible `jac-scale` package or `jac_scale` import shim.

**Impact:**

- There is no more `jac install jac-scale` / `jac install 'jac-scale[...]'` / `pip install jac-scale`. The scale subsystem ships inside the `jac` binary.
- Code that did `import from jac_scale...` (e.g. `import from jac_scale.persistence.lib { kvstore }`) must change to `import from jaclang.scale...` (e.g. `import from jaclang.scale.persistence.lib { kvstore }`).
- `jac plugins enable scale` is no longer needed -- scale is always available.
- Scale's optional third-party dependencies (kubernetes, prometheus-client, ...) are no longer installed via package extras. Instead, declare the matching `[scale.*]` config in `jac.toml` and run `jac install`; the capability registry resolves the required libraries into the project's `.jac/venv`. (The fastapi/pymongo/redis dependencies this entry originally listed have since left the closure entirely -- see the Postgres and serving entries above.)

**Unchanged from a user's perspective at the time:** the serving and deploy commands and all `[scale.*]` config behaved exactly as before -- only the packaging changed. (The command spellings have since moved to `jac run` / `jac scale deploy`; see the entry at the top of this page.)
