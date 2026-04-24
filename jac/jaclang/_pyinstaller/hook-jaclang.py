"""PyInstaller hook: datas + hiddenimports for jaclang and user Jac packages."""

import os
import sys

from PyInstaller.utils.hooks import collect_submodules

from jaclang.packaging import iter_jaclang_data_files, iter_user_jac_sources


def _search_dirs() -> list[str]:
    """cwd + sys.argv script/spec paths + sys.path dirs."""
    dirs = [os.getcwd()]
    for arg in sys.argv:
        if not arg or arg.startswith("-"):
            continue
        p = os.path.abspath(arg)
        if os.path.isfile(p):
            dirs.append(os.path.dirname(p))
        elif os.path.isdir(p):
            dirs.append(p)
    dirs.extend(p for p in sys.path if p and os.path.isdir(p))
    return dirs


hiddenimports = ["_jac_finder"] + collect_submodules("jaclang")
datas = list(iter_jaclang_data_files()) + list(iter_user_jac_sources(_search_dirs()))
