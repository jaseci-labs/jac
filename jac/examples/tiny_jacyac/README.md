# Tiny JacYac

Imported from [marsninja/tiny_jacyac](https://github.com/marsninja/tiny_jacyac)
at commit `df87b2c1241e9865acf8eb970418df8c0603ad52`.
Scaffold your own copy with `jac create mysocial --awetiny`.

A small social app in fewer than 1,000 physical lines of Jac and `jac.toml`,
including tests, blank lines, and styles. Six apps share one product:
web, React Native mobile, native desktop host, CLI, feed service, scoring service.
The shared mobUI screen supports registration, sign-in, posting, likes, deletion,
and reputation. Posts persist on the shared graph; only their authors can delete them.

## Screenshots

One community across four clients. These captures show the running app with
sample posts shared between the web, mobile, desktop, and CLI clients.

### Web · desktop browser

The two-column layout at **1440 × 1000**, with the composer, feed, and reputation.

![Web client showing the shared feed and 23 reputation points](docs/screenshots/web-desktop.png)

### Web · tablet browser

The same web client adapts to a single column at **768 × 1024**.

<img src="docs/screenshots/web-tablet.png" alt="Tablet-sized web client with the composer above the feed" width="560">

### Mobile · native Android

The **React Native Android app**, captured directly from a Pixel 5 emulator
running Android 11 at **1080 × 2340**. These captures use the debug APK with
Metro and the shared backend. The two views show composing a post, then the
feed and reputation.

| Compose | Feed and reputation |
| --- | --- |
| <img src="docs/screenshots/mobile-android-compose.png" alt="Native Android app showing the post composer" width="320"> | <img src="docs/screenshots/mobile-android-feed.png" alt="Native Android app showing a shared post, owner-only deletion, and 23 reputation points" width="320"> |

### Native desktop · Linux

The packaged **1200 × 800** WebKitGTK window, showing the shared feed and sign-in.

![Native Linux desktop client displaying the community feed](docs/screenshots/desktop.png)

### CLI · terminal

The CLI reads the same posts and reputation from the two services.

![Terminal running jac run cli to display the feed and 23 reputation points](docs/screenshots/cli.png)

## How it fits

The three graphical clients import one responsive mobUI component. The CLI uses
the same typed feed API; the feed calls the stateless scoring service. Jac supplies
authentication, graph persistence, transport, and generated platform packaging.
The four client entry points are `web.jac`, `mobile.jac`, `desktop.jac`, and
`cli.jac` at the project root; shared code and the two services live in `core/`.

| Authored files | Physical lines |
| --- | ---: |
| Shared UI and styles | 535 |
| Feed and scoring services | 170 |
| CLI | 116 |
| Web, mobile, desktop entry points | 19 |
| Tests | 66 |
| `jac.toml` | 51 |
| **Total** | **957** |

Reproduce the count with `wc -l jac.toml *.jac core/*.jac`.
Documentation, dependencies, compiler/runtime code, and generated platform files
are outside this application-source count. Local compatibility checks use Jac
`0.37.18`. The project uses the installed Jac binary without a compiler-source
override. Web fleet routing and authentication are exercised against that binary.
The desktop entry includes a `with entry` block with a `None;` no-op so the packaged host has
the bootstrap artifact expected by the current desktop runtime.
The original desktop captures used a generator fix with explicitly typed port
values so the native host includes the port number in its navigation URL.
The original native Android captures additionally used a local Jac runtime fix that
exports `useJacState` and `jacSetToken`; both are required to render the shared
screen and sign in. Native Android and iOS execution must be validated separately
from the mobile browser preview on the installed runtime.

## Run

From this project directory, using the locally installed Jac binary:

```bash
jac install
jac run --serve --fleet web
```

Open http://localhost:8000. Create an account in the UI. Use `--fleet` for this
example: it runs the two services in separate processes and mounts their
authentication endpoints behind the web gateway.
Accounts live in the feed service, using its built-in `/api/feed/user/*` endpoints.
Scoring is stateless: 10 points per post plus 3 per received like.
If scoring is unavailable, the feed remains usable and labels the missing score.

## Other clients

```bash
jac run cli -- login alice       # prompts for the password
jac run cli -- post "Hello from my terminal"
jac run cli -- feed              # prints post IDs for like/delete
jac run cli -- score
jac run cli -- logout
jac run desktop
jac run --dev mobile
```

The CLI stores a token in `~/.tiny-jacyac.json` with owner-only permissions.
`TINY_JACYAC_SESSION` selects another session file. `TINY_JACYAC_URL` selects
the backend for CLI and desktop; CLI also accepts `--url` before its command.
Mobile asks for a server address: use your computer's LAN address on a phone,
or `http://10.0.2.2:8000` in the Android emulator during development.
The packaged Android release uses Android's default network policy and needs an
HTTPS backend; its JavaScript is embedded, so it does not need Metro.
Start the web fleet first.
All clients connect to the same feed, accounts, and scores.

```bash
jac build web
jac build desktop
jac build --platform web mobile       # browser preview of the mobile entry
jac build --platform android mobile   # Android APK; provisions native tooling
jac build --platform ios mobile       # requires macOS and Xcode
```

Desktop uses an OS webview in a compiled native host. The feed and scoring
services execute on the server. No standalone LLVM scoring executable is included.
To work on the compiler itself, add `[dev].jaclang_source` pointing to an existing
Jac source directory. Ordinary application use does not require a source checkout.

## Validate

```bash
jac check --nowarn
JAC_TEST_JOBS=0 jac test
jac fmt . --check
jac browse open http://localhost:8000
jac browse snapshot
jac browse fill '[aria-label="Username"]' alice
jac browse fill '[aria-label="Password"]' your-password
jac browse click '[aria-label="Sign in"]'
jac browse console
```

The tests cover account impersonation, unauthorized writes/deletion, post length,
like/unlike, scoring thresholds, and the line limit. Build output, dependency
trees, local credentials, and screenshots under `.jac/` are generated artifacts.
