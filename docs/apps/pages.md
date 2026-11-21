---
description: A browser space's pages - routes from the files under pages/, a page's parameters, the layout and the entry's app, the HTML shell, @jac/runtime, calling the server and reading its streams, signing in, a desktop app's arrangement and local users, npm packages and style sheets.
keywords: page, pages, route, routes, layout, JsxPage, JsxLayout, @jac/runtime, Link, Outlet, navigate, sign_in, sign_out, signed_in, signed_in_as, signed_in_name, jacArrangement, jacUseArrangement, unsafe_html, browser space
---
# Pages

A browser space is a set of modules compiled to JavaScript, bundled, and handed to a browser by the
app that serves it ([the archwire](archwire.md), `jac docs graph spaces`). Its **pages** are its
modules under `pages/`: each one is a URL, and its `page` function is what that URL shows.

This page covers what makes a page and how the pages fit together. What a page returns, JSX,
state and effects, is on [Components and JSX](components.md) (`jac docs component`). File
routes need the `react` plugin, the standard `ui` plugin of a browser space: a page in a space
built with another is E1279 ([UI plugins and bundlers](ui-bindings.md)).

## The shortest site

A project with a server space and a browser space, as on [Apps](index.md) (`jac docs apps`):

```text
site/
  jac.toml
  archwire.jac
  svc.jac             the server's module
  web.jac             the browser space's entry
  pages/
    index.jac         /
    layout.jac        wraps every page
    user.jac          /user/:id
    docs/index.jac    /docs/*
  eco/web/
    index.html        the HTML shell
    vite.config.ts
```

`archwire.jac`:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer service { svc; }
    layer pages { web | pages.*; }
}

graph spaces {
    space api: native { svc; }
    space site: browser { entry web; pages.*; }

    app web { run api; serve site; }
}

graph import {
    edge Calls: service --> pages;

    svc ++> pages.index { greet }
}
```

`pages/index.jac`, the page at `/`, which calls the server's `greet` once it has shown:

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

`jac install` once, then `jac run web`, and `http://127.0.0.1:8000/` shows `hello jac`.

## Routes

Every `.jac` file below `pages/` (beside the archwire) that a browser space holds is a page,
except `.impl.jac` and `.test.jac` files and anything in a directory named `impl` or `test`. The
space holds them through a pattern, `pages.*`, as it holds any module.

A page's route is its path below `pages/`, with `index` left out, followed by its `page`
function's parameters:

| File | `page`'s parameters | Route | Example URL |
|---|---|---|---|
| `pages/index.jac` | none | `/` | `/` |
| `pages/about.jac` | none | `/about` | `/about` |
| `pages/user.jac` | `id: str` | `/user/:id` | `/user/amy` |
| `pages/sum.jac` | `a: str, b: str` | `/sum/:a/:b` | `/sum/2/3` |
| `pages/docs/index.jac` | `*rest: str` | `/docs/*` | `/docs/guide/install` |

- A parameter `name: str` is one segment of the URL, given as a `str`.
- A parameter `*name: str` is the rest of the path, given as its segments: `/docs/guide/install`
  gives `rest` as `["guide", "install"]`.
- Any other parameter, of another type or a keyword-only one, is E1228.

`pages/user.jac`:

<!-- example: not checked: a page is a module of a browser space, with JSX -->
```jac
def:pub page(id: str) -> JsxPage {
    return <p>user {id}</p>;
}
```

`pages/docs/index.jac`:

<!-- example: not checked: a page is a module of a browser space, with JSX -->
```jac
def:pub page(*rest: str) -> JsxPage {
    return <ul>{[<li key={part}>{part}</li> for part in rest]}</ul>;
}
```

`/docs/a/b/c` shows the list `a`, `b`, `c`.

A segment is always text. Convert it where it is used: `pages/sum.jac` calls `int(a)`.

Routes are under the space's `base` ([UI plugins and bundlers](ui-bindings.md#choosing-a-spaces-plugins)).
With `base = "/app/"`, `pages/index.jac` is at `/app/` and `pages/user.jac` at `/app/user/amy`. A
route is written without the base wherever the program names one: `<Link to="/user/amy">` and
`navigate("/user/amy")` go to `/app/user/amy`.

Each page is loaded when it is first shown: the bundle has a file per page, and the browser
fetches the page's file as the URL is visited.

### What a page module declares

- **`page`**, a function returning `JsxPage` (the type of a page, the same as `JsxElement`). A page
  module without a `page` function is E1227. Its access tag does not matter: the route table calls
  it either way.
