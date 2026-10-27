# jaclang.org -- the official Jac website

The marketing site, versioned docs reader, and JacYac (a Twitter-style social
app at `/jacyac`) for the Jac programming language, built end to end in Jac (naturally). One language spans all three
codespaces here: the pages and components compile to JavaScript, the
endpoints compile to Python and serve over RPC, and the game in
`core/site/game/arena.jac` compiles through LLVM to `/static/arena.wasm` -- fully
borrow-checked, with zero reference counting in the artifact.

It is also one **workspace**: a single type-checked repo whose `jac.toml`
declares six apps -- the `web` site, the same site as a `desktop` app, a mobUI
`mobile` app, a `cli`, and two file-rooted service apps (`social_graph`,
`knowledge`) -- over one shared `core/` tree. The web, desktop, mobile and cli
apps all consume the same social graph by importing it.

Built on jac-shadcn (nova style, orange accent, Geist). Dark-first with a
light-mode toggle. Visual-first: animated SVG diagrams drawn on scroll with
`motion`, a hand-rolled Jac syntax highlighter, an animated node/edge/walker
constellation, and a self-typing terminal.

## Run it

```bash
jac install               # first run: pulls npm deps
jac run web               # serves the site on http://localhost:8000
jac run                   # same: [project] default-app = "web"
jac run --dev web         # hot-reload dev loop
jac run mobile            # the mobUI app (React Native, built for its platform)
jac run desktop           # the site in an OS webview, talking to jaclang.org
jac run cli -- --help     # the command-line client
jac run --serve --fleet web   # service apps as their own local processes
```

Under plain `jac run` the two service apps are **colocated**: `social_graph`
and `knowledge` load into the web server's process and bridged calls stay
in-process. `--fleet` (and every deploy) runs each service app as its own
process behind the gateway. Nothing in the source changes between the two;
the app boundary is structural and the topology is a profile.

The docs reader holds three release lines. The newest is the docs corpus
bundled with the jac binary serving the site -- the same one `jac guide`
serves offline and `jac mcp` exposes as `jac://docs/*` -- read in-process
through `jaclang.cli.guide_store` and labelled after the running jac (`v0.38`
for jac 0.38.0). `/docs/latest` is a resolve-time alias for it, which is also
where `/docs` lands. The two lines before it come from the `knowledge`
service app (`core/knowledge_service.jac`), which keeps one clone of
`jaseci-labs/jac` per deployment:

- **One clone, made at startup.** A scheduled tick (`knowledge_repo_tick`)
  clones the repo treeless (`--filter=tree:0`) with a sparse checkout of the
  docs, the guides and the examples: seconds and a few megabytes. One process
  holds an exclusive file lock while it clones or fetches; every process reads
  the status file it writes. A restart with the clone already on disk runs
  `git fetch --tags` instead, at most once an hour. Everything is git
  protocol, so there are no REST API calls and no rate limit to manage.
- **Older lines come from git objects.** For each of the two minor lines
  below the serving release, the newest patch tag's docs are exported through a
  throwaway index (`git --work-tree=<dir> checkout <tag> -- <docs>`), so the
  checked-out tree never moves. The serving release's tag is what stays
  checked out, for anything that reads the tree.
- **The docs sync stays the only writer.** `docs_sync_tick`
  (`core/docs/sync.jac`, owned by `web`) ingests the bundled corpus, then asks
  the knowledge service which release lines it holds (`release_doc_lines`) and
  pulls any whose fingerprint differs (`release_docs`). Each version is
  fingerprinted (version string plus every page and nav title), so a restart
  whose graph already holds those fingerprints changes nothing. Versions that
  fall out of the window are retired. Until the clone is ready the site serves
  the bundled version alone.

Requests never trigger a sync -- they only read whatever the job last
committed. The clone lives under `.jac/data/knowledge` (`JACORG_KNOWLEDGE_DIR`
moves it; `JACORG_REPO_URL` points it at another repo). Without `git` on the
server the knowledge service reports `unavailable` and the docs keep the
bundled version.

