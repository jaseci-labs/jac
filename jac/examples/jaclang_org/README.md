# jaclang.org -- the official Jac website

The marketing site, docs reader, Ninja Leaderboard, and Socialize (a full
Twitter-style social app, Jacyak, living at `/socialize`) for the Jac
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
it. `GITHUB_TOKEN` only matters to the leaderboard's repo analysis.

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

The top level is split by **app**, and inside `web/` by **feature**. The
split is not client/server -- in Jac the codespace a declaration runs in is
inferred per-declaration, so no directory encodes it. It is *ownership*: a
module belongs to the app whose root contains it, and anything under no app
root is shared.

| Path | What it is |
|---|---|
| `jac.toml` | The workspace: `[apps.*]`, npm deps, shadcn theme, lint/test/gc config |
| `core/` | Shared domain and logic that belongs to no app: **no JSX, no DOM** |
| `core/social_graph.jac` | The whole Jacyak backend (profiles with uploaded avatars, posts, follows, channels, and projects that every user adds as GitHub repos and the Ninja Scores scorer grades on the way in); the `social_graph` **service app** is rooted at this file |
| `core/scoring_service.jac` | The repo scorer; the `scoring` **service app** is rooted at this file |
| `core/leaderboard/` | `board.jac` (graph, walkers, view models), `scoring.jac` (rubric), `format.jac` (belt labels) |
| `core/docs/` | `graph.jac` is the docs read model (schema + walkers), `sync.jac` the scheduled writer that ingests it |
| `core/source/files.jac` | The workspace-walking source browser backend |
| `core/{github,timefmt,progress,install,jac_tokenizer,async_utils,utils}.jac` | Tarball/API plumbing, timestamps, the job-progress protocol, the install script endpoint, the syntax highlighter, `sleep`, `cn()` |
| `core/socialize_mobile/` | The phone UI (`@jac/mobui` only): `SocializeMobile.jac` is the root component, `theme.jac` the tokens, `icon.jac` / `icon.native.jac` one icon API over two backends, `components/` and `screens/`; shared by the `mobile` app and the landing page's phone |
| `core/site/` | The site's UI, shared by the `web` and `desktop` apps: `landing/`, `docs/`, `leaderboard/`, `socialize/`, `source/`, `game/`, the jac-shadcn `ui/`, `examples/`, `styles/`, `assets/`, `scripts/` (each described below) |
| `web/` | The site (`kind = "web-app"`); `main.jac` is its entry: `app`, global CSS, and the imports that bring the web-owned endpoints into its program; `pages/` are thin re-exports into `core/site` |
| `desktop/` | The site as a desktop app (`kind = "desktop"`): the same `core/site` UI in an OS webview, backed by jaclang.org itself (`[apps.desktop.desktop] backend`); `main.jac` and `pages/` mirror `web/` |
| `web/pages/` | File-based routes -- thin re-exports into features |
| `core/site/landing/` | The marketing page: Hero, Showcase, Capabilities and friends; `MobileShowcase.jac` puts the live mobile app in a bezel; `diagrams/` holds the four animated SVG arguments |
| `core/site/docs/` | The docs reader: shell, sidebar, TOC rail, article, renderer |
| `core/site/leaderboard/` | Submit form, board, card, breakdown modal |
| `core/site/socialize/` | Jacyak embedded as a login-gated section: `Socialize.jac` + `components/`, `identity.jac` for handles and avatars |
| `core/site/source/` | The live source browser, code spotlights, and the floating window |
| `core/site/game/` | The rlgl shooter (`arena.jac`, owned/borrowed, zero-GC) and its WebGL host |
| `core/site/ui/` | jac-shadcn primitives (**registry-managed, import only**) plus the site chrome: Navbar, Footer, CodeBlock, GraphBackdrop, SectionRail |
| `core/site/examples/` | Real compiled Jac samples, runnable with `jac run` |
| `core/site/styles/`, `core/site/assets/`, `core/site/scripts/` | `global.css` is generated by `jac retheme`, `site.css` is hand-written; static assets; the OG-card generator |
| `mobile/` | The mobUI app (`kind = "mobile"`: native views through React Native); `main.jac` is a shell over `core/socialize_mobile/` |
| `cli/` | The command-line client (`kind = "cli"`) |

`core/` is the promotion destination for anything two apps share, and it is
also where every server-placed module lives that the web app *owns
implicitly*: `docs`, `leaderboard`, `source` and `install` reach the web
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
- **Across an app boundary** -- `core/leaderboard/board.jac` (owned by
  `web`) importing `fetch_and_score` from `core/scoring_service.jac` (the
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

Every endpoint returns a declared `obj`, and the client stores those types
directly (`has page: DocPageView | None`, `has entries: list[BoardEntry]`).
Nothing is hand-marshalled across the wire, so a server signature change lands
as a `jac check` diagnostic on the exact client line that went stale. Each
module owns its view models:

- `core/docs/graph.jac` -- `DocsStatus`, `DocTree`, `TreeNode`, `DocPageView`,
  `TocEntry`, `Crumb`, `PageRef`, `VersionInfo`
- `core/leaderboard/board.jac` -- `BoardView`, `BoardEntry`, `ScoreBreakdown`,
  `RepoFeatures`, `SubmitResult`, `BoardStatus`
- `core/scoring_service.jac` -- `ScoredPayload`, the wire type that crosses
  the `web` → `scoring` app boundary
- `core/progress.jac` -- `JobProgress` / `JobStep`, the live-narration
  protocol the leaderboard's scoring job reports through
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
(`core/site/socialize/fullstack.test.jac`) and the phone UI's format helpers
(`core/socialize_mobile/format.test.jac`) -- 63 tests -- plus the cli app's
16 (`cli/main.test.jac`, `cli/commands/*.test.jac`). `jac test cli` and
`jac test mobile` run only that app's tests: cli declares
`[apps.cli.test] directories = ["."]`, resolved against the app root, and
mobile points at `core/socialize_mobile`, the phone UI its shell wraps.

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
- **`core/` renders nothing.** No JSX, no DOM, no lucide. A module that needs
  a component belongs to the app that renders it.
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

That one line in `core/site/game/webgl_host.jac` is the whole wiring. Because the host
is client code and the target is native-anchored, the import IS the cl→na
edge: the client build compiles the module to `/static/arena.wasm`, binds
`init` to a generated stub that lazily instantiates the wasm on first call
(via `@jac/wasm_host`), and compiles to nothing on the server -- the same
import in a pure server module would still mean the ctypes crossing. Because arena declares app FFI, the host registers its WebGL
implementations first with `set_na_env("arena", sh, {"env": ...})`; an
FFI-free native module would need no ceremony at all.

Its memory story is the point: `[gc] default = "none"` builds it headerless --
no reference counting, no collector, static drops only -- and the build audits
the emitted IR for `__rc_*` machinery, so a wasm that re-entered the RC world
fails to build rather than shipping. The ownership checker's source-level
zero-RC contract (`[gc.enforce]`, E140x hard errors) ships disarmed until a
release carries jaseci-labs/jac#7732 -- the 0.34.x checker misfires E1401 on
arena's raylib extern decls; jac.toml says exactly when and how to re-arm
it. Entity pools are index arenas (parallel
scalar lists, the `own_rbtree` idiom) inside one `own Game` the browser holds
as an opaque handle; every update pass borrows it `&mut` down the call tree.
The same source also builds headlessly:

```bash
jac nacompile core/site/game/arena.jac --target wasm32 --enforce-nogc --gc none --assert-no-rc
```
