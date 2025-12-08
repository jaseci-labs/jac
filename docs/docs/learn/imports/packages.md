# <span style="color: orange">Packages</span>

Packages in Jac are directories containing `.jac` or `.py` files.

!!! tip "Prefer Absolute Imports"
    Use absolute imports like `import from mypackage.module { X }` for clarity and maintainability.

---

## Simple Package (No `__init__.jac` Required)

Import directly from a package directory. The `__init__.jac` file is **optional**.

> 📂 [**package_no_init/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init)

=== "main.jac"
    ```jac title="package_no_init/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init/main.jac)

=== "mylib/math_utils.jac"
    ```jac title="package_no_init/mylib/math_utils.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init/mylib/math_utils.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init/mylib/math_utils.jac)

=== "mylib/string_utils.jac"
    ```jac title="package_no_init/mylib/string_utils.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init/mylib/string_utils.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_no_init/mylib/string_utils.jac)

```
package_no_init/
├── main.jac
└── mylib/              # No __init__.jac needed!
    ├── math_utils.jac
    └── string_utils.jac
```

??? example "Output"
    ```
    add(3, 5): 8
    multiply(4, 6): 24
    greet('World'): Hello, World!
    ```

---

## Package with Re-exports

Use `__init__.jac` when you want to create a simplified public API.

> 📂 [**package_basic/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic)

=== "main.jac"
    ```jac title="package_basic/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic/main.jac)

=== "mypackage/__init__.jac"
    ```jac title="package_basic/mypackage/__init__.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic/mypackage/__init__.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic/mypackage/__init__.jac)

=== "mypackage/helper.jac"
    ```jac title="package_basic/mypackage/helper.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic/mypackage/helper.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/package_basic/mypackage/helper.jac)

```
package_basic/
├── main.jac
└── mypackage/
    ├── __init__.jac    # Re-exports from helper.jac
    └── helper.jac
```

??? example "Output"
    ```
    Package from-import - HELPER_VALUE: Helper value from package
    Package from-import - helper_func(): Helper function result
    ```

---

## Nested Package Imports

Access deeply nested packages using dot notation.

> 📂 [**nested_packages/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages)

=== "main.jac"
    ```jac title="nested_packages/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/main.jac)

=== "app/__init__.jac"
    ```jac title="nested_packages/app/__init__.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/__init__.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/__init__.jac)

=== "app/constants.jac"
    ```jac title="nested_packages/app/constants.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/constants.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/constants.jac)

=== "app/models/user.jac"
    ```jac title="nested_packages/app/models/user.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/models/user.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/models/user.jac)

=== "app/services/user_service.jac"
    ```jac title="nested_packages/app/services/user_service.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/services/user_service.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/nested_packages/app/services/user_service.jac)

```
nested_packages/
├── main.jac
└── app/
    ├── __init__.jac
    ├── constants.jac
    ├── models/
    │   ├── __init__.jac
    │   └── user.jac
    └── services/
        ├── __init__.jac
        └── user_service.jac
```

??? example "Output"
    ```
    Nested deep - APP_NAME: MyApp
    Nested deep - get_version(): 1.0.0
    Nested deep - create_user('Alice'): User(Alice) from MyApp
    ```

---

## Re-exports with `__init__.jac`

While optional, `__init__.jac` can be used to create a clean public API by re-exporting symbols.

> 📂 [**init_reexport/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport)

=== "main.jac"
    ```jac title="init_reexport/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/main.jac)

=== "mathlib/__init__.jac"
    ```jac title="init_reexport/mathlib/__init__.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/__init__.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/__init__.jac)

=== "mathlib/operations.jac"
    ```jac title="init_reexport/mathlib/operations.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/operations.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/operations.jac)

=== "mathlib/constants.jac"
    ```jac title="init_reexport/mathlib/constants.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/constants.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/constants.jac)

=== "mathlib/calculator.jac"
    ```jac title="init_reexport/mathlib/calculator.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/calculator.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/init_reexport/mathlib/calculator.jac)

```
init_reexport/
├── main.jac
└── mathlib/
    ├── __init__.jac      # Re-exports from submodules
    ├── calculator.jac
    ├── constants.jac
    └── operations.jac
```

??? example "Output"
    ```
    Init reexport - add(5, 3): 8
    Init reexport - subtract(10, 4): 6
    Init reexport - multiply(6, 7): 42
    Init reexport - divide(20, 4): 5.0
    Init reexport - PI: 3.14159
    Init reexport - E: 2.71828
    Init reexport - Calculator.compute(10, 2, 'add'): 12
    ```

!!! tip "When to use `__init__.jac`"
    Use `__init__.jac` when you want to:
    
    - Create a simplified public API
    - Hide internal module structure
    - Add package-level constants or initialization

---

## Sibling Subpackage Imports

Import between sibling subpackages using absolute paths.

> 📂 [**sibling_subpackage/**](https://github.com/Jaseci-Labs/jaseci/tree/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage)

=== "main.jac"
    ```jac title="sibling_subpackage/main.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage/main.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage/main.jac)

=== "top/sub_a/a_module.jac"
    ```jac title="sibling_subpackage/top/sub_a/a_module.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage/top/sub_a/a_module.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage/top/sub_a/a_module.jac)

=== "top/sub_b/b_module.jac"
    ```jac title="sibling_subpackage/top/sub_b/b_module.jac"
    --8<-- "jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage/top/sub_b/b_module.jac"
    ```
    [🔗 View on GitHub](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/tests/fixtures/imports_fixture/sibling_subpackage/top/sub_b/b_module.jac)

```
sibling_subpackage/
├── main.jac
└── top/
    ├── __init__.jac
    ├── sub_a/
    │   ├── __init__.jac
    │   └── a_module.jac
    └── sub_b/
        ├── __init__.jac
        └── b_module.jac    # Can import from sub_a
```

??? example "Output"
    ```
    Sibling subpkg - A_VALUE: A module value
    Sibling subpkg - a_func(): A function
    Sibling subpkg - B_VALUE: B uses A module value
    Sibling subpkg - b_func(): B calls: A function
    ```

---

## Key Takeaways

| Concept | Description |
|---------|-------------|
| **Packages** | Directories with `.jac` or `.py` files |
| **`__init__.jac`** | Optional, useful for re-exports |
| **Absolute imports** | `import from pkg.subpkg.module { X }` |
| **Nested access** | Use dot notation for deep packages |

!!! success "Best Practice"
    Use **absolute imports** with full package paths: `import from app.models.user { User }`. This is explicit and avoids ambiguity.
