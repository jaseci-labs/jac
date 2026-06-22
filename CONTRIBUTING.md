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
git submodule update --init --recursive
git remote add upstream https://github.com/jaseci-labs/jaseci.git
git remote -v
```

**Setting Up Your Dev Envrionment**

`jaclang` ships as the single `jac` binary (a Zig launcher + bundled CPython) -- there is no pip-installed jaclang. The bootstrap script builds the binary, puts it on PATH, installs the plugins editable, and sets up pre-commit:

```bash
./scripts/fresh_env.sh
```

This needs [Zig](https://ziglang.org/) 0.16.0 + `zstd`, and the typeshed submodule checked out (`git submodule update --init --recursive`). The script prints the line to add the binary to your PATH permanently, e.g.:

```bash
export PATH="$PWD/jac/zig-out/bin:$PATH"
```

**Run Some Tests**

Tests run through the binary's bundled test runner (pytest + xdist ship inside it -- no separate install). `JAC_TEST_JOBS=auto` runs them in parallel:

```bash
cd jac
JAC_TEST_JOBS=auto jac test tests
# See ci jobs in github actions for more stuff to run
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
   - **Packages**: `jaclang`, `byllm`, `jac-scale`, `jac-mcp`
   - **Note**: The Jac client and desktop runtimes are now part of `jaclang` core (under `jac/jaclang/runtimelib/client/`); changes to them use the `jaclang` package fragment.
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

Releasing new versions is a two-step process using GitHub Actions. `jaclang` ships as the native `jac` binary (built and attached to the GitHub Release; it is **no longer published to PyPI**), while the plugins (`byllm`, `jac-scale`, `jac-mcp`) still publish to PyPI.

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│  Create Release PR  │ ─▶ │  Close & reopen PR  │ ─▶ │   Merge to main     │ ─▶ │  Approve & Publish  │
│  (manual trigger)   │    │  (so CI runs) +     │    │  (auto-merge;       │    │  (one-click on the  │
│                     │    │  enable auto-merge  │    │  triggers publish)  │    │  pypi environment)  │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### Step 1: Create the Release PR

1. Go to **GitHub Actions** → **Create Release PR**
2. Click **Run workflow**
3. For each package, select the version bump type (`skip`, `patch`, `minor`, or `major`):
   - `jaclang`, `jac-byllm`, `jac-scale`, `jac-mcp`, `jaseci`
4. Click **Run workflow**
5. The workflow validates versions against PyPI, bumps them, and creates a PR from a `release/*` branch
6. **Close and reopen the PR** to make CI run. The PR is authored by `github-actions[bot]`, and GitHub does not run `pull_request` checks for PRs opened by the `GITHUB_TOKEN` actor (workflows triggered by `GITHUB_TOKEN` can't trigger further workflows, to prevent recursion). Closing and reopening makes the reopen event come from *you* (a real user), so the PR checks run and attach to the PR. *(Permanent fix: author the PR with a GitHub App / PAT token instead.)*
7. Once the checks attach, enable **auto-merge** on the PR
8. When CI passes, the PR auto-merges to `main` (or **approve and merge** it manually)

### Step 2: Approve Publishing

After the release PR is merged, the **Publish Release** workflow triggers automatically:

1. It parses the packages and versions from the PR title
2. **Manual approval required** (only maintainers with `pypi` environment access can approve):
   - Go to **GitHub Actions** → find the running **Publish Release** workflow
   - The workflow will pause at the "approve-release" job waiting for approval
   - Click on the job, then click **Review deployments**
   - Select the `pypi` environment and click **Approve and deploy**
3. The workflow then handles everything automatically:
   - Builds all packages once ([precompiling bytecode](https://docs.jaseci.org/reference/publishing/) for packages that need it)
   - Builds the native `jac` binary (this is the `jaclang` release artifact -- it is attached to the GitHub Release, not published to PyPI; includes the client and desktop runtimes)
   - Publishes the plugins to PyPI in dependency order (tiered):
     - **Tier 2**: `jac-byllm`, `jac-scale`, `jac-mcp` (build against `jaclang` from the source tree)
   - Pushes git tags (`{package}-v{version}`, plus the release `v{version}`)
   - Creates a GitHub Release with the binary artifacts

> **Note**: The workflow waits for each tier on PyPI before publishing the next, so a package never lands before a dependency it pins. Tiers are configured per package in `scripts/release_utils.jac`.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| CI checks not running / not showing on the release PR | Expected: GitHub skips `pull_request` checks for PRs opened by the `github-actions[bot]` / `GITHUB_TOKEN` actor. **Close and reopen the PR** so the reopen event comes from a real user, and the checks then run and attach. (A GitHub App / PAT token authoring the PR would remove this step.) |
| Auto-merge won't enable / PR won't merge | Auto-merge needs the PR's required status checks to be attached; do the close/reopen above first so the checks exist on the PR |
| Publish workflow didn't trigger | Ensure the PR branch started with `release/` |
| A tier failed to publish | Re-run the failed job from GitHub Actions; already-published packages are skipped (`skip-existing`) |
| Need to re-publish after the release PR is merged | Manually trigger **Publish Release** (`workflow_dispatch`) and check the packages to publish |
| Version conflict on PyPI | The `Create Release PR` workflow validates this upfront - if you hit this, someone manually published |
