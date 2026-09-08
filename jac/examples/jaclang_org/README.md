# jaclang.org -- the official Jac website

The marketing site, docs reader, and JacYac with integrated Ninja Scores (a
Twitter-style social app at `/jacyac`) for the Jac
programming language, built end to end in Jac (naturally). One language spans all three
codespaces here: the pages and components compile to JavaScript, the
endpoints compile to Python and serve over RPC, and the game in
`core/site/game/arena.jac` compiles through LLVM to `/static/arena.wasm` -- fully
borrow-checked, with zero reference counting in the artifact.

It is also one **workspace**: a single type-checked repo whose `jac.toml`
declares six apps -- the `web` site, the same site as a `desktop` app, a mobUI
`mobile` app, a `cli`, and two file-rooted service apps (`social_graph`,
`scoring`) -- over one shared `core/` tree. The web, desktop, mobile and cli
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
and `scoring` load into the web server's process and bridged calls stay
in-process. `--fleet` (and every deploy) runs each service app as its own
process behind the gateway. Nothing in the source changes between the two;
the app boundary is structural and the topology is a profile.

Docs content comes from the binary. The docs corpus bundled with jaclang
-- the same one `jac guide` serves offline and `jac mcp` exposes as
`jac://docs/*` -- is read in-process through `jaclang.cli.guide_store` by a
scheduled in-server job (`core/docs/sync.jac`) and grown into the docs graph as
one version labelled after the running jac (`v0.37` for jac 0.37.1). No
clone, no network, no GitHub token. The graph is populated once: the job
fingerprints the corpus (version string plus every page and nav title), and
a restart whose persisted graph already carries that fingerprint does
nothing. Only a binary whose bundled docs differ triggers a rebuild, which
replaces the version in place. After its first pass the tick is a no-op for
the life of the process, so an edited docs tree under the `[dev]`
live-source stanza shows up on the next restart. `/docs/latest` is a
resolve-time alias for that version, which is also where `/docs` lands.
Requests never trigger a sync -- they only read whatever the job last
committed. Which docs the site shows is decided by which jac binary serves
it. `GITHUB_TOKEN` only matters to Ninja Scores repository analysis.

## Optional AI

Set `ANTHROPIC_API_KEY` in the server environment to enable the Sonnet 5
model configured in `jac.toml`. No credential belongs in the workspace.
The scoring service and CLI add an AI review with a summary, an evidenced
strength, and a suggested next step. The numeric score stays deterministic.
Web, desktop, mobile, and CLI reports show the review only when it succeeds.
Each review samples at most 6,000 characters across at most eight files and
allows 450 output tokens, a 12-second request timeout, and no retries.

