---
description: Building and running a project's apps - jac build and jac run for apps, jac dev for working on one, what each app's artifact in dist/ holds, one artifact that holds several arrangements of an app, stopping a running app, rebuilds that skip what did not change, and the deployment values baked into an artifact with the environment variables that override them.
keywords: artifact, artifacts, deployment values, bundle-read.json, .jac/build, stopping an app, SIGTERM, SIGINT, jac dev, dev server, watch, rebuild on save, --listen, JAC_DEV_LISTEN, JAC_DEV_PAGE, JAC_DEV_SERVED, arrangement, arrangements, JAC_<APP>_ARRANGEMENT
---
# Building apps

`jac build` and `jac run`, given app names instead of a main module, build the apps a
project's `archwire.jac` declares ([the archwire](archwire.md), `jac docs graph spaces`). Each
app becomes one **artifact** in `dist/`, which needs nothing installed where it runs: not jac,
not Python, not Node.

`examples/jaclang_org` in jac's repository is a complete project of this kind: a web app with a
React site, Preact and Solid demos and a wasm game, a desktop app, a phone app and a command-line
app, built from one archwire.

## Commands

Run them from the project's root, the directory with `archwire.jac`:

```sh
jac build                       # every app of the archwire
jac build web cli               # those apps
jac build web --profile fleet   # an app as a profile arranges it
jac run web                     # build the app, then run it
jac run cli -- docs status      # pass the app its own arguments
jac run web --fresh             # run it with no data
jac dev web                     # build it, run it, and rebuild as you edit
```

