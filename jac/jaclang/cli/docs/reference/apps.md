# Workspaces & Apps

A Jac project is a set of **apps** over one body of **shared code**. Each app
is a table in `jac.toml` -- `[apps.web]`, `[apps.mobile]`, `[apps.social_graph]`
-- with a *kind* that says what it builds and where its files live. Everything
under no app's root is shared: plain modules that any app may import and that
belong to none of them. A project with no `[apps]` table at all is the simplest
case, a **single implicit app**, and the hello-world `jac.toml` you already
have is one.

Four principles hold the model together:

- **The boundary is structural, the topology is profile.** An app boundary
  always compiles and type-checks as a cut. Whether the apps on either side of
  it share one process, run as separate local processes, or run as separate
  pods is configuration, never source.
- **ACID within an app per request, eventual across apps.** One request
  against one app is one transaction. Anything that crosses an app boundary
  is a message.
- **No pass reads `jac.toml`.** The driver stamps *app facts* onto every
  module (which app, which root, which kind, which owner); the compiler's laws
  consume the stamps.
- **The platform is a stamped decision, never a filename property.** A
  `.native.jac` variant is selected for a mobile app's native platforms, not
  by where the file sits.

## The `[apps.<name>]` table

```toml
[project]
name = "acme"
default-app = "web"          # optional; a bare `jac run` uses it

[apps.web]                   # one table per app
kind = "web-app"             # required: a project kind
path = "web"                 # optional dir root, relative to the project root
entry-point = "main.jac"     # optional; relative to path; default = the kind's entry
platform = "android"         # optional default platform (mobile: android | ios | web; desktop: windows | macos | linux)
route = "/api/web"           # optional; default "/api/<name>" (apps with a server only)

[apps.social_graph]          # file-rooted app: no path, the entry file IS the app
kind = "service"
entry-point = "core/social_graph.jac"
```

