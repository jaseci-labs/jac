Jac modules organize code using top-level statements including imports, archetypes, implementations, globals, abilities, and entry points. This example demonstrates all top-level statement types.

**Module-Level Docstrings**

Lines 1-5 show the module docstring - a string literal at the very beginning of the file. This triple-quoted string documents what the entire module does. It appears before any code elements and is used by documentation tools.

**Top-Level Statements Coverage**

This module demonstrates all 9 top-level statement types from the grammar:

| Statement Type | Lines | Example |
|---------------|-------|---------|
| Import | 8 | `import math;` |
| Global Variable | 11 | `global_value: int = 42;` |
| Archetype | 14-16 | `obj MyObject { ... }` |
| Implementation | 19-23 | `impl MyObject { ... }` |
| Semstring | 26 | `sem MyObject.value = "...";` |
| Ability (Function) | 29-31 | `def add(a: int, b: int) -> int { ... }` |
| Free Code (Default Entry) | 34-36 | `with entry { ... }` |
| Free Code (Named Entry) | 39-41 | `with entry:__main__ { ... }` |
| Inline Python | 44-47 | `::py:: ... ::py::` |
| Test | 50-53 | `test basic_test { ... }` |

**1. Import Statements (Line 8)**

The `import math;` statement makes Python's math module available. Jac supports standard Python imports and Jac-specific imports using `import from module { items }` syntax.

**2. Global Variables (Line 11)**

`global_value: int = 42;` declares a module-level variable using the `let` keyword. Global variables can have access modifiers (`:priv`, `:pub`, `:protect`) and type annotations.

**3. Archetypes (Lines 14-16)**

`obj MyObject` defines an object archetype with a `value` field. Jac has 5 archetype types: `obj`, `class`, `node`, `edge`, and `walker`.

**Key distinction**: `obj` vs `class`:

- **`obj`**: All `has` fields are instance variables (each instance gets its own copy). **Methods have implicit `self`** - it doesn't appear in the parameter list (e.g., `def init(param: str)`). Compatible with spatial archetypes (`node`, `edge`, `walker` also use implicit `self`).
- **`class`**: `has` fields with defaults become class variables (shared across instances). **Methods require explicit `self` parameter with type annotation** (e.g., `def init(self: MyClass, param: str)`).

See [class_archetypes.md](class_archetypes.md) for detailed examples.

**4. Implementations (Lines 19-23)**

The `impl MyObject` block adds the `get_value` method to the MyObject archetype. Implementations allow forward declarations and deferred definitions, separating interface from implementation.

**5. Semstrings (Line 26)**

`sem MyObject.value = "..."` attaches semantic documentation to the `value` field. Semstrings guide LLM-based code generation and provide rich semantic context.

**6. Abilities (Lines 29-31)**

The `def add` function is a top-level ability that can be called throughout the module. Functions use type annotations and can be defined with `def` or `can` keywords.

**7. Free Code - Entry Points (Lines 34-41)**

Entry points execute when the module runs:

- **Default entry** (`with entry`): Executes when the module runs
- **Named entry** (`with entry:__main__`): Only executes when run directly (not when imported)

The default entry prints "Default entry: 13" by calling `add(5, 8)`.
The named entry prints "Named entry: 3" by calling `add(1, 2)`.

**8. Inline Python (Lines 44-47)**

The `::py:: ... ::py::` block embeds pure Python code. This allows seamless Python interop - the `python_multiply` function can be called from Jac code.

**9. Tests (Lines 50-53)**

`test basic_test` defines a unit test that verifies `add(2, 3)` returns 5. Tests can be run with `jac test` command and use assertions to validate behavior.
