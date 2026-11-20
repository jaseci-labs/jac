---
description: jac browse, a browser driven from the command line - sessions, the browser jac fetches and the ones it can be given, snapshots and refs, acting on elements, waiting, tabs, frames and dialogs, canvas and WebAssembly apps, what a page logged, cookies and saved state, and how a session is held.
keywords: browse, browser, headless, Chrome, snapshot, ref, click, fill, screenshot, pdf, tab, frame, dialog, browser session, DevTools protocol, CDP, canvas
---
# browse

`jac browse` drives a real browser, a command at a time: it opens a page, prints what is on it, acts on it with the input a person's would be, and reads what the page logged. It is for an agent or a script that has to look at a running app, and it needs nothing installed beside jac.

```sh
jac browse open localhost:8000
jac browse snapshot -i
jac browse click @e5
jac browse fill '#email' ann@example.com
jac browse press Enter
jac browse wait --text Welcome
jac browse screenshot page.png
jac browse close
```

A page that renders in JavaScript shows nothing to `curl`. `snapshot` shows what the browser made of it.

## A session

`open` starts a **session**: a browser, held by a background process until `close`. Every command after it acts on that session's page, so a command line holds no state of its own.

| Command | What it does |
|---|---|
| `open <url>` | Starts the session if there is none, opens the page, and prints its title and address once it has loaded |
| `close` | Ends the session: the browser exits and what it kept is removed. `close --all` ends every session |
| `session list` | Prints the sessions that are open, one name a line |

