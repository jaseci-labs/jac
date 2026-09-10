---
name: jac-apps
description: Configure workspace app membership, shared modules, and cross-app boundaries. Use for multi-app projects or E2039, E5104–E5106, and E5108 diagnostics.
---

An app is a declared entry module plus a build kind. CLI `run`, `build`, or
`check --app` selects its compilation context. Ordinary imports inherit that
context; imports through another declared entry cross an app boundary.

```toml
[project]
name = "acme"
default-app = "web"

[apps.web]
kind = "web-app"
entry-point = "web.main"

[apps.mobile]
kind = "mobile"
entry-point = "mobile.main"
platform = "android"

[apps.social_graph]
kind = "service"
entry-point = "core.social_graph"
```

Every explicit app requires `kind` and `entry-point`. Entries are relative to the
project root and must be distinct. The former directory `path` key is rejected.
A project without `[apps]` retains its implicit app configuration.

Shared source can participate in several app contexts. Its syntax is reused,
while semantic facts, artifacts, and runtime module globals remain app specific.
Neither directory containment, `default-app`, nor placement pins assign global
ownership. To share a server's state through an API, declare a service entry and
import its public walkers or `def:pub` functions. Direct helper imports are local
to the selected app context.

`E2039`/`W2039` report access to private declarations through another app's entry;
`[check] enforce_access` selects errors instead of warnings.

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
