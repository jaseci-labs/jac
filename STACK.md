# Stacked PR Workflow

This repo uses `gh stack` (github/gh-stack extension) to manage stacked PRs.

## Stack structure

```
main ← jac-python (PR #6973, c2jac) ← jac-python-next (next stage)
```

- **`jac-python`** - bottom of the stack. c2jac implementation. PR #6973.
- **`jac-python-next`** - top of the stack. Based on `jac-python`, ready for the next stage.

## Daily commands

| What you want | Command |
|---|---|
| See the stack | `gh stack view` |
| Jump to bottom branch | `gh stack bottom` |
| Jump to top branch | `gh stack checkout jac-python-next` |
| Move up one level | `gh stack up` |
| Move down one level | `gh stack down` |
| Switch to a specific branch | `gh stack checkout <branch-name>` |

## Workflow

### While c2jac (PR #6973) is being reviewed

You're on `jac-python`. Make changes from review feedback, commit, push. Business as usual.

### Starting the next stage

```bash
gh stack checkout jac-python-next
# ... write code, commit, repeat ...
gh stack submit
```

This pushes and creates a new PR stacked on top of `jac-python`.

### After c2jac (#6973) merges to main

The new PR's base auto-updates from `jac-python` → `main`. No rebase needed.

### Adding a third layer

```bash
gh stack checkout jac-python-next
gh stack add jac-python-feature-3     # creates third branch on top
```

## How stacking works

Each branch in the stack contains all the work from the branches below it, plus its own changes. When you create a PR, GitHub only shows the diff of the new commits (not the base). When a lower PR merges, higher PRs automatically retarget to `main`.

## Enabling GitHub stacking UI

For `gh stack submit` to auto-link PRs on GitHub, the repo needs stacked PRs enabled:

- **Settings → Pull Requests → Allow stacking** (requires admin access)
- Until then, set PR base branches manually with `--base <branch-name>`

## Install the extension

If you're on a new machine:

```bash
gh extension install github/gh-stack
```
