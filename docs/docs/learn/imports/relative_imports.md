# <span style="color: orange">Relative Imports</span>

Relative imports allow modules within a package to reference each other using `.` (current) and `..` (parent) notation.

!!! warning "Prefer Absolute Imports"
    **Relative imports can be ambiguous.** We recommend absolute imports in most cases. Use relative imports only for tightly coupled internal package code.

---

## Relative Import Syntax

| Syntax | Meaning |
|--------|---------|
| `.module` | Same directory |
| `..module` | Parent directory |
| `...module` | Grandparent directory |

---

## Same-Level Imports (`.`)

Import from modules in the same directory.

> 📂 [**relative_sibling/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling)

=== "main.jac"
    ```jac title="relative_sibling/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling/main.jac)

=== "pkg/base.jac"
    ```jac title="relative_sibling/pkg/base.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling/pkg/base.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling/pkg/base.jac)

=== "pkg/sibling.jac"
    ```jac title="relative_sibling/pkg/sibling.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling/pkg/sibling.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_sibling/pkg/sibling.jac)

```
relative_sibling/
├── main.jac
└── pkg/
    ├── base.jac       # Defines BASE_VALUE, base_func
    └── sibling.jac    # Uses .base to import
```

??? example "Output"
    ```
    Relative import - BASE_VALUE: Base value
    Relative import - SIBLING_VALUE: Sibling uses Base value
    Relative import - sibling_func(): Sibling calls: Base function
    ```

---

## Parent-Level Imports (`..`)

Import from the parent directory.

> 📂 [**relative_parent/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent)

=== "main.jac"
    ```jac title="relative_parent/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent/main.jac)

=== "project/config.jac"
    ```jac title="relative_parent/project/config.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent/project/config.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent/project/config.jac)

=== "project/sub/deep.jac"
    ```jac title="relative_parent/project/sub/deep.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent/project/sub/deep.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/relative_parent/project/sub/deep.jac)

```
relative_parent/
├── main.jac
└── project/
    ├── config.jac         # Defines CONFIG_VALUE, DEBUG
    └── sub/
        └── deep.jac       # Uses ..config to reach parent
```

??? example "Output"
    ```
    Parent relative - CONFIG_VALUE: Project config
    Parent relative - DEEP_VALUE: Deep module using config: Project config
    Parent relative - deep_func(): Deep function, DEBUG=True
    ```

---

## Mixed Absolute and Relative

You can combine both import styles, but prefer absolute imports for clarity.

> 📂 [**mixed_imports/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports)

=== "main.jac"
    ```jac title="mixed_imports/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports/main.jac)

=== "library/base.jac"
    ```jac title="mixed_imports/library/base.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports/library/base.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports/library/base.jac)

=== "library/extended.jac"
    ```jac title="mixed_imports/library/extended.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports/library/extended.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/mixed_imports/library/extended.jac)

```
mixed_imports/
├── main.jac
└── library/
    ├── base.jac
    └── extended.jac
```

??? example "Output"
    ```
    Mixed - BASE_ID (from import): 1000
    Mixed - EXTENDED_ID: 1001
    Mixed - get_extended_id(): Base: 1000, Extended: 1001
    Mixed - lib_base.BASE_ID (alias): 1000
    ```

---

---

!!! warning "Relative Import Boundaries"
    Relative imports only work within packages. You cannot use `..` to escape beyond your project's root.

!!! success "Best Practice"
    **Default to absolute imports.** They're explicit and don't break when you reorganize code.
