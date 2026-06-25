# GitHub Actions workflows

Workflows are grouped by purpose with a consistent prefix:

- **`ci-*`** - runs on pull requests / pushes to `main` (the test surface)
- **`release-*` / `publish-release` / `create-release-pr`** - releasing & publishing
- **`ops-*`** - scheduled / operational (docs deploy, nightly smokes)

## CI (pull requests)

| Workflow | `name:` | Purpose | Gates merge? |
|---|---|---|---|
| `ci-core.yml` | CI · core (binary) | Build the `jac` binary once, run the full jaclang suite through it (`test-compiler` + `test-runtime`) | **should** - see note |
| `ci-plugins.yml` | CI · plugins | Plugin / client / docs / desktop / macOS / CEF / scale matrices | partially (`test-client`) |
| `ci-packaging.yml` | CI · packaging smokes | Wheel builds + jacpack (jac-gpt / Algo) + fullstack-eject smoke servers | no |
| `ci-typecheck.yml` | CI · typecheck | `jac format --check` + `jac check` + jir-registry verify (`jac-check`) | **yes** (`jac-check`) |
| `ci-quality.yml` | CI · quality gates | AI-attribution block, no-`.py` block, docs build, release-notes check (`Contribution Checks`) | **yes** (`Contribution Checks`) |
| `ci-e2e-k8s.yml` | CI · k8s e2e | Real microk8s deploy e2e (path-gated to `jac/**`, `jac-scale/**`) | no |
| `ci-installer.yml` | CI · installer | `scripts/install.sh` download-and-run (path-gated) | no |

External required check: **`pre-commit.ci - pr`** (the pre-commit.ci app, not a workflow file).

> **Required-checks note.** Branch protection currently requires only
> `pre-commit.ci - pr`, `test-client`, `jac-check`, `Contribution Checks`. The
> core jaclang suite (`test-compiler`, `test-runtime` in `ci-core.yml`) is the
> real correctness gate but is **not** yet a required check - adding it is a
> separate repo-settings change tracked alongside this reorg.

The required-check **contexts are job IDs / job names** (`test-client`,
`jac-check`, `Contribution Checks`), not file names - so these workflows can be
renamed without breaking branch protection as long as those job identifiers stay
stable.

## Release & publish

| Workflow | Trigger | Purpose |
|---|---|---|
| `create-release-pr.yml` | manual dispatch | Open a `release/*` PR with version bumps |
| `publish-release.yml` | release/* PR merged, or dispatch | Tiered PyPI publish (jac-byllm / jac-scale / jac-mcp), npm, GitHub Release. The release engine. |
| `release-jaclang.yml` | release published, or dispatch | Build + attach the native `jac` binaries |
| `release-github.yml` | manual dispatch | Escape hatch: cut a `vX.Y.Z` GitHub Release directly (fires `release-jaclang.yml`) |

> Per-plugin publishing is handled entirely by `publish-release.yml` (including a
> manual `workflow_dispatch` with `jac-byllm` / `jac-scale` / `jac-mcp` toggles,
> routed through the `pypi` approval environment). The old standalone
> `release-byllm.yml` / `release-scale.yml` / `release-mcp.yml` were removed as
> redundant - use the `publish-release` dispatch instead.

## Ops (scheduled)

| Workflow | Trigger | Purpose |
|---|---|---|
| `ops-deploy-docs.yml` | release, push to `docs/**`, daily cron, dispatch | Build + deploy jac-lang.org |
| `ops-cef-smoke.yml` | daily cron, dispatch | Headless CEF desktop smoke |

## A note on "ghost" workflows in the Actions tab

The Actions tab may list workflows that **no longer have a file** here - e.g.
old TUI / mobile / desktop / VSCE entries, and the previous names of any
renamed workflow above (`test-jaseci.yml`, `jac-check.yml`, …). GitHub keeps a
deleted/renamed workflow listed with its historical runs; it does **not** run
and does **not** gate anything. These age out of the UI on their own. If the
clutter is bothersome they can be hidden, but there is nothing to fix in-repo.
