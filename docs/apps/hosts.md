---
description: What each host runs, reaches and refuses - native, browser, wasm, node, cpython and hermes spaces, desktop apps in a window with their arrangements and local users, and phone apps - and the artifact each makes.
keywords: host, hosts, native space, wasm space, node space, cpython space, hermes space, desktop app, phone app, apps.window, @jac/mobui, @jac/wasm_host, JAC_<SPACE>_CODE, local users, local user
---
# Hosts

A space's host, written after its name in the archwire (`space api: native { ... }`), says what
its code is compiled to and where it runs ([the archwire](archwire.md), `jac docs graph spaces`).
The language is the same on every host; what a host provides around it, and what it cannot run
yet, differs. A host is one of six words; any other is E1226.

| Host | Compiled to | Runs | Its `ui` plugin |
|---|---|---|---|
| `native` | Machine code, through LLVM | The app's own process | It has none |
| `browser` | ES modules, bundled | A browser tab, or a desktop app's window | `react`, unless `jac.toml` names another |
| `wasm` | A WebAssembly module | Inside a page of a browser space | It has none |
| `node` | ES modules | Node: its own process, or a native app's | `none` |
| `cpython` | CPython code objects | CPython: its own process, or a native app's | It has none |
| `hermes` | Hermes bytecode | A phone app, on React Native | `react_native`, unless `jac.toml` names another |

A program means the same on every host, but for the differences listed under
[Where the language differs by host](#where-the-language-differs-by-host) below.

## native

A native space is compiled as any jac program is. It reaches C libraries, Python packages
through CPython embedded in the program, and npm packages through Node embedded in the program
(see the interop pages: `jac docs search interop`).

An app whose native spaces have no `entry` serves them ([Serving a space](server.md)); one whose
space has an `entry` is a program that runs that module's `with entry` code and ends. Several
native spaces in one app are one program, and the calls between them are ordinary calls.

## browser

A browser space is compiled to JavaScript and bundled ([UI plugins and bundlers](ui-bindings.md)). An app
either **serves** it, handing it to browsers from its own address ([Pages](pages.md)), or
**runs** it, which makes the app a desktop app (below).

## wasm

A wasm space is one module, the first its patterns name, and what it imports, compiled to
WebAssembly for `wasm32-wasi` as a library of its `:pub` functions. A page loads it and calls its
functions as it calls any other space's, with `await`:

`archwire.jac`:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer service { svc; }
    layer calc { calc; }
    layer pages { web | pages.*; }
}

graph spaces {
    space api: native { svc; }
    space site: browser { entry web; pages.*; }
    space calc: wasm { calc; }

    app web { run api; serve site, calc; }
}

graph import {
    edge Calls: calc --> pages;

    calc ++> pages.sum { add }
}
```

`calc.jac`:

```jac
def:pub add(a: int, b: int) -> int {
    return a + b;
}
```

`pages/sum.jac`:

<!-- example: not checked: a page is a module of a browser space, with JSX and a crossing -->
```jac
def:pub page(a: str, b: str) -> JsxPage {
    has total: int = 0;

    async can with entry {
        total = await add(int(a), int(b));
    }

    return <p>{a} + {b} = {total}</p>;
}
```

`/sum/2/3` shows `2 + 3 = 5`. The call runs in the browser: nothing goes to the server.

- The app lists the wasm space under `serve`, beside the browser space whose pages call it. Its
  module is in the bundle as `static/<space>.wasm`, which the page loads.
- A wasm space cannot be in `run` beside native spaces (E5090). A desktop app may run one beside
  its browser space.
- A wasm space whose patterns name no module is E5090.
- What the `wasm32-wasi` target cannot build is refused as it is for any program built with
  `--target wasm32-wasi` (see `jac docs build`).

## node

A node space is Jac compiled to JavaScript and run on Node, the one jac ships. Its imports
resolve as Node resolves them, under Node's `node` condition, so it can use Node's built-in
modules and the project's npm packages:

`api.jac`, the module of `space svc: node { api; }` in `app svc { run svc; }`:

<!-- example: not checked: a module of a node space, with npm imports -->
```jac
import from "node:path" { join }
import from "node:os" { platform }

