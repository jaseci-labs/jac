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

## Release Flow (for the empowered)

- Version bump jac, jac-cloud, byllm
  - Remember to version bump requirement of jaclang in jac-cloud and byllm
- Update release notes (unreleased becomes released)
- Push to main
- Go to GitHub, run `Release jaclang to PYPI` action manually
- After success
  - Run `Release jac-cloud to PYPI` action manually
  - Run `Release jac-byllm to PYPI` action manually
  - Run `RElease jac-mtllm to PYPI` action manually, for deprecated library
- If All success, W for you!!
