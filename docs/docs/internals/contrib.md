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

## Working with Stable and Main Branches

Jaseci uses two primary branches with different purposes:

- **`stable`**: This is the production-ready branch used for PyPI package releases and website documentation synchronization. This branch contains stable, tested code suitable for production applications.
- **`main`**: This is the experimental/development branch. Code here is actively being developed and may be unstable. **Not recommended for production applications** as it will change frequently.

### When to Target Each Branch

**Target `stable` for:**

- Hotfixes for critical bugs reported from production/PyPI packages
- Security patches
- Critical fixes that need to be released immediately

**Target `main` for:**

- New features
- Bugfixes (non-critical)
- Experimental changes
- General improvements and enhancements

### Workflow for Hotfixes (Targeting `stable`)

When you need to fix a critical issue reported from the stable/PyPI version:

1. **Create a hotfix branch from `stable`**:

   ```bash
   # Fetch latest changes
   git fetch upstream

   # Checkout and create branch from stable
   git checkout upstream/stable
   git checkout -b hotfix/description-of-fix
   ```

2. **Make your hotfix changes** and commit:

   ```bash
   git add .
   git commit -m "fix: description of the hotfix"
   ```

3. **Push to your fork**:

   ```bash
   git push origin hotfix/description-of-fix
   ```

4. **Create a Pull Request targeting `stable`**:
   - Go to your fork on GitHub
   - Click **Compare & pull request**
   - **Important**: Change the base branch to `stable` (not `main`)
   - Fill in the PR description explaining:
     - The issue being fixed
     - That this is a hotfix for the stable branch
     - Any relevant issue numbers or user reports
   - Submit the pull request to the `stable` branch

5. **After the hotfix is merged to `stable`**, it should also be merged back to `main` to keep branches in sync (this is typically handled by maintainers).

!!! warning "Hotfix Guidelines"
    - Only submit hotfixes to `stable` for critical production issues
    - Ensure the fix is minimal and focused
    - Test thoroughly as this will affect production users
    - Coordinate with maintainers if unsure whether an issue qualifies as a hotfix

### Workflow for Features and Bugfixes (Targeting `main`)

For new features, non-critical bugfixes, and experimental work:

1. **Create a feature/bugfix branch from `main`**:

   ```bash
   # Fetch latest changes
   git fetch upstream

   # Checkout and create branch from main
   git checkout upstream/main
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/description-of-bugfix
   ```

2. **Make your changes** and commit:

   ```bash
   git add .
   git commit -m "feat: description of feature"
   # or
   git commit -m "fix: description of bugfix"
   ```

3. **Keep your branch synced with upstream `main`**:

   ```bash
   git fetch upstream
   git merge upstream/main
   ```

4. **Push to your fork**:

   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request targeting `main`**:
   - Go to your fork on GitHub
   - Click **Compare & pull request**
   - Ensure the base branch is `main` (default)
   - Fill in the PR description with details about your changes
   - Submit the pull request to the `main` branch

!!! note "Branch Synchronization"
    - Changes from `stable` may be merged into `main` periodically
    - Changes from `main` are merged into `stable` during release cycles
    - Maintainers handle the synchronization between branches

### Versioning Guidelines

Version numbers are managed in `pyproject.toml` files for each package. The version format follows [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH).

**Version Format: `X.Y.Z`**

- **X (MAJOR)**: Breaking changes that are incompatible with previous versions
- **Y (MINOR)**: New features that are backward compatible
- **Z (PATCH)**: Bug fixes that are backward compatible

**Packages that require version updates:**

- `jac/pyproject.toml` (jaclang)
- `jac-client/pyproject.toml` (jac-client)
- `jac-byllm/pyproject.toml` (byllm)
- `jaseci-package/pyproject.toml` (jaseci meta-package)

#### Version Bump Reference Table

| Change Type | Branch | Version Component | Example | When to Bump |
|------------|--------|------------------|---------|--------------|
| **Hotfix** (critical bug fix) | `stable` | **PATCH (Z)** | `0.9.3` → `0.9.4` | In your PR |
| **Bugfix** (non-critical) | `main` | **PATCH (Z)** | `0.9.3` → `0.9.4` | During release cycle |
| **New Feature** | `main` | **MINOR (Y)** | `0.9.3` → `0.10.0` | During release cycle |
| **Breaking Change** | `main` | **MAJOR (X)** | `0.9.3` → `1.0.0` | During release cycle |

#### Versioning for Hotfixes (Targeting `stable`)

When submitting a hotfix to the `stable` branch, **you must bump the PATCH version (Z component)**:

**Version Update Rule**: `X.Y.Z` → `X.Y.(Z+1)`

Examples:

- `0.9.3` → `0.9.4` (PATCH increment)
- `1.2.0` → `1.2.1` (PATCH increment)
- `2.0.5` → `2.0.6` (PATCH increment)

**Steps:**

1. **Identify which package(s) are affected** by your hotfix
2. **Update the version** in the relevant `pyproject.toml` file(s):
   - Increment **only the PATCH (Z)** component
   - MINOR (Y) and MAJOR (X) remain unchanged
   - Example: If fixing a bug in jaclang, update `jac/pyproject.toml`:

     ```toml
     version = "0.9.4"  # was 0.9.3 (PATCH: 3 → 4)
     ```

3. **If jaclang version is bumped**, also update the jaclang requirement in dependent packages:
   - Update `jac-client/pyproject.toml` dependencies if it requires a specific jaclang version
   - Update `jac-byllm/pyproject.toml` dependencies if it requires a specific jaclang version