obj Reply {
    has text: str,
        parts: list[str] = [];
}

def:pub greet(name: str) -> Reply {
    return Reply(text="hello " + name, parts=[join("a", name)]);
}

def:pub where -> str {
    return str(platform());
}
```

```sh
curl -X POST http://127.0.0.1:8000/__jac/call/svc/api/where
```

```text
{"ok":true,"data":"darwin"}
```

- **It serves** its `:pub` functions, and the untagged ones another space calls (with the
  deployment's key), at `JAC_<APP>_LISTEN`, in the same request and reply form as a native space
  ([Serving a space](server.md)).
- **Its calls of other spaces are awaited**, as in any JavaScript host, and it may call only their
  `:pub` and `:protect` functions and walkers (E1210).
- **Its artifact**, when an app runs it alone, is `dist/<app>/`: its modules (`.mjs`), Node, the
  project's npm packages, and `dist/<app>/<app>`, the launcher that starts it.
- **It keeps a graph of its own**, as a native space does: `root ++> Spot(v=1) ++> Spot(v=2);`,
  `root spawn Look()`, `visit [-->]` and a walker's `reports` work there. Only a walker as an
  endpoint is refused (below).

A node space refuses, with E5090, what Node cannot do yet:

| Refused | Message |
|---|---|
| A `:protect` function | `` `:protect` in a node space `` |
| A walker as an endpoint | `a walker endpoint in a node space` |
| JSX | `JSX in a node space` |

A node space may call another space's stream, and reads it with `async for`
([Crossings](crossings.md#calling-a-stream)).

A node space has its own small standard library: `sys`, `copy`, and parts of `io` and `struct`.
What else a native program imports by Python's names (`json`, `math`, `os`, `os.path`, `re`,
`time`, `random`, `datetime`, `collections`, `itertools`, `hashlib`, `base64`, `binascii`, ...)
is defined by the native runtime, and each use of it is E1540 (`'match' of re needs the native
runtime's own definitions, which a node space does not provide`). Use Node's modules
(`node:path`, `node:os`, `node:crypto`) or npm packages there instead.

| Module | Works in a node space | Refused (E1540) |
|---|---|---|
| `sys` | `sys.platform`, `sys.argv`, ... | |
| `copy` | `copy`, `deepcopy` | |
| `struct` | `pack`, `unpack`, `calcsize` | `unpack_from`, `pack_into`, `iter_unpack`, `Struct` |
| `io` | `StringIO`, `BytesIO`; a class deriving from `io.TextIOBase` that defines `write` | A method such a class inherits (`writelines`) |

## cpython

A cpython space is Jac lowered to Python and run on CPython, the one jac ships. Its code is
compiled to CPython's code objects with the `.jac` file as their file, so a traceback points at
the Jac source:

```text
  File "main.jac", line 17, in <module>
    fail(0);

  File "main.jac", line 10, in fail
    return 10 // n;

ZeroDivisionError: division by zero
```

What differs from a native space:

- **Imports are CPython's.** `import os;` is CPython's `os`, a Python package from the project's
  environment is imported as Python, and a `.py` file in the space is a module of it, wired in and
  shipped as it is (`space svc: cpython { api | helper; }` with `helper.py`): `helper ++> api
  { shout }` binds its `shout`, and `helper ++> api;` the module, read as `helper.shout`.
- **`int` is Python's**, with no limit (`2 ** 100` is exact). A sized type (`u8`, `i32`, `i64`)
  keeps its range and raises `OverflowError` past it.
- **An `obj` is a Python class** with the fields, `init`, `postinit`, properties, repr and
  equality a native one has.
