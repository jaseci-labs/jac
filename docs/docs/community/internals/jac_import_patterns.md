# Jac Client Import Patterns - Implementation Status

This document provides a comprehensive reference of all JavaScript/ECMAScript import patterns and their Jac equivalents, showing which patterns are currently supported.

## Import Pattern Support Matrix

| Category | JavaScript Pattern | Jac Pattern | Status | Generated JavaScript | Notes |
|----------|-------------------|-------------|--------|---------------------|-------|
| **Category 1: Named Imports** |
| Single named | `import { useState } from 'react'` | `cl import from react { useState }` |  Working | `import { useState } from "react";` | |
| Multiple named | `import { map, filter } from 'lodash'` | `cl import from lodash { map, filter }` |  Working | `import { map, filter } from "lodash";` | |
| Named with alias | `import { get as httpGet } from 'axios'` | `cl import from axios { get as httpGet }` |  Working | `import { get as httpGet } from "axios";` | |
| Mixed named + aliases | `import { createApp, ref as reactive } from 'vue'` | `cl import from vue { createApp, ref as reactive }` |  Working | `import { createApp, ref as reactive } from "vue";` | |
| **Category 1: Relative Paths** |
| Single dot (current) | `import { helper } from './utils'` | `cl import from .utils { helper }` |  Working | `import { helper } from "./utils";` | |
| Double dot (parent) | `import { format } from '../lib'` | `cl import from ..lib { format }` |  Working | `import { format } from "../lib";` | |
| Triple dot (grandparent) | `import { settings } from '../../config'` | `cl import from ...config { settings }` |  Working | `import { settings } from "../../config";` | Supports any number of dots |
| **Category 1: Module Prefix** |
| With jac: prefix | `import { renderJsxTree } from 'jac:client_runtime'` | `cl import from jac:client_runtime { renderJsxTree }` |  Working | `import { renderJsxTree } from "client_runtime";` | Prefix stripped for resolution |
| **Category 1: String Literal Imports** |
| Hyphenated packages | `import { render } from 'react-dom'` | `cl import from "react-dom" { render }` |  Working | `import { render } from "react-dom";` | Use string literals for package names with hyphens |
| Multiple hyphens | `import { BrowserRouter } from 'react-router-dom'` | `cl import from "react-router-dom" { BrowserRouter }` |  Working | `import { BrowserRouter } from "react-router-dom";` | Works with any special characters |
| **Category 1: Path Alias Imports** |
| Alias with wildcard | `import { Button } from '@components/Button'` | `cl import from "@components/Button" { Button }` |  Working | `import { Button } from "@components/Button";` | Requires `[plugins.client.paths]` in jac.toml |
| Exact alias | `import { constants } from '@shared'` | `cl import from "@shared" { constants }` |  Working | `import { constants } from "@shared";` | Maps to a single target path |
| **Category 2: Default Imports** |
| Default import | `import React from 'react'` | `cl import from react { default as React }` |  Working | `import React from "react";` | Must use `cl` prefix |
| Default with relative | `import Component from './Button'` | `cl import from .Button { default as Component }` |  Working | `import Component from "./Button";` | |
| **Category 4: Namespace Imports** |
| Namespace import | `import * as React from 'react'` | `cl import from react { * as React }` |  Working | `import * as React from "react";` | Must use `cl` prefix |
| Namespace with relative | `import * as utils from './utils'` | `cl import from .utils { * as utils }` |  Working | `import * as utils from "./utils";` | |
| **Category 3: Mixed Imports** |
| Default + Named | `import React, { useState } from 'react'` | `cl import from react { default as React, useState }` |  Working | `import React, { useState } from "react";` | Order matters: default first |
| Default + Namespace | `import React, * as All from 'react'` | `cl import from react { default as React, * as All }` |  Working | `import React, * as All from "react";` | Valid JS (rarely used) |
| Named + Namespace | `import * as _, { map } from 'lodash'` | `cl import from lodash { * as _, map }` | ️ Generates | `import * as _, { map } from "lodash";` | **Invalid JavaScript** - not recommended |