The private `jacyac_genius` walker in `core/social_graph.jac` wakes at the
start of each UTC hour under Jac's scheduler (`0 * * * *`). It traverses
`GeniusMemory` → `GeniusTopic` → `Profile`, using `Studies` and `PublishesAs` edges. The topic
comes from a random section of the bundled Jac guide interface; one byLLM
call turns at most 2,400 characters into a fact. Successful runs publish
under **JacYac Genius** (`@jacyac_genius`), with a docs link. Find the profile
in Explore and follow it to include facts in your feed.
The memory node records the last successful post and guide, preventing
immediate repeats and duplicate posts within the same UTC hour. The topic
is reused, and the profile is created only after a fact succeeds. Fact generation has
a 120-token output cap, a 12-second timeout, and no retries. Missing keys,
provider errors, invalid output, and unavailable guides skip the optional
work; scoring and the site remain usable. The first scheduled run occurs
at the next UTC hour; keep the social graph service running for posts.

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
JAC_TEST_JOBS=0 jac test core/docs/graph.jac core/leaderboard/board.jac core/social_graph.test.jac
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
| `core/social_graph.jac` | The whole JacYac backend (profiles with uploaded avatars, posts, follows, channels, and projects that every user adds as GitHub repos and the Ninja Scores scorer grades on the way in); the `social_graph` **service app** is rooted at this file |
| `core/scoring_service.jac` | The repo scorer; the `scoring` **service app** is rooted at this file |
| `core/leaderboard/` | `board.jac` (legacy storage schema; `social_graph.jac` imports it into JacYac), `scoring.jac` (rubric), `format.jac` (belt labels) |
| `core/docs/` | `graph.jac` is the docs read model (schema + walkers), `sync.jac` the scheduled writer that ingests it |
| `core/source/files.jac` | The workspace-walking source browser backend |
| `core/{github,timefmt,progress,install,jac_tokenizer,async_utils,utils}.jac` | Tarball/API plumbing, timestamps, the job-progress protocol, the install script endpoint, the syntax highlighter, `sleep`, `cn()` |
| `core/jacyac/native/` | The phone UI (`@jac/mobui` only): `JacYacMobile.jac` is the root component, `theme.jac` the native style adapter over `core/brand` tokens, `icon.jac` / `icon.native.jac` one icon API over two backends, `components/` and `screens/`; shared by the `mobile` app and the landing page's phone |
| `core/site/` | The site's UI, shared by the `web` and `desktop` apps: `landing/`, `docs/`, `leaderboard/`, `jacyac/`, `source/`, `game/`, the jac-shadcn `ui/`, `examples/`, `styles/`, `assets/`, `scripts/` (each described below) |
| `web/` | The site (`kind = "web-app"`); `main.jac` is its entry: `app`, global CSS, and the imports that bring the web-owned endpoints into its program; `pages/` are thin re-exports into `core/site` |
| `desktop/` | The site as a desktop app (`kind = "desktop"`): the same `core/site` UI in an OS webview, backed by jaclang.org itself (`[apps.desktop.desktop] backend`); `main.jac` and `pages/` mirror `web/` |
| `web/pages/` | File-based routes -- thin re-exports into features |
| `core/site/landing/` | The marketing page: Hero, Showcase, Capabilities and friends; `MobileShowcase.jac` puts the live mobile app in a bezel; `diagrams/` holds the four animated SVG arguments |
| `core/site/docs/` | The docs reader: shell, sidebar, TOC rail, article, renderer |
| `core/site/leaderboard/` | Scoring methodology, reused inside JacYac |
| `core/site/jacyac/` | JacYac embedded as a login-gated section: `JacYac.jac` + `components/`, shared `core/jacyac/identity.jac` for handles and avatars |
| `core/site/source/` | The live source browser, code spotlights, and the floating window |
| `core/site/game/` | The rlgl shooter (`arena.jac`, owned/borrowed, zero-GC) and its WebGL host |
| `core/site/ui/` | jac-shadcn primitives (**registry-managed, import only**) plus the site chrome: Navbar, Footer, CodeBlock, GraphBackdrop, SectionRail |
| `core/site/examples/` | Real compiled Jac samples, runnable with `jac run` |
| `core/site/styles/`, `core/site/assets/`, `core/site/scripts/` | `global.css` is generated by `jac retheme`, `site.css` is hand-written; static assets; the OG-card generator |
| `mobile/` | The mobUI app (`kind = "mobile"`: native views through React Native); `main.jac` is a shell over `core/jacyac/native/` |
| `cli/` | The command-line client (`kind = "cli"`) |

`core/` is the promotion destination for anything two apps share, and it is
also where every server-placed module lives that the web app *owns
implicitly*: `docs`, `source` and `install` reach the web
server only through `web/main.jac`, so `web` is their single owner. The
social graph and the scorer are reached by more than one app, so they are
declared as apps of their own and own exactly their entry files.