- **The entry module runs as `__main__`.**
- **A file cannot be imported by path** (E5090).

Walkers, nodes and edges work as they do natively. A cpython space with no `entry` serves exactly
as a native one does: its functions, streams and walkers with their callers' roots, each call on a
thread of its own, its graph kept in SQLite, accounts and `:protect`, `by`, scheduled functions
and jobs. A call it makes of another space blocks until the reply, and a stream it calls is read
with `for`, as in a native one ([Crossings](crossings.md)).

`jac emit-py <space> -o <dir>` writes a cpython space's code objects and, in `<dir>/py/`, each
module as Python source.

An app that runs a cpython space alone is `dist/<app>/`: the code, CPython, its home (the standard
library compressed in `lib/python315.zip`, the project's packages in
`lib/python3.15/site-packages`) and the launcher `dist/<app>/<app>`.

## Other hosts in a native app's process

A native app may run one cpython space and one node space beside its native spaces, in its own
process. The app's program embeds CPython and Node and starts each space from its code, which the
artifact keeps beside the program in `spaces/<space>/` (`JAC_<SPACE>_CODE` names another
directory):

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space api: native { front; }
    space ml: cpython { model; }
    space js: node { tools; }

    app web { run api, ml, js; }
}
```

- The calls between them are carried inside the process, each way, serialized as a request is.
- The app serves the endpoints of all three at its one address:
  `/__jac/call/ml/model/where` reaches the cpython space.
- **A stream is carried inside the process too.** A call there is answered whole, so a stream
  crosses as one its reader pulls: each item is asked for as the reader takes it, in every
  direction (the app's spaces reading the cpython or the node space's stream endpoints, and
  those reading the app's), and a reader that leaves early closes it. The app serves a carried
  space's stream endpoint as it serves its own, each item an event as it is made.
- **The node space answers one call at a time.** Node runs on the thread that started it, the
  program's first, which in a serving app is the server's loop. A call of the node space from
  another thread (an endpoint's call has a thread of its own) is made by the loop for it, and the
  calling thread waits for the answer. In a program with an `entry`, which has no loop, a call of
  the node space from any thread but the first raises `RuntimeError`.
- The cpython space keeps its graph in a store of its own, under the app's data directory
  ([An app's data](data.md)). Its scheduled functions run on the app's loop, and its jobs in
  copies of the app's program.
- A program with an `entry` starts such spaces too, before its entry's code runs.

Two cpython spaces, or two node spaces, in one app's process are E5090.

## hermes

A hermes space is a phone app on React Native. Its `entry` module's `app` function is the app's
root component, and its components use React Native's elements:

<!-- example: not checked: an entry is a module of a hermes space, with JSX and a crossing -->
```jac
import from "react-native" { Text, View }

