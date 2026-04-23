"""PyInstaller adapter — datas + hiddenimports for jaclang and user Jac packages.

Activates the path-level ``.jac`` hook here so it's scoped to the build-time
analyzer process only.
"""

import os
import sys

import _jac_finder
from PyInstaller.utils.hooks import collect_submodules

from jaclang.packaging import iter_jaclang_data_files, iter_user_jac_sources

_jac_finder._install_jac_path_hook()


def _search_dirs() -> list[str]:
    """cwd + sys.argv script/spec paths + sys.path dirs."""
    dirs = [os.getcwd()]
    for arg in sys.argv:
        if not arg or arg.startswith("-"):
            continue
        p = os.path.abspath(arg)
        dirs.append(os.path.dirname(p) if os.path.isfile(p) else p)
    dirs.extend(p for p in sys.path if p and os.path.isdir(p))
    return dirs


hiddenimports = ["_jac_finder"] + collect_submodules("jaclang")
datas = list(iter_jaclang_data_files()) + list(iter_user_jac_sources(_search_dirs()))
