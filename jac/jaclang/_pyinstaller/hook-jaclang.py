"""PyInstaller adapter — datas + hiddenimports for jaclang and user Jac packages.

Activates the path-level ``.jac`` hook here so it's scoped to the build-time
analyzer process only.
"""

import os
import sys

import _jac_finder
from PyInstaller.utils.hooks import collect_submodules

import jaclang as _jaclang
from jaclang.packaging import iter_jaclang_data_files, iter_user_jac_sources

_jac_finder._install_jac_path_hook()

# Under PEP 660 editable installs (``pip install -e``), jaclang is reachable
# via a ``sys.meta_path`` finder only — its source dir is never added to
# ``sys.path``. PyInstaller's modulegraph uses path-based discovery
# exclusively and would otherwise fail every ``jaclang.<sub>`` hidden import
# lookup. Surface the source parent on ``sys.path`` so path-based lookup
# resolves. No-op on wheel installs (site-packages is already on sys.path).
_jaclang_parent = os.path.dirname(os.path.dirname(_jaclang.__file__))
if _jaclang_parent and _jaclang_parent not in sys.path:
    sys.path.insert(0, _jaclang_parent)


def _search_dirs() -> list[str]:
    """cwd + sys.argv script/spec paths + sys.path dirs (existing dirs only)."""
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


_dirs = _search_dirs()
_jaclang_datas = list(iter_jaclang_data_files())
_user_datas = list(iter_user_jac_sources(_dirs))

print(
    f"[jaclang._pyinstaller] cwd={os.getcwd()!r} "
    f"search_dirs={_dirs} "
    f"user_jac_sources={len(_user_datas)}",
    file=sys.stderr,
)

hiddenimports = ["_jac_finder"] + collect_submodules("jaclang")
datas = _jaclang_datas + _user_datas
