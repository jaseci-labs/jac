# Contributing

Jac development happens in the open at
[github.com/jaseci-labs/jaseci](https://github.com/jaseci-labs/jaseci).

The canonical contributor guide lives at the repository root:
[CONTRIBUTING.md](https://github.com/jaseci-labs/jaseci/blob/main/CONTRIBUTING.md).
It covers the full workflow:

- Forking, cloning, and setting up the Zig-built `jac` binary with the
  editable dev loop for compiler work.
- Running the test suites and the `jac precommit` format/lint gates.
- PR conventions, including the required release-note fragment
  (`release_notes/unreleased/<package>/<PR#>.<category>.md`).
- Code rules: Jac style, type safety, no scaffolding, and documentation
  expectations.
- The release flow for maintainers.

For a guided tour of the codebase itself -- how the repository is laid out,
where the compiler, runtime, and CLI live, and how to find your way to the
code you want to change -- see the [Codebase Guide](codebase-guide.md).
