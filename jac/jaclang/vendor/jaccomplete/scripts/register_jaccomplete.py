#!/usr/bin/env python3
# JAC_COMPLETE_OK

"""
Register a Python executable for use with the jaccomplete module.

To perform the registration, source the output of this script in your bash shell
(quote the output to avoid interpolation).

Example:

    $ eval "$(register-python-jaccomplete my-favorite-script.py)"

For Tcsh

    $ eval `register-python-jaccomplete --shell tcsh my-favorite-script.py`

For Fish

    $ register-python-jaccomplete --shell fish my-favourite-script.py > ~/.config/fish/my-favourite-script.py.fish
"""

import argparse
import sys

from jaclang.vendor import jaccomplete

# PEP 366
__package__ = "jaccomplete.scripts"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument(
        "--no-defaults",
        dest="use_defaults",
        action="store_false",
        default=True,
        help="when no matches are generated, do not fallback to readline's default completion (affects bash only)",
    )
    parser.add_argument(
        "--complete-arguments",
        nargs=argparse.REMAINDER,
        help="arguments to call complete with; use of this option discards default options (affects bash only)",
    )
    parser.add_argument(
        "-s",
        "--shell",
        choices=("bash", "zsh", "tcsh", "fish", "powershell"),
        default="bash",
        help="output code for the specified shell",
    )
    parser.add_argument(
        "-e", "--external-jaccomplete-script", help="external jaccomplete script for auto completion of the executable"
    )

    parser.add_argument("executable", nargs="+", help="executable to completed (when invoked by exactly this name)")

    jaccomplete.autocomplete(parser)

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    sys.stdout.write(
        jaccomplete.shellcode(
            args.executable, args.use_defaults, args.shell, args.complete_arguments, args.external_jaccomplete_script
        )
    )


if __name__ == "__main__":
    sys.exit(main())
