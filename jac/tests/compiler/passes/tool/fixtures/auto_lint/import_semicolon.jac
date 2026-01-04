"""Test fixture for removing semicolons from import from {} style imports."""

# Module-level imports (correct - no semicolons)
import from os { path }
import from collections { defaultdict }

# Statement-level imports should keep their semicolons
import json;
import math;

obj MyClass {
    has value: int = 0;
}

def main {
    # Import inside a function - might accidentally have semicolon
    import from typing { List };
    import from sys { argv };

    x = 5;
    print(x);
}