Inside `web/`, features may depend on features -- `landing/Hero.jac` embeds
`source/FloatingSource.jac` -- and `Reveal` (nine consumers, every one of them
a landing section) and `CopyCommand` stay in `landing/` because nothing
outside it needs them.

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
  .scoring { RepoAnalysis }`.

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
  `core/docs/graph.jac`, `core/leaderboard/board.jac`,
  `core/social_graph.jac`: `def:pub`s and walkers bridge to RPC stubs, objs
  cross as wire types.
- **Across an app boundary** -- `core/social_graph.jac` (owned by
  `social_graph`) importing `fetch_and_score` from `core/scoring_service.jac` (the
  `scoring` app): the same plain import, classified as a service bridge. The
  stub is typed and async, so the call is `await fetch_and_score(...)` and a
  missing `await` is a type error, not a runtime surprise.
- **Native-anchored** (clib externs, ownership marks, or a dep that has
  them) -- `core/site/game/arena.jac` and friends: a client import takes the cl→na
  edge (wasm binding, `/static/arena.wasm`, nothing on the Python side);
  a server import stays the ctypes crossing.
- **Client-anchored** (JSX, npm string imports, browser globals) -- the
  components, `core/utils.jac`, `core/leaderboard/format.jac` (`Date`),
  `core/async_utils.jac` (`Promise`/`setTimeout`).
- **Unanchored pure logic** -- `core/jac_tokenizer.jac`,
  `core/site/landing/diagrams/motion.jac`: codespace-polymorphic, compiled into
  whichever side imports it; `def:pub` there means "exported", not
  "endpoint".

There are no placement markers anywhere in this tree: the `cl`/`sv`/`na`
prefixes and the `.cl.jac`/`.sv.jac`/`.na.jac` suffixes were retired, and
the only override an app can still express is a `[placement.pins]` entry
(or a per-app `[apps.<name>.placement.pins]` overlay) in `jac.toml`.

### Typed contracts, not dict payloads

Read models and scoring results use declared `obj`s, and the client stores those types
directly (`has page: DocPageView | None`, `has allProjects: list[Project]`).
Nothing is hand-marshalled across the wire, so a server signature change lands
as a `jac check` diagnostic on the exact client line that went stale. Each
module owns its view models:

- `core/docs/graph.jac` -- `DocsStatus`, `DocTree`, `TreeNode`, `DocPageView`,
  `TocEntry`, `Crumb`, `PageRef`, `VersionInfo`
- `core/leaderboard/scoring.jac` -- `ScoreBreakdown`, `RepoFeatures`
- `core/scoring_service.jac` -- `ScoredPayload`, the wire type that crosses
  the `social_graph` → `scoring` app boundary
- `core/github.jac` -- `RepoMeta` plus the shared tarball/API plumbing
- `core/source/files.jac` -- `SourceFile`, `SourceView`, `SourceSpan`
- `core/social_graph.jac` -- `ProfileBundle`, `ChannelBundle`, `TrendingTag`
  and the `Profile` / `Tweet` / `Channel` nodes every client app renders

Heading anchors are computed once, on the server (`core.docs.graph.slugify`),
and shipped in `DocPageView.toc`; the client renders them and never
re-derives a slug.

## Tests

A bare `jac test` targets the default app (`web`), whose `[test]
directories` lists `core`, `web`, `mobile` and `cli`, so it runs the whole
workspace: the pure logic on both sides of the wire -- the URL parser, repo
analyzer and scoring rubric (`core/leaderboard/*.test.jac`), the docs
slugifier, route rewriter, TOC builder and swap-commit protocol
(`core/docs/graph.test.jac`), the version label, link rewriter, corpus
fingerprint and once-only ingest (`core/docs/sync.test.jac`), the progress
protocol (`core/progress.test.jac`), the Jac syntax highlighter
(`core/jac_tokenizer.test.jac`), the social graph
(`core/social_graph.test.jac`) and its fullstack smoke
(`core/site/jacyac/fullstack.test.jac`) and the shared identity and validation helpers
(`core/jacyac/{format,validation}.test.jac`) plus the CLI app's tests in (`cli/main.test.jac`, `cli/commands/*.test.jac`). `jac test cli` and
`jac test mobile` run only that app's tests: cli declares
`[apps.cli.test] directories = ["."]`, resolved against the app root, and
mobile points at `core/jacyac`, the shared behavior and native views its shell wraps.

## The centerpiece diagrams

- **SynechicDiagram** -- three hand-synced programs (with unchecked JSON/FFI
  boundaries) vs one continuous `cl`/`sv`/`na` medium under one compiler.
- **TopokineticDiagram** -- data commuting to a stationary program vs a walker
  carrying computation through a persistent graph anchored at `root`.
- **PolypilerDiagram** -- PyPI/npm/C ABI flowing into the jac hexagon, Python
  bytecode/JavaScript/native·wasm flowing out.
- **GradualBorrowDiagram** -- opting a single declaration into ownership.

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
loading, mutations, profile editing, avatar caching, project scoring,
loading flags, and recoverable errors. Both renderers call this hook;
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

## GitHub sign-in and Ninja Scores

Ninja Scores lives at `/jacyac/scores`, inside both the web and native JacYac
navigation. It is public without signing in; submissions, removal, and
rescoring require the user's own JacYac account. `/leaderboard` redirects to
this directory. The social graph is the single source of project records,
including the full score breakdown. Old unowned leaderboard submissions are
imported once per repository under the clearly labeled `ninja_scores_archive`
profile on the system root. A current user submission takes precedence over
its archive copy in the public directory; historical data is retained.

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

GitHub buttons appear when both credentials are configured. Existing password
users select **Connect GitHub** from Ninja Scores; new users can choose
**Continue with GitHub**. Account associations use GitHub's immutable user ID,
never an editable profile handle or a matching email. The repository picker
lists public repositories owned by that verified identity. Adding a URL is
also supported: it records the submitter, and only a server-verified owner
gets an ownership badge. Private repositories are rejected even if a server
`GITHUB_TOKEN` can access them.

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