| Command | Does |
|---|---|
| `jac build [<app>...] [--profile <profile>]` | Builds the apps named, or every app, and prints each artifact's path |
| `jac run <app> [--fresh] [--profile <profile>] [-- <argument>...]` | Builds one app as `build` does, then runs it in its own place with the arguments after `--`; the status it ends with is the app's |
| `jac dev <app> [--listen <address>] [--fresh] [--profile <profile>] [-- <argument>...]` | Builds one app, starts it, and from then on builds again what each edit reaches ([below](#working-on-an-app)) |
| `jac check [<app>...] [--profile <profile>]` | Checks the apps named, or every app and every space no app holds: each program an app is, on its host, as its build compiles it ([check](../toolchain/check.md#checking-a-project)) |
| `jac check [<app>] --space <space>` | Checks one space's modules on its host: the app's program of it, with the app's plan, or the space alone |
| `jac emit-js <space> -o <dir> [--app <app>]` | Writes a JavaScript space's compiled modules (browser, node, hermes); with `--app`, as that app's build writes them, with its plan |
| `jac emit-py <space> -o <dir> [--app <app>]` | Writes a cpython space's compiled code and, in `<dir>/py/`, its Python source; with `--app`, with `stdjac.app` as its main module when it serves |

`--profile` and `--fresh` are on [the archwire](archwire.md#profiles) and
[An app's data](data.md#a-fresh-start). An app whose `jac.toml` lists `profiles` is built, with no
`--profile`, as one artifact that holds them all
([below](#several-arrangements-in-one-artifact)). An app that cannot be built is reported after
the others have been built, and the build exits with status 1.

| Mistake | What jac says |
|---|---|
| No `archwire.jac` in the directory | `` `jac build` builds the apps of the project in this directory, and there is no archwire.jac here `` |
| An app the archwire does not declare | `this project has no app 'nope': its apps are web, desk` |
| `jac run` with no app, or with two | `it needs the app to run`; `it runs one app, and was given 2: what an app is given goes after --` |
| `jac dev` with no app, or with two | `it needs the app to work on`; `it works on one app, and was given 2: what an app is given goes after --` |
| `--` after `jac build` | `` `--` begins an app's arguments, which `jac run` passes `` |
| A profile the archwire does not declare | E1274 |

An app builds for the machine jac runs on. Building a program for another platform is
`jac build <main.jac> --target`, on [build](../toolchain/build.md) (`jac docs build`).

## What a build does

For each app, from its archwire:

1. Compiles each JavaScript space it runs or serves (browser, node, hermes) to ES modules, and
   each cpython space to CPython code objects. Each is checked as its own program on its host.
2. Builds each wasm space it serves for `wasm32-wasi`, and puts the module beside the pages that
   call it.
3. Runs each browser or hermes space's bundler ([UI plugins and bundlers](ui-bindings.md)).
4. Compiles the app's program: its native spaces with jac's app runtime, `stdjac`, which starts
   it. No server code is generated; the runtime reads what the app is from the **plan** the build
   bakes into the program (below).
5. Assembles the artifact in `dist/`.

The work in between is in `.jac/build/<app>/` in the project, and a JavaScript space's in its npm
tree's, `eco/<tree>/.jac/build/<app>/`; compiled modules are in jac's
build cache, shared by every project (see [build](../toolchain/build.md)).

## Artifacts

| The app | Its artifact |
|---|---|
| Native spaces only | `dist/<app>-<platform>`: one program |
| Native spaces that serve pages, or run a cpython or node space, or use npm or Python packages | `dist/<app>-<platform>/`: the program `<app>` and what it reads, beside it |
| One node space | `dist/<app>/`: its modules, Node, the project's npm packages and the launcher `<app>` |
| One cpython space | `dist/<app>/`: its code, CPython and its home, and the launcher `<app>` |
| A browser space it runs (a desktop app) | `dist/<app>-<platform>/`: the program and the pages |
| One hermes space | `dist/<app>/`: the phone app's bundles, as Expo exported them |

`<platform>` is the machine's: `macos-aarch64`, `linux-x86_64` and so on. A program's directory
holds, as its app needs:

| Path | Holds |
|---|---|
| `<app>` | The program |
| `pages/<space>/` | Each browser space it serves, as its bundler wrote it |
| `lib/python315.zip` | CPython's standard library, compressed |
| `lib/python3.15/site-packages/` | The project's Python packages |
| `eco/<tree>/package.json`, `eco/<tree>/node_modules/` | The packages of an npm tree its code requires, with their production dependencies, where the tree is in the project |
| `spaces/<space>/` | The code of each cpython space it runs in its process |
| `eco/<tree>/spaces/<space>/` | The code of each node space it runs in its process, under its tree's packages, where Node resolves them from |

Copy the directory to a machine of that platform and run the program; nothing else is needed
there. When an app's artifact changes from a single program to a directory (it starts serving a
page, say), the build removes the other form.

## Several arrangements in one artifact

A [profile](archwire.md#profiles) arranges an app another way: the same name, with other spaces
in its `run`. `--profile` builds the app as one profile arranges it. `profiles` in `jac.toml`
puts several in one artifact instead, and its program is whichever **arrangement** is chosen
where it runs:

```toml
[apps.desk]
profiles = ["default", "local"]
```

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space api: native { svc; }
    space site: browser { entry web; pages.*; }

    app web { run api; serve site; }
    app desk { run site; }
}

graph spaces local {
    app desk { run site, api; }
}
```

- **`profiles` lists the archwire's profiles by name**, and `default` names its unnamed
  `graph spaces` block. A name that is no profile is E1274. A profile that does not declare the
  app arranges it as the unnamed block does. One name alone is an app with one arrangement.
- **`jac build desk`, with no `--profile`, builds the app as the arrangement that runs and
  serves every space the others do**, here `local`, so its program holds the code of each, and
  bakes a plan for every arrangement into it. With no such arrangement the app does not build
  (E5090: `an app 'desk' in one artifact as profiles none of which runs every space the others
  run`). `jac run` and `jac dev` build it the same way.
- **An arrangement runs all of the artifact's native spaces or none of them.** The program is
  one body of native code, in which a call from one native space to another is an ordinary call
  and a scheduled function is the program's, so an arrangement that ran some and not others
  could not leave the others out: it is refused (E5090: `an arrangement 'default' of app 'shop'
  that runs some of its artifact's native spaces and not others`). The arrangements may differ
  in the browser spaces they run and in the cpython and node spaces the program starts in its
  process.
- **`--profile local` still builds one arrangement**: a program that is only that.

Which arrangement a run is:

| In order | Decides |
|---|---|
| `JAC_<APP>_ARRANGEMENT` | The arrangement it names, where the program runs |
| The file `arrangement` in the app's data directory | The one the app's user chose ([An app's data](data.md#where-it-is-kept)) |
| Neither | The first that `profiles` lists |

A name that is none of the app's arrangements, in either place, leaves the first.

The app's user chooses from a page, with `jacUseArrangement(name)`
([Pages](pages.md#the-apps-arrangement)), which asks the app itself:

| Request | Reply's `data` |
|---|---|
| `GET /__jac/app/arrangement` | `{"names": ["default", "local"], "current": "default", "chosen": false}`: the arrangements, the one this run is, and whether it was chosen. `names` is empty for an app with one arrangement |
| `POST /__jac/app/arrangement` with `{"name": "local"}` | The same. The choice is kept. A name that is no arrangement is 400 `rejected` (`desk has no arrangement 'nope': it may be default, local`) |

A desktop app then closes its window and starts again in its own place as the arrangement chosen
([Hosts](hosts.md#one-program-with-a-server-or-without)). An app with no window is the arrangement
chosen the next time it starts.

In an arrangement that does not run a space the program holds, here `api` as `default`:

- the space's endpoints are not served: a request for one is 404;
- a page's calls of the space are forwarded to its URL in `[apps.<app>.remote]`, as for any space
  the app reaches and does not run ([Crossings](crossings.md#a-pages-calls-go-through-its-app));
- a native space's modules are still part of the program, and start with it, but none of its
  [scheduled functions](server.md#scheduled-functions-schedule) run;
- a cpython or node space the arrangement does not run is not started.

Every arrangement keeps its data in the app's one data directory.

## Stopping an app

`jac run <app>` builds the app, then runs its program from `dist/` in its own place: the
process that was `jac run` is the app's program from then on, with the same process id, parent
and terminal. No process of jac's stands between the app and whoever started it, so a signal
sent to `jac run` is sent to the app, the terminal's Ctrl-C reaches it once, and the status the
process ends with is the app's own (143 in a shell for an app SIGTERM stopped). On Windows, which
has no such call, the app is a child process `jac run` waits for.

A serving app installs no handler for SIGINT or SIGTERM: either signal stops its program at once.
What it has kept stays kept, since each call's changes are written when the call returns
([An app's data](data.md#when-the-graph-is-written)).

| The app was started | Stop it with |
|---|---|
| By `jac run`, in a terminal | Ctrl-C |
| By `jac run`, in the background | `kill <pid of jac run>`, which sends SIGTERM: that process is the app |
| By running its program yourself | `kill <pid>` |

A script or a test that only runs an app, and has built it, can start the built program itself.
It is `dist/<app>-<platform>` for an app that is one program, and
`dist/<app>-<platform>/<app>` for one whose artifact is a directory (an app that serves pages):

```sh
jac build web
JAC_WEB_LISTEN=127.0.0.1:8301 dist/web-macos-aarch64/web &
WEB_PID=$!
curl -s -X POST http://127.0.0.1:8301/__jac/call/api/svc/greet -d '{"args": {"name": "curl"}}'
kill $WEB_PID
```

A program a script starts with `&` ignores SIGINT, as the shell makes every background job of a
script do, so stop it with `kill`'s default, SIGTERM.

## Rebuilds

A build does only what a change reaches:

- A space is compiled again when something its compile read has changed: a module, or what a
  directory it holds whole lists. A page added under `pages/`, or removed, is routed by the next
  build, and so is a directory of them.
- The program is built again when its sources have, a module added to a package one of its spaces
  holds whole (`svc.*`) among them.
- A bundle is made again when its bundler says something it read has changed.
- Each part of the artifact is copied again only when what it is made from has changed.

With nothing changed, `jac build` runs nothing, and on a terminal says `✓ web is up to date`.

What a bundler read is in `bundle-read.json`, which it writes in its work directory:

```json
{"root": "/home/me/site", "files": ["..."], "missing": ["..."], "globs": ["src/**/*.css"], "public": "...", "env": ["NODE_ENV", "VITE_*"]}
```

| Field | Is |
|---|---|
| `root` | The directory `globs` are from |
| `files` | The files it read |
| `missing` | Paths it looked for and found nothing at |
| `globs` | Patterns for files it would read if they appeared |
| `public` | A directory it copies whole |
| `env` | The environment variables it read: a name, or `PREFIX*` for every variable so named |

Vite's half, `@jac/vite`, writes it from what Vite itself would rebuild for in watch mode (the
bundle's modules and what its Vite plugins watch), with Vite's configuration and what it imports, the
mode's `.env` files, the nearest `tsconfig.json` or `jsconfig.json`, `NODE_ENV` and the `VITE_`
variables. Expo's writes the space's modules as jac wrote them, the packages its npm tree pins
(`package.json` and `package-lock.json`), `NODE_ENV` and the `EXPO_PUBLIC_` variables; with none
of them changed a phone app is not bundled again, and its Android app is not built again. A
project's own bundler may write the same file. A bundler that writes none runs on every build.

A style-sheet framework that scans the whole project for class names, as Tailwind does by default,
makes every source file something the bundle read, so any edit bundles again. Tell it where the
markup is instead: `examples/jaclang_org` names its site's directories with `@source` in its
style sheet, so an edit to its backend bundles nothing.

## Working on an app

`jac dev <app>` builds the app, starts it, and watches the project:

```sh
jac dev web                           # the page is at http://127.0.0.1:8000/
jac dev web --listen 127.0.0.1:9000   # somewhere else
jac dev web --fresh -- --verbose      # no data, and the app's own arguments
```

When a file of the project changes, it builds again as `jac build <app>` would, which does only
what the change reaches (above), then:

| The build | `jac dev` |
|---|---|
| Changed what the app's program is or loads as it starts | Stops the program and starts it again |
| Changed only a page | Leaves the program running |
| Failed | Prints the diagnostics and leaves what is running as it was |

- **What is watched.** Every file under the project's root but those in `dist/` there, and in any
  `.jac/`, `node_modules/` or `.git/`. jac looks ten times a second. `jac.toml` and `jac.lock`
  are watched, so a package added with `jac install --npm` is noticed as it is added.
- **A build that fails** shows what is wrong, wherever it is: in a module, in the app, or in an
  `archwire.jac` that cannot be read. While it stays wrong, each build shows it again.
- **`--fresh`** applies to the first start only ([An app's data](data.md#a-fresh-start)).
- **A program that ends** is reported with its status, and starts again at the next change.
- **Stopping.** Ctrl-C, or SIGINT or SIGTERM to `jac dev`, stops the program and the dev server
  it started; `jac dev` then exits with 128 plus the signal's number.
- **`dist/`** holds the app's artifact as built, but for a page a dev server serves (below),
  whose copy there stays as the last `jac build` left it.

### A page from its bundler's dev server

An app's page is served by its bundler's dev server instead of being bundled, when the bundler has
one. The shipped `vite` and `expo` bundlers do; [a project's own](ui-bindings.md#a-projects-own-bundler)
does when its plugin names a `serve` script. The page served is the space whose `base` is `/`, else the first the
app serves; its other pages are bundled, and served by the program, as in the built app.

- **Where things are.** The dev server listens at `--listen` (`127.0.0.1:8000` without it), and
  the app's program at a free port of its own.
- **What the program still answers.** The dev server asks the program first for every request that
  is not its own, and serves what the program answers 404 to a GET for. So the app's endpoints,
  routes and other pages answer as in the built app.
- **A page edit** is one compile of its space and no bundle: the dev server sees the modules that
  came out different and reloads the open page.
- **A desktop app's** window opens the dev server's page, and closes when its app is stopped or
  started again.
- **A phone app** (one hermes space) is served by Expo's dev server, Metro, to a device or an
  emulator, at the port of `--listen` (8000 without it).

An app with no page a dev server serves runs as `jac run` starts it, at its own address, or at
`--listen` when that is given.

`jac dev` tells the program it starts where it is, with variables you never set yourself:

| Variable | Is |
|---|---|
| `JAC_DEV_LISTEN` | Where the program listens, in place of its own address |
| `JAC_DEV_SERVED` | The page space the dev server serves, of which the program answers nothing |
| `JAC_DEV_PAGE` | The dev server's page, which a desktop app's window opens |

## Deployment values

What an app is, and where its parts are, is baked into its program when it is built, from the
archwire and `jac.toml`. Each value that differs between deployments has an environment variable
that overrides it where the artifact runs, so one artifact deploys to staging and production:

| Value | Baked from | Overridden by |
|---|---|---|
| The address a serving app listens on | `127.0.0.1:8000` | `JAC_<APP>_LISTEN` |
| Where the app keeps its data | `.jac/data/<app>` in the project, as an absolute path | `JAC_<APP>_DATA` |
| Where each space it reaches and does not run is | `[apps.<app>.remote]` | `JAC_REMOTE_<SPACE>` |
| Where a cpython or node space's code is, for one the program runs in its process | `spaces/<space>/` beside the program | `JAC_<SPACE>_CODE` |
| The model `by llm()` asks | `[llm] model` | `JAC_LLM_MODEL` ([By and sem](../language/by-and-sem.md)) |
| Which arrangement the program is, of those its artifact holds | The first of `[apps.<app>] profiles`, until its user chooses | `JAC_<APP>_ARRANGEMENT` |

`<APP>` and `<SPACE>` are the names uppercased, each character that is not a letter or a digit made
`_`: the space `site_api` is `JAC_REMOTE_SITE_API`.

Other variables are read where the program runs and never baked: `JAC_DEPLOY_KEY` and
`JAC_REMOTE_TOKEN` ([Crossings](crossings.md)), `JAC_FRESH` ([An app's data](data.md)),
`JAC_TICKS_OFF` ([Serving a space](server.md)), and `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL`
([By and sem](../language/by-and-sem.md)).

The plan also holds what never changes between deployments: the spaces the program is, the pages
it serves and the endpoints they may reach through it, its window, and the spaces it runs in its
process.

### jac.toml for apps

```toml
[apps.web.remote]
knowledge = "https://knowledge.example.com"

[apps.desktop]
profiles = ["default", "local"]

[apps.desktop.window]
title = "Example"
width = 1280
height = 860

[spaces.site]
base = "/"

[spaces.site.ui]
plugin = "react"

[llm.anthropic]
model = "claude-sonnet-5-5"

[auth.accounts]
local_users = true
```

| Table | Keys | Page |
|---|---|---|
| `[apps.<app>]` | `profiles` | [Above](#several-arrangements-in-one-artifact) |
| `[apps.<app>.remote]` | A URL for each space the app reaches and does not run | [Crossings](crossings.md#where-the-other-space-is) |
| `[apps.<app>.window]` | `title`, `width`, `height`, `min_width`, `min_height` | [Hosts](hosts.md#desktop-apps) |
| `[spaces.<space>]` | `base`, `npm` | [UI plugins and bundlers](ui-bindings.md#choosing-a-spaces-plugins), [Packages](../toolchain/packages.md#which-tree-a-spaces-imports-use) |
| `[spaces.<space>.ui]`, `[spaces.<space>.bundler]` | The `ui` plugin and the `bundler` plugin a JavaScript space is built with, and the bundler's settings | [UI plugins and bundlers](ui-bindings.md#choosing-a-spaces-plugins) |
| `[<abstraction>]`, `[<abstraction>.<plugin>]` | The plugin that carries out an abstraction (`store`, `auth`, `transport`, `llm`, `jobs`, `schedule`, `limits`), and each listed plugin's settings | [Plugins](plugins.md) |

An app that reaches a space it does not run, with no URL for it, does not build:

```text
archwire.jac:10:5: error[E1212]: app 'desk' reaches space 'api' but doesn't run it: give its URL in jac.toml's [apps.desk.remote]
```

Give a placeholder and set `JAC_REMOTE_<SPACE>` where it runs if the address is known only there.

## What goes wrong

| Symptom | Cause |
|---|---|
| E1212 | An app reaches a space with no URL in `[apps.<app>.remote]` |
| E1274 | `--profile`, or `profiles` in `jac.toml`, names no profile of the archwire |
| E5090 | An arrangement the build does not make yet ([Hosts](hosts.md#what-is-rejected)) |
| E5160 | An npm tree's packages are not installed as `jac.toml` and `jac.lock` say: `jac install` |
| `bundling site with vite` fails, with Vite's own error | The bundler's error: a file a module imports missing, a Vite plugin its configuration names not among the tree's packages |
| `<app> can't start with the data it kept in ...` | The program's types changed under kept data ([An app's data](data.md)) |
| `<app> can't listen on <address>: Address already in use` | Another program listens on its address: set `JAC_<APP>_LISTEN` ([Serving a space](server.md#the-shortest-server)) |