## Unsupported Patterns

| Pattern | Why Not Supported | Workaround |
|---------|-------------------|------------|
| `default` or `*` in non-`cl` imports | No Python equivalent for default/namespace exports | Use `cl import` instead |
| Side-effect only imports | Not yet implemented | Use regular Python import for now |
| Dynamic imports | Runtime feature, not syntax | Use JavaScript directly or add to roadmap |
| Import assertions (JSON, CSS) | Stage 3 proposal, specialized | May add in future |

## Usage Rules

### 1. Client Import Requirement

- **Default imports** (`default as Name`) and **namespace imports** (`* as Name`) **MUST** use `cl` prefix
- **Named imports** work with or without `cl` prefix (but `cl` generates JavaScript)

### 2. Syntax Patterns

```jac
#  Correct Usage
cl import from react { useState }                    # Category 1: Named
cl import from react { default as React }            # Category 2: Default
cl import from react { * as React }                  # Category 4: Namespace
cl import from react { default as React, useState }  # Category 3: Mixed
```

```
#  Incorrect Usage (these would fail parsing or generate invalid JS)
import from react { default as React }   # Error: default requires cl
import from lodash { * as _ }            # Error: namespace requires cl
cl import from lodash { * as _, map }    # Generates invalid JS
```

### 3. String Literal Imports for Special Characters

For package names containing special characters (hyphens, @-scopes, etc.), use string literals:

```jac
#  Correct Usage - String literals for hyphenated packages
cl import from "react-dom" { render }
cl import from "styled-components" { default as styled }
cl import from "react-router-dom" { BrowserRouter, Route }
cl import from "date-fns" { format, parse }
```

```
#  Incorrect Usage - Without quotes (would fail parsing)
cl import from react-dom { render }  # Error: hyphen not allowed in identifier
```

**When to use string literals:**

- Package names with hyphens: `react-dom`, `styled-components`, `react-router-dom`, `date-fns`
- Package names with special characters that aren't valid in identifiers
- Any package name that would cause a syntax error without quotes

**Note:** String literals work with all import types (named, default, namespace, mixed)

### 4. Path Alias Imports

Path aliases let you define short prefixes (like `@components`) that map to project directories. Configure them in `jac.toml`:

```toml
[plugins.client.paths]
"@components/*" = "./components/*"
"@utils/*" = "./utils/*"
"@shared" = "./shared/index"
```

Then use them in imports:

```jac
cl {
    import from "@components/Button" { Button }
    import from "@utils/format" { formatDate }
    import from "@shared" { constants }
}
```

Aliases are resolved by:

- **Vite** (`resolve.alias`) for bundling
- **TypeScript** (`compilerOptions.paths`) for IDE support
- **Jac module resolver** for compilation

### 5. Relative Path Conversion

Jac uses Python-style dots for relative imports, which are automatically converted to JavaScript format:

| Jac Syntax | JavaScript Output | Description |
|------------|-------------------|-------------|
| `.utils` | `"./utils"` | Current directory |
| `..lib` | `"../lib"` | Parent directory |
| `...config` | `"../../config"` | Grandparent directory |
| `....deep` | `"../../../deep"` | Great-grandparent directory |

## Implementation Details

### Grammar

```lark
import_path: (NAME COLON)? (dotted_name | STRING) (KW_AS NAME)?
import_item: (KW_DEFAULT | STAR_MUL | named_ref) (KW_AS NAME)?
```

### Type Handling

- Regular named imports: `ModuleItem.name` is `Name`
- Default imports: `ModuleItem.name` is `Token(KW_DEFAULT)`
- Namespace imports: `ModuleItem.name` is `Token(STAR_MUL)`
- String literal imports: `ModulePath.path` contains a single `String` node

### Validation