## Accounts

Every account registers with a username and an email address
(`[serve.auth.identifiers] username = "required"`, `email = "required"`). The
username is the public JacYac handle; the email stays private and can be used
in place of the username to log in. After a login the client reads the
account's username from `/user/me`, so signing in with the email still shows
the username. Email addresses are not verified (`[serve.auth.email]` keeps its
default `verification = "none"`).

## Registration verification

Password registration uses a built-in SHA-256 proof-of-work challenge. The
client solves it locally before submitting the form; no third-party service
or API key is involved. Challenges expire after five minutes and are consumed
once, before account creation. Verification is enforced on `/user/register`,
including direct API requests. A failed or expired challenge requires a fresh
attempt. Verified GitHub OAuth account creation is exempt; a client cannot
claim an SSO exemption through the password registration endpoint.

This workspace enables the check with `[serve.auth.registration] challenge = true`.
Other Jac projects retain their existing registration behavior by default.
The existing shared authentication token store provides replay protection
across workers. `jacSignup` performs the check automatically on web, desktop, and mobile.

## Optional AI

Set `ANTHROPIC_API_KEY` in the server environment to enable the Sonnet 5.5
model configured in `jac.toml`. No credential belongs in the workspace.
ninjaclaw is the only feature that uses it.

### ninjaclaw

ninjaclaw answers Jac questions on JacYac. Mention `@ninjaclaw` in a post or a
reply, or post anything in the `#help` channel it owns, and it replies with a
link to a tutorial or a docs page that answers the question. Posts that are
off topic or not about Jac are ignored. Everything it does is public at
`/jacyac/ninjaclaw`, and every reply links to its own job page there.

The work is split across the two service apps:

- **The desk** (`ninjaclaw_desk` in `core/social_graph.jac`, every 15 s) owns
  the `@ninjaclaw` profile and `#help`, scans for new asks (posts, replies and
  `#help` posts newer than the desk), submits them to the knowledge service,
  and posts each finished reply as a comment. Asks are limited per user
  (`NINJACLAW_ASKS_PER_HOUR`, default 3).
- **The worker** (`ninjaclaw_work_tick` in `core/knowledge_service.jac`, every
  5 s) claims one queued job and hands it to a background runner
  (`core/ninjaclaw/runner.jac`), so model calls never hold a database
  transaction open; the next tick records the outcome. Jobs and tutorials live
  in `core/ninjaclaw/graph.jac`, readable by anyone; a daily budget
  (`NINJACLAW_DAILY_JOBS`, default 200) caps the work.
- **A job** classifies the post (`core/ninjaclaw/brain.jac`), retrieves
  candidate tutorials and docs sections from the serving release's checkout
  (`core/ninjaclaw/index.jac`, BM25 over `##` sections), and asks the model
  whether one answers it. A confident match is linked. A failed attempt is
  retried once.
