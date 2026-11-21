---
description: Using npm packages and Node's built-in modules from a native Jac program - imports by quoted name, how their names are checked from TypeScript declarations, how values cross, Node's loop, and jac node, npm and npx.
keywords: npm, npm package, Node.js, JsObject, JsNull, js_error, js, node:, Node-API, TypeScript declarations
---
# npm and Node

A native Jac program imports an npm package, or one of Node's built-in modules, by its quoted
name. Node then runs inside the program's own process, and what the module gives is used from Jac
directly.

```jac
import from "node:path" { basename, join }
import from "node:url" { URL }
import from "node:util" { format }

with entry {
    print(join("docs", "interop"), basename("/x/y.txt"));
    print(format("%s is %d", "x", 5));
    u = URL.new("https://example.org:8080/docs?q=jac");
    print(u.hostname, u.searchParams.get("q"), type(u).__name__);
    port: int = int(u.port);
    print(port + 1);
}
```

```output
docs/interop y.txt
x is 5
example.org jac JsObject
8081
```

Node is jac's own: nothing needs installing on the machine. A package from the registry is
listed in the project's `jac.toml` and installed with `jac install`, by npm on that Node.

This page is about JavaScript a native program calls. A space whose host is `node` or `browser`,
whose own Jac is compiled to JavaScript, is described in [Apps](../apps/index.md)
(`jac docs apps`).

## Installing packages

A project's npm packages are an npm tree of its `jac.toml`, a `[npm.<tree>]` table, which is that
tree's `package.json` ([Packages](../toolchain/packages.md)):

```sh
jac install --npm nanoid lodash --tree app    # the first packages name the tree they make
jac install --npm @types/lodash               # declarations, for a package that ships none
```

```toml
[npm.app.dependencies]
nanoid = "^5.1.0"
lodash = "^4.17.21"
"@types/lodash" = "^4.17.0"
```

They are installed in `eco/app/node_modules`, and `jac.lock` records what npm resolved. On a fresh
clone, `jac install` installs them again. `main.jac`, in that project:

<!-- example: not checked: needs nanoid and lodash installed in node_modules -->
```jac
import from "lodash" { default as _ }
import from "nanoid" { customAlphabet, nanoid }

with entry {
    pairs: list[list[int]] = _.chunk([1, 2, 3, 4], 2);
    make = customAlphabet("abc", 8);
    id: str = make();
    print(pairs, len(nanoid(10)), len(id));
}
```

```text
[[1, 2], [3, 4]] 10 8
```

## How an import is resolved

- `import from "pkg" { a, b }` imports the module as an ES `import` of that specifier does on Node:
  Node's own resolution and export conditions, from the project's npm tree (`eco/<tree>`): its
  only tree, or the one the module's space names in `jac.toml`.
  It is settled as the program starts, before its entry code runs.
- Each name is the module's export of that name. A CommonJS module's `module.exports` is its
  `default`: `import from "lodash" { default as _ }` is the form to write, and `_.chunk` its
  function. Its properties are not named exports, as in Node's ES modules, so
  `import from "lodash" { chunk }` raises `ImportError: cannot import name 'chunk' from 'lodash'`
  as the program starts. Checking catches that only where the package has declarations
  (`@types/lodash` makes it E1145); without them the import passes `jac check`.
- `import "pkg";` imports a module for its effect.
- `node:` names Node's built-in modules (`node:path`, `node:fs/promises`, `node:events`, ...).
- The program reads its packages from the tree's `node_modules` in the project as it runs,
  wherever the program itself is. An app's artifact carries them with it
  ([Building apps](../apps/building.md)). Node starts the first time the program imports a JavaScript module.

## A project's own JavaScript

