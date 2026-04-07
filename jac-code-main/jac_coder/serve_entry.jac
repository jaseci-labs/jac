"""Entry point for `jac-coder-server` command.

Finds server.jac inside the installed jac_coder package and runs it with
`jac run`. Works both in dev and after pip install.
"""

import os;
import sys;
import subprocess;

def main() -> None {
    pkg_dir = os.path.dirname(os.path.abspath(__file__));
    server_jac = os.path.join(pkg_dir, "server.jac");

    if not os.path.exists(server_jac) {
        print("Error: server.jac not found at " + server_jac);
        sys.exit(1);
    }

    sys.exit(subprocess.call(["jac", "run", server_jac] + sys.argv[1:]));
}

with entry {
    main();
}