- `pyast_gen_pass.py`:
  - Logs error if `default` or `*` used without `cl`
  - Logs error if string literal imports used without `cl` (Python doesn't support string literal module names)
- `sym_tab_build_pass.py`: Only alias added to symbol table for default/namespace; skips symbol creation for String paths
- `esast_gen_pass.py`: Generates appropriate `ImportSpecifier`, `ImportDefaultSpecifier`, or `ImportNamespaceSpecifier`
- `parser.py`: Handles both `dotted_name` (list of Names) and `STRING` in import paths
- `unitree.py`: `ModulePath.dot_path_str` extracts string value from String literals

## Testing

All patterns tested and verified in:

- `test_js_generation.py::test_category1_named_imports_generate_correct_js`
- `test_js_generation.py::test_category2_default_imports_generate_correct_js`
- `test_js_generation.py::test_category4_namespace_imports_generate_correct_js`
- `test_js_generation.py::test_hyphenated_package_imports_generate_correct_js`
- `test_pyast_gen_pass.py::test_string_literal_import_requires_cl`
- `test_pyast_gen_pass.py::test_string_literal_import_works_with_cl`

## Examples

### Full Feature Demo

```jac
cl {
    # Named imports
    import from react { useEffect, useRef }
    import from lodash { map as mapArray, filter }

    # Default imports
    import from react { default as React }
    import from axios { default as axios }

    # Namespace imports
    import from "date-fns" { * as DateFns }
    import from .utils { * as Utils }

    # String literal imports (for hyphenated packages)
    import from "react-dom" { render, hydrate }
    import from "styled-components" { default as styled }
    import from "react-router-dom" { BrowserRouter, Route }

    # Mixed imports
    import from react { default as React, useEffect }

    # Relative paths
    import from .components.Button { default as Button }
    import from ..lib.helpers { formatDate }
    import from ...config.constants { API_URL }

    def MyComponent() {
        # Reactive state - auto-generates useState
        has count: int = 0;

        now = DateFns.format(Date.now());
        axios.get(API_URL);

        return count;
    }
}
```

> **Note:** Inside `cl {}` blocks and `.cl.jac` files, use `has` variables for reactive state instead of explicit `useState` calls. The compiler automatically generates `const [count, setCount] = useState(0);`, auto-injects the `useState` import from `@jac-client/utils`, and transforms assignments to setter calls.

### Generated JavaScript Output

```javascript
import { useState } from "@jac-client/utils";  // Auto-injected for `has` variables
import { useEffect, useRef } from "react";
import { map as mapArray, filter } from "lodash";
import React from "react";
import axios from "axios";
import * as DateFns from "date-fns";
import * as Utils from "./utils";
import { render, hydrate } from "react-dom";
import styled from "styled-components";
import { BrowserRouter, Route } from "react-router-dom";
import React, { useEffect } from "react";
import Button from "./components.Button";
import { formatDate } from "../lib.helpers";
import { API_URL } from "../../config.constants";

function MyComponent() {
  // Generated from `has count: int = 0;` (useState import auto-injected from @jac-client/utils)
  const [count, setCount] = useState(0);
  now = DateFns.format(Date.now());
  axios.get(API_URL);
  return count;
}
```

## Status Summary

- **Category 1 (Named Imports)**: Fully implemented and tested
- **Category 2 (Default Imports)**: Fully implemented and tested
- **Category 3 (Mixed Imports)**: Working for default+named and default+namespace
- **Category 4 (Namespace Imports)**: Fully implemented and tested
- **Relative Paths**: Full support with automatic conversion
- **Path Aliases**: Full support via `[plugins.client.paths]` in jac.toml (Vite, TypeScript, and module resolver)
- **String Literal Imports**: Full support for hyphenated package names (react-dom, styled-components, etc.)
- ️ **Named + Namespace Mix**: Generates but produces invalid JavaScript

**Last Updated**: 2025-10-23
