**Import and Include Statements**

Import statements control module dependencies, allowing code to access functionality from other modules and packages. Jac supports various import patterns including simple imports, aliases, selective imports, and relative imports.

**Simple Imports**

Lines 4-5 demonstrate basic import patterns. Line 4: Imports a single module (`os`)
Line 5: Imports multiple modules in one statement, comma-separated (`sys`, `json`)

After importing, all module members are accessible via dot notation: `os.getcwd()`, `sys.path`, `json.dumps()`.

**Import with Alias**

Line 8 shows renaming a module during import. The module is imported but referenced by the shorter name `dt` instead of `datetime`. Use this for:
- Shorter names (convenience)
- Avoiding naming conflicts
- Conventional abbreviations

Line 26 demonstrates usage: `dt.datetime.now().year`

**Import From with Specific Items**

Line 11 demonstrates selective imports using `import from`. This syntax:
- Imports only specific items from a module (`sqrt`, `pi`, `log`)
- Can alias imported items (`log as logarithm`)
- Uses curly braces `{ }` to group the imports
- Makes imported items directly accessible without module prefix

Lines 23-25 show usage: `sqrt(16)`, `pi`, `logarithm(10)` - no `math.` prefix needed.

**Import From with Trailing Comma**

Line 14 shows that trailing commas are allowed. The trailing comma after `Counter` is valid and useful for version control (adding/removing items creates cleaner diffs).

**Relative Imports**

Lines 17-19 (commented) show relative import syntax for package-relative imports. The dot notation indicates package hierarchy:
- `.` - Current package
- `..` - Parent package
- `...` - Grandparent package

Each additional dot goes one level up in the package hierarchy.

**Import Patterns Summary**

| Pattern | Syntax | Access Method | Example Line |
|---------|--------|---------------|--------------|
| Simple | `import module` | `module.item` | 4 |
| Multiple | `import mod1, mod2` | `mod1.item`, `mod2.item` | 5 |
| Aliased | `import module as alias` | `alias.item` | 8 |
| Selective | `import from module { items }` | `item` directly | 11 |
| Aliased items | `import from module { item as alias }` | `alias` directly | 11 |
| Relative | `import from . { module }` | `module.item` | 17-19 |

**Import Flow Diagram**

```mermaid
flowchart TD
    Start([Import Statement]) --> Type{Import<br/>Type?}
    Type -->|Simple| Simple[import module]
    Type -->|From| From[import from module]
    Simple --> Alias1{With<br/>Alias?}
    Alias1 -->|Yes| UseAlias1[module as alias]
    Alias1 -->|No| UseDirect1[Use module.item]
    From --> Items{Specific<br/>Items?}
    Items -->|Yes| SelectItems["Curly braces with items"]
    Items -->|No| ImportAll[Import all]
    SelectItems --> Alias2{Item<br/>Aliases?}
    Alias2 -->|Yes| ItemAlias[item as alias]
    Alias2 -->|No| DirectItem[Use item directly]
    UseAlias1 --> Done([Module Available])
    UseDirect1 --> Done
    ItemAlias --> Done
    DirectItem --> Done
    ImportAll --> Done
```

**Usage Examples**

Lines 21-27 demonstrate using imported items:

**When to Use Each Pattern**

**Simple import** - Best for:
- Need many items from the module
- Module name is short and clear
- Standard library modules

**Aliased import** - Best for:
- Long module names
- Conventional abbreviations (numpy as np, pandas as pd)
- Avoiding naming conflicts

**Selective import** - Best for:
- Only need specific items
- Frequently used functions
- Cleaner code without module prefix

**Relative import** - Best for:
- Package-internal imports
- Maintaining package structure
- Avoiding absolute path dependencies

**Import Best Practices**

**At module top:**

**Group by category:**

**Use aliases for clarity:**

**Import only what you need:**

**Key Points**

1. Simple imports require module prefix for access
2. `import from` enables direct access to specific items
3. Aliases improve code readability and avoid conflicts
4. Trailing commas are allowed in import lists
5. Relative imports use dot notation for package hierarchy
6. Multiple modules can be imported in one statement
7. Items can be individually aliased in `import from` syntax
