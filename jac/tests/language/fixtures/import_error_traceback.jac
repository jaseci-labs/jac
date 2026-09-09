"""Test file to verify error traceback shows source code context.

The imported module does not exist on the import path, so this fails at run
time with a traceback. (A missing relative import is a compile error, E1134.)
"""

import from jac_nonexistent_module { Something }

def main {
    print("This should never execute");
}
