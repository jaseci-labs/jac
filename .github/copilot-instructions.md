# Copilot Instructions

## Repository Structure

This monorepo contains:

- `jac/`: Jac language compiler, runtime, and language server
- `jac-byllm/`: LLM integration and model-driven features
- `jac-client/`: Client libraries and SDKs
- `docs/`: Documentation site and reference materials
- `scripts/`: Build, test, and maintenance scripts

## Common Workflows

Run tests for a specific package:

```bash
pytest -n auto <package-name>
```

Run pre-commit checks (formatting, linting):

```bash
./scripts/check.sh
```

Full test suite across all packages:

```bash
./scripts/tests.sh
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
- Examples: `examples/agentic_ai/`, `examples/tool_calling/`

### jac-client/ (Client SDKs)

- Plugin: `jac_client/plugin/`

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
