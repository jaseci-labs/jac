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

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e jac
pip install -e jac-byllm
pip install -e jac-scale
pip install -e jac-client
pip install pre-commit
pre-commit install
pip install pytest pytest-xdist pytest-asyncio
```

**Run Some Tests**

```bash
pytest jac -n auto
# See ci jobs in github actions for more stuff to run
```

**Build something awesome, or fix something that's broken**

See Rules below.
And check [`.pre-commit-config.yaml`](.pre-commit-config.yaml) to see our lint strategy.

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
- **Tutorials** -- How to do things step by step. OK to not touch this for most changes.
- **Reference** -- Must cover everything. **Every feature or change should update the reference docs.**

## Release Flow (for the empowered)

Releasing new versions to PyPI is a two-step process using GitHub Actions.

### Step 1: Create and Merge the Release PR

1. Go to **GitHub Actions** → **Create Release PR**
2. Click **Run workflow**
3. For each package, select the version bump type (`skip`, `patch`, `minor`, or `major`)
4. Click **Run workflow**
5. The workflow creates a PR with all version bumps (example: [PR #4675](https://github.com/jaseci-labs/jaseci/pull/4675))
6. Wait for CI tests to pass, then **approve and merge** the PR to main

### Step 2: Publish to PyPI

After the release PR is merged, go to **GitHub Actions** and run the `Release <package> to PYPI` workflow for each bumped package **in this order**:

1. **jaclang** (core - must be first)
2. **jac-client**, **jac-byllm**, **jac-scale**, **jac-super** (depend on jaclang)
3. **jaseci** (meta-package - last)

> **Important**: Wait for each workflow to complete before starting the next.
