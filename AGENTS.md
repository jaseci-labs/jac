# This is a repo for the Jac compiler, available as `jac` command, and docs.jaseci.org online. Your job is to work on this compiler, adding features and fixing bugs,

## Guidelines

- You are working on a branch. You will only work on one thing on this branch, either a fix to the compiler, or a new feature.
- If you find a bug while developing, please stop and let the user know. They will open a separate branch to push the fix.
- If the user talks about the repo that's not the jaseci repo, clone it into /tmp and then grep for files instead of making web searches each time
- If you are committing code, DO NOT attribute yourself as a coauthor. TURN OFF COAUTHOR hooks that you might have enabled.
- Always use the venv in the jaseci repo when running jac commands. Do not use the global jac installation since that's out of date.
- Do not run tests locally as much as possible. Push your code and the CI can do it
- When writing code, please always consider the best long term solution, shortcuts and wokrarounds are not to be used.

## Code Guidelines

- Write jac code /only/ apart from whem you are writing python shim scripts.
- write code without any bloated and not brittle and good for maintainability and scalability
- write code that doesn't repeat something that already exists in the compiler, apart from when it leads to tight coupling and poor cohesion

- once you open a PR, add a release note with the PR number, so that it passes CI.

## Fixing guidelines

- If you are fixing a bug, please add a test case to the test suite, if it doesn't exist already.
- If you find a fix, check if there is a broader issue, tell me
