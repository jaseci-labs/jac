---
description: Every jac.toml key jac reads, table by table - memory, check.lint, check, fmt, test, dependencies.pypi, npm, cargo, c, packages, an abstraction's own declaration, an abstraction's binding, spaces and apps - each with its type, default and meaning, and what goes wrong.
keywords: jac.toml, memory.profile, check.lint, check.lint.select, check.lint.ignore, check.lint.exclude, check.exclude, fmt.exclude, test.directories, test.directory, test.exclude, spaces.<space>.ui, spaces.<space>.bundler, spaces.<space>.base, spaces.<space>.npm, npm.<tree>, apps.<app>.window, apps.<app>.profiles
---
# jac.toml

`jac.toml` is a project's settings, in [TOML](https://toml.io). The directory that holds it is the project's root ([Projects](../toolchain/projects.md)); jac reads the one at the root of the project a command works on, and no other. Every table is optional, and an empty file is a project with no settings.

```toml
[project]
name = "shop"

[memory]
profile = "managed"

[check.lint]
select = ["style", "separate-impls"]
exclude = ["tests/*/reject/*"]

[fmt]
exclude = ["build/*", "*/reject/*"]

[test]
directories = ["src", "tests"]
exclude = ["*/reject/*"]

[dependencies.pypi]
requests = ">=2.31"

[npm.web.dependencies]
nanoid = "^5.1.0"
```

A key is named here in dotted form, `check.lint.select` for `select` in `[check.lint]`, which is also how TOML lets you write it: `memory.profile = "rc"` at the top of the file is the same key as `profile = "rc"` under `[memory]`. `jac docs <key>` prints this page.

jac reads only the tables below and ignores the rest. Another tool's settings go in `[tool.<name>]`, which is the tools' own (below). `[project]` is a package's identity: `name`, `version` (`MAJOR.MINOR.PATCH`, as Semantic Versioning has it: E2228 for one that is not), and `kind` (`"library"` or `"plugin"`) for a package other projects declare ([Packages](../toolchain/packages.md#jac-packages)). A project that is neither has no `kind`. `jac` is the oldest jac the package builds with, `jac = "0.4"`: a jac older than that refuses it (E2229), the project's own included.

## [memory]

The memory profile a program is built under, and which modules are held to the ownership contract. See [Memory](../language/memory.md) (`jac docs memory`) for what each profile means, and [The nogc contract](../language/ownership-contract.md) (`jac docs memory.enforce`) for `enforce` and `exempt`.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `memory.profile` | string | `"managed"` | `"managed"` (reference counting and a cycle collector), `"rc"` (reference counting; cycles leak) or `"nogc"` (every module held to the ownership contract, nothing counted). Case does not matter. `--memory` on the command line overrides it |
| `memory.enforce` | list of strings | `[]` | Patterns of module names whose modules `jac check` holds to the ownership contract under `managed` and `rc` |
| `memory.exempt` | list of strings | `[]` | Patterns of module names taken out of what `enforce` matches |

A pattern matches a module's dotted name (`core.site.game.sim`; the main module by its file's name without `.jac`), with `*` for any run of characters, `?` for one, and `[...]` for a set, as fnmatch does. Modules of the runtime are never matched.

| Message | Cause |
|---|---|
| `jac.toml: [memory] profile='fast' is not one of managed, rc, nogc` | Another value |
| `jac.toml: [memory] enforce and exempt have no effect under profile = 'nogc', which holds every module to the contract` | `enforce` or `exempt` with `profile = "nogc"`, where every module is held already |

## [check.lint]

The lint rules `jac check` reports. See [Lint rules](../toolchain/lint.md) (`jac docs lint`) for every rule.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `check.lint.select` | list of strings | `["clean"]` | The rules to report, by name, `"style"` for the style rules, and `"clean"` for every rule but `no-print` and `too-many-params` |
| `check.lint.ignore` | list of strings | `[]` | Rules taken out of what `select` chose, by name or group |
| `check.lint.exclude` | list of strings | `[]` | fnmatch patterns of file paths, relative to the root with `/` between parts, that no selected rule judges |

With no `select`, or no `[check.lint]`, the rules are `"clean"`: `jac check` reports every comment, every docstring and every body written inline, and `jac fmt --fix` deletes the comments and docstrings and moves the bodies into annexes. `select = []` selects no rule. `jac fmt --fix` applies the fixes of the rules a file's project selects.

## [check]