- Anything else a module may declare. Other functions of the module are ordinary functions, and
  components it uses may live anywhere the space reaches.

## The layout

`pages/layout.jac` is not a route. Its `layout` function returns a `JsxLayout` and wraps every
page; `<Outlet />` is where the page goes:

<!-- example: not checked: a page is a module of a browser space, with JSX -->
```jac
import from "@jac/runtime" { Link, Outlet }

def:pub layout -> JsxLayout {
    return <div>
        <nav><Link to="/">home</Link><Link to="/user/amy">amy</Link></nav>
        <Outlet />
    </div>;
}
```

A `pages/layout.jac` with no `layout` function is E1227.

## The entry

A browser space's `entry` is optional. When there is one, it is where the space's global style
sheets are imported, and its `app` function, when it has one, wraps everything, layout included.
`web.jac`:

<!-- example: not checked: an entry is a module of a browser space, with JSX -->
```jac
import "./styles/site.css";

def:pub app(children: any) -> JsxElement {
    return <main className="app">{children}</main>;
}
```

With the layout above, `/user/amy` renders as:

```html
<main class="app"><div><nav><a href="/">home</a><a href="/user/amy">amy</a></nav><p>user amy</p></div></main>
```

A browser space with no pages (under a `ui` plugin other than `react`, for one) is started by its
entry's `with entry` block, which renders into the page itself: see
[UI plugins and bundlers](ui-bindings.md).

## The HTML shell

