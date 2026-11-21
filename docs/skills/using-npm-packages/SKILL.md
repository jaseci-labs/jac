---
name: using-npm-packages
description: Use when Jac code needs an npm package or a Node built-in module (lodash, nanoid, date-fns, node:path...), in a native program or in a browser or node space - jac install --npm, npm trees in jac.toml, imports by quoted name, CommonJS default imports, how values cross, and what TypeScript declarations check.
---
# Using npm packages

## When to use this

Use it when Jac code imports JavaScript: an npm package, or one of Node's `node:` modules.

- In a **native program**, Node runs inside the program's process.
- In a **browser** or **node** space of an app, the space is compiled to JavaScript and the
  package is bundled or loaded by Node.

Load `writing-jac` first. Pages and components themselves are `pages-and-components`; spaces and
apps are `building-an-app`.

## Before you start

```sh
jac docs npm              # imports, checking, values both ways, exceptions, Node's loop
jac docs host             # what a node and a browser space reach
jac docs JsObject         # the same page, at its values
```

A project's npm packages are an npm tree of its `jac.toml`: a `[npm.<tree>]` table, which is that
tree's `package.json`. Look for one in `jac.toml`; the first install makes it. An import resolves
in the project's only tree, or the one its space names (`[spaces.<space>] npm = "<tree>"`).
Never write `package.json` by hand: jac writes it, in `eco/<tree>/`, from `jac.toml`.

## Steps

1. **Install with `jac install --npm`**, never a system npm: it runs the npm of the Node
   jac embeds, and records the packages in `jac.toml` and what was resolved in `jac.lock`.

```sh
jac install --npm nanoid lodash --tree app   # --tree names the tree; needed only to make the first, or among several
jac install --npm @types/lodash              # declarations, for a package that ships none
jac install                                  # on a fresh clone: everything jac.toml lists
```

2. **Import by the package's quoted name.** Each name is an ES export. A CommonJS package
   (lodash, most older packages) exports only `default`: import that and reach its functions as
   attributes. An ES package (nanoid) exports names.

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

Prints `[[1, 2], [3, 4]] 10 8`. Node's built-in modules need no install:

```jac
import from js { js_error }
import from "node:path" { basename, join }
import from "node:url" { URL }
import from "node:vm" { runInThisContext }

with entry {
    print(join("docs", "interop"), basename("/x/y.txt"));
    u = URL.new("https://example.org:8080/docs?q=jac");
    port: int = int(u.port);
    print(u.hostname, u.searchParams.get("q"), port + 1);
    arr = runInThisContext("[1, 2, 3]");
    xs: list[int] = arr;
    print(str(arr), xs);
    try {
        runInThisContext("(() => { const e = new Error('x'); e.code = 'ENOENT'; throw e; })()");
    } except RuntimeError as e {
        print(js_error(e).code);
    }
}
```

```output
docs/interop y.txt
example.org jac 8081
1,2,3 [1, 2, 3]
ENOENT
```

3. **Convert at the boundary.** An object, array or function JavaScript gives is a `JsObject`:
   - `C.new(args)` is `new C(args)`; `o.f()` calls with `o` as `this`.
   - Annotate to convert: `xs: list[int] = arr` copies an array into a list, a plain object
     into a `dict`. `str(arr)` is JavaScript's `String()`, `1,2,3`.
   - `undefined` is `None`; `null` is `JsNull` from `import from js { JsNull }`.
   - An `int` past 2**53 sent to JavaScript is `OverflowError`.
   - A JavaScript callback may get more arguments than it names: give the Jac function
     `*rest: any`.
   - JavaScript's `TypeError` and `RangeError` arrive as `TypeError` and `ValueError`, anything
     else as `RuntimeError`; `js_error(e)` is what was thrown, with its `.code` and `.name`.

4. **Check, build, run.**

```sh
jac check main.jac
jac build main.jac -o main && ./main
```

A native program that imports JavaScript links Node, so it is over 100 MB, and builds only for
the platform jac runs on. It reads its packages from the tree's `eco/<tree>/node_modules` as
it runs.

5. **In an app's space**, import the same way. A node space serves its `:pub` functions:

<!-- example: not checked: a module of a node space, with npm imports -->
```jac
import from "lodash" { default as _ }
import from "nanoid" { nanoid }

def:pub make(n: int) -> list[str] {
    return [nanoid(n) for _i in range(2)];
}

def:pub pairs(xs: list[int]) -> list[list[int]] {
    return _.chunk(xs, 2);
}
```

with `space ids: node { api; }` and `app ids { run ids; }` in the archwire; `jac check --space
ids`, then `jac run ids`. In a browser space a page imports `import from "date-fns" { format }`
and the bundler takes the package; check with `jac check --space <space>`.

## What a correct result looks like

- `jac check` prints nothing; the program prints what the examples show.
- `jac.toml`'s `[npm.<tree>.dependencies]` lists the packages; `jac.lock` has a `[npm.<tree>]`
  table; `eco/<tree>/node_modules/<pkg>` exists.
- A node space answers `curl -X POST http://127.0.0.1:<port>/__jac/call/ids/api/pairs -d '{"args": {"xs": [1, 2, 3]}}'`
  with `{"ok":true,"data":[[1,2],[3]]}`.

## Mistakes to expect

| Symptom | Means | Fix |
|---|---|---|
| W1100 `cannot find module 'x'` | Not among the packages of the tree the module resolves in | `jac install --npm x` |
| E5160 `the packages of npm tree ... are not installed` | `jac.toml` or `jac.lock` changed, or a fresh clone | `jac install` |
| E1288 `imports from npm, and jac.toml declares the trees ...` | Several trees, and the space names none | `npm = "<tree>"` under `[spaces.<space>]` in `jac.toml` |
| E1145 `module 'x' has no 'y'` | The package's declarations do not export `y` | Check the name; for CommonJS import `default` |
| `ImportError: cannot import name 'chunk' from 'lodash'` at start-up, though `check` passed | A CommonJS package's property imported as a named export, in a project with no declarations for the package (with `@types/lodash` installed, `check` reports it as E1145) | `import from "lodash" { default as _ }`, then `_.chunk`; install the package's declarations so `check` catches it |
| `AttributeError: ... has no attribute 'nope'` | A property the object lacks, looked up at run time | Attribute names are not checked; fix the name |
| `TypeError` where a Jac type is annotated | The JavaScript value is not that type | Annotate what it is, or convert |
| E1219 in a browser space | A package another `ui` plugin owns (`solid-js` under React) | Use the packages of the space's own `ui` plugin |
| E5090 | A JavaScript import in a build for another platform | Build for this platform |

Only imported names are checked, and only against `.d.ts` files: the package's own or its
`@types/<pkg>`. A package with neither is dynamic.

## Where to look things up

- `jac docs npm`: resolution, declarations, values both ways, Node's event loop, `jac node`.
- `jac docs host`: node spaces (what they refuse: `:protect`, walker endpoints, JSX).
- `jac docs apps/pages`: npm packages and style sheets in a browser space.
- `jac help npm`: the `jac npm` command (`jac help node` for `jac node`).
