Jac provides flexible module importing capabilities that extend Python's import system with additional convenience features and compile-time source inclusion. The language supports three distinct import mechanisms for different use cases.

#### Standard Import

Standard imports bring entire modules into the current namespace:

```jac
import math;
import my_utils.helpers as utils;
```

The compiler automatically detects module types: paths ending with `.jac` are treated as Jac modules, while other paths are forwarded to Python's import machinery. The `as` keyword provides aliasing functionality identical to Python's behavior.

#### Selective Import with Curly Braces

Jac enables selective importing using curly brace syntax borrowed from ES modules:

```jac
import from my_pkg.subpkg { foo, bar as baz };
```

This syntax avoids ambiguity in comma-separated import lists while maintaining visual consistency with Jac's block delimiters. The curly brace notation clearly distinguishes between multiple import paths and multiple items from a single path.

#### Include Statement

The `include` statement imports all exported symbols from the target module into the current namespace:

```jac
include os.path;
```

Include operations are functionally equivalent to Python's `from target import *` syntax, bringing all public symbols from the target module into the current scope. This mechanism is particularly useful for importing helper functions from Python files or accessing all symbols from Jac modules without explicit enumeration, while maintaining clean namespace organization.

#### Module Resolution

Jac follows a systematic approach to module resolution:

1. **Relative paths** are resolved relative to the current file's location
2. **Absolute module names** are searched first in `JAC_PATH`, then in Python's `sys.path`
3. **Module caching** ensures each file is processed only once per build cycle

#### Interface and Implementation Separation

Jac's `impl` keyword enables separation of interface declarations from implementation details. Import statements bring only the interface unless the implementation file is found on the module path, supporting lightweight static analysis and efficient incremental builds.

#### Integration with Object-Spatial Programming

Import statements work seamlessly with Jac's object-spatial constructs, enabling modular organization of walkers, nodes, and edges across multiple files while maintaining the topological relationships essential for graph-based computation.

```jac
import from graph_utils { PathFinder, DataNode }
import spatial_algorithms as algorithms;

walker MyWalker {
    can traverse with entry {
        finder = PathFinder();
        path = finder.find_path(here, target);
        visit path;
    }
}
```

Organized imports enable the Jac compiler to analyze dependencies effectively and optimize distributed execution graphs for object-spatial operations.

#### Application Bundling

Jac programs can be packaged together with their dependencies into a single
deployable bundle using the toolchain.  Bundling resolves imports at build time
and embeds module contents so that applications can be distributed without
external file dependencies.
