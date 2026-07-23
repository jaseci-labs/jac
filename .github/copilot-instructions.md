# Copilot Instructions

## Repository Structure

This monorepo contains:

- `jac/`: Jac language compiler, runtime, language server, and the client/desktop runtimes (`jac/jaclang/runtimelib/client/`)
- `jac-byllm/`: LLM integration and model-driven features
- `docs/`: Documentation site and reference materials
- `scripts/`: Build, test, and maintenance scripts

## Common Workflows

`jaclang` ships as the single `jac` binary (Zig launcher + bundled CPython) -- there is no pip-installed jaclang. Build it and put it on PATH with `./scripts/fresh_env.sh` (see CONTRIBUTING.md).

Run tests through the binary's bundled runner (`JAC_TEST_JOBS=auto` runs them in parallel):

```bash
cd jac && JAC_TEST_JOBS=auto jac test tests
```

Run the formatting/lint gate (same checks the git hook runs):

```bash
jac precommit
```

## Package-Specific Notes

### jac/ (Compiler & Runtime)

- Grammar: `jac/jaclang/compiler/jac.lark`
- IR: `unitree.py` (UniTree nodes)
- Passes: `jac/jaclang/compiler/passes/main/`
- Codegen: `pyast_gen_pass.py`, `pybc_gen_pass.py`
- Compiler passes subclass `Transform`/`UniPass` with `enter_*`/`exit_*` hooks
- Test fixtures: `jac/jaclang/compiler/**/tests/fixtures/`
- For type system work, see `.github/agents/type-system-agent.md`

### jac-byllm/ (LLM Features)

- Core logic: `byllm/lib.py`, `llm_connector.py`
- Schema definitions: `schema.py`
- Examples: `examples/agentic_ai/`

### Client & Desktop Runtimes

- Now part of `jaclang` core: `jac/jaclang/runtimelib/client/`

## Jac Language Conventions

Import syntax:

```jac
import from module { symbol, another_symbol }
import module as alias;
```

Entry point:

```jac
with entry { /* ... */ }
```

## PR Guidelines

- **Target repository**: Always create PRs against `https://github.com/jaseci-labs/jaseci` (not forks). Use `gh pr create --repo jaseci-labs/jaseci`.
- **Release notes**: If your PR affects Jac developer experience, add a concise bullet under `## jaclang <version> (Unreleased)` in `docs/docs/communityhub/release_notes/jaclang.md`.
- **Grouping**: Organize related changes under sections like "Type Checking Enhancements" or "Cloud Platform Updates".
- **Testing**: Ensure relevant tests pass before submitting.

## Quick Reference

- Jac examples: `jac/examples/reference/`, `jac/examples/*`
- Type system details: `.github/agents/type-system-agent.md`
- Compiler passes: `jac/jaclang/compiler/passes/main/`
- LLM examples: `jac-byllm/examples/`
