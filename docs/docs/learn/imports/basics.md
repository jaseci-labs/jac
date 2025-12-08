# <span style="color: orange">Import Basics</span>

Jac provides a powerful and flexible import system to organize code across multiple files and packages.

!!! tip "Prefer Absolute Imports"
    **We recommend using absolute imports** over relative imports. Absolute imports are explicit, easier to read, and avoid ambiguity.

---

## Import Syntax Overview

| Pattern | Syntax | Use Case |
|---------|--------|----------|
| Absolute import | `import module;` | Import entire module |
| From-import | `import from module { X, Y }` | Import specific symbols |
| Include (wildcard) | `include module;` | Include all symbols into namespace |
| Aliased import | `import module as alias;` | Rename module |
| From-import alias | `import from module { X as Y }` | Rename symbol |

!!! note "File Extensions"
    Jac resolves both `.jac` and `.py` files—you don't need to include the extension in import paths. This makes Jac fully interoperable with Python modules.

---

## Absolute Import

Import an entire module and access its members using dot notation.

> 📂 [**absolute_import/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/absolute_import)

=== "main.jac"
    ```jac title="absolute_import/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/absolute_import/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/absolute_import/main.jac)

=== "module_a.jac"
    ```jac title="absolute_import/module_a.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/absolute_import/module_a.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/absolute_import/module_a.jac)

```
absolute_import/
├── main.jac
└── module_a.jac
```

??? example "Output"
    ```
    Absolute import - VALUE_A: Hello from module_a
    Absolute import - greet(): Greet from module_a
    ```

!!! tip "When to use"
    Use absolute imports when you need multiple items from a module and want to make the source clear (e.g., `module_a.VALUE_A`).

---

## From-Import (Selective Import)

Import specific symbols directly into your namespace.

> 📂 [**from_import/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/from_import)

=== "main.jac"
    ```jac title="from_import/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/from_import/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/from_import/main.jac)

=== "module_b.jac"
    ```jac title="from_import/module_b.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/from_import/module_b.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/from_import/module_b.jac)

```
from_import/
├── main.jac
└── module_b.jac
```

??? example "Output"
    ```
    From-import - VALUE_B: Hello from module_b
    From-import - calculate(5): 10
    From-import - MyClass: MyClass instance
    ```

!!! tip "When to use"
    Use from-imports when you need specific items and want shorter names in your code.

---

## Include Statement (Wildcard Import)

The `include` statement imports all public symbols from a module directly into your namespace.

> 📂 [**include_statement/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/include_statement)

=== "main.jac"
    ```jac title="include_statement/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/include_statement/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/include_statement/main.jac)

=== "module_c.jac"
    ```jac title="include_statement/module_c.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/include_statement/module_c.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/include_statement/module_c.jac)

```
include_statement/
├── main.jac
└── module_c.jac
```

??? example "Output"
    ```
    Star import - PUBLIC_VAR: I am public
    Star import - public_func(): Public function
    ```

!!! info "Private symbols"
    Symbols starting with `_` (underscore) are considered private and are **not** included.

!!! warning "Use sparingly"
    Include statements can pollute your namespace. Prefer explicit imports in production code.

---

## Aliased Imports

Rename modules or symbols during import to avoid conflicts or for convenience.

> 📂 [**aliased_import/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/aliased_import)

=== "main.jac"
    ```jac title="aliased_import/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/aliased_import/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/aliased_import/main.jac)

=== "module_d.jac"
    ```jac title="aliased_import/module_d.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/aliased_import/module_d.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/aliased_import/module_d.jac)

```
aliased_import/
├── main.jac
└── module_d.jac
```

??? example "Output"
    ```
    Import as - md.LONG_MODULE_VALUE: Value from long named module
    From import as - lfn(): Result from long function
    ```

!!! tip "When to use"
    - Shorten long module names
    - Avoid naming conflicts
    - Create more descriptive names

---

## Key Takeaways

| Concept | Description |
|---------|-------------|
| **`import X;`** | Access via `X.symbol` |
| **`import from X { Y }`** | Access `Y` directly |
| **`include X;`** | All public symbols available directly |
| **`import X as Z;`** | Access via `Z.symbol` |
| **`import from X { Y as Z }`** | Access `Y` as `Z` |

!!! success "Best Practice: Use Absolute Imports"
    Absolute imports like `import from mypackage.module { X }` are clearer and more maintainable than relative imports.
