# Custom Agent: Jac Type System

## Scope

- Work exclusively in `jac/jaclang/compiler/type_system/` and related compiler passes.
- Do not modify other packages (`jac-byllm/`, `jac-scale/`, `jac-client/`).
- Goal: add/adjust type checking rules; do not alter grammar.

## Key Components

- `type_evaluator.jac` (Jac): main engine
  - Key methods: `get_type_of_expression()`, `assign_type()`, `get_type_of_module()`
  - Uses vendored stubs: `vendor/typeshed/stdlib/{builtins.pyi, typing.pyi}`
- `types.py` (Py): type representations (`TypeBase`, `ClassType`, `FunctionType`, `UnionType`, `ModuleType`)
- `operations.py` (Py): operator resolution (`BINARY_OPERATOR_MAP`, `get_type_of_binary_operation()`)
- `type_utils.py` (Py): helpers for conversions/comparisons
- `passes/main/type_checker_pass.py` (Py): orchestrates evaluation, wires diagnostics

## Dependency Map

- type_evaluator imports: `types`, `operations`, `type_utils`, `unitree`
- Users of type_evaluator: `compiler/program.py` (creates evaluator), `type_system/operations.py` (recursive queries)

## Development Workflow

1. Identify a missing rule.
2. Update `type_evaluator.jac` to implement the rule (extend `get_type_of_expression()` or add a focused helper).
3. Create a fixture in `jac/jaclang/compiler/passes/main/tests/fixtures/` named `checker_<feature>.jac` with OK and Error cases commented. This `checker_*.jac` naming is enforced for all new fixtures.
4. Add a test in `jac/jaclang/compiler/passes/main/tests/test_checker_pass.py` following existing patterns.
5. Run tests locally:

   ```bash
   pytest -n auto jac/jaclang/compiler/passes/main/tests/test_checker_pass.py -v
   ```

6. Add a one-line entry to `docs/docs/communityhub/release_notes/jaclang.md` under the Unreleased section (optionally under “Type Checking Enhancements”).

## Naming Conventions (enforced)

- Fixture files: `checker_<feature>.jac` (e.g., `checker_iife.jac`, `checker_arg_param_match.jac`).
- Test function names in `test_checker_pass.py`: `test_<feature>()` so they can be targeted with `pytest -k`.

## Done Criteria

All of the following must pass before a PR is marked complete:

- Pre-commit checks succeed for the repo root:

  ```powershell
  pre-commit run --all-files
  ```

- The focused test(s) for your feature pass (PowerShell-friendly one-liner and multi-line variants):

  ```powershell
  cd jac; pytest -k test_<name_of_the_test> -v
  ```

  or

  ```powershell
  cd jac
  pytest -k test_<name_of_the_test> -v
  ```

  Replace `<name_of_the_test>` with your test function name (e.g., `test_iife_type_checking`).

## Testing Pattern (canonical)

```python
program = JacProgram()
mod = program.compile(self.fixture_abs_path("checker_<feature>.jac"))
TypeCheckPass(ir_in=mod, prog=program)
self.assertEqual(len(program.errors_had), <N>)
self._assert_error_pretty_found("""
  <line excerpt with ^^^^^ marker>
""", program.errors_had[0].pretty_print())
```

Fixture example:

```jac
with entry {
  ok: int = 42;          # <-- OK
  bad: str = 42;         # <-- Error
}
```

## Diagnostics & Conventions

- Report via `diagnostic_callback(node, message, is_warning)` from `TypeEvaluator`.
- `program.errors_had`/`program.warnings_had` collect results; use `.pretty_print()` in tests.
- Keep changes focused; do not reformat unrelated code or refactor beyond the rule.

## Jac Essentials (minimal)

- Import syntax:

  ```jac
  import from module { symbol, another_symbol }
  import module as alias;
  ```

- Entry point:

  ```jac
  with entry { /* ... */ }
  ```

- OSP archetypes exist (`node`, `edge`, `walker`); type rules must respect member access and traversal semantics when relevant.

## Quick Commands

```bash
# Focused type-checker tests
pytest -n auto jac/jaclang/compiler/passes/main/tests/test_checker_pass.py -v

# Full compiler tests
pytest -n auto jac

# Code quality
./scripts/check.sh
```

## Notes

- Pyright is an inspiration for approach; we follow similar methods but not 1:1.
- Pitfalls: none recorded yet; add to release notes and extend this doc when patterns emerge.

# Commands

When I say make PR you should:

- Do a git status and git diff to see changes and understand
- Make sure in a new branch, if on main, checkout to a new branch.
- Commit changes with a meaningful message.
- Push the branch to origin.
- Open a PR agains upstream main with a meaningful title and description. using `gh` cli tool.
- Display the PR link in the terminal.
