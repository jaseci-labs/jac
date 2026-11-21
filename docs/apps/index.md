---
description: What an app is in jac, the smallest project with a server and a page, and the map of the apps pages.
keywords: apps
---
# Apps

An app is a program jac builds from a project: a server, a web site with its server, a
command-line tool, a desktop window, a phone app. A project says what its apps are in one file,
`archwire.jac`, and `jac build` turns each into an artifact in `dist/` that needs nothing
installed where it runs.

Four terms carry everything else:

| Term | What it is |
|---|---|
| Space | A named set of modules that run on one host |
| Host | Where a space's code runs: `native`, `browser`, `wasm`, `node`, `hermes` or `cpython` |
| App | The spaces one program runs, and the browser and wasm spaces it serves |
| Crossing | A call from a module of one space to a function or walker of another |

The code never says where it runs. A page calls `greet("jac")` the way it calls any function; the
archwire says `greet` is in a space on the server, so the compiler makes the call a request and the
server answers it. Moving a module to another space, or a space to another app, changes
`archwire.jac` and nothing else.

## The smallest project

A server with one function, and one page that calls it. Seven files:

```text
hello/
  jac.toml          the project
  archwire.jac      its spaces, its app, and what the page may import
  svc.jac           the server's module
  pages/index.jac   the page
  eco/web/          what the page's tools read
    vite.config.ts    the page's bundler configuration
    index.html        the page's HTML shell
```

`jac.toml` marks the project's root, and lists the page's npm packages as the tree `web`:

```toml
[project]
name = "hello"

[npm.web]
private = true
type = "module"

[npm.web.dependencies]
react = "^19.1.0"
react-dom = "^19.1.0"
react-router-dom = "^7.6.0"

[npm.web.devDependencies]
"@vitejs/plugin-react" = "^5.0.0"
vite = "^7.1.0"
```

`[npm.web]` is the tree's `package.json`, which jac writes into `eco/web` from it
([Packages](../toolchain/packages.md)).

`archwire.jac` puts the server's module and the pages in a [layer](../language/modules-layers.md)
each, and declares a space on the server, a space in the browser, one app that runs the first and
serves the second, and the wire that gives the page `greet`, with the edge rule that admits it
from one layer into the other:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer service { svc; }
    layer pages { pages.*; }
}

graph spaces {
    space api: native { svc; }
    space site: browser { pages.*; }

    app web { run api; serve site; }
}

graph import {
    edge Calls: service --> pages;

    svc ++> pages.index { greet }
}
```

`svc.jac` is the server's code. `:pub` lets anyone call `greet` from outside its space:

```jac
def:pub greet(name: str) -> str {
    return "hello " + name;
}
```

`pages/index.jac` is the page at `/`. Its `page` function is a component: `has` declares state, the
`can with entry` block runs once after the page first shows, and the call of `greet` crosses to the
server, so it is awaited:

<!-- example: not checked: a page is a module of a browser space, with JSX and a crossing -->
```jac
def:pub page -> JsxPage {
    has text: str = "...";

    async can with entry {
        text = await greet("jac");
    }

    return <h1>{text}</h1>;
}
```

The remaining two files are the bundler's own, written as its ecosystem writes them, in the
tree's directory, `eco/web`, where the bundler runs.

`eco/web/vite.config.ts`, where `@jac/vite` is the Vite plugin jac supplies (the build installs it;
it is not among the tree's packages):

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import jac from "@jac/vite";

export default defineConfig({
    plugins: [jac(), react()],
});
```

`eco/web/index.html`, whose script is the space's entry:

```html
<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <title>hello</title>
    </head>
    <body>
        <div id="root"></div>
        <script type="module" src="/@jac/entry"></script>
    </body>
</html>
```

## Build and run it

From the project's root:

```sh
jac install         # once: the page's packages, by npm on jac's Node
jac run web         # build what changed, then start the app
```

```text
listening on http://127.0.0.1:8000/
```

`jac install` passes on npm's warning that esbuild's install script was not run
(`esbuild@... (postinstall: node install.js)`, `not yet covered by allowScripts`). The build does
not need the script: nothing is to be done about the warning.

The page at that address shows `hello jac`. The function is also reachable directly:

```sh
curl -X POST http://127.0.0.1:8000/__jac/call/api/svc/greet -d '{"args": {"name": "curl"}}'
```

```text
{"ok": true, "data": "hello curl"}
```

`JAC_WEB_LISTEN=127.0.0.1:8151 jac run web` listens elsewhere: the variable is
`JAC_<APP>_LISTEN`, the app's name uppercased. Ctrl-C stops the app; to run one in the background
and stop it, see [Building apps](building.md#stopping-an-app) (`jac docs stopping an app`).

`jac build web` builds without running. Here the artifact is the directory
`dist/web-<platform>/` (`dist/web-macos-aarch64/`, `dist/web-linux-x86_64/`): the program `web`
and `pages/site/`, the page as Vite wrote it. Copy the directory to a machine of that platform and
run `web`; nothing else is needed there.

## What the build did

- It compiled `svc.jac` and jac's app runtime (`stdjac`) to one native program. No server code
  was generated: as `svc` starts it hands `greet` to the runtime, which serves it.
- It compiled `pages/index.jac` to a JavaScript module, checked against the same `greet` signature,
  and ran the project's Vite on the result.
- It put the program and the bundle together in `dist/`.

A second `jac build web` with nothing changed runs nothing and says the app is up to date.

## Where to go next

| Page | Covers | Look it up |
|---|---|---|
| [The archwire's spaces](archwire.md) | `graph spaces`: spaces, hosts, `entry`, patterns, apps, profiles | `jac docs graph spaces` |
| [Crossings](crossings.md) | Calls between spaces, reading a stream, access tags, what crosses, remote spaces | `jac docs crossings` |
| [Serving a space](server.md) | Endpoints over HTTP, streams, calls answered at once, signing in, `@restspec`, `@limit`, scheduled functions, jobs | `jac docs apps/server` |
| [An app's data](data.md) | Each caller's `root`, the kept graph and `commit()`, the data directory, `--fresh` | `jac docs apps/data` |
| [Pages](pages.md) | Routes from `pages/`, layouts, the entry, `@jac/runtime` | `jac docs pages` |
| [Components and JSX](components.md) | JSX, state with `has`, effects, hooks, what a component may not do | `jac docs component` |
| [UI plugins and bundlers](ui-bindings.md) | The `ui` plugins (React, Preact, Solid, React Native, `none`) and the `bundler` plugins (Vite, Expo); a project's own | `jac docs apps/ui-bindings` |
| [Hosts](hosts.md) | What each host runs, reaches and refuses; desktop apps, their arrangements and local users; phone apps | `jac docs host` |
| [Building apps](building.md) | `jac build` and `run`, artifacts, several arrangements in one artifact, incremental builds, deployment values | `jac docs apps/building` |
| [stdjac](stdjac.md) | The app runtime library a program imports | `jac docs stdjac` |
| [stdjac.server](stdjac-server.md) | The decorators for routes, schedules, jobs and limits, and the contracts their plugins conform to | `jac docs stdjac.server` |
| [By and sem](../language/by-and-sem.md) | A function a language model (an LLM) answers, `by llm()`: an agent's tools, an answer streamed to a page, a kept conversation; the skill `language-models-and-agents` is the playbook | `jac docs by-and-sem` |

The wires in `graph import` (`++>`, `-->`, `edge`) are the module system's and apply to every
project, with or without spaces: see [Wiring modules](../language/modules-wiring.md)
(`jac docs language/modules-wiring`).