A JavaScript or TypeScript file of the project is a module of it, named by its path from
`archwire.jac` as a Jac module is (`kit/loud.js` is `kit.loud`). A Jac module takes its exports
through a [wire](../language/modules-wiring.md), as it takes another Jac module's:

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    kit.loud ++> page { shout, default as pick }
    kit.loud as loud ++> page;
    kit.marks --> kit.loud { mark }
}
```

- `{ shout }` binds the export `shout`, `{ default as pick }` the default export, and a wire with
  no names the module's namespace, under the name `as` gives it. A module wired whole under a
  dotted name and no `as` is loaded for its effect.
- A wired name the file does not export is E1145, read from the file by TypeScript. A CommonJS
  file states no exports, so any name is taken of it.
- The file writes its own imports, of packages and of other files of the project. Each import of
  another file of the project is declared by a `-->` wire, which TypeScript holds to the source
  ([Declared wires](../language/modules-wiring.md#declared-wires---)).
- Under an `archwire.jac` the file is not imported by its path: `import from "./kit/loud.js"
  { shout }` is E1144, whose message gives the wire to write. A path import stays for what is no
  module: a stylesheet or an asset a browser space's bundler takes.
- A node space carries the file, and every file of the project it imports, beside its own modules,
  each at its path in the project, as it is: Node runs it, so what it imports must resolve on
  Node. A browser space's bundler reads it where it is. A native program imports it from where it
  is, and an app's artifact carries it at the same path.

## How names are checked

jac reads a package's TypeScript declarations: its own `.d.ts` files, or those of
`@types/<pkg>` when it ships none. It resolves the package as an ES import does, under the
`import` condition, so a package with separate ES and CommonJS builds is checked against its ES
build's declarations.

- A name the declarations don't export is refused where it is imported (E1145).
- A package with no declarations is dynamic: its names are not checked, and a name it lacks is an
  `ImportError` as the program starts.
- Node's built-in modules are not checked: `import from "node:path" { nope }` builds, and raises
  `ImportError` as the program starts.
- Only the imported names are checked. An attribute of a JavaScript value (`_.nope`) is looked up
  as the program runs, an `AttributeError` when the object has no such property.
- Types are not checked. The declarations' parameter and return types are not applied to a call,
  whether the function is a named import (`nanoid` of `import from "nanoid" { nanoid }`) or a
  member of a default import (`_.kebabCase`): `nanoid("ten")` passes `jac check`, and so does
  `n: int = _.kebabCase("A B")`. A call's result is a JavaScript value, converted where a Jac type
  is wanted ([below](#javascripts-values-in-jac)); that one is a `TypeError` as the program runs
  (`expected int, found str`). Annotate what a call returns with the type it is.
- A build reads the declarations again when they change.
- The host's own names (`Date`, `RegExp`, `Symbol`, `isNaN`) are its declarations' globals. A name
  that is Jac's wins: `Number` is Jac's interface of the number types, so `Number.isNaN(x)` is
  E1030. JavaScript's `Number` is `globalThis.Number`, as every global is `globalThis`'s:
  `globalThis.Number.isNaN(x)`, `globalThis.Number.MAX_SAFE_INTEGER`.

jac reads declarations with TypeScript 6.0.3, which it fetches the first time it needs it: that
first check needs the network.

## JavaScript's values in Jac

An object, function or symbol JavaScript gives is a `JsObject`. Its properties are its attributes
(`o.n`) and its items (`o["n"]`); calling a function read from an object, either way, calls it with
that object as `this`. `C.new(args)` is JavaScript's `new C(args)`. Iterating it iterates it as
JavaScript does, and `len()` reads its `length`.

A primitive is the Jac value it is:

| JavaScript | Jac |
|---|---|
| `undefined` | `None` |
| `null` | `JsNull`, from the runtime's `js` module (`import from js { JsNull }`) |
| a boolean | `bool` |
| a number | `int` when it is whole and an int holds it (`2**60` is `1152921504606846976`), else `float` (`-0` is `-0.0`, `2**63` is `9.223372036854776e+18`) |
| a BigInt | `int`; `OverflowError` past 64 bits |
| a string | `str`; `ValueError` for one holding a lone surrogate |

A `JsObject` fits wherever a Jac type is wanted, and becomes a Jac value as it arrives there,
copied: an array a `list` of what its items become, a plain object (whose prototype is
`Object.prototype` or `null`) or a `Map` a `dict`, a `Uint8Array` (a `Buffer` among them)
`bytes`. Any other object is a `TypeError` where another type is wanted. A cycle the copy reaches
is one value, reached again.

A `JsObject` equals only itself: `a == b` is whether they are the same JavaScript value, so two
objects with the same properties are not equal. `copy.copy` of one is that same value.

## Jac's values in JavaScript

| Jac | JavaScript |
|---|---|
| `None` | `undefined` |
| `JsNull` | `null` |
| `bool`, `float`, `str` | a boolean, a number, a string |
| `int` | a number; `OverflowError` past 2**53, where a number stops being exact |
| `bytes`, `bytearray` | a new `Buffer` of its bytes |
| `list`, `tuple` | a new array of what its items become |
| `dict` | a new plain object when its keys are all strs (each an own data property, `__proto__` among them), else a new `Map` |
| a function or lambda | a JavaScript function that calls it with every argument JavaScript passes |
| any other Jac object | a JavaScript object wrapping it |
| a `JsObject` | what it holds |

A Jac function or object stays one JavaScript value for as long as JavaScript holds it, and comes
back to Jac as itself: `ee.off("x", cb)` removes the listener `ee.on("x", cb)` added. A JavaScript
caller may pass more arguments than a Jac function names (`array.map` passes three), so a callback
takes `*rest`.

```jac
import from js { JsNull }
import from "node:vm" { runInThisContext }

