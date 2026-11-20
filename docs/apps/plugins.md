---
description: Plugins, the mechanisms behind the language's abstractions - the abstractions that take one, binding a plugin in jac.toml, the plugins jac ships, listing several and picking one where the program runs, the two that are picked as a space is built, settings and secrets, a project's own plugin by its path, writing one, and what is refused.
keywords: binding a plugin, standard plugin, store, sqlite, Store, Secret, settle, stdjac.bound, stdjac.sqlfile, JAC_STORE, auth plugin, transport, http plugin, process_jobs, loop_schedule, memory_limits
---
# Plugins

A plugin is what carries out one of the language's abstractions: where `root` is kept, who a
caller is, what answers `by llm()`, which library a component becomes. A program's modules name
the abstraction and never the plugin ([Principles](../language/principles.md)). The project names
its plugins in `jac.toml`, and for most abstractions the place a program runs may pick among
them.

```toml
[store]
plugin = "sqlite"
```

That is what a project with no `[store]` table has: each abstraction has a **standard plugin**,
which jac ships and a project uses until it names another.

## The abstractions

| Abstraction | What source says | Its interface | One for each | Picked | Standard plugin |
|---|---|---|---|---|---|
| `store` | `root`, `root.shared`, `++>` | `stdjac.graph.Store` | Space | As the program starts | `sqlite` |
| `auth` | `:protect`, the caller's `root`, a page's `sign_in()` | `stdjac.server.Auth` | Project | As the program starts | `accounts` |
| `transport` | A call from outside, and a call to another app | `stdjac.remote.Transport` | Project | As the program starts | `http` |
| `llm` | `by llm()` | `stdjac.llm.Model` | Project | As the program starts | `anthropic` |
| `jobs` | `@job`, `flow f(x)`, `wait j` | `stdjac.server.Jobs` | Project | As the program starts | `process_jobs` |
| `schedule` | `@schedule` | `stdjac.server.Scheduler` | Project | As the program starts | `loop_schedule` |
| `limits` | `@limit`, `consume_limit` | `stdjac.server.Limits` | Project | As the program starts | `memory_limits` |
| `ui` | A component: `has` in a function, `can with entry`, JSX | A `[ui]` table of the plugin's `jac.toml` | Space | As the space is built | Its host's: `react` in a browser, `react_native` on hermes, `none` on node |
| `bundler` | Nothing: a JavaScript space is bundled as it is built | A `[bundler]` table of the plugin's `jac.toml` | Space | As the space is built | The one the space's `ui` plugin names: `vite`, `expo` |

The abstractions are the language's and stdjac's: a project chooses a plugin for one, and does not
declare one.

