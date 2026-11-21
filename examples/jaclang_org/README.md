# jaclang.org

The Jac website: the marketing site, the versioned docs reader, the packages
index, and JacYac (a social app at `/jacyac`, with ninjaclaw, its help agent).
It is one Jac project built by jac, and it is jac's working example of
spaces and apps.

## Run it

```bash
jac build web         # the site and its server: dist/web-<platform>
dist/web-linux-x86_64    # http://127.0.0.1:8000
```

`jac run web` does both, and builds only what changed since the last time: with nothing
changed it starts at once. `jac dev web` is for working on the site: it serves the pages
through Vite's dev server at the same address, compiles a page's space again as you save, and
starts the server again when the backend changes. The server's data lives in `.jac/data/web`. When that data no longer
fits the program (a node type renamed, a field added without a default), the server says which
and stops; `jac run web --fresh` sets the data aside, in a dated directory beside it, and starts
empty.

The site's stylesheet is Tailwind's, told where the site's markup is (`@source` in
`eco/web/global.css`: the pages, `core/site`, `core/demo`), so only a change there
is a change to the stylesheet. Left to find its own sources Tailwind reads every file in the
project, and a change to the backend would bundle the site again.

| Variable | What it does |
|---|---|
| `JAC_WEB_LISTEN` | The address to listen on (`127.0.0.1:8000`) |
| `JAC_WEB_DATA` | Where the graph and the accounts are kept |
| `JAC_FRESH` | `1` starts with no data, setting aside what `.jac/data/web` held (what `--fresh` sets) |
| `JAC_WEB_STATIC` | Where the built site is, when not at its build path |
| `JAC_WEB_DOCS` | Where jac's `docs/` tree is, when not at its path in this checkout; the docs are labelled with the version in the `VERSION` file beside it (a release's), else in the `jac.toml` beside it (a checkout's) |
| `JAC_TICKS_OFF` | Scheduled work to skip: names with commas, or `all` |
| `ANTHROPIC_API_KEY` | Turns ninjaclaw on. No credential belongs in the repo |
| `JAC_LLM_MODEL` | Overrides `[llm] model` in `jac.toml` |
| `NINJACLAW_ENABLED` | `0` turns ninjaclaw off |
| `NINJACLAW_ASKS_PER_HOUR` | Each person's limit (3) |
| `NINJACLAW_DAILY_JOBS` | The daily budget (200) |
| `JAC_DEPLOY_KEY` | What lets one of this program's apps call another's untagged functions |
| `JACYAC_POSTS_PER_WINDOW`, `JACYAC_POST_WINDOW_SECONDS`, `JACYAC_POSTS_PER_DAY` | The posting quota (1 per 10 s, 50 a day) |

## Spaces and apps

`archwire.jac` groups the modules into layers and says where everything runs:

```jac
graph layers {
    layer cli { cli; }
    layer core { core.*; }
    layer demos { demos.*; }
    layer mobile { mobile.*; }
    layer pages { pages.*; }
    """What no wire joins to the rest."""
    layer apart { web; }
}

graph spaces {
    space site: browser { entry web; pages.* | core.site.*; }
    space phone: hermes { entry mobile.main; }
    space arena: wasm { core.site.game.arena | core.site.game.sim | ...; }
    space site_api: native { core.docs.graph | core.source.* | ...; }
    space social: native { core.social_graph | core.jacyac.limits; }
    space knowledge: native { core.knowledge_service | core.knowledge.* | core.ninjaclaw.*; }
    space cli: native { entry cli; }
    space demo_preact: browser { entry demos.preact; }
    space demo_solid: browser { entry demos.solid; }

    app web { run site_api, social, knowledge; serve site, arena, demo_preact, demo_solid; }
    app desktop { run site, arena, demo_preact, demo_solid; }
    app mobile { run phone; }
    app cli { run cli; }
}
```

A module belongs to the space whose most specific pattern matches it. One no
space holds (`core.model.*`, `core.brand.*`, ...) is compiled into each space that
reaches it. A `++>` wire whose ends are in different spaces is a crossing, and
nothing else about it changes: the page imports `create_tweet` from
`core.social_graph` the way it imports anything else.

Only functions and walkers cross, and their types live in modules no space holds. An
access tag says who may call one: none means this program, `:protect` a signed-in
caller, `:pub` anyone. A browser or hermes space calling something untagged is a
compile error (E1210), and so is a tag in a module no space holds (E1211).

What each host's spaces become:

- **browser:** ES modules with their JSX kept, built by the space's bundler, Vite by default
  through `@jac/vite`, with the project's own `vite.config.ts`, run in the space's npm tree
  (`eco/web`). The npm ecosystem works as usual.
- **wasm:** `static/<space>.wasm`, a WASI reactor loaded on the first call, with the
  host the page bound.
- **native:** one binary. The build generates a program under `.jac/build/<app>/`
  with typed encoders and decoders for every `obj`, `node` and `edge`, a route for
  every endpoint with its tag's check, and a tick for every `@schedule` function.

Each caller has their own `root` in a space, `root.shared` is everyone's, and an
anonymous caller starts at `root.shared`. `root spawn W()` starts at the root of
`W`'s space. The graph commits after every call, to SQLite by default
(the `store` abstraction's standard plugin).

The modules name abstractions and no mechanism: `root` for what is kept, `:protect` and
`sign_in()` for who is calling, `by llm()` for the model, `@job` for work too long for the
server's event loop. What carries each out is a plugin `jac.toml` binds (`jac docs plugins`):
here the standard ones, `sqlite`, `accounts`, `anthropic` and `process_jobs`, with their settings
in `[auth.accounts]` and `[llm.anthropic]`.

## UI libraries

The compiler knows what a component means, and no library. `has` is a reactive value, a value
derived from it stays current, and a component's body can't depend on how many times it runs.
A space's `ui` plugin picks the library (`[spaces.<space>.ui] plugin = "preact"` in `jac.toml`):
one jac ships, or a plugin package of the project's own, and each host has a standard one. Its
model is `rerender`, `fine-grained` or `none`, under which `has` in a function is an error and the
library's functions are ordinary imports.

`/tech_demo` runs `core/demo/Playground.jac`, which names no library, on React, Preact and Solid.
Preact and Solid are spaces of their own, `demo_preact` and `demo_solid`, each with its own Vite
config in `demos/`. The phone on that page is React Native.

## The docs

`/docs` reads jac's documentation, the Markdown tree at the repository's `docs/` that
`jac docs` prints too. Its `nav.json` is the reader's tree: the sidebar, the breadcrumb above
a page, the order of reading and `/llms.txt` all show its sections, nested and ordered as it has
them, and a page it doesn't name goes in a last section, "Other pages". A page is served at its
file's path (`/docs/latest/language/walkers` for `language/walkers.md`), wherever its section
puts it, and its front matter gives its description. `docs_sync_tick` (`core/docs/sync`)
reads the tree on its first tick after the server starts, then every ten minutes (every 30 s
while it fails). When the tree has changed, it grows it into the graph under `root.shared` as a
`DocVersion` labelled with jac's version series (`v0.2` for `[project] version = "0.2.6"` in
the root `jac.toml`), and tears down every other version. `/llms.txt` is the map of the same
pages, for agents.

## ninjaclaw

Mention `@ninjaclaw` in a post or a reply, or post in `#help`, and it replies with
a page that answers the question. Everything it does is public at
`/jacyac/ninjaclaw`.

- **The desk** (`ninjaclaw_desk_tick`, every 15 s) scans for new asks, limits them per
  person, submits them, and posts each finished reply as a comment.
- **The worker** (`ninjaclaw_work_tick`, every 5 s) claims one queued job and starts it
  as the `run_question` job. Its steps show live, and a failed attempt is retried once.
- **A job** classifies the post, retrieves tutorials and docs sections (BM25 over the
  jac repo's serving release), and asks the model whether one answers it.
- **When nothing does**, it writes a tutorial with tools that can read only the repo's
  docs, guides and examples. Every ` ```jac ` block must pass on the serving `jac`, in
  a sandbox with no network, with up to two repairs. A tutorial that passes is published
  at `/jacyac/tutorials`; one that doesn't becomes a logged docs gap.

The jac repo is cloned by the `refresh_repo` job, so a first run shows "warming up"
until it's done. Verification needs a `jac` on `PATH`. Docs PRs from popular tutorials
stay off unless `NINJACLAW_DOCS_REPO` and `NINJACLAW_GITHUB_TOKEN` are set.

## Accounts

Signing in is the `accounts` plugin's, its form included: a page calls `sign_in()`, and no
module of the project holds a form, a password rule or an OAuth callback. An account has a
username and an email (`[auth.accounts] email_required`). The username is the public handle, and
either logs in. GitHub sign-in is offered where the app runs with a GitHub OAuth app's
`SSO_GITHUB_CLIENT_ID` and `SSO_GITHUB_CLIENT_SECRET`; the OAuth app's callback is
`<the site>/__jac/auth/github`, and `JAC_AUTH_ORIGIN` says where the site is when the OAuth app
registers another. An account made through GitHub is called by its login there.

## Layout

| Path | What it is |
|---|---|
| `archwire.jac` | Spaces, apps, and every wire between modules |
| `jac.toml` | `[llm]`, `[memory]`, each app's deployment values, and the npm packages of the two trees, `[npm.web]` and `[npm.mobile]` |
| `jac.lock` | What npm resolved for each tree |
| `eco/web/` | The browser spaces' tooling: `vite.config.ts`, `index.html`, `tsconfig.json`, `components.json`, and `global.css`, Tailwind's stylesheet. jac writes the tree's `package.json` and `package-lock.json` here from `jac.toml` and `jac.lock`, and `jac install` its `node_modules`; none of the three is tracked |
| `eco/mobile/` | The phone app's tree, made by `jac install`: nothing in it is written by hand |
| `web.jac`, `pages/` | The site's entry and its pages: a page's route is its path, and its `page` function's parameters (`*slug: str`) name the dynamic parts |
| `core/model/` | The types that cross between spaces |
| `core/social_graph.jac` | JacYac's backend |
| `core/knowledge_service.jac`, `core/knowledge/`, `core/ninjaclaw/` | The repo clone and ninjaclaw |
| `core/docs/`, `core/source/`, `core/packages/` | The docs, source browser and packages backends |
| `core/jacyac/` | JacYac's behavior, shared by both UIs; `native/` is the phone's |
| `core/site/` | The site's UI: `landing/`, `docs/`, `jacyac/`, `source/`, `game/`, `ui/` |
| `core/brand/` | The shared palette, type scale and artwork |
| `mobile/`, `cli.jac` | The phone app and the command-line client |

## The game

`core/site/game/arena.jac` compiles through LLVM to `/static/arena.wasm`. The page
imports `init`, `frame`, the accessors and `shutdown` like anything else, and gives the
space its WebGL host with `bind_na_host(init, host)`. Its modules are held to the nogc
contract by `[memory] enforce` in `jac.toml`: entity pools are index arenas inside an
owned `Game`, and `RenderView` is a view that lends the renderer just what drawing needs.

## House rules

- **Never edit the shadcn primitives in `core/site/ui/`.** The hand-written chrome
  beside them (Navbar, Footer, CodeBlock, GraphBackdrop, SectionRail) is ours.
- **Shared behavior stays in `core/jacyac/`.** Both renderers call `state.jac`'s
  `useJacYac`; neither keeps its own copy of the graph operations.
- **House style:** "discontinuities", not "seams"; "the first…", not "the only…".

## The other apps

`jac build <app>` builds any of them, and `jac build` builds all of them, once `jac install`
has installed the project's packages. A space's npm packages are those of its tree (`npm` under its
`[spaces.<space>]` in `jac.toml`): `web` for the site and the demos, `mobile` for the phone app.
`jac install --npm <package> --tree web` adds one.

| App | What it is | Try it |
|---|---|---|
| `cli` | The command-line client: a native program, 3.6 MB | `dist/cli-linux-x86_64 docs status` |
| `desktop` | The site in a window, through WebKitGTK on Linux. It reaches the site's spaces through a loopback server of its own. macOS and Windows say they aren't built yet | `dist/desktop-linux-x86_64` |
| `mobile` | The phone app's Hermes bundles for Android and iOS, in `dist/mobile`, through Expo and Metro. An `.apk` or `.ipa` needs the platform's SDK, with `expo run:android` or `expo run:ios` in `.jac/build/mobile` | `jac build mobile` |

`jac build --profile fleet` builds `web` and `knowledge` as two processes.
`jac build desktop --profile offline` builds the whole site and its backend into the window's
app, with its own graph and accounts. A space an app doesn't run is reached at its URL in `[apps.<app>.remote]`, or
`JAC_REMOTE_<SPACE>`, and a served space reaches it through its app. Both sides need the same
`JAC_DEPLOY_KEY` for what's untagged. `JAC_REMOTE_TOKEN` is who `cli` calls as: a token from
`POST /__jac/auth/login`.

```bash
JAC_REMOTE_SOCIAL=http://127.0.0.1:8000 JAC_REMOTE_SITE_API=http://127.0.0.1:8000 \
    dist/cli-linux-x86_64 docs status
```
