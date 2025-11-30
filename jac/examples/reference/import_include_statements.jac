"""Import/Include statements: Module imports with various patterns."""

# Simple imports
import os;
import sys, json;

# Import with alias
import datetime as dt;

# Import from with specific items
import from math { sqrt, pi, log as logarithm }

# Import from with aliases and trailing comma
import from collections {
    defaultdict as ddict,
    Counter,
}

# Relative imports (when in a package)
# import from . { sibling_module };
# import from .. { parent_module };
# import from ... { grandparent_module };
with entry {
    print(f"CWD: {os.getcwd()}");
    print(f"Sqrt(16): {sqrt(16)}");
    print(f"Pi: {pi}");
    print(f"Log(10): {logarithm(10)}");
    print(f"Now: {dt.datetime.now().year}");
}