- **When nothing answers**, the job writes a short tutorial
  (`write_tutorial` in `core/ninjaclaw/brain.jac`). The model can search and
  read the checkout's docs, guides and examples through the tools in
  `core/ninjaclaw/tools.jac`, which cannot read anything else. Every ` ```jac `
  block is then verified on the serving jac (`core/ninjaclaw/verify.jac`): it
  must pass `jac check`, and a block with `with entry` that touches no server
  or model feature must also `jac run`. Each block runs in a fresh temporary
  project with a scratch `HOME`, CPU and memory limits, and, on Linux, no
  network (`unshare -rn`). Failures go back to the model for up to two
  repairs. A tutorial whose examples all pass is published under
  `/jacyac/tutorials`; one that never passes becomes a docs gap instead.

Upkeep runs on its own tick (`ninjaclaw_upkeep_tick`, every 60 s, background
work in `core/ninjaclaw/upkeep.jac`):

- **Re-verification.** When the serving jac version changes, every tutorial
  not yet verified on it is re-run. Passing tutorials are marked verified on
  the new version; failing ones are marked stale, drop out of answers, and
  are written afresh the next time someone asks.
- **Docs PRs** (`core/ninjaclaw/promote.jac`) are off unless
  `NINJACLAW_DOCS_REPO` (`owner/repo`) and `NINJACLAW_GITHUB_TOKEN` are set;
  `NINJACLAW_DOCS_FORK` pushes the branch to a fork, and
  `NINJACLAW_DOCS_DRY_RUN=1` only reports what it would do. A tutorial
  qualifies once `NINJACLAW_PROMOTE_ASKERS` distinct people (default 3) were
  sent to it, it is `NINJACLAW_PROMOTE_AGE_DAYS` old (default 7), and it is
  verified on the serving jac. The PR adds the page under
  `docs/tutorials/jacyac/`, a nav entry and a release fragment. Only one PR
  is open at a time, its state is checked hourly, and a tutorial whose PR was
  closed without merging is never proposed again.

The submit and collect calls between the apps carry a shared secret
(`NINJACLAW_SERVICE_SECRET`, or a generated file under the knowledge
directory when the apps share a host). ninjaclaw is off when
`ANTHROPIC_API_KEY` is unset or `NINJACLAW_ENABLED=0`, and warming up until
the jac repo clone is ready; the activity view says which.

## Checks

The gates to run before committing, from the workspace root:

```bash
git ls-files -z '*.jac' | xargs -0 jac fmt --check --lintfix   # format + deslop autolint
jac check --nowarn                                             # the workspace gate
JAC_TEST_JOBS=0 jac test                                       # [test] directories = core, web, mobile, cli
```

`jac check` with no paths is the workspace gate: it type-checks every app as
its own rooted program (prefixing diagnostics with `[web]`, `[mobile]`, ...
when more than one app is checked) and then sweeps `core/` for anything no
app reaches. `jac check --app web` restricts it to one app. `jac precommit
--install` wires the first two as a git hook. To run one module's tests:

```bash
JAC_TEST_JOBS=0 jac test core/docs/graph.jac core/knowledge/repo.jac core/social_graph.test.jac
```

## Layout

The top level is split by **app**, and inside the shared UI trees by **feature**. The
split is not client/server -- in Jac the codespace a declaration runs in is
inferred per-declaration, so no directory encodes it. It is *ownership*: a
module belongs to the app whose root contains it, and anything under no app
root is shared.

| Path | What it is |
|---|---|
| `jac.toml` | The workspace: `[apps.*]`, npm deps, shadcn theme, lint/test/gc config |
| `core/` | Shared modules outside app roots: domain, client behavior, branding, and explicitly named UI trees |
| `core/social_graph.jac` | The whole JacYac backend (profiles with uploaded avatars, posts, follows, channels); the `social_graph` **service app** is rooted at this file |
| `core/knowledge_service.jac` | The repo clone's endpoints and schedule; the `knowledge` **service app** is rooted at this file |
| `core/knowledge/` | `repo.jac`, the one clone of the jac repo: clone, fetch, the serving checkout and older-line docs exports |
| `core/docs/` | `graph.jac` is the docs read model (schema + walkers), `sync.jac` the scheduled writer that ingests it, `corpus.jac` the bundle a docs tree reads into (shared with the knowledge service) |
| `core/source/files.jac` | The workspace-walking source browser backend |
| `core/{github,timefmt,progress,install,jac_tokenizer,async_utils,utils}.jac` | GitHub API plumbing, timestamps, the job-progress protocol, the install script endpoint, the syntax highlighter, `sleep`, `cn()` |
| `core/jacyac/native/` | The phone UI (`@jac/mobui` only): `JacYacMobile.jac` is the root component, `theme.jac` the native style adapter over `core/brand` tokens, `icon.jac` / `icon.native.jac` one icon API over two backends, `components/` and `screens/`; shared by the `mobile` app and the landing page's phone |
| `core/site/` | The site's UI, shared by the `web` and `desktop` apps: `landing/`, `docs/`, `jacyac/`, `source/`, `game/`, the jac-shadcn `ui/`, `examples/`, `styles/`, `assets/`, `scripts/` (each described below) |
| `web.jac` | The site's entry (`[apps.web]`, `kind = "web-app"`): the global CSS and `app`, the layout wrapper the routes in `pages/` render inside; the wires that bring the web-owned endpoints into its program land here |
| `desktop.jac` | The site as a desktop app (`kind = "desktop"`): the same entry as `web.jac` over the same `pages/`, so the same `core/site` UI in an OS webview, backed by jaclang.org itself (`[apps.desktop.desktop] backend`) |
| `pages/` | File-based routes -- thin re-exports into `core/site`. `web` and `desktop` are both rooted at the workspace, so this one tree serves both apps |
| `core/site/landing/` | The tech demo page (`TechDemo.jac`): the WebAssembly arena, the live mobile app in a bezel (`MobileShowcase.jac`), agents, the book and the source explorer, plus the Wait, Wuuut?! page |
| `core/site/docs/` | The docs reader: shell, sidebar, TOC rail, article, renderer |
| `core/site/jacyac/` | JacYac embedded as a login-gated section: `JacYac.jac` + `components/`, shared `core/jacyac/identity.jac` for handles and avatars |
| `core/site/source/` | The live source browser, code spotlights, and the floating window |
| `core/site/game/` | The rlgl shooter (`arena.jac`, owned/borrowed, zero-GC) and its WebGL host |
| `core/site/ui/` | jac-shadcn primitives (**registry-managed, import only**) plus the site chrome: Navbar, Footer, CodeBlock, GraphBackdrop, SectionRail |
| `core/site/examples/` | Real compiled Jac samples, runnable with `jac run` |
| `core/site/styles/`, `core/site/assets/`, `core/site/scripts/` | `global.css` is generated by `jac retheme`, `site.css` is hand-written; static assets; the OG-card generator |
| `mobile/` | The mobUI app (`kind = "mobile"`: native views through React Native); `main.jac` is a shell over `core/jacyac/native/`. It keeps its own folder because a client app rooted beside `pages/` compiles those routes in, and the site's DOM pages are not mobUI |
| `cli.jac` | The command-line client (`kind = "cli"`), with its tests in `cli.test.jac` |

`core/` is the promotion destination for anything two apps share, and it is
also where every server-placed module lives that the web app *owns
implicitly*: `docs`, `source` and `install` reach the web
server only through `web.jac`, so `web` is their single owner. The
social graph and the knowledge service are reached by more than one app, so
they are declared as apps of their own and own exactly their entry files.

Inside `core/site/`, features may depend on features -- `landing/WaitWuuut.jac`
embeds `source/FloatingSource.jac` -- and `Reveal` and `CopyCommand` stay in
`landing/` even though `home/` uses them too, because nothing outside the site
needs them.

### Import forms

Two rules, and neither is stylistic:

- **Across directories, use the absolute form from the workspace root.**
  `import from core.docs.graph { doc_page }`, `import from web.ui.button {
  Button }`, `import from core.social_graph { load_feed }`. It resolves the
  same way under `jac run`, `jac test <file>` and the client bundler (which
  emits a file-relative specifier from the resolved path), and it reads as
  what it is: an app reaching into shared code, or a feature reaching a
  sibling feature.
- **Within a directory, use the sibling form.** `import from .Reveal {
  Reveal }`, `import from .components.AuthForm { AuthForm }`, `import from
  .corpus { DocBundle }`.

The one exception is `core/site/ui/`'s registry-managed primitives, which keep the
`import from ...core.utils { cn }` form `jac install --shadcn` writes for
this layout (`[jac-shadcn] components_dir` / `utils_path` pin it). Impl
annexes (`impl/<name>.impl.jac`) resolve imports exactly like their decl
file.

### Where the codespaces are

Nowhere in the source. Placement is inferred per declaration, and every
import is a plain `import` -- the compiler classifies each module by its
anchors and takes the right edge:

- **Server-anchored** (Python imports, nodes/edges/walkers, `::py::`) --
  `core/docs/graph.jac`, `core/knowledge/repo.jac`,
  `core/social_graph.jac`: `def:pub`s and walkers bridge to RPC stubs, objs
  cross as wire types.
- **Across an app boundary** -- `core/docs/sync.jac` (owned by `web`)
  importing `release_doc_lines` from `core/knowledge_service.jac` (the
  `knowledge` app): the same plain import, classified as a service bridge. The
  stub is typed and async, so the call is `await release_doc_lines()` and a
  missing `await` is a type error, not a runtime surprise.
- **Native-anchored** (clib externs, ownership marks, or a dep that has
  them) -- `core/site/game/arena.jac` and friends: a client import takes the cl→na
  edge (wasm binding, `/static/arena.wasm`, nothing on the Python side);
  a server import stays the ctypes crossing.
- **Client-anchored** (JSX, npm string imports, browser globals) -- the
  components, `core/utils.jac`, `core/async_utils.jac` (`Promise`/`setTimeout`).
- **Unanchored pure logic** -- `core/jac_tokenizer.jac`: codespace-polymorphic,
  compiled into whichever side imports it; `def:pub` there means "exported", not
  "endpoint".

There are no placement markers anywhere in this tree: the `cl`/`sv`/`na`
prefixes and the `.cl.jac`/`.sv.jac`/`.na.jac` suffixes were retired, and
the only override an app can still express is a `[placement.pins]` entry
(or a per-app `[apps.<name>.placement.pins]` overlay) in `jac.toml`.

### Typed contracts, not dict payloads

Read models use declared `obj`s, and the client stores those types
directly (`has page: DocPageView | None`, `has tweets: list[Tweet]`).
Nothing is hand-marshalled across the wire, so a server signature change lands
as a `jac check` diagnostic on the exact client line that went stale. Each
module owns its view models:

- `core/docs/graph.jac` -- `DocsStatus`, `DocTree`, `TreeNode`, `DocPageView`,
  `TocEntry`, `Crumb`, `PageRef`, `VersionInfo`
- `core/docs/corpus.jac` -- `DocBundle`, `NavEntry`, the docs tree a version
  is built from
- `core/knowledge_service.jac` -- `ReleaseLines`, `ReleaseDocsInfo`, the wire
  types that cross the `web` → `knowledge` app boundary
- `core/knowledge/repo.jac` -- `RepoStatus`, `ReleaseLine`
- `core/source/files.jac` -- `SourceFile`, `SourceView`, `SourceSpan`
- `core/social_graph.jac` -- `ProfileBundle`, `ChannelBundle`, `TrendingTag`
  and the `Profile` / `Tweet` / `Channel` nodes every client app renders

Heading anchors are computed once, on the server (`core.docs.graph.slugify`),
and shipped in `DocPageView.toc`; the client renders them and never
re-derives a slug.

## Tests

A bare `jac test` targets the default app (`web`), whose `[test]
directories` lists `core`, `web`, `mobile` and `cli`, so it runs the whole
workspace: the pure logic on both sides of the wire -- the docs
slugifier, route rewriter, TOC builder and swap-commit protocol
(`core/docs/graph.test.jac`), the version label, link rewriter, corpus
fingerprint and per-version ingest (`core/docs/sync.test.jac`), the clone
manager against a local fixture repo (`core/knowledge/repo.test.jac`), the progress
protocol (`core/progress.test.jac`), the Jac syntax highlighter
(`core/jac_tokenizer.test.jac`), the social graph
(`core/social_graph.test.jac`) and its fullstack smoke
(`core/site/jacyac/fullstack.test.jac`) and the shared identity and validation helpers
(`core/jacyac/{format,validation}.test.jac`) plus the CLI app's tests in `cli.test.jac`. `jac test cli` and
`jac test mobile` run only that app's tests: cli declares
`[apps.cli.test] directories = []`, so it runs just its entry file and that
annex instead of inheriting the workspace list, and mobile points at
`core/jacyac`, the shared behavior and native views its shell wraps.

## The CLI app: jacorg

The `cli` app of the workspace (`[apps.cli]`, `kind = "cli"`, entry
`cli.jac`). It is a client of the site: `jacorg docs`, `jacorg feed` and
`jacorg post` import server-placed elements that belong to other apps -- the
docs graph the `web` app owns, the walkers the `social_graph` service app
owns. Per the workspace rules a CLI never touches another app's store: those
imports compile to typed async stubs, the call is an `await`, and a failure
arrives as one of the `BridgeError` family from `jaclang.server.bridge`.
Nothing in the source says so; they are plain `import from core... { ... }`
lines, and the compiler classifies each by the owner of what is imported.

### Run it

From the workspace root:

```bash
jac run cli -- --help
jac run cli -- docs status                      # needs the site: jac run web
jac run cli -- docs sync
jac run cli -- feed --limit 5 --search "#jac"
jac run cli -- post "hello from the cli"
```

Everything after `--` is the program's own argv (`argparse`, subcommands).

### Commands

| Command | Flavor | What it does |
|---|---|---|
| `docs status` | client of `web` | `await docs_status()` -- which docs versions the site's graph holds. |
| `docs sync` | client of `web` | `await docs_sync_tick()` then `status`. The tick is the same scheduled job the server runs: it ingests the bundled corpus and the knowledge service's release lines whose fingerprints the graph does not already carry. |
| `feed [--limit N] [--search TEXT]` | client of `social_graph` | `await (root spawn load_feed(search_query=...))` and prints `.reports[0]` -- the same walker and the same report shape the web and mobile UIs read. |
| `post "<text>"` | client of `social_graph` | `await (root spawn create_tweet(content=...))`; prints the tweet the walker reports. |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | done |
| 1 | the command ran and failed (a bridged call returned a server error) |
| 2 | usage (argparse) |
| 3 | `BridgeUnavailable`: the owning app is not reachable -- start the site with `jac run web` |
| 4 | `BridgeTimeout` |
| 5 | `BridgeRejected`: the site refused the call (typically: the command needs a signed-in identity) |

Bridged commands print a one-line reason and a hint on stderr; stdout stays
clean for piping.

### Identity

`feed` and `post` are per-user walkers (`load_feed` walks from the caller's
root, `create_tweet` needs a `Profile` under it). Which identity a bridged
call carries is the bridge runtime's business, not this app's: the CLI
passes nothing. Set `JAC_BRIDGE_TOKEN` to a token the site issued (`POST
/user/login` on the `web` app) and every bridged call goes out with
`Authorization: Bearer <token>`; a program can also install one itself with
`sv_client.set_bearer_token(token)` (`import from jaclang.server {
sv_client }`) before its first bridged call. Without a token the CLI runs as
a fresh identity: it sees an empty feed and cannot post until `/socialize`
has created its profile. A `BridgeRejected` here means the site wanted a
signed-in user.

### Tests

`jac test cli` runs `cli.test.jac`, the annex beside `cli.jac`: the argument
parser, the posting-quota message, and the exit-code mapping for bridge
failures. None of them touch the network or a
server; the bridged commands are exercised against a running site by hand.

## The mobile app

The React Native face of JacYac. `mobile/main.jac` renders
`core/jacyac/native/JacYacMobile.jac`, which is also embedded on the website.
Both it and the web renderer consume `core/jacyac/state.jac` and
`core/jacyac/session.jac`; graph operations and error handling are shared.

The UI uses `@jac/mobui` primitives, native styles, the shared JacYac SVG,
real uploaded avatars (initials when absent), and the same light/dark
palette as web. Theme changes propagate to the live phone embed. Native
fonts load through Expo Font from the configured Jac backend. The native
bio editor uses the shared profile update operation, including clearing a bio.

```bash
jac install
jac run web
jac setup mobile
jac run --dev mobile
jac run --dev --platform web mobile
jac build mobile --platform android
jac build mobile --platform ios
jac test mobile
```

The web preview uses React Native Web; it is not a native-device test.
`core/jacyac/native/icon.native.jac` selects native icons while the default
variant uses browser icons. `core/brand/font.native.jac` loads the same
Geist font asset used by web. See the sections above for shared ownership,
brand generation, and validation commands.

GitHub sign-in opens the system browser through Expo WebBrowser. Jac Scale
completes the provider callback, and the initiating device redeems the result
using its private, expiring polling secret. No GitHub client secret is bundled
into the app, and no custom URL scheme is required. Configure the backend's
GitHub OAuth credentials and callback as described under GitHub sign-in below.
A physical device needs a reachable HTTPS backend rather than the development
loopback URL. Browser previews use the web PKCE flow instead.

## House rules

- **Comments and docstrings do not survive.** `[check.lint]` selects the deslop
  rules, so `jac fmt --lintfix`, `jac precommit`, and CI strip them from every
  non-excluded `.jac`. Explanation belongs in commit messages, `AGENTS.md`,
  or this README. The exclude list is short and each entry says
  why it is there.
- **Never edit the shadcn primitives in `core/site/ui/`.** Fixes belong upstream in
  the jac-shadcn template; a local patch is a fork that silently diverges.
  The hand-written chrome beside them (Navbar, Footer, CodeBlock,
  GraphBackdrop, SectionRail) is ours.
- **Shared ownership is explicit.** `core/jacyac/{session,state,identity,validation}` contains shared behavior, `core/brand` contains design tokens and assets, `core/site` contains web/desktop views, and `core/jacyac/native` contains React Native views also embedded by web. Keep DOM and device APIs in their renderers; domain modules render nothing.
- **Content is anchored** to the monorepo README, *the twelve claims*, the
  `this_is_jac` showcase, and the fundamentals book ("the ninja book").
  House style: "discontinuities", not "seams"; "the first…", not "the only…".

## The game module

`core/site/game/arena.jac` carries no marker at all; the compiler classifies it native
by its anchors (raylib externs in `platform_rl`, `own`/`&mut` throughout),
and the browser host reaches it with a plain import:

```jac
import from .arena { init }
```

The compiler generates typed Wasm calls from the native declarations, including
scalar conversions and opaque ownership handles. The application imports `init`,
`frame`, the score/health accessors, and `shutdown` normally. It supplies Jac's
reusable `@jac/webgl` host with `bind_na_host(init, host)`; host methods are checked
against the native import declarations. Module instantiation and host-import
registration belong to `@jac/wasm_host`.

Production client bundles include `/static/boundaries.json`. This audit records
qualified endpoint identities, placements, callers, value shapes, native ownership
contracts, host requirements, and effect assumptions. The compiler retains these
records in cached client artifacts so they survive release of its syntax trees.
Unknown effects disable endpoint caching; explicit effect declarations are
reported as assumptions, not inferred guarantees.

The game's `[memory]` enforcement remains declared in `jac.toml`. Entity pools
are index arenas inside an owned `Game`; update passes borrow it mutably, and
`shutdown` consumes its browser handle.

The same source also builds headlessly:

```bash
jac build --native core/site/game/arena.jac --target-triple wasm32 --memory nogc
```

## JacYac: shared behavior, native rendering

`/jacyac` is the canonical social route; `/socialize` remains an inbound
compatibility route. Web navigation and all product copy use **JacYac**.

`core/jacyac/session.jac` owns login, signup, session storage migration, and
logout. `state.jac` exposes a typed `JacYacState` from `useJacYac`: graph
loading, mutations, profile editing, avatar caching, loading flags, and
recoverable errors. Both renderers call this hook;
neither maintains a second copy of the graph operations. The web renderer
owns browser image resizing. The native renderer owns keyboard handling,
native views, and its compact bio form. `identity.jac` centralizes names and
avatar lookup; `validation.jac` is pure logic consumed by both clients and
the social service. Read refreshes are safe to repeat; failed mutations are
never automatically replayed, and post drafts clear only after success.

`core/brand/tokens.jac` is the shared palette, spacing, radius, and type
scale. `core/brand/theme.jac` shares the live light/dark preference across
web chrome and the embedded phone. `core/brand/logo.jac` owns the SVG artwork.
Regenerate the web artifacts after editing tokens or artwork:

```bash
jac run core/brand/styles.jac
```

This writes `core/site/styles/brand.css` and the web logo asset; it does not
patch registry-managed shadcn primitives. Native views translate the same
palette into React Native styles. Geist is vendored with its OFL license;
web loads it through CSS and the native font variant loads it from the
configured backend through Expo Font.

`react-native-web` is a workspace dependency because web and desktop also
render the live native phone. `react-native-svg` stays in the mobile native
overlay: the default BrandMark variant uses an image and its native variant
uses SvgXml, both consuming the same artwork. The embedded phone is the actual mobile UI.

## GitHub sign-in

Register a GitHub OAuth app and configure its callback as
`http://127.0.0.1:8095/jacyac/github/callback` locally, or
`https://jaclang.org/jacyac/github/callback` in production. Use separate OAuth
registrations for those environments. Set these server environment variables
(or place them in the ignored `.env` file):