| Key | Type | Default | Meaning |
|---|---|---|---|
| `check.exclude` | list of strings | `[]` | fnmatch patterns of file paths, relative to the root with `/` between parts, that [`jac precommit`](../toolchain/lint.md#jac-precommit) fixes and does not check as programs of their own |
| `check.imports` | string | `"open"` | `"ruled"` asks an [edge rule](../language/modules-wiring.md#a-rule-for-every-import-from-outside) in `archwire.jac` for every import from outside the project (E2211); `"open"` asks one only for a package some rule names |

`jac check <main.jac>` does not read `exclude`: a program is checked whole.

| Message | Cause |
|---|---|
| `jac.toml: [check.lint] select is a list of strings` (or `ignore`, `exclude`) | The key is not a list of strings |
| `jac.toml: [check] imports is "open" or "ruled", not 'strict'` | `imports` is some other word |
| `jac.toml:5:22: error[E3057]: [check.lint] select names 'no-such-rule', which is no rule a project selects` | A name in `select` or `ignore` that is no rule, reported at its place in the file |

## [fmt]

| Key | Type | Default | Meaning |
|---|---|---|---|
| `fmt.exclude` | list of strings | `[]` | fnmatch patterns of paths, relative to the root, that `jac fmt` leaves alone when it formats a directory. A directory that matches is not entered |

A file named on the command line is formatted whatever `exclude` says. See [fmt](../toolchain/fmt.md#which-files).

| Message | Cause |
|---|---|
| `<path>/jac.toml: [fmt] exclude must be a list of strings` | `exclude` has another type |

## [test]

Where `jac test` looks for tests when it is given no paths. See [test](../toolchain/test.md#which-modules-are-tested).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `test.directories` | list of strings | the root | The directories to search, relative to the root |
| `test.directory` | string | | One directory, read when `directories` is absent or empty |
| `test.exclude` | list of strings | `[]` | fnmatch patterns of paths, relative to the root, that a directory search leaves out. A file named on the command line is tested whatever it says |

| Message | Cause |
|---|---|
| `[test] directory 'x' (resolved to '...') does not exist` | A listed directory is not there |
| `<path>/jac.toml: [test] directories must be a list of strings` | `directories` is not a list of strings |
| `<path>/jac.toml: [test] directory must be a string` | `directory` is not a string |
| `<path>/jac.toml: [test] is not a table` | `test` is a key with a value, not a table |
| `<path>/jac.toml: [test] exclude must be a list of strings` | `exclude` is not a list of strings |

## [dependencies.pypi]

The project's Python packages, which `jac install` installs into `.jac/venv/` on jac's CPython and pins in `jac.lock`. See [Python](../interop/python.md) (`jac docs interop/python`).

| Key | Type | Meaning |
|---|---|---|
| `dependencies.pypi.<package>` | string | A version specifier for the package (`">=2.31"`, `"==1.4.2"`), or `"*"` for any version |

`jac install --pypi <package>...` adds packages to the table and `jac remove --pypi <package>...` takes them out; both rewrite only that table, and leave the rest of the file and its comments as they were. A name TOML takes for more than a key is written quoted, as one with a dot in it is: `"zope.interface" = "~=7.2"`. Write it as a `[dependencies.pypi]` table: a dotted or inline form is read, but `install` and `remove` refuse to edit it (E5157).

| Message | Cause |
|---|---|
| `jac.toml: [dependencies.pypi] <name> is not a version specifier string` | A value that is not a string |
| `jac.toml: [dependencies] is not a table`, `jac.toml: [dependencies.pypi] is not a table` | The key has another type |
| E5157 | `install` or `remove` on a dotted or inline form |

## [npm.\<tree\>]

One npm tree of the project: a package and the packages it depends on. The table is that tree's `package.json`, key for key and in the table's order, with npm's own names for its keys (`dependencies`, `devDependencies`, `type`, `scripts`, ...). jac writes it to `eco/<tree>/package.json` and `jac install` installs it there, pinning what npm resolved in `jac.lock`. See [Packages](../toolchain/packages.md) (`jac docs packages`).

| Key | Type | Meaning |
|---|---|---|
| `npm.<tree>` | table | The tree's `package.json`. `<tree>` is its directory under `eco/`: letters, digits, `-` and `_` |
| `npm.<tree>.dependencies.<package>` | string | A package and the versions of it the tree takes, as npm writes them (`"^5.1.0"`) |

`jac install --npm <package>... [--tree <tree>]` adds packages and `jac remove --npm <package>...` takes them out; `jac npm`, run in a tree, changes what npm changes. Each rewrites only the tree's table.

| Code | Cause |
|---|---|
| E5155 | A value JSON has none for: a date, `inf`, `nan` |
| E5157 | The table is written inline or with dotted keys, where jac has it to rewrite |
| E5158 | `npm`, or one of its entries, is not a table, or a tree's name is not a directory's |
| E5159 | A tree declares `workspaces`: a tree is one package |

## [cargo."\<directory\>"] and [c."\<directory\>"]

A Rust crate's or workspace's `Cargo.toml` (`cargo`), and a C module's `cmodule.toml` (`c`), by the directory it is in, from the project's root. The table is the manifest's own text with its tables named under the directory's; jac writes the file where it stands before a command looks for it. `jac absorb <directory>` takes existing manifests in, and `jac cargo` takes back what cargo changes. See [Packages](../toolchain/packages.md#rust-crates-and-c-modules), [Rust modules](../interop/rust-modules.md) and [C modules](../interop/c-modules.md).

| Code | Cause |
|---|---|
| E5157 | The table is written inline or with dotted keys where jac has it to rewrite, or a manifest's text cannot be moved under a table's name as it is |
| E5158 | `cargo` or `c` is not a table of manifests, each a table named by its directory |

## [packages]

The Jac packages a package uses, libraries and plugins alike, each by its version or by where it is. Which kind a package is, its own `jac.toml` says. See [Packages](../toolchain/packages.md#jac-packages) (`jac docs toolchain/packages`) and [Plugins](../apps/plugins.md) (`jac docs plugins`).

| Key | Type | Meaning |
|---|---|---|
| `packages.<name>` | string or table | A string is the package's version requirement, `"1.2"`: the least version asked for, satisfied below the next change of its left-most number that is not zero. The package is the one installed in the project's `eco/jac/<name>`. A table is where the package is: `{ path = "<directory>" }`, from the directory of this `jac.toml`, or `{ git = "<repository>", rev = "<revision>" }`, which `jac install` fetches into `eco/jac/<name>` and `jac.lock` pins. Its own `jac.toml` says `kind = "library"`, or `kind = "plugin"` and which abstraction it fills |

- A project, a library and a plugin each declare the libraries their modules import.
- Only a project declares a plugin, and a plugin it declares is one it binds or lists ([\<abstraction\>](#abstraction)). A plugin jac ships (`sqlite`) needs no entry.
- A program holds one copy of a package: the one the project declares, or else the one the first package to declare it does.

| Code | Cause |
|---|---|
| E2216 | No package is at the path, its `jac.toml` says it is neither a library nor a plugin, or it has another name there. For a plugin: its `jac.toml` does not say what it fills |
| E2217 | The package declares an abstraction: its `kind` is `"abstraction"`, or it has an `[abstraction]` table. The abstractions are jac's own ([below](#abstraction-an-abstractions-own)) |
| E2219 | A module imports a library its own package does not declare |
| E2220 | A declaration does not hold of the copy the program holds: it names another place, or a version the copy's does not satisfy |
| E2221 | A library or a plugin declares a plugin, or a library's `jac.toml` binds one |
| E2222 | The project's tree has a directory or a module of a library's name |
| E2226 | A `[libraries]` or a `[plugins]` table: what they held is in `[packages]` |
| E2227 | A plugin the project declares that no binding names and no abstraction lists |
| E2228 | A requirement that is not one (`"^1.2"`, `"1.x"`), or a package's `version` that is not a version |
| E5158 | An entry that is neither a string nor a table with a `path`, or with a `git` and a `rev` |
| E5161 | A package is not installed as the entry asks: nothing is in `eco/jac/<name>`, or one from a repository is not fetched (`jac install`) |

## [tool.\<name\>]

A table of another program's. jac defines no key under `[tool]` and reads none, so a tool that works on a project (a package manager, an editor's extension) keeps its settings for the project in `[tool.<its name>]`, where no table of jac's will ever be.

```toml
[tool.jacpm]
registry = "https://packages.example.org"
```

## [abstraction], an abstraction's own

An abstraction's own declaration. It is a table of jac's own files, the `jac.toml` of each directory of its `abstractions/` (`abstractions/store/jac.toml`), whose `[project]` says `kind = "abstraction"`. No project and no package writes one (E2217): a project binds a plugin to an abstraction ([next](#abstraction)), and a package fills one or is a library. See [Plugins](../apps/plugins.md#the-abstractions).

| Key | Type | Meaning |
|---|---|---|
| `abstraction.interface` | string | The class a plugin of it implements, in the abstraction's own contract: `<abstraction>.contract.<Interface>` (`store.contract.Store`). `ui` and `bundler` have none: their contract is the `[ui]` or `[bundler]` table of a plugin's `jac.toml` |
| `abstraction.interface_ver` | integer | The interface's version: what a plugin's `plugin.interface_ver` has to be (E2230) |
| `abstraction.per` | string | What has one plugin of it: `"project"` or `"space"` |
| `abstraction.picked` | string | When that plugin is chosen: `"start"`, as a program starts, or `"build"`, as a space is built |
| `abstraction.standard` | string or table | The plugin a project has until it names another, a directory beside this file. For `ui`, a table of one for each host (`browser = "react"`) |

```toml
[project]
name = "store"
kind = "abstraction"

[abstraction]
interface = "store.contract.Store"
interface_ver = 1
per = "space"
picked = "start"
standard = "sqlite"
```

## [\<abstraction\>]

The plugin that carries out one of the language's abstractions, and the plugins a program is built with for it. There are nine abstractions. Seven are picked as a program starts: `store`, `auth`, `transport`, `llm`, `jobs`, `schedule` and `limits`. Two are picked as a JavaScript space is built: `ui` and `bundler`. See [Plugins](../apps/plugins.md#binding-a-plugin).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `<abstraction>.plugin` | string | the abstraction's standard plugin (`sqlite` for `store`, `accounts` for `auth`, `http` for `transport`, `anthropic` for `llm`, `process_jobs`, `loop_schedule`, `memory_limits`; for `ui` the one of the space's host, and for `bundler` the one its `ui` plugin names) | The plugin a program uses, unless `JAC_<ABSTRACTION>` names another where it runs. For `ui` and `bundler`, the plugin a space is built with, which nothing where it runs changes |
| `<abstraction>.<plugin>` | table | | Lists the plugin `<plugin>`, which is then compiled into the program, and holds its settings: each key a field of the plugin's class. For `ui` and `bundler`, only the table of the plugin the space is built with, holding the settings that plugin's own `jac.toml` lists |
| `spaces.<space>.<abstraction>` | table | the project's | The same table for one space, for an abstraction a space has one of: `store`, `ui` and `bundler` |

```toml
[store]
plugin = "sqlite"

[store.jsonstore]
file = "notes.json"

[llm.anthropic]
model = "claude-sonnet-5-5"
timeout = 30

[auth.accounts]
local_users = true
```

A setting is overridden where the program runs by `JAC_<ABSTRACTION>_<FIELD>` ([Environment variables](environment.md)).

| Code | Cause |
|---|---|
| E2214 | `plugin`, or a plugin's table, names a plugin there is none of |
| E2215 | The plugin fills another abstraction |
| E1050, E1052, E1053 | A setting left out that has no default, a key that is no setting, a value of another type |
| E5158 | A key of the table that is neither `plugin` nor a plugin's table. For `ui` and `bundler`: a string where the table is (`ui = "preact"`), the table of a plugin the space is not built with, or a setting its plugin does not list |

## [spaces.\<space\>]

Settings of one space of the project's `archwire.jac`, by the space's name. They are read when a space on a JavaScript host (browser, node, hermes) is built or checked. See [Apps](../apps/index.md) (`jac docs apps`).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `spaces.<space>.ui` | table | `plugin = "react"` on a browser, `"react_native"` on hermes, `"none"` on node | The `ui` plugin the space's JSX is compiled for, as `plugin = "<name>"`: one jac ships (`react`, `preact`, `solid`, `react_native`, `none`), or one `[plugins]` declares. See [UI plugins and bundlers](../apps/ui-bindings.md#choosing-a-spaces-plugins) |
| `spaces.<space>.bundler` | table | `plugin` is the one the space's `ui` plugin names | The `bundler` plugin that packs the space, as `plugin = "<name>"`: one jac ships (`vite`, `expo`), or one `[plugins]` declares, whose script jac runs on its Node |
| `spaces.<space>.bundler.<plugin>` | table | | The settings of the space's bundler. `vite` has `config`: a configuration file, relative to the root (in the space's npm tree: `eco/web/vite.config.ts`) |
| `spaces.<space>.base` | string | `"/"` | The URL path a browser space is served at |
| `spaces.<space>.npm` | string | the project's only tree | The npm tree (`[npm.<tree>]`) the space's imports resolve in and its bundler runs in. Read for a native space too, whose code may import npm packages |

| Code | Cause |
|---|---|
| E2214 | `ui` or `bundler` names a plugin that jac does not ship and `[packages]` does not declare |
| E2215 | `ui` or `bundler` names a plugin that fills another abstraction |
| E1214 | `ui` names a plugin that does not support the space's host |
| E5158 | `ui` or `bundler` is a string, or the space has a `bundler_config`: the forms these had before; or the space has the table of a plugin it is not built with, or a setting its bundler does not list |
| E1287 | `npm` names a tree `jac.toml` does not declare |
| E1288 | The space imports from npm, `jac.toml` declares several trees, and `npm` names none |

## [apps.\<app\>]

Settings of one app of the project's `archwire.jac`, by the app's name, read when the app is built.

| Table | Keys | Meaning |
|---|---|---|
| `[apps.<app>]` | `profiles` (list of strings, default `[]`) | The archwire profiles whose arrangements of the app its one artifact holds, `"default"` naming the unnamed `graph spaces` block. The program starts as the first until its user chooses another. A name that is no profile is E1274. See [Building apps](../apps/building.md#several-arrangements-in-one-artifact) |
| `[apps.<app>]` | `name` (default: the app's name), `identifier` (default `app.jac.<app>`; E1289 where it is no application identifier), `version` (default `"1.0.0"`) | A phone app as its phone shows and installs it: the name under its icon, the identifier Android installs it under (as `dev.example.app`), and its version. See [UI plugins and bundlers](../apps/ui-bindings.md#expo) |
| `[apps.<app>.remote]` | `<space> = "<URL>"` | Where each space the app reaches but does not run is served. A space the app reaches with no URL here is E1212. A deployment overrides it with `JAC_REMOTE_<SPACE>`. See [Crossings](../apps/crossings.md) |
| `[apps.<app>.window]` | `title` (default: the app's name), `width` (1280), `height` (860), `min_width` (640), `min_height` (480) | The window of a desktop app (one whose `run` holds a browser space), its sizes in pixels |

## [android]

What a phone app's Android build is made with. With no `[android]` table jac fetches nothing, and uses the SDK `ANDROID_HOME` names if there is one.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `android.licenses` | string | none | `"accepted"` says the project's author accepts the Android SDK's licenses (https://developer.android.com/studio/terms): `jac install` then fetches the SDK into jac's cache (unless `ANDROID_HOME` names one, which is used as it is) and a JDK to build with (Eclipse Temurin 21, unless `JAVA_HOME` names one), each a pinned release checked against its digest, and a phone app's build fetches the parts of the SDK it asks for. Anything else, with the table present, and `jac install` stops and says so |
| `android.emulator` | boolean | `false` | Whether `jac install` also fetches the Android emulator and a system image, for `jac run <app>` where no phone is connected |

## Other files

| File | What it is |
|---|---|
| `jac.lock` | Written by jac: what each ecosystem's own resolver pinned for `jac.toml`, the Python distributions of `[dependencies.pypi]` (`[pypi]`) and each npm tree's lock as npm wrote it (`[npm.<tree>]`). Keep it in version control; `jac install --frozen` installs exactly it ([Packages](../toolchain/packages.md)) |
| `eco/<tree>/` | An npm tree's directory: the files its tools are configured by, which are the project's, and the `package.json`, `package-lock.json` and `node_modules` jac writes there, which are not tracked |
| `archwire.jac` | The project's spaces, apps and import wiring, in Jac ([Archwire](../apps/archwire.md)) |
| `cmodule.toml`, `Cargo.toml`, `Cargo.lock` | In a project, written by jac from the `[c."<directory>"]` and `[cargo."<directory>"]` tables above, and not tracked. A program with no `jac.toml` above it keeps them as files ([C modules](../interop/c-modules.md), [Rust modules](../interop/rust-modules.md)) |

## What goes wrong

A `jac.toml` that is not valid TOML stops every command that reads it, with TOML's own message and where it is:

```text
jac: jac.toml: Expected ']' at the end of a table declaration (at line 1, column 9)
```

A key of the wrong type stops the command that reads it, with a message naming the key, as each table above lists. A key jac does not know is ignored, so a misspelled key (`[tests]`, `directores`) is not an error: if a setting seems to have no effect, check its spelling against this page.