def:pub app -> JsxElement {
    has reply: str = "";

    async can with entry {
        reply = await ping();
    }

    return <View><Text>{reply}</Text></View>;
}
```

- `@jac/mobui` re-exports React Native's common elements (`View`, `Text`, `Pressable`,
  `ScrollView`, `TextInput`, `Image`, `FlatList`, `StyleSheet`, ...) from `react-native`. A module
  no space holds can import them and be shared with a browser space whose Vite configuration
  aliases `react-native` to `react-native-web`
  (`resolve: { alias: [{ find: /^react-native$/, replacement: "react-native-web" }] }`).
- Lowercase tags are E1221, and text directly in a `View` is E1220.
- Its globals are React Native's, typed from React Native's own declarations in the space's npm
  tree, whether or not a module imports `react-native`: the timers (`setTimeout`, `setInterval`
  and their `clear`s), `requestAnimationFrame`, `fetch`, `console`, `XMLHttpRequest`,
  `WebSocket`, `URL`, beside the language's own (`JSON`, `Promise`, `Date`, `Math`,
  `globalThis`). A browser's names are not among them: `document` and `window` are W2001.
- **It keeps no graph.** It may make a node and read its `jid` (a node that crossed from another
  space carries its own), but `root`, a connect, a `spawn`, an edge reference and a walker's
  `report` or `visit` are each E1540 (`a connect needs a graph, which a hermes space does not
  provide`). The graph is the spaces' it calls.
- Its `sys.platform` is the device's, as Python names it: `android` or `ios`.
- The app calls each space it reaches directly, at the URL `[apps.<app>.remote]` gives it, baked
  into the bundle. A signed-in session's token lasts as long as the app's process.
- A stream it calls is read with `async for`, as in a browser. React Native's `fetch` gives no
  body to read as it arrives, so the stream is read from an `XMLHttpRequest`'s progress.
- Its bundler is Expo, and its artifact is `dist/<app>/`: the app's bundles for Android and iOS,
  and `<app>.apk`, the app an Android phone installs, where the Android SDK is at hand.
  `jac run <app>` puts it on a connected phone or an emulator and starts it
  ([UI plugins and bundlers](ui-bindings.md#expo)).

## Desktop apps

An app that **runs** a browser space is a desktop app: the space in a window of its own.

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space api: native { svc; }
    space site: browser { entry web; pages.*; }
    space calc: wasm { calc; }

    app web { run api; serve site, calc; }
    app desk { run site, calc; }
}
```

```toml
[apps.desk.remote]
api = "https://api.example.com"

[apps.desk.window]
title = "Hello"
width = 900
height = 600
```

- The program serves the space's bundle on a loopback port only it knows, and shows it in a
  window. The pages' calls go through that port to the spaces the app reaches, as a served app
  forwards them ([Crossings](crossings.md)). An app that runs no native space signs its user in
  with the first space it reaches.
- The app ends when its window closes, with status 0. Where the window cannot be shown, the app
  says why and ends with status 1.
- Its artifact is `dist/<app>-<platform>/`: the program and `pages/<space>/`.

`[apps.<app>.window]`:

| Key | Default |
|---|---|
| `title` | The app's name |
| `width`, `height` | 1280, 860 |
| `min_width`, `min_height` | 640, 480 |

The window is the platform's web view:

| Platform | Window |
|---|---|
| Linux | GTK 3 with WebKitGTK 4.1, opened as the window opens. Where they are not installed, the app says `this app's window needs GTK 3 and WebKitGTK 4.1` and ends with status 1. |
| macOS, Windows | None yet: the app says `jac has no webview for this platform yet` and ends with status 1 |

### One program, with a server or without