- `--session <name>` names the session a command is for; without it the session is `JAC_BROWSE_SESSION`, else `default`. Sessions are separate browsers with separate cookies.
- A session keeps nothing once it is closed. `state save` writes its cookies and local storage to a file a later session loads ([below](#cookies-storage-and-saved-state)).
- A URL with no scheme is `https://`, and `http://` for `localhost`, `127.…` and `[::1]`.
- A command other than `open` with no session open is an error. `close` with none does nothing.

## The browser

The browser is Chrome's headless shell, the build Google publishes for testing. jac fetches it the first time `open` runs and keeps it beside the [build cache](cache.md), in `fetched/`; a release does not hold it. That first `open` needs the network, and says `fetching Chrome <version>'s headless shell`.

- **It is pinned.** A release names one version of the browser and the sha256 of every file in it (`lib/browser/<platform>/`), and each file is checked as it is fetched. What `snapshot` prints is therefore the same on every machine.
- **jac never looks for an installed browser.** A browser of your own is one you name:

| Option of `open` | The session's browser |
|---|---|
| none | The pinned headless shell |
| `--chrome <path>` | That program, a Chrome or Chromium, started by jac |
| `--cdp <address>` | A browser that is already running, which jac attaches to and `close` leaves running. The address is its debugging port (`9222`), `host:port`, an `http://` address, or its `ws://` debugger address |

- **The sandbox is on.** Chrome does not sandbox a browser root runs, so for root jac starts it without and says so. Elsewhere `--no-sandbox` starts it without: a container that gives no user namespaces needs it, and Chrome's own message, which jac prints, says when.
- **On Linux the headless shell uses the system's libraries** (NSS, GLib, X11's and others), which a desktop has and a bare container may not. When one is missing the browser does not start; jac prints the loader's message and where the packages it needs are listed (`deb.deps` and `rpm.deps`, which Google ships with the browser).
- It runs on Linux (x86_64 and arm64) and on macOS on Apple silicon. On Windows `jac browse` says it does not run there yet.

## Snapshots and refs

`snapshot` prints the page as its accessibility outline: what a screen reader is told, which is what the page means and not how it is marked up.

```text
- heading "Fixture page" [level=1] [ref=e1]
- navigation
  - link "Second page" [ref=e2]
- main
  - paragraph: clicked 0 times
  - button "Bump" [ref=e4]
  - button "Disabled" [disabled] [ref=e6]
  - form
    - textbox "Email" [ref=e7]
    - checkbox "Agree" [ref=e9]
    - combobox "Size" [collapsed] [ref=e12]: Small
  - iframe "Inner" [ref=e33]
    - button "Inside" [ref=e34]
```

- A line is a role, then the name in quotes, then what holds of it in brackets (`[level=1]`, `[checked]`, `[disabled]`, `[expanded]` or `[collapsed]`, `[selected]`, `[pressed]`, `[required]`, `[focused]`), then after a colon the value a field holds or the text of a part that holds only text.
- **`[ref=e4]` is a ref**: a name for that element in commands, written `@e4`. Everything that can be acted on has one, and so has every part with a name.
- A frame's document is printed under its `iframe`, with refs of its own.
- `snapshot -i` prints only what can be acted on, one a line.
- Refs are the last snapshot's. After the page changes, take another: a ref whose element is gone is refused (`@e4 is no longer in the page: take a new snapshot`).

Parts that tell a reader nothing are left out: wrappers with no role, and a paragraph, list or image with neither a name nor contents.

## Elements

Where a command takes an `<element>`, it is one of:

| Written | The element |
|---|---|
| `@e4` | The ref `e4` of the last snapshot |
| anything else | A CSS selector: the first element it matches, in the page or the frame commands are acting in |

A command that acts on an element waits for it, up to the [timeout](#waiting): until it is in the page, **visible**, **enabled** where that matters, **still** (in the same place twice running), and **not covered** where the command points at it. Then it scrolls it into view and sends the browser real input at its center. A page can still move an element between the pointer's arrival and its press; a click whose press would land on something else is held back before the page sees it, and made again where the element now is. When the wait runs out the error says which of those failed:

```text
jac: browse: cannot act on #under: div#cover covers it
```

## Acting

| Command | What it does |
|---|---|
| `click <element>`, `dblclick <element>` | Moves the pointer to its center and presses and releases the left button, once or twice |
| `hover <element>` | Moves the pointer to its center |
| `focus <element>` | Gives it the keyboard |
| `fill <element> <text>` | Replaces what a text field, a textarea or editable text holds with `<text>`. A date, time, color or range input is set to it |
| `type <element> <text>` | Focuses it and types `<text>` a key at a time, after what it holds |
| `press <key>` | Presses and releases a key, or several joined by `+` with the last pressed while the others are held: `Enter`, `Shift+Tab`, `Control+a` |
| `keydown <key>`, `keyup <key>` | Presses a key and leaves it down; releases it |
| `select <element> <option>...` | Selects options of a `<select>`, each by its value or its label |
| `check <element>`, `uncheck <element>` | Clicks a checkbox, a radio button or a switch unless it is already so, and fails if the click did not make it so |
| `scroll <up \| down \| left \| right> [<pixels>]` | Scrolls what is under the pointer, or the page: by `<pixels>`, else by most of the window |
| `scrollintoview <element>` | Scrolls it into the window |
| `upload <element> <file>...` | Gives files to a file input |
| `mouse move <x> <y>` | Moves the pointer to a point of the window |
| `mouse down [<button>]`, `mouse up [<button>]` | Presses and releases `left` (the default), `right` or `middle` where the pointer is |
| `mouse wheel <dy> [<dx>]` | Turns the wheel where the pointer is |

- A key is a character (`a`, `A`, `7`, `?`) or a name: `Enter`, `Tab`, `Escape`, `Backspace`, `Delete`, `Space`, `ArrowLeft`, `ArrowRight`, `ArrowUp`, `ArrowDown`, `Home`, `End`, `PageUp`, `PageDown`, `Insert`, `F1` to `F12`, `Shift`, `Control`, `Alt`, `Meta`.
- When a click or a key starts a navigation, the command returns once the new page has loaded.
- `set viewport <width> <height>` sets the window's size, 1280 by 720 at first. A browser jac starts draws no scrollbars, so a page is laid out across the whole window, and the same way in a screenshot of the window and in one of the whole page.
- An argument that begins with `-` and is not a number is read as an option. Write `--` before text that begins so: `jac browse fill '#q' -- --verbose`.

### Canvas and WebAssembly apps

An app that draws to a `<canvas>`, as a game compiled to WebAssembly does, has no elements inside the canvas: `snapshot` shows one `canvas`, with a ref, and nothing of what is drawn. Such an app is driven by coordinates and looked at as an image:

```sh
jac browse get box canvas          # {"x":8,"y":120,"width":960,"height":600}
jac browse mouse move 300 400      # a point of the window
jac browse mouse down
jac browse mouse up
jac browse focus canvas
jac browse keydown ArrowLeft       # held until keyup
jac browse keyup ArrowLeft
jac browse screenshot frame.png
jac browse eval 'Module.score()'   # what the app exposes to JavaScript
```

The headless shell draws WebGL in software, so a screenshot shows it on a machine with no GPU.

## Reading

| Command | Prints |
|---|---|
| `get title`, `get url` | The page's title; its address |
| `get text [<element>]` | The text a person would read: the element's, or the page's |
| `get html [<element>]` | The element's inner HTML, or the page's whole document |
| `get value <element>` | What a field holds |
| `get attr <element> <name>` | An attribute's value. One the element lacks is an error |
| `get count <selector>` | How many elements the selector matches |
| `get box <element>` | Its box in the window, as `{"x":…,"y":…,"width":…,"height":…}` |
| `is visible <element>`, `is enabled <element>`, `is checked <element>` | `true` or `false`. An element that is not in the page is `false` |
| `eval <javascript>` | The value of an expression in the page, a promise's once it settles: a string as it is, anything else as JSON, and nothing for `undefined`. An exception is an error |
| `screenshot [<file>] [--full]` | Writes the window as a PNG and prints the file's path: `<file>`, else a new file in the temporary directory. `--full` is the whole page |
| `pdf <file>` | Writes the page as a PDF |

`get` waits for its element as an action does, for it to be in the page; `is` answers at once.

## Waiting

`wait` returns when what it is given holds, and fails when the timeout passes first.

| Command | Waits until |
|---|---|
| `wait <element>` | The element is in the page and visible |
| `wait <milliseconds>` | That long has passed |
| `wait --text <text>` | The page's text contains `<text>` |
| `wait --url <pattern>` | The page's address matches, `*` standing for any run of characters |
| `wait --load <state>` | The page has reached `load`, `domcontentloaded` or `networkidle` (no request for half a second) |
| `wait --fn <javascript>` | The expression is true |

`--timeout <seconds>` on any command is how long it waits for what it needs. Without it an action or a `wait` gives up after 10 seconds, and a page's load after 30.

## Tabs, frames and dialogs

| Command | What it does |
|---|---|
| `tab` | Lists the tabs: its number, title and address each, `*` before the one commands act on |
| `tab new [<url>]` | Opens a tab, makes it the one commands act on, and opens `<url>` in it |
| `tab <number>` | Makes that tab the one commands act on |
| `tab close [<number>]` | Closes that tab, or the current one |
| `frame <element>` | Makes commands act in the document of that `iframe`, until `frame main` or a new page |
| `frame main` | Makes commands act in the page again |
| `dialog` | Prints the dialog that is open: its kind and its message |
| `dialog accept [<text>]` | Accepts it, answering a prompt with `<text>` |
| `dialog dismiss` | Dismisses it |

- A tab the page opens (a link with `target="_blank"`, `window.open`) is listed, and is not made current.
- A ref already says which frame its element is in, so `click @e34` needs no `frame`. `frame` is for selectors and `eval`.
- **An `alert`, `confirm` or `prompt` stops the page until it is answered.** The command that opened one says so and succeeds (`a dialog opened (confirm "Sure?"): answer it with …`), and until `dialog accept` or `dialog dismiss` every other command on that page is refused with the same instruction.

## What the page logged

| Command | Prints |
|---|---|
| `console` | What the page wrote to its console and what the browser reported about it, a line each, as `[log] …`, `[warning] …`, `[error] …` |
| `errors` | The exceptions nothing in the page caught, each with its stack |
| `network requests [--filter <text>]` | The requests the page made, as `<method> <status> <kind> <url>`, with why one failed; `--filter` keeps the URLs that contain `<text>` |

Each takes `--clear`, which forgets what was kept and prints nothing. A session keeps the last 2000 of each for a tab.

## Cookies, storage and saved state

| Command | What it does |
|---|---|
| `cookies` | Prints the page's cookies, each as a `Set-Cookie` line |
| `cookies set <name> <value>` | Sets one for the page's site. `--url <url>` or `--domain <domain>` names another site, and `--path`, `--expires <seconds since 1970>`, `--secure`, `--httponly` and `--samesite <Strict \| Lax \| None>` its attributes |
| `cookies clear` | Removes every cookie of the session |
| `storage local`, `storage session` | Prints the page's local or session storage as JSON |
| `storage local <key>` | Prints one item. One that is not there is an error |
| `storage local set <key> <value>`, `storage local clear` | Sets one item; removes all |
| `state save <file>` | Writes the session's cookies, and the local storage of each open page's site, as JSON |
| `state load <file>` | Sets the cookies of such a file, and gives each site its local storage: at once where a page of it is open, and otherwise as the first page of it loads, before the page's own code runs |

A saved state is what signs a later session in without its form: save it once after logging in. The file has the layout Playwright's `storageState` has.

## Errors

A command that fails prints `jac: browse: <why>` on stderr and exits with 1. One that succeeds exits with 0 and prints only what it was asked for: an action prints nothing. A mistake in the command line itself (a word that is no command, an argument missing) is answered with the form it is a mistake in.

## How a session is held

- **The host.** `open` starts `jac browse serve` in the background. It starts the browser, and answers each command over a socket in the session's directory, one at a time. `jac browse serve` run by hand is the same host in the foreground, which is how a container keeps a session as its main process.
- **The browser's connection.** The host speaks the DevTools protocol to the browser over a pipe the two share, not a network port: nothing else on the machine can reach it, and the browser exits when the host does. A browser given with `--cdp` is reached at the address given.
- **The session's directory** is `browse/<session>/` beside the build cache (`~/.cache/jac/browse/` on Linux, under `JAC_CACHE_DIR` when that is set): the socket, the browser's profile, and a log of what the browser and the host wrote. `close` removes them. A host that was killed leaves them, and the next `open` of that session, or `close --all`, clears them.

## What it leaves out

`jac browse` has the commands an agent needs to drive and check a page. It has no request interception, no device, location or media emulation, no recording, tracing or profiling, no clipboard, and no download handling.