4. **Include the version bump in your hotfix PR** - this is required for the hotfix to be released to PyPI

!!! warning "Hotfix Version Requirements"
    - **Always** bump **only the PATCH (Z)** version for hotfixes to `stable`
    - **Never** bump MINOR (Y) or MAJOR (X) for hotfixes
    - Version bumps are mandatory for hotfixes as they will be released to PyPI
    - Coordinate with maintainers if you're unsure which packages need version bumps

#### Versioning for Features and Bugfixes (Targeting `main`)

For PRs targeting the `main` branch:

1. **Generally, do NOT bump versions** in your PR
   - Version bumps are handled during release cycles when code is merged from `main` to `stable`
   - The `main` branch is experimental and versions are not tied to specific releases

2. **Exception**: If you're working on a breaking change or major feature that requires version coordination:
   - Discuss with maintainers first
   - They may request a version bump if it's part of a planned release

3. **During release cycles** (handled by maintainers when merging `main` → `stable`):

   **For Bugfixes (non-critical):**
   - **Bump PATCH (Z)**: `X.Y.Z` → `X.Y.(Z+1)`
   - Examples: `0.9.3` → `0.9.4`, `1.2.0` → `1.2.1`
   - Reset: MINOR and MAJOR remain unchanged

   **For New Features:**
   - **Bump MINOR (Y)**: `X.Y.Z` → `X.(Y+1).0`
   - Examples: `0.9.3` → `0.10.0`, `1.2.5` → `1.3.0`
   - Reset: PATCH resets to 0, MAJOR remains unchanged

   **For Breaking Changes:**
   - **Bump MAJOR (X)**: `X.Y.Z` → `(X+1).0.0`
   - Examples: `0.9.3` → `1.0.0`, `1.2.5` → `2.0.0`
   - Reset: MINOR and PATCH reset to 0

!!! tip "Version Bump Best Practices"
    - **Hotfixes to `stable`**: Always bump **PATCH (Z)** only: `X.Y.Z` → `X.Y.(Z+1)`
    - **Bugfixes in `main`** (during release): Bump **PATCH (Z)**: `X.Y.Z` → `X.Y.(Z+1)`
    - **Features in `main`** (during release): Bump **MINOR (Y)**: `X.Y.Z` → `X.(Y+1).0`
    - **Breaking changes in `main`** (during release): Bump **MAJOR (X)**: `X.Y.Z` → `(X+1).0.0`
    - For main branch PRs: Usually no version bump needed (handled during release)
    - When in doubt, ask maintainers or check existing PRs for patterns
    - Version bumps should be in separate commits with clear messages like `chore: bump version to X.Y.Z`
    - Remember: When incrementing MINOR or MAJOR, reset lower components to 0

## General Setup and Information

To get setup run

```bash
# Install black
python3 -m venv ~/.jacenv/
source ~/.jacenv/bin/activate
pip3 install pre-commit pytest pytest-xdist
pre-commit install
```

To understand our linting and mypy type checking have a look at our pre-commit actions. You can set up your enviornment accordingly. For help interpreting this if you need it, call upon our friend Mr. ChatGPT or one of his colleagues.

??? Grock "Our pre-commit process"
    ```yaml linenums="1"
    --8<-- ".pre-commit-config.yaml"
    ```

This is how we run checks on demand.

```bash
--8<-- "scripts/check.sh"
```

This is how we run our tests.

```bash
--8<-- "scripts/tests.sh"
```

## Run docs site locally

This is how we run the docs.

```bash
--8<-- "scripts/run_docs.sh"
```

## Build VSCode Extention

```bash
--8<-- "scripts/build_vsce.sh"
```

## Release Flow (Automated)

The release process is fully automated via GitHub Actions. Each package (jaclang, jac-client, byllm) has its own release workflow that handles version updates, release notes, and PyPI publishing automatically.

### Release Order

Packages must be released in this specific order due to dependencies:

1. **jaclang** (core package - no dependencies on other Jac packages)
2. **jac-client** (depends on jaclang)
3. **byllm** (depends on jaclang)

### How to Release

#### Step 1: Release jaclang

1. Go to **GitHub Actions** → **Release jaclang to PYPI**
2. Click **Run workflow**
3. Enter the version to release (e.g., `0.9.9`)
4. Click **Run workflow**

**What happens automatically:**

- Updates `version` in `jac/pyproject.toml` to the specified version
- Updates `docs/docs/communityhub/release_notes/jaclang.md`:
  - Removes `(Latest Release)` from the previous latest version
  - Changes `(Unreleased)` to `(Latest Release)` for the new version
  - Adds a new `(Unreleased)` section with the next patch version
- Commits and pushes the changes
- Builds and publishes the package to PyPI

#### Step 2: Release jac-client and byllm

For each package (jac-client and byllm):

1. Go to **GitHub Actions** → **Release jac-client to PYPI** or **Release jac-byllm to PYPI**
2. Click **Run workflow**
3. Enter the version to release (e.g., `0.2.9` for jac-client, `0.4.14` for byllm)
4. Click **Run workflow**

**What happens automatically:**

- Updates `version` in the package's `pyproject.toml`
- Reads jaclang version from `jac/pyproject.toml` and updates the jaclang dependency
- Updates the corresponding release notes file (same pattern as jaclang)
- Commits and pushes the changes
- Builds and publishes the package to PyPI
