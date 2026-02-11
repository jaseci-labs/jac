"""Category 1: Named Imports - Test fixture for import pattern validation.

This fixture tests the following patterns from the proposal:
1. Single named import: import { useState } from 'react'
2. Multiple named imports: import { a, b, c } from 'lib'
3. Named import with alias: import { foo as bar } from 'lib'
"""

cl {
    # Single named import
    import from react { useState }

    # Multiple named imports
    import from lodash { map, filter, reduce }

    # Named import with alias
    import from axios { get as httpGet }

    # Mixed named imports and aliases
    import from vue { createApp, ref as reactive, computed }

    # Relative path imports
    import from .utils { helper }
    import from ..lib { formatter as format }
    import from ...config { settings }

    # String path notation (@jac/runtime)
    import from "@jac/runtime" { renderJsxTree, jacLogin, jacLogout }

    # Using imported functions in a simple client function
    def example_usage()  -> int {
        count = 0;
        httpGet("/api/data");
        jacLogin("user", "pass");
        return count;
    }
}