| Key | Type | Description |
|-----|------|-------------|
| `kind` | string | **Required.** One of the [project kinds](../quick-guide/project-kinds.md): `cli`, `cli-native`, `native-binary`, `native-lib`, `service`, `service-mesh`, `py-package`, `js-package`, `web-app`, `web-static`, `desktop`, `mobile`. The kind decides the default entry, the action a bare `jac run <app>` takes, what the client renders (`web-app`, `web-static`, `desktop` and `js-package` render React DOM; `mobile` renders native views through [`@jac/mobui`](plugins/jac-client.md#the-jacmobui-vocabulary), with the `E1105` host-tag guard on every module the app claims), and whether the app has a server. |
| `path` | string | Directory root of the app, relative to the project root. Absolute paths are rejected. Omit it (and set `entry-point`) for a file-rooted app. |
| `entry-point` | string | Entry file, relative to `path` (or to the project root when there is no `path`). Defaults to the kind's entry (`main.jac`; `lib.jac` for the package kinds). |
| `platform` | string | Default platform: `android`, `ios` or `web` for a `mobile` app; `windows`, `macos` or `linux` for a `desktop` app. `--platform` on `jac run` / `jac build` overrides it for one invocation. |
| `route` | string | The app's public route prefix, for apps whose kind has a server. Must start with `/`. Defaults to `/api/<name>`. |

Any key other than these is a hard config error naming the accepted keys. App
names cannot contain `/` or `\` and cannot end in `.jac`, so that `jac run
<target>` can always tell an app name from a file path.

A nested table under an app -- `[apps.web.serve]`, `[apps.mobile.dependencies.npm]`,
`[apps.social_graph.scale]` -- is an **overlay**, covered under
[Effective configuration](#effective-configuration) below.

## Dir-rooted, file-rooted, and shared

An app with a `path` is **dir-rooted**: every module under that directory
belongs to it. An app with no `path` but an `entry-point` is **file-rooted**:
it claims exactly that one file and nothing else -- not the file's siblings,
not its directory.

**Membership** is decided by the nearest root. A module belongs to the app
whose root contains it; when roots nest, the innermost wins; a file-rooted app
matches only its own entry file. A module under no app root is **shared**.

```
acme/
  jac.toml
  core/                      shared: no app claims this directory
    social_graph.jac         ...except this one file, which [apps.social_graph] claims
    scoring.jac
    utils.jac
  web/                       [apps.web]  (dir-rooted)
    main.jac
    pages/
  mobile/                    [apps.mobile]
    main.jac
  cli/                       [apps.cli]
    main.jac
```

Shared code is the only thing two apps may both load in-process. The compiler
enforces the layering with two laws, checked wherever a symbol is used:

- **App isolation** (`E2039` / `W2039`): a module of app *A* may not use a
  symbol declared in a module of app *B*, except through app *B*'s **bridge
  surface** -- its walkers and `def:pub` functions, which compile to a call
  across the boundary rather than an in-process reference.
- **Shared layering** (`E2040` / `W2040`): a shared module may not import from
  any app. Dependencies point from apps toward shared code, never back.

Both follow `[check] enforce_access`: they are errors when access is enforced
and warnings otherwise, exactly like `E2038`.

## The implicit single app

With no `[apps]` table the project is one app. Its name is `[project] name`
(or `"main"`), its kind is `[project] kind` (or inferred from the entry-point,
exactly as before), its entry is `[project] entry-point`, and its root is the
project root. Nothing about a single-app `jac.toml` changed:

```toml
[project]
name = "hello"
entry-point = "main.jac"
kind = "web-app"
```

The two forms are exclusive. `[project] kind` and `[project] entry-point`
cannot appear alongside `[apps]` -- the parser raises a hard error telling you
to move the key onto the app (`[apps.<name>] kind`), and the CLI exits 2.

## Effective configuration

Each app sees its own **effective config**, assembled in this order (later
layers win, tables deep-merge):

1. the base `jac.toml`;
2. the app's overlays -- every `[apps.<name>.<section>]` table, merged over the
   matching top-level `[<section>]`;
3. the active profile -- `jac.<profile>.toml` and/or `[environments.<profile>]`,
   selected by `--profile`, `JAC_PROFILE`, or `[environment] default_profile`;
4. `jac.local.toml`.

Any recognized section may be overlaid per app:

```toml
[serve]
port = 8000                        # every app that serves

[apps.web.serve]
port = 3000                        # ...except web

[apps.mobile.dependencies.npm]     # merged over the base [dependencies.npm]
lucide-react-native = "^0.4"

[apps.social_graph.scale]          # per-app scale settings (replicas, resources, ...)
http_activation = true

[apps.web.placement.pins]          # per-app pins merged over the base [placement.pins]
"core.docs.*" = "server"

[apps.kiosk.desktop]               # a desktop app's identity, window and backend
backend = "https://example.org"
```

`jac run web` reads `serve.port` from the `web` effective config; `jac test
mobile` reads `[test]` from the `mobile` effective config and resolves its
`directories` against the app root; `jac config` shows the base file, and the
`apps` group lists the app tables.

`${VAR}`, `${VAR:-default}` and `${VAR:?message}` interpolation applies to
**every** string in the file, uniformly -- app tables, overlays, profiles, and
capability tables alike. There are no sections where it is skipped.

`default-app` names the app a bare `jac run`, `jac build`, `jac test`, or `jac
setup` targets. Without it, a workspace with exactly one app uses that app; a
workspace with several and no default errors, listing the apps.

## Ownership: one owner per server-placed shared module

Shared code that carries walkers or persisted node/edge archetypes has to run
on exactly one app's server, so that every other app bridges to the same place.
That app is the module's **owner**:

- A **file-rooted service app** owns its entry file explicitly. This is what
  `[apps.social_graph] entry-point = "core/social_graph.jac"` means: the
  walkers in that file run in the `social_graph` app, and every other app that
  imports them bridges there.
- Otherwise, when the workspace has exactly one serving app, it owns every
  server-placed shared module implicitly. A `web` app plus a `mobile` app plus
  a `cli` app needs no service tables at all: `web` owns the server side.
- When several apps serve, `[project] default-app` breaks the tie: the default
  app is the implicit owner of every server-placed shared module that no
  service app claims. In the flagship, `web` owns the docs graph and the
  leaderboard while `social_graph` and `scoring` own their own entry files.
- Two or more serving apps, no `default-app`, and a shared module that defines
  walkers or node/edge archetypes with no explicit owner is **`E5107`**. Give the module its own `[apps.<name>]`
  table (`kind = "service"`, `entry-point = "<path>"`), or pin it to an owner
  with `[apps.<owner>.placement.pins] "<module>" = "server"`.

Client apps are consumers. A `mobile` or `web-static` app that imports a
server-placed walker bridges to the owner; a `cli` app does the same -- a
command-line app never touches another app's store directly. Store-touching
admin commands are entry actions of the owning app.

## The app dependency graph

Every bridged import records an edge *consumer app → provider app*. The graph
has to be a DAG: apps bridge to their providers over the wire, and providers
boot first, so a cycle has no boot order. **`E5104`** names the cycle on the
import that closes it. Break it by moving the code both apps need into shared
code, or by folding one app into the other.

The **bridge surface** of an app is one bit: a walker or a `def:pub` function
is callable by any consumer app; everything else in the app is private to its
own server. Bridging to a non-`pub` element is **`E5106`**. There are no
per-app grants.

## Routes

An app with a server answers under its `route`, default `/api/<name>`. Routes
are checked at config load: two serving apps claiming the same prefix, or an
app claiming a prefix a page owns, is a hard config error.

When you `jac run <app>` a client-capable app, that app is served at `/`.
Other client-capable apps in the workspace whose bundle has been built
(`jac build --all` writes `dist/<app>/`) are mounted at `/cl/<app-name>/` --
a constant prefix, with no config key. The API index, `/docs`, `/walker/*` and
`/function/*` belong to the served app as before.

## Working with a workspace

Every command that used to take a filename now takes an **app name or a
path**. A target that matches a key in `[apps]` is an app; anything else is a
file. There is no `--app` flag on `run`/`build`/`test`/`setup` -- the
positional is the interface.

```bash
jac run                      # the default-app (or the sole app), per its kind
jac run web                  # serve the web app (web-app kinds serve)
jac run cli -- score jaseci-labs/jac      # execute the cli app; argv after --
jac run --dev --platform web mobile       # run the mobile app in a browser (react-native-web)
jac run --show               # one plan row per app: app, kind, entry, action, ui, route
jac run web --fleet          # serve web; run the service apps as separate local processes

jac build                    # the default app's artifact into dist/
jac build --all              # every app into dist/<app>/
jac build mobile --platform ios

jac check                    # the workspace gate (below)
jac check --app web          # one app only
jac test social_graph        # [test] from that app's effective config, rooted at the app
jac setup mobile             # the app named mobile; `jac setup` alone is the default app

jac create myproj --kind web-app         # a single-app project, as before
jac create --app scoring --kind service  # scaffold an app inside this project
jac create --app admin --kind web-app --path tools/admin
jac create mysite --awesome              # the flagship workspace, below
```

`jac create --app <name> --kind <kind>` writes the app's files under
`<path>/` (default: the app name) and appends an `[apps.<name>]` table to the
project's `jac.toml`, leaving the rest of the file intact.

**`jac check` is the workspace gate.** With no paths in a workspace it compiles
**one rooted program per app entry**, each with that app's facts stamped, then
sweeps every `.jac` file no app reached as its own root. When more than one
app was checked, each diagnostic is prefixed `[<app>]`. Explicit paths keep the
file-per-root behavior you know, with the owning app's facts. `--app <name>`
restricts the run to one app. Because the same app facts drive placement, the
`.jir` placement cache is keyed by an **app-fact digest** (name, kind,
platform, pins, npm names), so changing an app table invalidates
exactly the modules it affects.

## Worked example: the flagship workspace

`jac create <name> --awesome` scaffolds jaclang.org itself -- five apps over
one shared `core/`:

```toml
[project]
name = "jaclang_org"
default-app = "web"

[apps.web]                     # the site: landing, docs, leaderboard, socialize, wasm game
kind = "web-app"
path = "web"

[apps.mobile]                  # a mobUI (React Native) client for the same social graph
kind = "mobile"
path = "mobile"

[apps.cli]                     # a command-line client: offline scorer + docs/feed over the wire
kind = "cli"
path = "cli"

[apps.social_graph]            # file-rooted service app: owns the socialize walkers
kind = "service"
entry-point = "core/social_graph.jac"

[apps.scoring]                 # file-rooted service app: owns the leaderboard scorer
kind = "service"
entry-point = "core/scoring_service.jac"

[test]
directories = ["core", "web", "cli"]

[apps.web.client.vite]         # web-only client settings stay on the web app
plugins = ["tailwindcss()"]
```

```
jaclang_org/
  core/            shared domain + logic: NO JSX, NO DOM
    social_graph.jac       ← [apps.social_graph] claims exactly this file
    scoring_service.jac    ← [apps.scoring] claims exactly this file
    leaderboard/  docs/  source/  github.jac  utils.jac ...
  web/             the site (main.jac, pages/, docs/, leaderboard/, socialize/, ui/ ...)
  mobile/          screens/, components/, theme.jac, icon.jac + icon.native.jac
  cli/             main.jac, commands/
```

Read it top down. `core/social_graph.jac` declares the nodes, edges and
walkers of the social app -- one file, no routes, no serializers. The `web`
app's `socialize/` pages, the `mobile` app's screens, and the `cli` app's
`feed`/`post` commands all `import from core.social_graph { load_feed,
create_tweet, ... }` with a plain import. The compiler classifies each import
by the owner of what is imported: the `web` app's client code bridges over
HTTP as it always did; the `mobile` app's screens do the same from React
Native; the `cli` app -- server-side Python, but not the owner -- gets a
**typed-async stub** and `await`s the call. Nothing in the source says which
is which.

The `cli` app's `score` command imports `core.leaderboard.scoring` -- a pure
shared module -- and runs it offline, in-process. Same import form, no bridge,
because nothing server-placed is involved.

## The consistency model

**Within an app, one request is one transaction.** A walker spawned on the
`social_graph` app reads and writes that app's store atomically, exactly as a
single-app server does today.

**Across apps, consistency is eventual, and the write path is single-writer.**
A consumer never writes another app's store; it *ships a walker* to the owner
and the owner writes. Two shapes of shipping exist, chosen by whether you wait:

```jac
import from core.social_graph { create_tweet, load_feed }

# awaited: the result comes back, failures raise
walker:pub post_and_show {
    can run with Root entry {
        posted = await create_tweet(content=self.text);   # runs on social_graph
        feed = await load_feed(limit=10);
        report feed.reports;
    }
}

# un-awaited, statement context: deferred delivery through the outbox
walker:pub fire_and_forget {
    can run with Root entry {
        create_tweet(content=self.text);   # enqueued; at-least-once; never raises here
        report "queued";
    }
}
```

- **Awaited** cross-app calls are coroutines (the type checker reports a
  missing `await` as `E1042`, in server code just as in client code). A
  failure raises one of the **`BridgeError`** family from
  `jaclang.server.bridge` -- `BridgeUnavailable` (no route to the provider),
  `BridgeTimeout`, `BridgeRejected` (the provider answered 4xx: not `pub`,
  unauthorized, bad arguments), or plain `BridgeError` (5xx) -- each carrying
  `app`, `name`, `detail` and `status`. Client apps get the same four classes
  from `@jac/runtime`. Exception parity with an in-process spawn is the
  contract: catch at the boundary where you want graceful degradation.
- **Un-awaited** cross-app walker spawns in statement position never raise at
  the call site. The spawn is written to an **outbox** inside the caller's
  request, then delivered to the owner by a background worker with
  exponential backoff (up to 8 attempts, then dead-lettered). Every entry
  carries an idempotency key (default: a hash of app, walker and arguments;
  pass your own when the arguments alone are not identity), sent as
  `X-Jac-Idempotency-Key`; the receiving app dedupes by key, so delivery is
  **at-least-once with idempotent receipt**. The outbox lives in the project's
  Postgres store when one is configured, else in `.jac/data/outbox.sqlite`.
- **Reads go to the owner** by default (owner-read). An app may opt into an
  in-process read cache for effect-free provider endpoints with
  `[apps.<consumer>.scale] read_cache = true`; the cache is invalidated when an
  effectful call to the same provider app goes through.

## Boundary is structural, topology is profile

Every app boundary is compiled as a cut whether or not the apps ever run
apart. Where they run is decided when you serve:

| Topology | How | What runs where |
|---|---|---|
| **Colocated** (default) | `jac run <app>` | Every service app is loaded into the served app's process and registered locally; bridged calls are in-process (still awaited, no HTTP). |
| **Local fleet** | `jac run <app> --fleet`, or `[scale.gateway] colocate = false` | Each service app is a separate local process behind the served app's gateway; bridged calls go over HTTP; peers find each other through `JAC_APP_<APP>_URL`. |
| **Deployed** | `jac scale deploy` | Always a fleet: each service app is its own Deployment/Service/HPA, the served app hosts the gateway, peer URLs are injected, and providers boot before their consumers (the DAG order). `colocate` is ignored. |

Fleet membership is the set of serving apps -- `web-app`, `service`, and
`service-mesh` kinds. The gateway's own knobs live under `[scale.gateway]`
(ports, timeouts, CORS, rate limiting, logs, tracing, shared volumes, `colocate`);
per-app scale settings live in the app's `[apps.<name>.scale]` overlay. See
[Scale -- HTTP API & Walkers](plugins/jac-scale-http.md#service-apps-cross-app-bridging)
and [Kubernetes & Operations](plugins/jac-scale-kubernetes.md#service-apps-in-kubernetes).

## Related diagnostics

- `E2039` / `W2039` -- app isolation: a symbol of one app used from another
  outside the bridge surface.
- `E2040` / `W2040` -- shared layering: a shared module importing from an app.
- `E5107` -- a server-placed shared module with no single owner.
- `E5108` -- an app importing another app's node or edge; only walkers and
  `def:pub` functions bridge, and an imported `obj` or `enum` mirrors as a
  boundary type.
- `E5104` -- an app dependency cycle.
- `E5105` -- a `.native.jac` variant disagrees with its base module's public
  surface.
- `E5106` -- bridging to a non-`pub` element of another app.
- `E5087` -- an app whose kind has no server contains code that needs one.
- `E1042` -- a bridged call that was not awaited.

See [Diagnostics](diagnostics.md) for the full reference, and
[Placement](placement.md) for how app facts feed the placement solver.