```dotenv
SSO_HOST=http://127.0.0.1:8095
SSO_GITHUB_CLIENT_ID=your_client_id
SSO_GITHUB_CLIENT_SECRET=your_client_secret
```

GitHub buttons appear when both credentials are configured; new users can
choose **Continue with GitHub**. Account associations use GitHub's immutable
user ID, never an editable profile handle or a matching email.

Ninja Scores (repo scoring) and the leaderboard were retired with the
knowledge service; `/leaderboard` and `/jacyac/scores` redirect to `/jacyac`.
Persisted project and score records belong to types that no longer exist, so
the store quarantines them on load instead of deleting them; `jac db
quarantine list` shows them and `jac db` can still recover them.

`core/jacyac/github/auth.jac` is an application configuration/RPC facade over
Jac Scale's `OAuthSession`. Scale owns PKCE, expiring single-use state,
provider identity resolution, explicit account linking, and native handoff.
Provider access tokens and client secrets never enter the client bundle.
Web keeps the PKCE verifier in session storage and removes callback parameters
before completing the exchange. Native opens the system browser and redeems
a short-lived, single-use result with a separate random polling secret; no
custom deep-link scheme is required. Use a device-reachable `SSO_HOST` and
backend address for native testing (a phone's loopback address is not your
computer). Production callback addresses must use HTTPS.

Registration throttling is configured in `[serve.auth]`: password registration
allows 5 attempts per IP per hour (`registration_attempts_per_hour`), and
challenge issuance allows 20 requests per IP per 10 minutes
(`registration_challenges_per_10_minutes`). Rejections return HTTP 429 with
`Retry-After`. The server uses its resolved client IP; configure trusted proxies
when deploying behind a reverse proxy. Verified GitHub SSO bypasses these
password-registration checks.

Posts, comments, and channel posts share an account quota: 1 per 10 seconds and
50 per 24-hour window starting with the first accepted submission. Server
environment variables `JACYAC_POSTS_PER_WINDOW`, `JACYAC_POST_WINDOW_SECONDS`,
and `JACYAC_POSTS_PER_DAY` override these defaults. The 280-character maximum
still applies. GitHub users have the same posting quota; ninjaclaw's replies
are exempt. Rejected submissions show the remaining wait and keep the draft.
Counters use atomic updates in the existing database and persist across workers
and restarts. If that database is unavailable, limited actions are temporarily
rejected. No external CAPTCHA or rate-limiting service is needed.
