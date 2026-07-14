# Contrib and Codebase Guide

## Checkout and push ready

**Fork the Repository**

1. Navigate to [https://github.com/jaseci-labs/jaseci](https://github.com/jaseci-labs/jaseci)
2. Click the **Fork** button in the top-right corner
3. Select your GitHub account to create the fork

**Clone and Set Up Upstream**

After forking, clone your fork and set up the upstream remote:

```bash
# Clone your fork (replace YOUR_USERNAME with your GitHub username)
git clone https://github.com/YOUR_USERNAME/jaseci.git
cd jaseci
git remote add upstream https://github.com/jaseci-labs/jaseci.git
git remote -v
```

**Setting Up Your Dev Environment**

`jaclang` ships as the single `jac` binary (a Zig launcher + a private bundled CPython) -- there is no pip-installed jaclang. You build that binary once, then use the editable dev loop below so day-to-day edits to `jac/jaclang` run live without rebuilding.

**1. Install Zig**

The binary is built with [Zig](https://ziglang.org/) **0.16.0** (the version is pinned -- newer/older majors will fail to build). Zig plus a network connection are the only build-time deps: `launcher/payload.zig` does all the HTTP fetching, integrity checks, and (de)compression in Zig's std, so there's nothing else to install (the old `curl`/`git`/`zstd`/`tar` shellouts are gone).

```bash
# Zig: download the 0.16.0 tarball for your platform and put it on PATH
#   https://ziglang.org/download/
# (Most distro/Homebrew zig packages lag behind; prefer the official tarball.)
zig version          # must print 0.16.0
```

(One optional host tool: if `strip` is on PATH the build shrinks the bundled libpython from ~245 MiB to ~20 MiB; without it the build still succeeds, the binary is just larger.)

(The vendored typeshed stdlib stubs are not committed -- `zig build` fetches them at the pinned commit on first build, so there is nothing to check out manually.)

**2. Build the binary and set up plugins + pre-commit**

The bootstrap script builds the binary, puts it on PATH for the current shell, installs the plugins editable, and sets up pre-commit:

```bash
./scripts/fresh_env.sh
```

(It runs `cd jac && zig build` under the hood; the binary lands at `jac/zig-out/bin/jac`.) The script prints the line to add the binary to your PATH permanently, e.g.:

```bash
export PATH="$PWD/jac/zig-out/bin:$PATH"
```

**3. The editable dev loop (skip rebuilds for jaclang edits)**

Without help, a change to `jac/jaclang` would only take effect after another `zig build`, because the binary runs its own bundled copy of jaclang. This repo's root `jac.toml` points `jac` at the in-repo source so you don't have to rebuild per edit:

```toml
[dev]
jaclang_source = "jac"   # dir containing jaclang/, relative to this jac.toml
```

With this enabled, `import jaclang` resolves to `jac/jaclang` (it's prepended to `sys.path` at startup), so edits to jaclang's `.py` and `.jac` source -- the compiler, passes, CLI, runtime -- run live. The per-module compile cache is content-keyed, so edits self-invalidate; the dev loop also skips the binary's shipped precompiled bundle automatically (no manual cache clearing needed). Comment the stanza out to fall back to the binary's bundled jaclang.

**Faster builds: `zig build -Ddev`.** `fresh_env.sh` builds with `zig build -Ddev`, which *bakes* this link into the binary: the compiler is not bundled at all (no ~100 MB tree copy, no JIR precompile -- a much smaller, faster build), and the binary reroutes `import jaclang` to the build-root source from any directory, so the loop holds with no `[dev]` stanza in scope. It's the fastest build and the right default for compiler work; the tradeoff is the binary hard-depends on that source dir, so it's dev-only and not distributable. Use `-Djaclang-dir=PATH` to bake an explicit compiler dir, or a plain `zig build` for the fully self-contained release binary. Because the compiler imports the native passes at startup, a `-Ddev` binary still needs the LLVMPY_* shim **placed in the linked tree** (the same `zig build fetch-llvm` prerequisite as a release build -- `-Ddev` then compiles and places it automatically; without it the build stops with a clear message). `fresh_env.sh` runs `fetch-llvm` for you.

The stanza is read from the **nearest `jac.toml`** (like every other config setting), so it ships in *both* the repo root and `jac/jac.toml` (both pointing at the same source) -- the loop is active whether you work from the repo root or `cd jac` to run the suite. Other subprojects (`jac-byllm/`, `jac-mcp/`, ...) opt in by adding their own `[dev]` stanza. To force the loop *off* for a single command -- e.g. to test the shipped binary's bundled + precompiled jaclang instead of your edits -- set `JAC_NO_DEV_SOURCE=1` (CI's binary self-test does this).

You still need to `zig build` again when you change the parts that live *inside* the binary rather than in jaclang source: the launcher (`jac/launcher/*.zig`, `jac/build.zig`), the payload bootstrap (`jac/sitecustomize.py`, `jac/_jac_finder.py`), or the bundled CPython version.

**Run Some Tests**

Tests run through the binary's bundled test runner (pytest + xdist ship inside it -- no separate install). `JAC_TEST_JOBS=auto` runs them in parallel:

```bash
cd jac
JAC_TEST_JOBS=auto jac test tests
# See ci jobs in github actions for more stuff to run
```

The worker count can also be set persistently in `jac.toml` so you don't have to prefix every run -- the `JAC_TEST_JOBS` env var still overrides it when set:

```toml
[dev]
test_jobs = "auto"   # "auto" = one worker per core; "0" = serial; or a fixed count like "4"
```

**Build something awesome, or fix something that's broken**

See Rules below.
And check [`.pre-commit-config.yaml`](https://github.com/Jaseci-Labs/jaseci/blob/main/.pre-commit-config.yaml) to see our lint strategy.

**This is how we run the docs.**

```bash
pip install -e docs # <-- Not a real package more of a script
python docs/scripts/mkdocs_serve.py
```

**Pushing Your First PR**

1. **Create a branch, make changes, sync, and push**:

   ```bash
   git checkout -b your-feature-branch

   # Make your changes, then commit
   git add .
   git commit -m "Description of your changes"

   # Keep your fork synced with upstream
   git fetch upstream
   git merge upstream/main

   # Push to your fork
   git push origin your-feature-branch
   ```

2. **Create a Pull Request**:
   - Go to your fork on GitHub
   - Click **Compare & pull request**
   - Fill in the PR description with details about your changes
   - Submit the pull request to the `main` branch of `jaseci-labs/jaseci`

> **Tip: PR Best Practices**
>
> - Make sure all pre-commit checks pass before pushing
> - Run tests locally using the test script above
> - Keep your PR focused on a single feature or fix
> - Write clear commit messages and PR descriptions
> - Add a release note fragment (see below)

**Adding Release Notes**

Every PR that changes package code must include a release note fragment file:

1. Create a file at `docs/docs/community/release_notes/unreleased/<package>/<PR#>.<category>.md`
   - **Packages**: `jaclang`, `byllm`
   - **Note**: The Jac client and desktop runtimes, the `scale` deployment subsystem, and the MCP server are now part of `jaclang` core (under `jac/jaclang/runtimelib/client/`, `jac/jaclang/scale/`, and `jac/jaclang/cli/mcp/`); changes to them use the `jaclang` package fragment.
   - **Categories**: `feature`, `bugfix`, `breaking`, `refactor`, or `docs`
   - **Example**: `docs/docs/community/release_notes/unreleased/jaclang/1234.bugfix.md`

2. Add one or more bullet points:

   ```markdown
   - **Fix: Brief title**: Description of what changed.
   - **Fix: Another fix in same PR**: Description.
   ```

To skip this check, add the `skip-release-notes-check` label to your PR.

**Example PR with a release note fragment**: [#5573](https://github.com/jaseci-labs/jaseci/pull/5573)

## Code Rules and Guidelines

**Jac Style**

All Jac code must follow the project's established coding style. If you're using an AI assistant, prompt it to study the existing style before generating code. For example, when working in a specific area:

> "Can you study the jac coding style used in this code base (byllm/project folder), and make sure my change adheres to that style."

**No Scaffolding**

Never add code that only exists as scaffolding or infrastructure for future PRs. Every line in your PR should serve the change being made right now. The one exception is when two different authors have a producer-consumer dependency for a feature or fix and need to coordinate across PRs.

**Type Safety**

Write type-safe code. Avoid stringly-typed interfaces:

- Use **enums** instead of bare strings for option sets
- Create **named types or dataclasses** for complex return values instead of raw tuples like `-> tuple[str, str, dict, dict, dict]`

**Check for Bloat**

Before submitting, use an AI assistant to audit your diff for unnecessary code. A good prompt:

> "Can you look at the local changes to see if there is any bloat or inefficient implementation given what these changes are achieving."

**Issue Assignment**

Assignees on GitHub issues means the person is **committing to resolve** that issue, not that they "should" work on it. Keep as many issues unassigned as possible so contributors can pick them up.

**Documentation Updates**

The docs site has three tiers with different expectations for contributors:

- **Quick Guide** -- Get a quick experience with Jac. Most features don't need to touch this.
- **Full Reference** -- Must cover everything. **Every feature or change should update the reference docs.**

## Release Flow (for maintainers)

Releasing is a two-step process using GitHub Actions. `jaclang` ships as the
native `jac` binary -- built per platform and attached to the GitHub Release.
**Nothing is published to PyPI**: the `scale` subsystem, byLLM (`jaclang.byllm`),
the MCP server, and the client/desktop runtimes are all bundled into the binary.

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  Create Release PR  │ ─▶ │  Close & reopen PR  │ ─▶ │   Merge to main     │ ─▶ │  Approve & Release  │
│  (manual trigger)   │    │  (so CI runs) +     │    │  (auto-merge;       │    │  (one-click on the  │
│                     │    │  enable auto-merge  │    │  triggers publish)  │    │  release-approval   │
│                     │    │                     │    │                     │    │  environment)       │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### Step 1: Create the Release PR

1. Go to **GitHub Actions** -> **Release**
2. Click **Run workflow**, set `action` to `create-pr`, and pick the `jaclang` bump type (`patch`, `minor`, or `major`)
3. The workflow bumps the version in `jac/jac.toml` (the single source of truth) and opens a PR from a `release/*` branch
4. **Close and reopen the PR** to make CI run. The PR is authored by `github-actions[bot]`, and GitHub does not run `pull_request` checks for PRs opened by the `GITHUB_TOKEN` actor (workflows triggered by `GITHUB_TOKEN` can't trigger further workflows, to prevent recursion). Closing and reopening makes the reopen event come from *you* (a real user), so the PR checks run and attach. *(Permanent fix: author the PR with a GitHub App / PAT token instead.)*
5. Once the checks attach, enable **auto-merge** on the PR (or approve and merge manually when CI passes)

### Step 2: Approve the Release

After the release PR is merged, the **Release** workflow triggers automatically:

1. **Manual approval required** (only maintainers with `release-approval` environment access):
   - Go to **GitHub Actions** -> find the running **Release** workflow
   - Click the paused job, then **Review deployments**, select `release-approval`, and **Approve and deploy**
2. The workflow then handles everything automatically:
   - Tags `v<version>` at the merge commit and creates/updates the GitHub Release
   - Builds the native `jac` binary per platform (Linux x86_64 + aarch64 at a pinned glibc 2.17 floor, macOS arm64), smoke-tests each on real hardware, verifies the Linux glibc floors, and attaches the binaries + checksums to the Release

Every step is idempotent: re-running a partial release converges instead of erroring (existing tags are left in place, the release is updated in place, and asset uploads clobber).

### Troubleshooting

| Issue | Solution |
|-------|----------|
| CI checks not running / not showing on the release PR | Expected: GitHub skips `pull_request` checks for PRs opened by the `github-actions[bot]` / `GITHUB_TOKEN` actor. **Close and reopen the PR** so the reopen event comes from a real user, and the checks then run and attach. (A GitHub App / PAT token authoring the PR would remove this step.) |
| Auto-merge won't enable / PR won't merge | Auto-merge needs the PR's required status checks to be attached; do the close/reopen above first so the checks exist on the PR |
| Publish workflow didn't trigger | Ensure the PR branch started with `release/` |
| Binaries missing from the release | Re-run **Build jac native binaries** via `workflow_dispatch` with the release tag (e.g. `v0.30.4`); it rebuilds and re-attaches idempotently. An empty tag builds artifacts only (a dry run that attaches nothing) |
| Need to re-run after the release PR is merged | Manually trigger **Release** with `action: publish`; the version is re-read from `jac/jac.toml` |
