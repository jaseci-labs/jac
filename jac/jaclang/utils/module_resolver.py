"""Module resolver utilities."""

from __future__ import annotations

import os
import site
import sys
from typing import Optional, Tuple


def get_jac_search_paths(base_path: Optional[str] = None) -> list[str]:
    """Construct a list of paths to search for Jac modules."""
    paths = []
    if base_path:
        paths.append(base_path)
    paths.append(os.getcwd())
    if "JACPATH" in os.environ:
        paths.extend(
            p.strip() for p in os.environ["JACPATH"].split(os.pathsep) if p.strip()
        )
    paths.extend(sys.path)
    site_pkgs = site.getsitepackages()
    if site_pkgs:
        paths.extend(site_pkgs)
    user_site = getattr(site, "getusersitepackages", None)
    if user_site:
        user_dir = user_site()
        if user_dir:
            paths.append(user_dir)
    return list(dict.fromkeys(filter(None, paths)))


# TODO: need to be removed once python modules are fully supported in jac
def get_py_search_paths(base_path: Optional[str] = None) -> list[str]:
    """Construct a list of paths to search for Python modules."""
    paths = []
    if base_path:
        paths.append(base_path)
    paths.append(os.getcwd())
    return list(dict.fromkeys(filter(None, paths)))


def _candidate_from(base: str, parts: list[str]) -> Optional[Tuple[str, str]]:
    candidate = os.path.join(base, *parts)
    if os.path.isdir(candidate):
        if os.path.isfile(os.path.join(candidate, "__init__.jac")):
            return os.path.join(candidate, "__init__.jac"), "jac"
        if os.path.isfile(os.path.join(candidate, "__init__.py")):
            return os.path.join(candidate, "__init__.py"), "py"
    if os.path.isfile(candidate + ".jac"):
        return candidate + ".jac", "jac"
    if os.path.isfile(candidate + ".py"):
        return candidate + ".py", "py"
    return None


def resolve_module(target: str, base_path: str) -> Tuple[str, str]:
    """Resolve module path and infer language."""
    parts = target.split(".")
    level = 0
    while level < len(parts) and parts[level] == "":
        level += 1
    actual_parts = parts[level:]

    for sp in get_jac_search_paths(base_path):
        res = _candidate_from(sp, actual_parts)
        if res:
            return res

    typeshed_paths = get_typeshed_paths()
    for typeshed_dir in typeshed_paths:
        res = _candidate_from_typeshed(typeshed_dir, actual_parts)
        if res:
            # print(f"Found '{target}' in typeshed: {res[0]}")
            return res

    # If not found in any typeshed directory, but typeshed is configured,
    # return a stub .pyi path for type checking.
    stub_pyi_path = os.path.join(typeshed_paths[0], *actual_parts) + ".pyi"
    if os.path.isfile(stub_pyi_path):
        return stub_pyi_path, "pyi"
    base_dir = base_path if os.path.isdir(base_path) else os.path.dirname(base_path)
    for _ in range(max(level - 1, 0)):
        base_dir = os.path.dirname(base_dir)
    res = _candidate_from(base_dir, actual_parts)
    if res:
        return res

    jacpath = os.getenv("JACPATH")
    if jacpath:
        res = _candidate_from(jacpath, actual_parts)
        if res:
            return res
        target_jac = actual_parts[-1] + ".jac"
        target_py = actual_parts[-1] + ".py"
        for root, _, files in os.walk(jacpath):
            if target_jac in files:
                return os.path.join(root, target_jac), "jac"
            if target_py in files:
                return os.path.join(root, target_py), "py"

    return os.path.join(base_dir, *actual_parts), "py"


def infer_language(target: str, base_path: str) -> str:
    """Infer language for target relative to base path."""
    _, lang = resolve_module(target, base_path)
    return lang


def resolve_relative_path(target: str, base_path: str) -> str:
    """Resolve only the path component for a target."""
    path, _ = resolve_module(target, base_path)
    return path


def get_typeshed_paths() -> list[str]:
    """Return the typeshed stubs and stdlib directories if available."""
    # You may want to make this configurable or autodetect
    # Corrected base path calculation: removed one ".."
    base = os.path.join(
        os.path.dirname(__file__),  # jaclang/utils
        "..",  # jaclang
        "vendor",
        "typeshed",  # jaclang/vendor/typeshed
    )
    base = os.path.abspath(base)
    stubs = os.path.join(base, "stubs")
    stdlib = os.path.join(base, "stdlib")
    paths = []
    if os.path.isdir(stubs):
        paths.append(stubs)
    if os.path.isdir(stdlib):
        paths.append(stdlib)
    return paths


def _candidate_from_typeshed(base: str, parts: list[str]) -> Optional[Tuple[str, str]]:
    """Find .pyi files in typeshed, trying module.pyi then package/__init__.pyi."""
    if not parts:  #
        return None

    # This is the path prefix for the module/package, e.g., os.path.join(base, "collections", "abc")
    candidate_prefix = os.path.join(base, *parts)

    # 1. Check for a direct module file (e.g., base/parts.pyi or base/package/module.pyi)
    # Example: parts=["collections", "abc"] -> candidate_prefix = base/collections/abc
    # module_file_pyi = base/collections/abc.pyi
    # Example: parts=["sys"] -> candidate_prefix = base/sys
    # module_file_pyi = base/sys.pyi
    module_file_pyi = candidate_prefix + ".pyi"
    if os.path.isfile(module_file_pyi):
        return module_file_pyi, "pyi"

    # 2. Check if the candidate_prefix itself is a directory (package)
    #    and look for __init__.pyi inside it.
    # Example: parts=["_typeshed"] -> candidate_prefix = base/_typeshed
    # init_pyi = base/_typeshed/__init__.pyi
    if os.path.isdir(candidate_prefix):
        init_pyi = os.path.join(candidate_prefix, "__init__.pyi")
        if os.path.isfile(init_pyi):
            return init_pyi, "pyi"

        # Heuristic for packages where stubs are in a subdirectory of the same name
        # e.g., parts = ["requests"], candidate_prefix = base/requests
        # checks base/requests/requests/__init__.pyi
        # This part of the original heuristic is preserved.
        if parts:  # Ensure parts is not empty for parts[-1]
            inner_pkg_init_pyi = os.path.join(
                candidate_prefix, parts[-1], "__init__.pyi"
            )
            if os.path.isfile(inner_pkg_init_pyi):
                return inner_pkg_init_pyi, "pyi"

    return None


class PythonModuleResolver:
    """Resolver for Python modules with enhanced import capabilities."""

    def resolve_module_path(self, target: str, base_path: str) -> str:
        """Resolve Python module path without importing."""
        caller_dir = (
            base_path if os.path.isdir(base_path) else os.path.dirname(base_path)
        )
        caller_dir = caller_dir if caller_dir else os.getcwd()
        local_py_file = os.path.join(caller_dir, target.split(".")[-1] + ".py")

        if os.path.exists(local_py_file):
            return local_py_file
        else:
            raise ImportError(f"Module '{target}' not found in {caller_dir}")