obj Thing {
    has x: int = 1;
}

with entry {
    kind = runInThisContext(
        "(x) => x === null ? 'null' : Array.isArray(x) ? 'array' : x instanceof Map ? 'map' : Buffer.isBuffer(x) ? 'buffer' : typeof x",
    );
    keyed: dict[any, any] = {1: "a"};
    print(kind(None), kind(JsNull), kind(True), kind(5), kind(1.5), kind("s"));
    print(kind([1]), kind((1, 2)), kind({"a": 1}), kind(keyed), kind(b"ab"), kind(Thing()));
    back = runInThisContext("(x) => x");
    t = Thing(x=7);
    print(back(t) is t, back(None) is None, back(JsNull) is JsNull);
    arr = runInThisContext("[1, 2, 3]");
    xs: list[int] = arr;
    d: dict[str, any] = runInThisContext("({ a: 1, b: [2] })");
    print(xs, d, arr[0], len(arr), [x * 2 for x in arr]);
    print(
        runInThisContext("1.5"),
        runInThisContext("2"),
        runInThisContext("2n ** 40n"),
        runInThisContext("undefined"),
    );
    o = runInThisContext("({ n: 3, f() { return this.n; } })");
    print(o.n, o["n"], o.f(), o["f"]());
}
```

```output
undefined null boolean number number string
array array object map buffer object
True True True
[1, 2, 3] {'a': 1, 'b': [2]} 1 3 [2, 4, 6]
1.5 2 1099511627776 None
3 3 3 3
```

## Exceptions

A JavaScript exception reaching Jac is a `TypeError` for a `TypeError`, a `ValueError` for a
`RangeError`, and a `RuntimeError`, its message prefixed with the error's name, for anything else.
`js_error(e)` is what was thrown, a `JsObject` whose `.name`, `.code` and other properties read as
in JavaScript, or `None` for an exception that did not come from JavaScript. A Jac exception thrown
into JavaScript is a `TypeError`, a `RangeError` (for a `ValueError`) or an `Error` named after its
class, with its message; it is the same Jac exception again if it comes back.

```jac
import from js { js_error }
import from "node:vm" { runInThisContext }

with entry {
    for src in [
        "null.x",
        "new Array(-1)",
        "(() => { const e = new Error('nope'); e.code = 'E_NOPE'; throw e; })()",
    ] {
        try {
            runInThisContext(src);
        } except Exception as e {
            print(type(e).__name__, "|", e, "|", js_error(e).name);
        }
    }
    try {
        runInThisContext("(() => { const e = new Error('x'); e.code = 'ENOENT'; throw e; })()");
    } except RuntimeError as e {
        print(js_error(e).code);
    }
    catcher = runInThisContext(
        "(f) => { try { f(); } catch (e) { return e.constructor.name + ': ' + e.message; } }"
    );
    print(catcher(lambda (*rest: any) -> any { raise ValueError("bad value"); }));
    try {
        runInThisContext("({})").missing;
    } except AttributeError as e {
        print("AttributeError:", e);
    }
    try {
        runInThisContext("(x) => x")(2 ** 53 + 1);
    } except OverflowError as e {
        print("OverflowError");
    }
}
```

```output
TypeError | Cannot read properties of null (reading 'x') | TypeError
ValueError | Invalid array length | RangeError
RuntimeError | Error: nope | Error
ENOENT
RangeError: bad value
AttributeError: 'Object' object has no attribute 'missing'
OverflowError
```

## Node's loop

Node's event loop runs as it does in `node`:

- The program's code between two waits is one task of the loop. What its calls queue (promise
  reactions, `process.nextTick` callbacks) runs when it waits or ends.
- `await` of a `JsObject` that is a promise, in an async function, runs the loop until the promise
  settles, and gives its value or raises its rejection. Waiting inside a Jac function that
  JavaScript called is a `RuntimeError`: the loop cannot run there.
- A rejection no handler took is reported as Node reports it, and ends the program.
- When the entry code ends normally, the loop runs out: timers and callbacks still pending run,
  then `beforeExit` and `exit`, as Node's main ends.
- `sys.exit()` and an uncaught Jac exception end the program as `process.exit()` does: `exit`
  handlers run, the loop does not. An uncaught JavaScript exception, and `process.exit()` called
  from JavaScript, end it as they end Node.
- Node is used from the thread that started it. A call from another thread is a `RuntimeError`.

```jac
import from "node:events" { EventEmitter }
import from "node:timers" { setTimeout }

