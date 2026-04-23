"""PyInstaller adapter — translates ``jaclang.packaging`` into datas/hiddenimports.

Also activates the path-level ``.jac`` hook here (not from jaclang's init)
so it's scoped to the build-time analyzer process only.
"""

import os
import sys

import _jac_finder
from PyInstaller.utils.hooks import collect_submodules

from jaclang.packaging import find_packages, iter_jaclang_data_files

_jac_finder._install_jac_path_hook()

hiddenimports = ["_jac_finder"] + collect_submodules("jaclang")
datas = list(iter_jaclang_data_files())


def _user_project_search_dirs() -> list[str]:
    """cwd + sys.argv entries + sys.path dirs — catches the project root
    across spec-file builds, CI wrappers, and pytest-xdist workers."""
    dirs: list[str] = [os.getcwd()]
    for arg in sys.argv:
        if not arg or arg.startswith("-"):
            continue
        abs_arg = os.path.abspath(arg)
        if os.path.isfile(abs_arg):
            dirs.append(os.path.dirname(abs_arg))
        elif os.path.isdir(abs_arg):
            dirs.append(abs_arg)
    dirs.extend(p for p in sys.path if p and os.path.isdir(p))
    return dirs


for _pkg in find_packages(_user_project_search_dirs()):
    for _src in _pkg.iter_sources():
        datas.append((_src.path, os.path.dirname(_src.relative_path)))
