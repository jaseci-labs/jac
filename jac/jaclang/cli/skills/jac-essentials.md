---
name: jac-essentials
description: Start coding in Jac with essential syntax, task routing, and validation commands. Load before an unfamiliar Jac task, then retrieve only the relevant specialist guidance.
---

# Jac essentials

Use the project's installed `jac` and existing conventions. Run `jac --version` when checking compatibility. These guides ship with that toolchain; compiler diagnostics identify more specific guidance.

## Syntax needed to start

```jac
node Item { has name: str; }

def greet(name: str) -> str {
    return f"Hello, {name}";
}

with entry:__main__ {
    print(greet("Jac"));
}
```

- Use `{ }` for blocks and `;` for statements. `match` arms use `case pattern:` plus indentation. A final expression without `;` can return a value.
- Annotate parameters, value-returning function results, and `has` fields. Use lowercase `any` only at a deliberate dynamic boundary; narrow or cast before a typed use. Read `jac-types` for that boundary.
- Module variables use `glob`. Plain `with entry` runs when the module loads; put executable demos in `with entry:__main__`.
- `import os;` imports a module. `import from math { sqrt }` imports names without a trailing semicolon. Server/native project imports can use project-root paths.
- Use `obj` for ordinary objects, `node`/`edge` for topology, and `walker` with `can ... with Type entry` for encounter behavior. `root` is a value, not `root()`.
- Inside a walker: `self` is the walker, `here` the location. Inside a node ability: `self` is the node, `visitor` the walker.
- `visit` queues destinations; `report` collects results; `skip` ends an ability; `disengage` stops traversal.
- Client JSX uses Jac expressions and typed lambdas. Reactive component state uses `has`; imports and syntax inform placement. Await consumed cross-app bridge results.

## Load for the task

| Task | Guide |
|---|---|
| Choose or scaffold a project | `jac-project-kinds`, then `jac-scaffold` |
| Syntax or type error | Diagnostic's guide; `jac-core-cheatsheet` or `jac-types` |
| Graph traversal or graph shape | `jac-walker-patterns` or `jac-node-edge-patterns` |
| UI component | `jac-cl-components` |
| Server endpoint or stored data | `jac-sv-endpoints` or `jac-sv-persistence` |
| Multiple apps or bridge calls | `jac-apps` or `jac-sv-microservices` |
| Model delegation | `jac-by-llm` |
| Native code or lifetime rules | `jac-native` or `jac-native-memory` |

Read only the relevant guide. For a long guide or reference:

```bash
jac guide jac-types --sections
jac guide jac-types --section pitfalls
```

Section output includes its subsections. A code fragment may still depend on declarations elsewhere in that guide.

## Verify

Run `jac check <file-or-app>` after editing. Run the relevant `jac test` tests and exercise changed behavior. Parser success alone does not check types or runtime results. For a new project, inspect its generated files and `jac run --show` before choosing run options. Diagnose persisted-data failures before any reset; use `jac-debugging`.
