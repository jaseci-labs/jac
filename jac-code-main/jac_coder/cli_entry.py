"""CLI entry point for `jac-coder` command."""

import os
import subprocess
import sys


def main():
    # Find the project root (where cli.jac lives)
    pkg_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(pkg_dir)
    cli_jac = os.path.join(project_root, "cli.jac")

    if not os.path.exists(cli_jac):
        print("Error: cli.jac not found. Run from the jac-coder project directory.")
        sys.exit(1)

    # Set JACCODER_ROOT so tools can find data/ directory regardless of CWD
    os.environ["JACCODER_ROOT"] = project_root

    sys.exit(subprocess.call(["jac", cli_jac] + sys.argv[1:]))


if __name__ == "__main__":
    main()
