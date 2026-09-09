# jacorg -- the command-line face of jaclang.org

The `cli` app of the workspace (`[apps.cli]`, `kind = "cli"`, entry
`cli/main.jac`). It exists to show the two things a command-line app in a
Jac workspace can be, side by side, over the same shared `core/`:

- **Offline, in-process.** `jacorg score` imports the pure rubric
  (`core.leaderboard.scoring`) and the tarball plumbing (`core.github`) and
  scores a GitHub repo right here. No server, no site, nothing bridged.
- **A client of the site.** `jacorg docs`, `jacorg feed` and `jacorg post`
  import server-placed elements that belong to other apps -- the docs graph
  the `web` app owns, the walkers the `social_graph` service app owns. Per
  the workspace rules a CLI never touches another app's store: those imports
  compile to typed async stubs, the call is an `await`, and a failure
  arrives as one of the `BridgeError` family from `jaclang.server.bridge`.

Nothing in the source says which is which. Both flavors are plain
`import from core... { ... }` lines; the compiler classifies each by the
owner of what is imported.

## Run it

From the workspace root:

```bash
jac run cli -- --help
jac run cli -- score jaseci-labs/jac            # offline, prints the breakdown
jac run cli -- score jaseci-labs/jac --json     # same, as JSON on stdout
jac run cli -- docs status                      # needs the site: jac run web
jac run cli -- docs sync
jac run cli -- feed --limit 5 --search "#jac"
jac run cli -- post "hello from the cli"
```

Everything after `--` is the program's own argv (`argparse`, subcommands).

## Commands

| Command | Flavor | What it does |
|---|---|---|
| `score <owner/name \| github url> [--json]` | offline | Fetches the default-branch tarball, runs `analyze` + `score`, prints the belt, the four category totals and every rubric line. `--json` prints the same breakdown as JSON and keeps stderr quiet. `GITHUB_TOKEN` raises the API rate limit. |
| `docs status` | client of `web` | `await docs_status()` -- which docs versions the site's graph holds. |
| `docs sync` | client of `web` | `await docs_sync_tick()` then `status`. The tick is the same scheduled job the server runs: it ingests the bundled corpus only if the graph does not already carry that fingerprint. |
| `feed [--limit N] [--search TEXT]` | client of `social_graph` | `await (root spawn load_feed(search_query=...))` and prints `.reports[0]` -- the same walker and the same report shape the web and mobile UIs read. |
| `post "<text>"` | client of `social_graph` | `await (root spawn create_tweet(content=...))`; prints the tweet the walker reports. |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | done |
| 1 | the command ran and failed (repo not found, not a Jac repo, a bridged call returned a server error) |
| 2 | usage (argparse), or a repo reference that is not `owner/name` / a github.com URL |
| 3 | `BridgeUnavailable`: the owning app is not reachable -- start the site with `jac run web` |
| 4 | `BridgeTimeout` |
| 5 | `BridgeRejected`: the site refused the call (typically: the command needs a signed-in identity) |

Bridged commands print a one-line reason and a hint on stderr; stdout stays
clean for piping.

## Identity

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

## Layout

| Path | What it is |
|---|---|
| `main.jac` | `argparse` subcommands -> `Invocation` -> `dispatch`; `async def main(argv) -> int`; `with entry:__main__ { sys.exit(asyncio.run(main(sys.argv[1:]))); }`. The `__main__` guard is what lets `main.test.jac` load the module without running it. |
| `commands/score.jac` | The offline scorer: `parse_repo_ref`, `score_repo` (the exact pipeline `core/scoring_service.jac` runs), `as_dict`, `render`, `run_score` |
| `commands/docs.jac` | `run_docs`: bridges to `docs_sync_tick` / `docs_status` (owned by `web`) |
| `commands/feed.jac` | `run_feed`, `run_post`: bridges to the `social_graph` walkers; `FeedLine` is the CLI's own view of a reported tweet |
| `commands/common.jac` | Exit codes and `explain_bridge_error`; endpoint consumers use declared record fields |

## Tests

`jac test cli` (the app's `[apps.cli.test] directories = ["."]`), or the
workspace-wide `jac test` (whose `[test] directories` lists `cli`), runs
the annexes beside each module: the argument parser
(`main.test.jac`), the repo-reference parser, JSON shape and renderer of the
scorer (`commands/score.test.jac`), and the field readers and exit-code
mapping (`commands/common.test.jac`). None of them touch the network or a
server; the bridged commands are exercised against a running site by hand.
