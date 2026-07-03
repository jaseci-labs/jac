"""sys.meta_path finder/loader for jac-bridge shared libraries.

After install_finder() is called, ``import jac_bridge_<mod>`` resolves to
``lib jac_bridge_<mod>.so`` found in the configured search directories.
"""

import importlib.abc
import importlib.machinery
import types as pytypes
from pathlib import Path

from ._blob import parse
from ._codegen import build_module
from ._elf import read_jac_bridge_section

_STEMS = ("lib{}.so", "lib{}.dylib", "{}.dll")
_PREFIX = "jac_bridge_"


def _find_so(lib_name: str, dirs: list[Path]) -> Path | None:
    stems = [s.format(lib_name) for s in _STEMS]
    for d in dirs:
        for stem in stems:
            p = d / stem
            if p.exists():
                return p
    return None


class JacBridgeFinder(importlib.abc.MetaPathFinder):
    def __init__(self, extra_dirs: list[str | Path]) -> None:
        cwd = Path.cwd()
        defaults = [
            cwd / "target" / "release",
            cwd / "target" / "debug",
            cwd.parent / "target" / "release",
            cwd.parent / "target" / "debug",
        ]
        self._dirs = [Path(d) for d in extra_dirs] + defaults

    def find_spec(
        self,
        fullname: str,
        path: object,
        target: object = None,
    ) -> importlib.machinery.ModuleSpec | None:
        if not fullname.startswith(_PREFIX):
            return None
        lib_name = fullname  # e.g. "jac_bridge_regex"
        so = _find_so(lib_name, self._dirs)
        if so is None:
            return None
        return importlib.machinery.ModuleSpec(
            fullname, _Loader(str(so)), origin=str(so)
        )


class _Loader(importlib.abc.Loader):
    def __init__(self, so_path: str) -> None:
        self._so = so_path

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> None:
        return None

    def exec_module(self, module: pytypes.ModuleType) -> None:
        blob = read_jac_bridge_section(self._so)
        meta = parse(blob)
        built = build_module(self._so, meta)
        module.__dict__.update(
            {k: v for k, v in built.__dict__.items() if not k.startswith("__")}
        )
        module.__file__ = self._so
