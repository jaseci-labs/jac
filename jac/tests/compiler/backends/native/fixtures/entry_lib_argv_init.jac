"""Entry-lib init ordering: glob initializers must see argv set by the host.

When a sealed .jab runs via the in-process entry library, the Python host
sets __jac_argc/__jac_argv and calls __jac_shared_init manually. Any module
global whose initializer reads sys.argv must observe the host argv, not 0/null.
"""

import sys;

glob captured_argc: int = len(sys.argv);

def:pub get_captured_argc -> int {
    return captured_argc;
}
