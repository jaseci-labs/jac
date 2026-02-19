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
git submodule update --init --recursive # Pulls in typeshed

# Add the original repository as upstream (may already exist)
git remote add upstream https://github.com/jaseci-labs/jaseci.git

# Verify your remotes
git remote -v
# You should see:
# origin    https://github.com/YOUR_USERNAME/jaseci.git (fetch)
# origin    https://github.com/YOUR_USERNAME/jaseci.git (push)
# upstream  https://github.com/jaseci-labs/jaseci.git (fetch)
# upstream  https://github.com/jaseci-labs/jaseci.git (push)
```

**Pushing Your First PR**

1. **Create a new branch** for your changes:

   ```bash
   git checkout -b your-feature-branch
   ```

2. **Make your changes** and commit them:

   ```bash
   git add .
   git commit -m "Description of your changes"
   ```

3. **Keep your fork synced** with upstream:

   ```bash
   git fetch upstream
   git merge upstream/main
   ```

4. **Push to your fork**:

   ```bash
   git push origin your-feature-branch
   ```

5. **Create a Pull Request**:
   - Go to your fork on GitHub
   - Click **Compare & pull request**
   - Fill in the PR description with details about your changes
   - Submit the pull request to the `main` branch of `jaseci-labs/jaseci`

!!! tip "PR Best Practices"
    - Make sure all pre-commit checks pass before pushing
    - Run tests locally using the test script above
    - Keep your PR focused on a single feature or fix
    - Write clear commit messages and PR descriptions

## General Setup and Information

To get setup run

```bash
python3 -m venv ~/.jacenv/
source ~/.jacenv/bin/activate
pip3 install pre-commit pytest pytest-xdist
pre-commit install
```

Pre-commit handles all linting (ruff), formatting, and type checking (mypy) automatically when you commit.

??? info "Our pre-commit process"
    ```yaml linenums="1"
    --8<-- ".pre-commit-config.yaml"
    ```

This is how we run our tests.

```bash
--8<-- "scripts/tests.sh"
```

## Run docs site locally

```bash
--8<-- "scripts/run_docs.sh"
```

## Release Flow (Automated)

Releasing new versions to PyPI is a two-step process using GitHub Actions.

### Step 1: Create and Merge the Release PR

1. Go to **GitHub Actions** → **Create Release PR**
2. Click **Run workflow**
3. For each package, select the version bump type (`skip`, `patch`, `minor`, or `major`)
4. Click **Run workflow**

**What happens automatically:**

- The workflow runs `scripts/release.py` to bump versions in the relevant `pyproject.toml` files
- Creates a new branch with the version changes
- Opens a PR with a summary of all version bumps (example: [PR #4675](https://github.com/jaseci-labs/jaseci/pull/4675))

1. **Review the PR** - Verify the version bumps are correct
2. Wait for CI tests to pass, then **approve and merge** the PR to main

### Step 2: Publish to PyPI

After the release PR is merged, manually trigger the release workflow for each bumped package.

!!! warning "Release Order"
    Packages must be released in dependency order. **jaclang must be released first** since other packages depend on it.

| Order | Package | Workflow | Dependencies |
|-------|---------|----------|--------------|
| 1 | **jaclang** | Release jaclang to PYPI | None (core package) |
| 2 | **jac-client** | Release jac-client to PYPI | jaclang |
| 3 | **jac-byllm** | Release jac-byllm to PYPI | jaclang |
| 4 | **jac-scale** | Release jac-scale to PYPI | jaclang |
| 5 | **jac-super** | Release jac-super to PYPI | jaclang |
| 6 | **jaseci** | Release jaseci to PYPI | Meta-package (release last) |

#### How to Trigger a Release

For each package you need to release:

1. Go to **GitHub Actions** → Select the appropriate release workflow
2. Click **Run workflow**
3. Click **Run workflow** again to confirm

**What happens automatically:**

- Precompiles bytecode for Python 3.12, 3.13, and 3.14
- Builds the package distribution
- Publishes to PyPI

!!! tip "Best Practice"
    Wait for each workflow to complete successfully before starting the next one. Check the Actions tab to monitor progress.
