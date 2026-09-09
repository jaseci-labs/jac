---
name: jac-apps
description: Configure workspace app membership, shared modules, and cross-app boundaries. Use for multi-app projects or E2039/E2040 and E5104–E5108 diagnostics.
---

A Jac project is a set of **apps** over one body of **shared code**. Each app is a table in `jac.toml` with a *kind* (what it builds) and a root (which files are its). Everything under no app's root is shared: any app may import it, none owns it. A project with no `[apps]` table is the simplest case, one **implicit app** named after `[project] name`, and nothing about that `jac.toml` changed.

```
[project]
name = "acme"
default-app = "web"          # a bare `jac run` / `jac build` / `jac test` uses it

[apps.web]                   # dir-rooted: every module under web/ is the web app's
kind = "web-app"             # required: any project kind
path = "web"                 # optional dir root; omit for a file-rooted app
entry-point = "main.jac"     # optional, relative to path; default is the kind's entry
route = "/api/web"           # optional; default /api/<name>; serving kinds only

[apps.mobile]
kind = "mobile"              # mobUI (React Native) client; E1105 guards host tags
path = "mobile"
platform = "android"         # default platform for run/build; --platform overrides

[apps.social_graph]          # file-rooted service app: it owns exactly this file
kind = "service"
entry-point = "core/social_graph.jac"
```

**The five keys are the whole table.** `client`, `client_kind`, or any other key under `[apps.<name>]` is a hard config error naming the accepted keys; the kind decides the client (`web-app`, `web-static`, `desktop`, `js-package` render React DOM; `mobile` renders native views). `[project] kind` / `entry-point` cannot appear next to `[apps]`: move them onto an app. App names cannot contain `/` or `\` or end in `.jac`, so a target is always either an app name or a path.

## Membership: who owns a file

- **Dir-rooted** (`path`): every module under the directory, innermost root wins when roots nest.
- **File-rooted** (`entry-point` only): exactly that file, not its siblings.
- **Shared**: under no root. Shared code is the only thing two apps may both load in-process, and it never imports from an app.

```
acme/
  jac.toml
  core/                 shared; no app claims this directory...
    social_graph.jac    ...except this file, which [apps.social_graph] claims
    scoring.jac
  web/  mobile/  cli/   one app each
```

Two laws follow `[check] enforce_access` (errors when enforced, else warnings):

- **E2039 app isolation**: app A may not use a symbol of app B except through B's **bridge surface**, its walkers and `def:pub` functions, which compile to a call across the boundary.
- **E2040 shared layering**: a shared module may not import from any app. Dependencies point from apps toward shared code, never back.

## Ownership of server-placed shared code

A shared module with walkers or persisted `node`/`edge` archetypes runs on exactly **one** app's server so every other app bridges to the same place. The owner is decided in this order:

1. a **file-rooted service app** whose `entry-point` is the module (explicit);
2. the **only serving app**, when there is one (a `web` + `mobile` + `cli` workspace needs no service tables: `web` owns the server side);
3. `[project] default-app` when several apps serve;
4. otherwise **E5107**: give the module its own `[apps.<name>] kind = "service"` table, or pin it with `[apps.<owner>.placement.pins] "<module>" = "server"`.

Client apps (`mobile`, `web-static`, `cli`) are consumers: they bridge to the owner and never touch another app's store. Store-touching admin commands are entry actions of the owning app.

## The bridge surface and its laws

- A **walker** or `def:pub` function is callable from any consumer app; everything else is private to its own server. Bridging to a non-`pub` element is **E5106**.
- **E5108**: an app may not import another app's `node` or `edge`. Only walkers and `def:pub` bridge; an imported `obj` or `enum` mirrors as a boundary type.
- Every bridged import is an edge consumer -> provider; the graph must be a DAG, providers boot first. **E5104** names the import that closes a cycle: move the code both need into shared code, or fold one app into the other.
- **E5105**: a `.native.jac` platform variant disagrees with its base module's public surface.
- A bridged call is a coroutine: `await` it, or the checker reports **E1042**. Failures raise the `BridgeError` family; an un-awaited walker spawn in statement position goes through the outbox (at-least-once, idempotent receipt). Details, colocation and the wire format: `jac-sv-microservices`.

```jac
import from core.social_graph { create_tweet, load_feed }

walker:pub post_and_show {
    has text: str = "";

    async can run with Root entry {
        posted = await create_tweet(content=self.text);   # runs on social_graph
        feed = await load_feed(limit=10);
        report feed.reports;
    }
}
```

## Per-app configuration

Each app sees its own **effective config**: base `jac.toml`, then every `[apps.<name>.<section>]` overlay deep-merged over the matching `[<section>]`, then the profile (`jac.<profile>.toml` / `[environments.<profile>]`), then `jac.local.toml`. Any section overlays: `[apps.web.serve] port = 3000`, `[apps.mobile.dependencies.npm]`, `[apps.social_graph.scale]`, `[apps.web.placement.pins]`. `${VAR}` interpolation applies to every string, app tables included.

## Commands take an app name or a path

```
jac run                       # the default app (or the sole app), per its kind
jac run web                   # serve web; every service app is COLOCATED in this process
jac run web --fleet           # service apps as separate local processes behind the gateway
jac run cli -- score org/repo # execute the cli app; argv after --
jac run --dev --platform web mobile
jac run --show                # one plan row per app: kind, entry, action, ui, route
jac build                     # the default app -> dist/;  --all -> dist/<app>/
jac build web --as client     # only the client bundle -> .jac/client/web/dist
jac check                     # workspace gate: one rooted program per app, [<app>] prefixes
jac check --app web
jac test social_graph         # [test] from that app's effective config, rooted at the app
jac create --app scoring --kind service          # appends an [apps.scoring] table
jac create --app admin --kind web-app --path tools/admin
jac create mysite --awesome   # the flagship five-app workspace (jaclang.org)
```

**Topology is profile, not source.** Colocated (`jac run <app>`) loads every service app into the served process and bridged calls stay in-process, still awaited. `--fleet` (or `[scale.gateway] colocate = false`) runs each service app as its own process; peers find each other through `JAC_APP_<APP>_URL` / `JAC_APP_<APP>_ROUTE`. `jac scale deploy` is always a fleet: one Deployment per serving app (`web-app`, `service`, `service-mesh`), providers before consumers. Other built client apps mount at `/cl/<app>/` under the served app.

Reference: `jac guide reference/apps` (the model), `reference/placement` (app facts and pins), `reference/diagnostics` (E51xx), and the breaking-changes entry for what the workspace model replaced.