A desktop app may work two ways from one program: against a server, or alone on its machine, with
the server's spaces in its own process. Each way is an **arrangement** of the app, a profile of
the archwire, and `profiles` in `jac.toml` puts them in one artifact
([Building apps](building.md#several-arrangements-in-one-artifact)):

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

```toml
[apps.desk]
profiles = ["default", "local"]

[apps.desk.remote]
api = "https://api.example.com"

[auth.accounts]
local_users = true
```

- `jac build desk` makes one program that is either. It starts as `default`, the first
  listed: the pages' calls of `api` are forwarded to `https://api.example.com`. As `local` it
  runs `api` itself, and keeps its graph and accounts in the app's data directory
  ([An app's data](data.md)).
- A page asks which arrangement it is in with `jacArrangement()`, and chooses one with
  `jacUseArrangement(name)`, from `"@jac/runtime"` ([Pages](pages.md#the-apps-arrangement)).
- When one is chosen, the window closes and the program starts again in its own place, with the
  same process id, as that arrangement. The choice is kept in the data directory, so the app
  starts as it the next time too. The page is signed in to no one after the change.

### Local users

`local_users = true` in `[auth.accounts]`, a setting of the standard auth plugin, makes the people
at the machine the app's users, with no password between them and it. It applies where the
window's program runs spaces of its own: in the example above, in the arrangement `local`. As
`default`, the app has no local users, and its user signs in to the server's accounts
([Pages](pages.md#signing-in)).

- **A local user is a name.** `sign_in()` asks who is there, offering the names it knows, and
  signs the page in as them. The first time, it makes the account `local:<name>`, which no
  password signs in to.
- **Each has a root of their own**, as every account does: `root` in a `:protect` endpoint is the
  current user's.
- **The current user is kept** in the data directory (the file `local-user`), so the app opens
  as them the next time: `sign_in()` then signs the page in at once. `sign_out()` makes the
  current user no one.
- **A name** is 1 to 256 characters, with the spaces around it dropped.

## Where the language differs by host

These are the differences by design. Anything else a program does differently on another host is a
defect.

| Host | Differs from native code |
|---|---|
| `cpython` | An `int` is Python's, with no limit ([Numbers](../language/numbers.md)) |
| `cpython` | A generator, a coroutine and an async generator print as CPython's own, naming the function and its address (`<generator object count_to at 0x1206c4d40>`); natively `<generator object>` |
| `cpython` | A dict whose keys change under a loop over it, its size the same, is found out by CPython's rule. Natively, removing any key but the newest leaves a hole the loop stops at: its next step raises `RuntimeError: dictionary keys changed during iteration`, and removing the newest key and adding another walks on. CPython walks on past some such changes and raises at the end of others: in `{"a": 1, "b": 2, "c": 3}`, removing `"b"` and adding `"z"` when the loop is at `"a"` raises natively and walks `a, c, z` on cpython. A change of size raises `dictionary changed size during iteration` on both |
| `cpython` | An `any` holding a list, dict or set taken as a typed one (`list[int]`) is the same container whenever no item has to change; natively it is always a new one |
| `cpython` | `list[int]` is CPython's alias of `list`, so `type([1]) is list[int]` is `False`; natively `True` |
| `node`, `browser`, `hermes` | A dict whose keys change under a loop over it, its size the same, is walked as JavaScript walks a `Map`: on, past a removed key and through an added one, where native code raises `dictionary keys changed during iteration` for a key removed from the middle. A change of size raises `dictionary changed size during iteration`, as on every host |
| `node`, `browser`, `hermes` | A whole float held in an `any` is an int: `a: any = 2.0` prints `2`, `-0.0` prints `0`, and `[1, "two", 3.0]` of anys prints `[1, 'two', 3]`. A `float`-typed value prints as natively (`2.0`) |
| `node`, `browser`, `hermes` | An `int` is a JavaScript number ([Numbers](../language/numbers.md)) |
| Every host but native and wasm | Owners, borrows and memory regions are checked, then erased: values are freed by the host's own collector, `region_of` gives `None`, and on a JavaScript host `__del__` never runs ([Memory](../language/memory.md), [Memory regions](../language/memory-regions.md)) |

## What is rejected

| Code | Cause |
|---|---|
| E1226 | A host that is not one of the six |
| E1540 | In a cpython, node, browser or hermes space: a use of C, a C function, record or global ([C libraries](../interop/c-libraries.md)). In a node space: a standard-library module or function only the native runtime defines. In a hermes space: anything that needs a graph. In a browser, hermes or node space: an import of a stdjac module that needs the native runtime (`stdjac.remote`, `stdjac.graph`, `stdjac.plan`, `stdjac.server`) |
| E1210 | A browser, hermes or node space calls an untagged function or walker of another space |
| E1220, E1221 | Text or a lowercase tag React Native does not show |
| E5090 | In a node space: `:protect`, a walker endpoint, JSX. In a cpython space: an import by path. In an app: a wasm space in `run` beside native spaces, a wasm space naming no module, two cpython or two node spaces in one process, an app that runs no space (one that only serves pages), an app whose `profiles` hold no arrangement that runs every space the others run |
