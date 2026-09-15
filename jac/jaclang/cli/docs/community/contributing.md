# Contributing

Jac development happens in the open at
[github.com/jaseci-labs/jaseci](https://github.com/jaseci-labs/jaseci).

The canonical contributor guide lives at the repository root:
[CONTRIBUTING.md](https://github.com/jaseci-labs/jaseci/blob/main/CONTRIBUTING.md).
It covers the full workflow:

- Forking, cloning, and setting up the Zig-built `jac` binary with the
  editable dev loop for compiler work.
- Running the test suites and the `jac precommit` format/lint gates. The
  repo's own suites run on the native `jac test` runner (the pytest harness
  was retired).
- PR conventions, including the required release-note fragment
  (`release_notes/unreleased/<package>/<PR#>.<category>.md`).
- Code rules: Jac style, type safety, no scaffolding, and documentation
  expectations.
- The release flow for maintainers.
- Downloading and experimenting with the opt-in
  [JacPython release binary](https://github.com/jaseci-labs/jac/blob/main/CONTRIBUTING.md#trying-the-jacpython-release-binary).

For a guided tour of the codebase itself -- how the repository is laid out,
where the compiler, runtime, and CLI live, and how to find your way to the
code you want to change -- see the [Codebase Guide](codebase-guide.md).

## Writing documentation and agent skills

Human documentation and agent skills serve different reading patterns:

| Material | Write for | Include |
|---|---|---|
| Tutorial | A learner completing a task | Prerequisites, a small runnable step, explanation, expected behavior, and a recovery checkpoint |
| Reference | A reader resolving a specific question | Definitions, supported syntax, constraints, failure behavior, and focused examples |
| Agent skill | An assistant implementing a task | A short task-trigger description, necessary syntax and invariants, specific pitfalls, and validation commands |

Use direct technical prose. Explain what a construct does before giving its design motivation. Qualify guarantees by execution context and avoid universal claims about other languages, libraries, or model correctness. Research terminology belongs in background pages unless it helps explain the immediate task.

Keep one detailed source for a rule or pattern. A skill can summarize the necessary constraint and point to a reference section through `jac guide`; do not duplicate a long catalog in its entrypoint. Preserve diagnostic codes and exceptions that change the correct implementation. Compression should reduce irrelevant reading, not remove information needed to avoid a known error.

When updating examples, distinguish complete programs from fragments and intentional errors. Check links and navigation, parse example code, and exercise representative complete programs. Parsing alone is not evidence that a tutorial runs correctly. For troubleshooting, diagnose the selected source, app, storage, and error before suggesting a reset; name the data affected by any destructive operation.
