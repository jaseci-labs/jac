from __future__ import annotations

import hashlib
import importlib.abc
import importlib.machinery
import importlib.util
import logging
import marshal
import os
import sys
import types
from collections.abc import Sequence
from pathlib import Path
from types import ModuleType

import jaclang.jac0 as _jac0_mod
from jaclang.jac0 import compile_jac as _jac0_compile  # noqa: E402
from jaclang.jac0 import discover_impl_files as _jac0_discover_impls  # noqa: E402
from jaclang.jac0core import ext_registry  # noqa: E402
from jaclang.jac0core.cache_paths import get_bootstrap_cache_dir  # noqa: E402

_jac0_source_path = getattr(_jac0_mod, "__file__", "")
_jac0_hash = (
    hashlib.sha256(Path(_jac0_source_path).read_bytes()).digest()
    if _jac0_source_path and os.path.isfile(_jac0_source_path)
    else b""
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")


def _bootstrap_compile(
    file_path: str,
    jac_source: str,
    impl_sources: list[tuple[str, str]] | None = None,
) -> types.CodeType:
    """Compile a bootstrap .jac file, using a marshalled bytecode disk cache."""
    h = hashlib.sha256()
    h.update(sys.version.encode())
    h.update(_jac0_hash)
    h.update(jac_source.encode())
    if impl_sources:
        for src, path in impl_sources:
            h.update(path.encode())
            h.update(src.encode())
    digest = h.hexdigest()[:16]

    base_name = os.path.splitext(os.path.basename(file_path))[0]
    cache_file = get_bootstrap_cache_dir() / f"{base_name}.{digest}.jbc"

    if cache_file.is_file():
        try:
            return marshal.loads(cache_file.read_bytes())  # noqa: S302
        except Exception:
            cache_file.unlink(missing_ok=True)

    py_source = _jac0_compile(jac_source, file_path, impl_sources=impl_sources)
    code = compile(py_source, file_path, "exec")
    try:
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        tmp_file = cache_file.with_suffix(cache_file.suffix + f".{os.getpid()}.tmp")
        try:
            tmp_file.write_bytes(marshal.dumps(code))
            os.replace(tmp_file, cache_file)
        finally:
            tmp_file.unlink(missing_ok=True)
    except OSError:
        pass

    return code


_jac0core_dir = os.path.join(os.path.dirname(__file__), "jac0core")
_modresolver_jac = os.path.join(_jac0core_dir, "modresolver.jac")
with open(_modresolver_jac, encoding="utf-8") as _f:
    _modresolver_code = _bootstrap_compile(_modresolver_jac, _f.read())
_modresolver = types.ModuleType("jaclang.jac0core.modresolver")
_modresolver.__file__ = _modresolver_jac
_modresolver.__package__ = "jaclang.jac0core"
exec(_modresolver_code, _modresolver.__dict__)  # noqa: S102
sys.modules["jaclang.jac0core.modresolver"] = _modresolver
get_jac_search_paths = _modresolver.get_jac_search_paths


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    _jaclang_dir: str = str(Path(__file__).parent)

    _bootstrap_dir: str = str(Path(__file__).parent / "jac0core")

    def _is_bootstrap_jac(self, file_path: str) -> bool:
        """Check if a .jac file should be compiled with jac0 (bootstrap).

        Only .jac files inside jaclang/jac0core/ are bootstrap files — they
        are part of the compiler infrastructure and must be compiled with the
        lightweight jac0 transpiler rather than the full Jac compiler (which
        depends on them). Files in jaclang/compiler/ use full Jac syntax
        and must go through the full compiler.
        """
        return file_path.startswith(self._bootstrap_dir)

    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: ModuleType | None = None,
    ) -> importlib.machinery.ModuleSpec | None:
        """Find the spec for the module."""
        if path is None:
            paths_to_search = get_jac_search_paths()
            module_path_parts = fullname.split(".")
        else:
            paths_to_search = [*path]
            module_path_parts = fullname.split(".")[-1:]

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            if os.path.isdir(candidate_path):
                for init_name in ext_registry.INIT_FILES:
                    init_file = os.path.join(candidate_path, init_name)
                    if os.path.isfile(init_file):
                        return importlib.util.spec_from_file_location(
                            fullname,
                            init_file,
                            loader=self,
                            submodule_search_locations=[candidate_path],
                        )
                if not os.path.isfile(
                    os.path.join(candidate_path, "__init__.py")
                ) and any(ext_registry.is_jac(f) for f in os.listdir(candidate_path)):
                    spec = importlib.machinery.ModuleSpec(
                        fullname, loader=None, is_package=True
                    )
                    spec.submodule_search_locations = [candidate_path]
                    return spec
            for suffix in ext_registry.MODULE_SUFFIXES:
                module_file = candidate_path + suffix
                if os.path.isfile(module_file):
                    return importlib.util.spec_from_file_location(
                        fullname, module_file, loader=self
                    )

        return None

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create the module."""
        return None

    def _exec_bootstrap(self, module: ModuleType, file_path: str) -> None:
        """Execute a bootstrap .jac module using jac0 with bytecode caching.

        Bootstrap modules are part of the jaclang compiler infrastructure.
        They are compiled with the lightweight jac0 transpiler rather than
        the full Jac compiler, which depends on them.
        """
        with open(file_path, encoding="utf-8") as f:
            jac_source = f.read()

        impl_sources: list[tuple[str, str]] = []
        for impl_path in _jac0_discover_impls(file_path):
            with open(impl_path, encoding="utf-8") as f:
                impl_sources.append((f.read(), impl_path))

        code = _bootstrap_compile(file_path, jac_source, impl_sources or None)
        exec(code, module.__dict__)

    def exec_module(self, module: ModuleType) -> None:
        """Execute the module by loading and executing its bytecode.

        This method implements PEP 451's exec_module() protocol, which separates
        module creation from execution. It handles both package (__init__.jac) and
        regular module (.jac/.py) execution.
        """
        if not module.__spec__ or not module.__spec__.origin:
            raise ImportError(
                f"Cannot find spec or origin for module {module.__name__}"
            )

        file_path = module.__spec__.origin

        if self._is_bootstrap_jac(file_path):
            self._exec_bootstrap(module, file_path)
            return

        from jaclang.jac0core.runtime import JacRuntime as Jac

        is_pkg = module.__spec__.submodule_search_locations is not None

        if not module.__name__.startswith("jaclang."):
            Jac.load_module(module.__name__, module)

        compiler = Jac.get_compiler()
        program = Jac.get_program()
        codeobj = compiler.get_bytecode(
            full_target=file_path,
            target_program=program,
        )
        if not codeobj:
            if is_pkg:
                return
            raise ImportError(f"No bytecode found for {file_path}")

        fullname = module.__name__
        stem = os.path.splitext(os.path.basename(file_path))[0]
        for suffix in ext_registry.STEM_REKEY_SUFFIXES:
            if stem.endswith(suffix):
                stem = stem[: -len(suffix)]
                break
        if fullname and stem and fullname != stem and fullname != "__main__":
            prefix = stem + "."
            renamed = {
                fullname + "." + key[len(prefix) :]: program.mtir_map.pop(key)
                for key in list(program.mtir_map)
                if key.startswith(prefix)
            }
            program.mtir_map.update(renamed)

        native_engine, interop_py_funcs = compiler.get_native_interop_setup(
            file_path, program
        )
        if native_engine is not None:
            module.__dict__["__jac_native_engine__"] = native_engine
        if interop_py_funcs is not None:
            module.__dict__["__jac_interop_py_funcs__"] = interop_py_funcs

        exec(codeobj, module.__dict__)

        if native_engine is not None:
            layout = compiler.get_native_layout(file_path, program)
            if layout is not None:
                try:
                    from jaclang.jac0core.native_marshal import (
                        install_native_wrappers,
                    )

                    count = install_native_wrappers(module, native_engine, layout)
                    if count > 0:
                        import logging

                        logging.getLogger(__name__).debug(
                            f"Installed {count} native wrappers for {file_path}"
                        )
                except Exception as e:
                    import logging

                    logging.getLogger(__name__).debug(
                        f"Native wrapper install failed for {file_path}: {e}"
                    )

    def get_code(self, fullname: str) -> object | None:
        """Get the code object for a module.

        This method is required by runpy when using `python -m module`.
        """
        from jaclang.jac0core.runtime import JacRuntime as Jac

        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

        compiler = Jac.get_compiler()
        program = Jac.get_program()

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            if os.path.isdir(candidate_path):
                for init_name in ext_registry.INIT_FILES:
                    init_file = os.path.join(candidate_path, init_name)
                    if os.path.isfile(init_file):
                        return compiler.get_bytecode(
                            full_target=init_file,
                            target_program=program,
                        )
            for suffix in ext_registry.MODULE_SUFFIXES:
                module_file = candidate_path + suffix
                if os.path.isfile(module_file):
                    return compiler.get_bytecode(
                        full_target=module_file,
                        target_program=program,
                    )

        return None