with entry {
    ee = EventEmitter.new();
    seen: list[any] = [];
    cb = lambda (*args: any) -> any {
        seen.append(args[0]);
        return None;
    };
    ee.on("tick", cb);
    ee.emit("tick", 7);
    ee.off("tick", cb);
    ee.emit("tick", 9);
    print(seen, ee.listenerCount("tick"));
    setTimeout(lambda -> None { print("timer fired") }, 5);
    print("end of entry");
}
```

```output
[7] 0
end of entry
timer fired
```

## jac node, npm and npx

`jac node` runs Node 26 with its own command line, and `jac npm` and `jac npx` run the npm
it ships:

```sh
jac node -e 'console.log(process.version)'
jac node app.ts                 # TypeScript's types stripped, as Node does
jac npm ls
jac npx tsc --version
```

- Node is built into jac and runs in jac's own process, with its own C++ and libuv compiled
  by jac, V8, ICU with every locale's data, and the OpenSSL, zlib, Zstandard, SQLite and libffi
  the toolchain also gives CPython. Its built-in modules are all there, `node:worker_threads`,
  `node:zlib`'s Brotli and `node:sqlite`'s sessions among them, and so is `Temporal` (dates,
  durations, time zones' rules and other calendars).
- `lib/node/bin/node` in the toolchain is a link to jac, which started by that name is that
  Node; it is the path `process.execPath` names, by which npm and `child_process` start Node again.
  `jac node`, `npm` and `npx` put its directory first on `PATH`, so a script npm runs finds
  `node` there.
- npm is the one Node ships, in the toolchain's `lib/node/npm/`. In a Jac project, `jac npm`
  and `jac npx` run in an npm tree of `jac.toml` (`eco/<tree>`), and `jac.toml` and `jac.lock`
  take what they wrote there ([Packages](../toolchain/packages.md#running-npm)). Where there is no
  `jac.toml`, they are npm as it is anywhere.
- Node exports Node-API, Node's C++ API, V8's and libuv's (what their headers mark for export), as
  Node's own Windows build does. So the native addons packages ship load as they do on Node:
  Node-API addons, and V8 addons built against the same C++ library, libc++. Their headers are in
  `lib/node/include/`; build one with [`jac cc`](c-and-cpp.md) (`-shared -fPIC` on Linux,
  `-bundle -undefined dynamic_lookup` on macOS). An addon of Node's C++ API and V8's (`node.h`,
  `v8.h`) builds with `jac c++` as node-gyp builds one: in C++20, with the module's name
  defined.

```sh
jac c++ -std=c++20 -DNODE_GYP_MODULE_NAME=hello -bundle -undefined dynamic_lookup \
    -I <toolchain>/lib/node/include hello.cc -o hello.node
jac node -e 'console.log(require("./hello.node").hello(14))'
```

## Platforms and size

Node is in the toolchain for Linux (x86_64 and arm64) and macOS on Apple silicon. On Windows,
`jac node` says the toolchain has no Node. A program can import JavaScript only when it is built
for the platform jac runs on, with that platform's Node; a build for another platform refuses
each such import (E5090).

A program that imports JavaScript links Node, so it is large: over 100 MB.

## What is rejected

| Code | Condition |
|---|---|
| E1145 | A name the package's declarations don't export |
| W1100 | A package that is not installed, or not among the packages of the tree the import resolves in: `cannot find module` |
| E1287, E1288 | The module's space names a tree `jac.toml` does not declare, or none of several |
| E5160 | The tree's packages are not installed as `jac.toml` and `jac.lock` say |
| E5090 | A JavaScript import in a build for a platform without the toolchain's Node |

As the program runs: `ImportError` for an export an undeclared package or a built-in module
lacks, `AttributeError` for a property an object lacks, `OverflowError` for an int past 2**53 sent
to JavaScript.

## Differences from Python and from the reference design

- Pyodide's `JsProxy` is the nearest thing in Python. As there, a missing property is an
  `AttributeError` rather than `undefined`, and `C.new(...)` is `new C(...)`.
- `import from "lodash" { chunk }` fails for a CommonJS package whose exports Node cannot list,
  exactly as `import { chunk } from "lodash"` fails in an ES module on Node: import its `default`.
- `str()` of a `JsObject` is JavaScript's `String()` of it: an array prints as `1,2,3`. Convert it
  to a Jac value first (`xs: list[int] = arr`) to print it as a list.