**Each interface has a version,** a number that goes up when the interface changes so that a
plugin written for it would not survive. Every interface is at 1 in this jac. A plugin says
the version it was written for (`interface_ver`, [below](#writing-a-plugin)), and one written for
another is refused before anything is asked of it (E2230): the message is that the interface
moved on, and not that some method of the plugin's class is missing.

**Seven are picked as a program starts, and two as a space is built.** A plugin of the first seven
is a class that runs with the program, so a program may hold several and start with one. `ui` and
`bundler` decide what the compiler and the build make of a JavaScript space, so a space is built
with one of each, and they have a page of their own:
[UI plugins and bundlers](ui-bindings.md) (`jac docs apps/ui-bindings`).

## Binding a plugin

```toml
[packages]
jsonstore = { path = "../jsonstore" }

[store]
plugin = "sqlite"

[store.jsonstore]
file = "notes.json"
indent = 2
```

- **`[packages]` declares the plugins that are not jac's own,** beside the project's
  libraries and as they are declared, each by its version (`postgres = "0.4"`, an
  [installed package](../toolchain/packages.md#installed-packages)) or by where its package is: a
  directory, or a repository at a revision (`{ git = "...", rev = "..." }`), which
  `jac install` fetches and `jac.lock` pins
  ([Packages](../toolchain/packages.md#fetching-and-pinning)). The plugin's own `jac.toml`
  says that it is one. A standard plugin needs no line there.
- **A plugin the project declares is one it uses:** `plugin` names it or a table lists it, for
  the project or for a space. One that is declared and never used is E2227.
- **`[<abstraction>] plugin`** names the plugin a program uses.
- **Each `[<abstraction>.<plugin>]` table lists a plugin.** Every listed plugin is compiled into
  the program, and the table holds its settings. The plugin `plugin` names needs a table only when
  it has settings.
- **`[spaces.<space>.<abstraction>]`** binds one space's, for an abstraction a space has one of.
  The spaces one program runs share one `store`, so they are bound alike (E5090 otherwise).
- **`ui` and `bundler` have one plugin for a space,** the one `plugin` names, and only its table:
  `[spaces.site.ui]` `plugin = "preact"`, and `[spaces.site.bundler.vite]` for the bundler's
  settings. Listing another there is E5158
  ([UI plugins and bundlers](ui-bindings.md#choosing-a-spaces-plugins)).

Nothing else changes: no module, and no line of `archwire.jac`.

## Picking a plugin where the program runs

For an abstraction picked as a program starts (every one but `ui` and `bundler`), one program
holds every plugin its project lists, and runs with one:

```sh
dist/api-linux-x86_64                        # sqlite, as jac.toml's `plugin` says
JAC_STORE=jsonstore dist/api-linux-x86_64    # jsonstore
```

- `JAC_<ABSTRACTION>` picks among the listed plugins as the program starts. For a space's own
  binding it is `JAC_<SPACE>_<ABSTRACTION>`, which is read first.
- A name that is not listed ends the program with status 1:

  ```text
  JAC_STORE=postgres: this program was not built with a plugin 'postgres' for `store`. jac.toml lists: sqlite, jsonstore
  ```

- Nothing is loaded as a program runs. A plugin `jac.toml` does not list is not in the program.

So one artifact serves development and production: list both plugins, and say which where it is
deployed.

`ui` and `bundler` are not picked this way. What a component compiles to and what bundles a space
are settled when the space is built, so there is no `JAC_UI` and no `JAC_BUNDLER`, and a bundler's
settings are read from `jac.toml` alone.

## Settings

A setting of a plugin picked as a program starts is a field of the plugin's class. `jac.toml`
gives its value, which is built into the program, and the place the program runs overrides it:

```sh
JAC_STORE=jsonstore JAC_STORE_FILE=/var/lib/api/notes.json JAC_STORE_INDENT=0 dist/api-linux-x86_64
```

- **`JAC_<ABSTRACTION>_<FIELD>`** overrides a setting of the plugin picked. A `str` is taken as it
  is written, and any other type is read as JSON (`2`, `true`, `["a", "b"]`).
- **A build holds a table to the fields.** A key that is no field is E1052, a value of another
  type E1053, and a field with no default that is given no value E1050, each at its line of
  `jac.toml`.
- **A value that is not of the setting's type where the program runs** ends it with status 1,
  naming the variable.

### Secrets

A setting of type `Secret` is never written in `jac.toml`, and is not in the program: it names a
variable of the environment, read where the program runs when the plugin asks for it. A plugin's
field says which variable (`ANTHROPIC_API_KEY`), and `JAC_<ABSTRACTION>_<FIELD>`, when it is set,
is read in its place. Giving one a value in `jac.toml` is E1053.

## The standard plugins

| Plugin | Carries out | Its settings |
|---|---|---|
| `sqlite` | `store`: a space's graph, as rows in a SQLite file, which the programs of one machine may keep together | `path`, the file: `graph.db` in the app's data directory |
| `accounts` | `auth`: accounts of a username and a password, and their sessions, in a SQLite file; and signing in through GitHub, where the program runs with an OAuth app's ID and secret | `path`, `rounds`, `session_seconds`, `local_users`, `email_required`, `origin`, `github`, `github_api`, and the secrets `github_id` and `github_secret` ([Serving a space](server.md#the-accounts-plugin)) |
| `http` | `transport`: requests over HTTP, a call's reply as JSON and a stream's events as they are made, and the server that answers them | None ([Serving a space](server.md#what-the-server-will-and-will-not-read)) |
| `anthropic` | `llm`: a model behind Anthropic's Messages API | `model`, `address`, `timeout`, `retries`, and the secret `key` ([By and sem](../language/by-and-sem.md#the-anthropic-plugin)) |
| `process_jobs` | `jobs`: each job in a copy of the program | `dir`, where a job's input and what it says are kept while it runs: `jobs` in the app's data directory |
| `loop_schedule` | `schedule`: each scheduled function run by the thread that listens, when it is due | `tick`, how often its clock looks for one that is due, in seconds: `0.25` |
| `memory_limits` | `limits`: uses counted in the program's memory | `sweep_at`, how many actors' uses are kept before those whose window has passed are let go: `1024` |
| `react` | `ui`: React, with React Router's file routes. A browser space's standard | None |
| `preact` | `ui`: Preact | None |
| `solid` | `ui`: Solid, whose state is fine-grained | None |
| `react_native` | `ui`: React Native. A hermes space's standard | None |
| `none` | `ui`: no UI library. A node space's standard | None |
| `vite` | `bundler`: the project's own Vite, run in the space's npm tree. What `react`, `preact` and `solid` name | `config`, the project's Vite configuration, from its root |
| `expo` | `bundler`: the project's Expo, which makes a phone app of a hermes space. What `react_native` names | None |

The app's data directory is `JAC_<APP>_DATA` ([An app's data](data.md#where-it-is-kept)). What
each `ui` plugin does with a component, and what each bundler does, is on
[UI plugins and bundlers](ui-bindings.md).

An abstraction that every app has one of (`auth`, `transport`, `llm`, `jobs`, `schedule`,
`limits`) is bound for the project, in `[<abstraction>]`. `store`, `ui` and `bundler` may also be
bound for one space.

## Writing a plugin

A plugin is a package: a directory with a `jac.toml` and its modules.

```toml
[project]
name = "jsonstore"
kind = "plugin"

[plugin]
fills = "store"
interface_ver = 1
class = "jsonstore.store.JsonStore"
```

- `fills` is the abstraction, and `class` the class that carries it out, named as
  `<plugin>.<module>.<Class>`: here `JsonStore` of `store.jac` in the package's directory.
- `interface_ver` is the version of the abstraction's interface the plugin was written for
  ([The abstractions](#the-abstractions)). It is required (E2216 without it), and a plugin whose
  `interface_ver` is not this jac's is E2230. When an interface's version goes up, a plugin is
  written again for the new one and published as a new version of its own, which says so.
- The class conforms to the abstraction's interface. One that does not is refused where it is
  bound (E1281).
- A plugin of `ui` or `bundler` has no class: nothing of it runs with the program. In place of
  `class`, its `jac.toml` has a table named for the abstraction, which says how it fills it
  ([below](#a-plugin-picked-as-a-space-is-built)).

<!-- example: not checked: a plugin is a package of its own, with a jac.toml that names this class -->
```jac
import json;
import os;
import from stdjac.graph { Row, Store }
import from stdjac.plan { data_dir }

obj JsonStore(Store) {
    has file: str = "graph.json",
        indent: int = 0;
    has rows: dict[str, list[any]] postinit;

    def postinit {
        self.rows = {};
    }

    def kept_as -> str {
        return os.path.join(data_dir(), self.file);
    }

    def open {
        if os.path.exists(self.kept_as()) {
            with open(self.kept_as()) as f {
                self.rows = json.load(f);
            }
        }
    }

    # ... the rest of `Store`: types, shapes, of_type, rows, edges, mark, since, write,
    # every, root_of, roots, shared_root.
}
```

- **Its fields are its settings.** `file` and `indent` are what `[store.jsonstore]` may give.
- **What it keeps for itself is a `postinit` field,** which no constructor takes: `rows` is no
  setting, and `[store.jsonstore] rows = ...` is E1052.
- **It does nothing until its abstraction asks.** The plugin is made with `jac.toml`'s settings,
  then given the environment's, and only then used: `Store.open` is where a store reaches its
  file, and `Transport.claim` where a transport takes its address, raising `CannotListen` with
  the reason where it can't. Work done in `postinit` would be done with settings that may still
  change.
- **It imports what it needs of stdjac** and of any library, and nothing imports it. A library
  that is not jac's own is declared in the plugin's own `[packages]`
  ([Packages](../toolchain/packages.md#jac-packages)). A plugin declares no plugin (E2221).
  `stdjac.plan`'s `data_dir()` is where a program keeps files beside itself, and
  `stdjac.sqlfile`'s `open_db` opens a SQLite file at a layout, upgrading an older one.

### What a store is asked

`stdjac.graph.Store` is rows by their ids, with no query language: a graph database is used as
rows too. The runtime above it owns which node is which object, what of the graph is in memory
and what a call changed ([An app's data](data.md#what-of-the-graph-is-in-memory)).

| Method | Gives or does |
|---|---|
| `open()`, `kept_as()` | Makes ready to hold rows; what its data is called, where an app says what is wrong with what it kept |
| `rows(ids)` | The rows of those ids, those it holds: a `Row` is a node or an edge, with its type's name, its fields as JSON text, an edge's two ends and its place in the order edges were made, and its `version` |
| `edges(id)` | Every edge at a node, out of it and into it, in the order they were made |
| `write(w)` | Keeps what one commit writes, all of it or none: the rows to keep and those to take out, each at the version it was read at, the roots first given to users, and the shared root. `StoreConflict` when a row is at another version, or a user has a root already. Gives the store's new mark |
| `mark()`, `since(mark)` | Where its writes are counted to, and what was written after a mark by any user of it: the rows as they are now, and the ids taken out. `None` when it no longer knows that far back |
| `types()`, `shapes()`, `of_type(name)` | How many rows it holds of each type, the shape each type's rows were written in, and every row of one type: what a program is held against as it starts, reading rows only of a type whose shape it has changed |
| `every()` | Every row, one at a time and without its data: what `sweep()` reads |
| `root_of(user)`, `roots()`, `shared_root()` | The ids of a user's root, of every user's, and of the shared one |

- **A store that one program uses** may answer `since` with nothing and keep its mark to itself, as
  the tests' `jsonstore` does. One that several programs share, as `sqlite` is, tells each what
  the others wrote.
- **A write is the only thing that changes it,** and it is whole: a store never holds half of what
  a call made.

### A plugin picked as a space is built

A `ui` or a `bundler` plugin is a `jac.toml` with a table of its abstraction's name, and the files
that table names:

```toml
[project]
name = "bundle"
kind = "plugin"

[plugin]
fills = "bundler"
interface_ver = 1

[bundler]
build = "bundle.mjs"
settings = ["minify"]
```

- **A `[ui]` table** says which library's functions the language's state, derived values and
  effects become, which hosts the library runs on and which npm packages are its own
  ([A project's own `ui` plugin](ui-bindings.md#a-projects-own-ui-plugin)).
- **A `[bundler]` table** names the script that bundles a space, the one that serves it under
  `jac dev`, and the settings a project may give it
  ([A project's own bundler](ui-bindings.md#a-projects-own-bundler)).
- **A plugin that fills one of the two and has no such table** is E2216.
- **Its settings are the names its table lists,** written in `jac.toml` and read as the space is
  built. They are not fields, and no variable of the environment overrides one.

### A second plugin of each abstraction

The repository's `tests/plugins/` holds a second plugin for each abstraction that is picked as a
program starts, each a package a project declares by its path, and the suite runs one built
program under both. Each is a short
example of its interface:

| Plugin | Fills | How it differs from the standard one |
|---|---|---|
| `jsonstore` | `store` | The rows in one JSON file |
| `ticket_auth` | `auth` | No accounts: callers sign in at another service, which says whose each ticket is |
| `line_transport` | `transport` | A wire of its own, a line of JSON each way over TCP: it carries calls and serves no paths |
| `chat_model` | `llm` | A model behind a chat-completions API: one dialect, and nothing of tool rounds or decoding |
| `queue_jobs` | `jobs` | One worker, which runs the jobs queued in their order |
| `timer_schedule` | `schedule` | A thread for each scheduled function, which sleeps until it is due |
| `file_limits` | `limits` | Uses counted in a SQLite file, so they outlast the program |

## What is refused

| Code | Condition |
|---|---|
| E2214 | `jac.toml` names a plugin that `[packages]` does not declare and jac does not ship |
| E2215 | A plugin is bound to an abstraction it does not fill |
| E2216 | A plugin's package is not where `[packages]` says, or its manifest does not say what it fills: its `class`, or for `ui` and `bundler` its table |
| E2217 | A package declares an abstraction: only stdjac does |
| E2218 | A module imports a plugin |
| E2221 | A library or a plugin declares a plugin: only a project does |
| E2227 | The project declares a plugin that no binding names and no abstraction lists |
| E2230 | A plugin was written for another version of its abstraction's interface than this jac's |
| E1050, E1052, E1053 | A setting left out, a key that is no setting, a value of another type |
| E1281 | The plugin's class does not conform to the abstraction's interface |
| E5158 | An abstraction's table holds something other than `plugin` and plugins' tables, or `[packages]` an entry that is no source. For `ui` and `bundler`: the table of a plugin the space is not built with, a setting the plugin does not list, or a form `jac.toml` had before (`ui = "preact"`, `bundler_config`) |
| E1214 | A `ui` plugin that does not run on the space's host |
| E5090 | Spaces that run in one program are bound to different plugins for an abstraction a space has one of; or a plugin is bound for one crossing (`[crossings.<a>.<b>.transport]`), which jac does not build yet: every crossing of a project is carried by the plugin its `[transport]` binds |

## Differences from Python and from the reference design

- The reference design's plugins are Python packages a program finds installed as it starts, and each adds what it
  likes. Here a plugin fills one abstraction the language has, the build compiles it in, and what
  a program means does not depend on which one it has.
- Python has no counterpart: a library there is imported by the code that uses it.
