"""Collection of passes for Jac IR.

This module uses lazy imports to enable converting passes to Jac.
The .jac passes are loaded lazily via __getattr__ to avoid circular imports.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

# Passes that are imported lazily to allow .jac conversion
# These are loaded on first access via __getattr__
_LAZY_PASSES = {
    "CFGBuildPass": ".cfg_build_pass",
    "MTIRGenPass": ".mtir_gen_pass",
    "PyastBuildPass": ".pyast_load_pass",
    "PyJacAstLinkPass": ".pyjac_ast_link_pass",
    "SemDefMatchPass": ".sem_def_match_pass",
    "TypeCheckPass": ".type_checker_pass",
}

# Cache for lazily loaded passes
_lazy_cache: dict[str, type] = {}

if TYPE_CHECKING:
    from .cfg_build_pass import CFGBuildPass as CFGBuildPass
    from .mtir_gen_pass import MTIRGenPass as MTIRGenPass
    from .pyast_load_pass import PyastBuildPass as PyastBuildPass
    from .pyjac_ast_link_pass import PyJacAstLinkPass as PyJacAstLinkPass
    from .sem_def_match_pass import SemDefMatchPass as SemDefMatchPass
    from .type_checker_pass import TypeCheckPass as TypeCheckPass


def __getattr__(name: str) -> type:
    """Lazily load passes on first access.

    All lazy passes are .jac files - Python passes are imported directly from pycore.
    """
    if name in _lazy_cache:
        return _lazy_cache[name]

    if name in _LAZY_PASSES:
        import importlib.util
        import os
        import sys

        module_name = _LAZY_PASSES[name]
        base_name = module_name.lstrip(".")

        # Load .jac file
        package_dir = os.path.dirname(__file__)
        jac_file = os.path.join(package_dir, f"{base_name}.jac")
        full_module_name = f"{__name__}.{base_name}"

        if os.path.exists(jac_file):
            # Use Jac import mechanism via the meta importer
            from jaclang.meta_importer import JacMetaImporter
            from jaclang.pycore.runtime import JacRuntime as Jac

            # Create module spec and load
            importer = JacMetaImporter()
            spec = importlib.util.spec_from_file_location(
                full_module_name, jac_file, loader=importer
            )
            if spec and spec.loader:
                module = importlib.util.module_from_spec(spec)
                sys.modules[full_module_name] = module
                Jac.load_module(full_module_name, module)
                spec.loader.exec_module(module)
            else:
                raise ImportError(f"Could not load Jac module: {jac_file}")
        else:
            raise ImportError(f"Jac module not found: {jac_file}")

        cls = getattr(module, name)
        _lazy_cache[name] = cls
        return cls

    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    "CFGBuildPass",
    "MTIRGenPass",
    "PyastBuildPass",
    "PyJacAstLinkPass",
    "SemDefMatchPass",
    "TypeCheckPass",
]