The bundler starts from an `index.html` in its root directory (the project's root, unless the
bundler's configuration says another). It holds the element the app renders into, `#root`, and
one script, `/@jac/entry`, which is the space's compiled routes and entry:

```html
<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <title>site</title>
    </head>
    <body>
        <div id="root"></div>
        <script type="module" src="/@jac/entry"></script>
    </body>
</html>
```

The app serves the bundle. A request for a path that is not a file of the bundle, `/user/amy`,
gets `index.html`, even with a dot in it (`/user/a.b`, `/docs/v0.39`), and the router picks the
page in the browser. A path that names a missing file of a kind it serves (`/x.js`, `/logo.png`)
is 404, and one that leads out of the bundle's directory, by `..` or a symbolic link, is 403. Only
the files under the bundle's own `assets/` are served as cached for a year, since the bundler
names them by their content. `static_file` in `stdjac.server` is this, for a program that serves
files itself ([stdjac.server](stdjac-server.md#static_file)).

## @jac/runtime

`"@jac/runtime"` is the module a browser space imports what jac's runtime gives it from. Import
names from it as from any npm package: `import from "@jac/runtime" { Link, navigate }`. Under the
`react` plugin it has:

| Name | What it is |
|---|---|
| `Link` | A link to a route: `<Link to="/user/amy">amy</Link>`, which changes the page without reloading |
| `navigate(path)` | Goes to `path` from code |
| `Navigate` | An element that goes to its `to` when shown |
| `Outlet` | Where a layout puts the page |
| `useLocation`, `useNavigate`, `useParams`, `useSearchParams` | React Router's hooks |
| `useState`, `useEffect`, `useRef`, `useMemo`, `useCallback`, `useContext`, `createContext` | React's, for code that calls the library directly ([Components](components.md) says when) |
| `unsafe_html(html)` | An element showing `html` as HTML, unescaped. Use only on HTML the project controls. |
| `sign_in`, `sign_out`, `signed_in`, `signed_in_as`, `signed_in_name` | Signing in, below |
| `jacArrangement`, `jacUseArrangement` | Which arrangement of its app the page is in, and choosing another, [below](#the-apps-arrangement) |
| `RemoteError` and its subclasses | What a failed crossing raises ([Crossings](crossings.md)) |
| `__getLocalStorage`, `__setLocalStorage`, `__removeLocalStorage` | `localStorage`, or an in-memory store where there is none |

Under any other `ui` plugin jac ships, `@jac/runtime` has the sign-in and arrangement
functions, the storage functions and the `RemoteError` classes, and none of the routing names.
A name it does not have under the space's `ui` plugin is E1145, as a package's is.

## Calling the server

A page calls a function or spawns a walker of another space as it calls any function, and awaits
the result, since every crossing is asynchronous in a browser:

- `text = await greet("jac");`
- `w = await (root spawn MyNotes());`, with the spawn in parentheses because `await` binds
  tighter than `spawn`.
- `async for step in steps(3) { ... }` reads a stream, a function that gives an iterator, item by
  item as the server makes them. It is not awaited: the loop is
  ([Crossings](crossings.md#calling-a-stream)).

The call goes to the app that served the page, at the page's own origin. What the page may call is
what the archwire wires to its modules, and each function or walker it calls must be `:pub` or
`:protect` (E1210). [Crossings](crossings.md) has the rules (`jac docs crossings`).

A page can make crossings in an effect (`async can with entry`, as above) or in an event handler.
A wasm space the app serves is called the same way: its module is loaded into the page, and a call
of one of its functions is awaited ([Hosts](hosts.md)).

## Signing in

A `:protect` function or walker needs a signed-in caller. A page says that it wants one, and
names no way of signing in: the project's `auth` [plugin](plugins.md) says what signing in takes,
and the functions of `@jac/runtime` carry it out. Each is awaited:

| Function | Does |
|---|---|
| `await sign_in()` | Signs the caller in. It gives `True` once they are, at once for one signed in already, and `False` if they turned the form away |
| `await sign_out()` | Ends the caller's session |
| `await signed_in()` | Whether the caller is signed in |
| `await signed_in_as()` | Who the caller is signed in as, or `""` |
| `await signed_in_name()` | What the caller is called: the name the plugin gave as they signed in, where it has one (their login at the service they signed in through), else who they are; `""` for no one |

<!-- example: not checked: a page is a module of a browser space, with JSX and crossings -->
```jac
import from "@jac/runtime" { RemoteRejected, sign_in }

def:pub page -> JsxPage {
    has notes: list[str] = [];
    has error: str = "";

    async def load {
        try {
            notes = (await (root spawn MyNotes())).texts;
        } except RemoteRejected as e {
            error = e.detail;
        }
    }

    async def enter {
        if await sign_in() {
            await (root spawn AddNote(text="first"));
            await load();
        }
    }

    async can with entry {
        await load();
    }

    return <section>
        <button onClick={enter}>sign in</button>
        <p>{error}</p>
        <ul>{[<li key={t}>{t}</li> for t in notes]}</ul>
    </section>;
}
```

Before signing in, `MyNotes` (a `walker:protect`) is refused and the page shows
`This needs a signed-in caller.`; after, it lists the notes.

What `sign_in()` shows is the plugin's:

- **A form,** for a plugin that asks for something: the standard `accounts` plugin's has a
  username, an email and a password, with `Sign in` and `Create account`
  ([Serving a space](server.md#the-accounts-plugin)). It is shown over the page, says what the
  plugin refused a try with, and goes when the caller is signed in or cancels.
- **A place to go,** for a plugin that signs callers in elsewhere, or for one of a form's
  buttons that does (`Continue with GitHub`): the page leaves for it, and the caller comes back
  signed in, to the page they left from.
- **Nothing,** for a caller the plugin knows already.

The form is the runtime's own, built of plain elements whatever the space's `ui` plugin, so one
page works under every auth plugin. Its parts carry classes a project's style sheet styles:
`jac-sign-in` (what covers the page), `jac-sign-in-form`, `jac-sign-in-field`,
`jac-sign-in-input`, `jac-sign-in-error`, `jac-sign-in-actions`, `jac-sign-in-action` and
`jac-sign-in-cancel`. Its own rules are written with `:where()`, so any rule of the project's
wins over them.

The session's token is kept in the browser's `localStorage` (under `jac_token`) and sent with
every crossing; the name the plugin gave with it is kept beside it (under `jac_name`).

**On a phone** (a `hermes` space) the same call shows the same form, drawn by the `react_native`
plugin with React Native's own views over the app: a field for each the plugin asks for, a button
for each way of signing in that answers in place, and Cancel. A way of signing in that leaves for
a page (GitHub) is not offered there: a page has no way back into the app. Where the plugin offers
only such ways, `sign_in()` raises `RemoteRejected`.

## The app's arrangement

A page asks the app that serves it which arrangement of the app it is in with two functions of
`@jac/runtime`. They are for a desktop app
([Hosts](hosts.md#one-program-with-a-server-or-without)), and each is awaited:

| Function | Gives or does |
|---|---|
| `await jacArrangement()` | `{names, current, chosen}`: the arrangements the app's artifact holds (`names`), the one this run is (`current`), and whether it was chosen (`chosen`): `False` while the app runs as its first arrangement because none has been |
| `await jacUseArrangement(name)` | Chooses the arrangement `name`: a desktop app starts again as it, and the page is signed in to no one. A name that is none of `names` raises `RemoteRejected` |

In an app with one arrangement, `jacArrangement()` gives `{names: [], current: "", chosen: True}`.
So one page serves in a browser and in a window: it offers a choice only where there is one.

<!-- example: not checked: a page is a module of a browser space, with JSX -->
```jac
import from "@jac/runtime" { jacArrangement, jacUseArrangement, sign_in, signed_in_as }

def:pub page -> JsxPage {
    has ways: list[str] = [];
    has who: str = "";

    async def load {
        a = await jacArrangement();
        ways = [] if a.chosen else a.names;
        who = await signed_in_as();
    }

    async def enter {
        await sign_in();
        await load();
    }

    async can with entry {
        await load();
    }

    return <section>
        {[<button key={w} onClick={lambda { jacUseArrangement(w) }}>{w}</button> for w in ways]}
        <button onClick={enter}>who is here</button>
        <p>{who}</p>
    </section>;
}
```

Opened for the first time, the app of [Hosts](hosts.md#one-program-with-a-server-or-without) shows
the buttons `default` and `local`. `local` starts it again running its own server. Where the
project's `accounts` plugin takes the people at the machine as its users
([Hosts](hosts.md#local-users)), `sign_in()` asks who is there, by name and with no password, and
knows them the next time; every `:protect` endpoint the page calls then runs for them, on their
own root.

The app answers the arrangement at `/__jac/app/arrangement`: a `GET` reads, and a `POST` of
`{"name": ...}` chooses. The replies are the JSON envelope of every call
([Serving a space](server.md#replies)).

## npm packages and style sheets

A browser space imports from npm with a string module name and names in braces:

- `import from "solid-js/web" { render }` binds a package's exports.
- `import "./styles/site.css";` imports a file for its effect, as the bundler takes it: a style
  sheet goes into the bundle's CSS. A cpython space cannot import a file by path (E5090).

The packages are those of the space's npm tree, `[npm.<tree>]` in `jac.toml`, installed with
`jac install` (by the npm of jac's own Node) into `eco/<tree>`
([Packages](../toolchain/packages.md)).

What a space imports from npm is checked against the package's TypeScript declarations, read by
a TypeScript that jac runs on its own Node: the package's own `.d.ts` files, or its `@types`
package, and the host's globals (`lib.dom.d.ts` in a browser, so `document` and `window` are
typed; in a hermes space, React Native's own declarations, as the space's npm tree has them, so
`setTimeout`, `fetch` and `console` are typed and `document` is not). Under those checks:

| Import | Result |
|---|---|
| A package that is not installed | W1100, reported as an error |
| A name a typed package does not export | E1145 (`module 'solid-js/web' has no 'nothere'`) |
| A package with no declarations | Allowed: its values are dynamic, as an untyped Python package's are |
| A package another `ui` plugin owns (`solid-js` in a React space) | E1219 ([UI plugins and bundlers](ui-bindings.md)) |
| A host global nothing declares (`windw.alert(n)`) | W2001, reported as an error (`unknown name 'windw'`) |

A package's `declare global { ... }` adds to the host's globals when a module imports it. A package
installed after a build that failed for want of it is seen by the next build.

## What is rejected

| Code | Cause |
|---|---|
| E1227 | A module under `pages/` with no `page` function, or `pages/layout.jac` with no `layout` |
| E1228 | A `page` parameter that is not `name: str` or `*name: str` |
| E1279 | A page in a space whose `ui` plugin has no file routes (any but `react`) |
| E1210 | A page calls a function or walker of another space that is not `:pub` or `:protect` |
| E1540 | An import of a stdjac module that is native code's (`stdjac.remote`): its classes are `"@jac/runtime"`'s here |
| E1219 | An import of a package another `ui` plugin owns |
| E1145 | An import of a name a typed npm package does not export |
| W1100 | An import of an npm package that is not installed |
| W2001 | A name that is neither the program's nor a declared host global |

`jac check --space site` checks a browser space's modules as its build does, and reports each
of these with its file and line:

```text
pages/user.jac:1:1: error[E1228]: a page's parameter 'n' is a segment of its URL: a str, or `*` and str for the rest
```

The page itself runs in the browser, so what goes wrong there is seen there. Under the `react`
plugin, an exception a component raises is printed to the browser's console
(`jac: a component failed ...`), and the app shows the error's stack in place of the page.
