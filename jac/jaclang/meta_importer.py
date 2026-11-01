"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
The host never compiles Jac: every module it imports is a code object the
kernel made, read from a sealed image or asked of the kernel (which serves it
from its caches or compiles it). The kernel loads first
(``jaclang.jac0core.stage0.boot_kernel``), so a process without a usable
kernel stops here with an error naming ``jac native build kernel``.

Until the Jac runtime and ``JacCompiler`` have loaded, modules come from the
sealed image's bytecode or straight from the kernel module; after that, every
import goes through ``JacCompiler.get_bytecode``, which also restores the
products a module carries (MTIR, native interop, client artifacts).
"""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import importlib.util
from importlib.abc import Loader, MetaPathFinder
from importlib.machinery import ModuleSpec
import logging
import os
import sys
import types
from collections.abc import Sequence
from pathlib import Path
from types import ModuleType

from jaclang.jac0core import ext_registry  # noqa: E402
from jaclang.jac0core import sealed as _sealed  # noqa: E402
from jaclang.jac0core import stage0 as _stage0  # noqa: E402

# Inline logging config (previously in jaclang.compiler.driver.log)
logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")

_PACKAGE_ROOT = str(Path(__file__).resolve().parent)
_RUNTIME_MODULES = ("jaclang.runtime.runtime", "jaclang.compiler.driver.compiler")


class JacSourceCompileError(ImportError):
    """A .jac module was found on disk but its source failed to compile.

    Distinct from a module that is simply absent (``ModuleNotFoundError``) or
    only partially initialized mid-bootstrap (``cannot import name ...``): the
    file resolved, so this is a defect in that file, never a condition to
    degrade around silently. It subclasses ``ImportError`` so existing handlers
    keep their behavior; callers that must not degrade -- the compiler's own
    pass-schedule builders -- opt in by inspecting ``jac_source_path``.
    """

    def __init__(self, message: str, jac_source_path: str) -> None:
        """Record the .jac file whose compile produced this failure."""
        super().__init__(message)
        self.jac_source_path = jac_source_path


def _module_scoped_alerts(program: object, file_path: str) -> list:
    """Compile errors recorded against file_path or one of its annexes.

    The program's diagnostic ledger owns the rule (an error in `foo.impl.jac`,
    `foo.impl/bar.jac` or `impl/foo.impl.jac` is `foo.jac`'s own), so the
    importer reports exactly what the compiler retains and drops.
    """
    return program.diags.owned_errors(file_path)


def _runtime_ready() -> bool:
    """Whether the Jac runtime and JacCompiler have finished loading."""
    for name in _RUNTIME_MODULES:
        module = sys.modules.get(name)
        spec = getattr(module, "__spec__", None) if module is not None else None
        if spec is None or getattr(spec, "_initializing", False):
            return False
    return True


def _diagnostic_line(diagnostic: dict) -> str:
    span = diagnostic["span"]
    return (
        f"{span['path']}:{span['line']}:{span['col']}: "
        f"{diagnostic['code']} {diagnostic['message']}"
    )


def _kernel_code(file_path: str) -> types.CodeType:
    """Ask the kernel for a module's code object, before the runtime loads."""
    kernel = _stage0.boot_kernel()
    request = {
        "paths": [file_path],
        "search_paths": list(sys.path),
        "package_root": _PACKAGE_ROOT,
        "products": ["bytecode"],
    }
    try:
        result = kernel.compile(request)
    except kernel.KernelError as exc:
        raise JacSourceCompileError(f"{file_path}: {exc}", file_path) from exc
    if result["errors"]:
        details = "\n".join(_diagnostic_line(d) for d in result["errors"])
        raise JacSourceCompileError(f"{file_path} failed to compile:\n{details}", file_path)
    real = os.path.realpath(file_path)
    for unit in result["units"]:
        if os.path.realpath(unit["path"]) == real:
            if unit["code"] is None:
                raise JacSourceCompileError(
                    f"the kernel made no bytecode for {file_path}", file_path
                )
            return unit["code"]
    raise JacSourceCompileError(f"the kernel compiled no unit for {file_path}", file_path)


def _boot_module(name: str, rel: str) -> ModuleType:
    """Load one jaclang module the importer itself needs, from the image or the kernel."""
    found = _sealed.find_module(name)
    origin = os.path.join(_PACKAGE_ROOT, rel)
    code = None
    if found is not None:
        code = found[0].module_code(name)
        origin = found[0].virtual_origin(found[2])
    if code is None:
        code = _kernel_code(origin)
    module = types.ModuleType(name)
    module.__file__ = origin
    module.__package__ = name.rpartition(".")[0]
    sys.modules[name] = module
    exec(code, module.__dict__)  # noqa: S102
    return module


_modresolver = _boot_module(
    "jaclang.project.modresolver", os.path.join("project", "modresolver.jac")
)
_modresolver.install_search_roots(list(sys.path))
get_jac_search_paths = _modresolver.get_jac_search_paths


class JacMetaImporter(MetaPathFinder, Loader):
    """Meta path importer to load .jac modules via Python's import system."""


    def find_spec(
        self,
        fullname: str,
        path: Sequence[str] | None = None,
        target: ModuleType | None = None,
    ) -> ModuleSpec | None:
        """Find the spec for the module."""
        # Sealed image is authoritative: a sealed binary resolves its modules
        # from the manifest by name, with no filesystem probing for .jac. This
        # is the primary path (not a fallback) so a sealed runtime never touches
        # the disk for its own code. In an unsealed dev tree no image is loaded,
        # so this is a no-op and resolution falls through to the source search.
        sealed_spec = self._sealed_spec(fullname)
        if sealed_spec is not None:
            return sealed_spec

        if path is None:
            # Top-level import
            paths_to_search = get_jac_search_paths()
            module_path_parts = fullname.split(".")
        else:
            # Submodule import
            paths_to_search = [*path]
            module_path_parts = fullname.split(".")[-1:]

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package (canonical __init__ variants and
            # precedence come from the shared extension registry).
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
                # No __init__.jac found — treat as an implicit Jac namespace
                # package when a .jac source lives anywhere in its subtree (and
                # it is not a regular Python package). Without this, Python's
                # PathFinder must create the namespace package, which only works
                # when the parent directory happens to be on sys.path at that
                # moment. The subtree check (not just direct .jac files) is what
                # lets per-component import descend through an *intermediate*
                # namespace package like ``engine/`` in ``engine.math.vec3``
                # (issue #7211).
                if ext_registry.is_jac_namespace_package(candidate_path):
                    spec = importlib.machinery.ModuleSpec(
                        fullname, loader=None, is_package=True
                    )
                    spec.submodule_search_locations = [candidate_path]
                    return spec
            # Check for a module file in codespace precedence order.
            for suffix in ext_registry.MODULE_SUFFIXES:
                module_file = candidate_path + suffix
                if os.path.isfile(module_file):
                    return importlib.util.spec_from_file_location(
                        fullname, module_file, loader=self
                    )
            # Migration guard: the .na.jac marker was retired in 0.35. A
            # leftover file must fail loudly with the rename, not as a bare
            # module-not-found.
            retired = candidate_path + ext_registry.RETIRED_NATIVE_SUFFIX
            if os.path.isfile(retired):
                raise ImportError(
                    f"{retired}: the .na.jac marker was retired in 0.35 -- "
                    "rename the file to .jac; native placement is inferred "
                    "(or forced by 'jac build --native')."
                )

        return None

    def _sealed_spec(self, fullname: str) -> importlib.machinery.ModuleSpec | None:
        found = _sealed.find_module(fullname)
        if found is None:
            return None
        image, entry, src_rel = found
        origin = image.virtual_origin(src_rel)
        is_pkg = entry.get("package", False)
        spec = importlib.machinery.ModuleSpec(
            fullname, self, origin=origin, is_package=is_pkg
        )
        # Populate __file__ from the (virtual) origin so tracebacks and code
        # that inspects __file__ behave as if the source were on disk.
        spec._set_fileattr = True
        if is_pkg:
            spec.submodule_search_locations = [os.path.dirname(origin)]
        return spec

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create the module."""
        return None  # use default machinery

    def _exec_boot(self, module: ModuleType, file_path: str) -> None:
        """Execute a module imported before the Jac runtime has loaded."""
        found = _sealed.find_module(module.__name__)
        code = found[0].module_code(module.__name__) if found is not None else None
        if found is not None and code is None:
            raise ImportError(
                f"{module.__name__} has no bytecode in its sealed image: it is "
                "native-only, compiled into the kernel"
            )
        if code is None and file_path.endswith(".py"):
            with open(file_path, encoding="utf-8") as source:
                code = compile(source.read(), file_path, "exec")
        exec(code or _kernel_code(file_path), module.__dict__)  # noqa: S102

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
        if not _runtime_ready():
            self._exec_boot(module, file_path)
            return
        self._exec_compiled_module(module, file_path)

    def _exec_compiled_module(self, module: ModuleType, file_path: str) -> None:
        from jaclang.runtime.runtime import JacRuntime as Jac

        assert module.__spec__ is not None
        is_pkg = module.__spec__.submodule_search_locations is not None

        from jaclang.compiler.native_scope import native_only_module

        if native_only_module(module.__name__):
            raise ImportError(
                f"{module.__name__} is native-only: it is compiled into the "
                "kernel and is never imported as bytecode"
            )

        # Register module in JacRuntime's tracking (skip internal jaclang modules)
        if not module.__name__.startswith("jaclang."):
            Jac.load_module(module.__name__, module)

        # The registry is itself Jac. Read it only after its import completes;
        # importing it here would recurse while bootstrapping the compiler.
        registry = sys.modules.get("jaclang.runtime.prepared")
        lookup = getattr(registry, "application_for", None)
        prepared = lookup(file_path, module.__name__) if lookup is not None else None
        prepared_path = os.path.realpath(file_path)
        if prepared is not None and prepared_path in prepared.code:
            registry.execute_module(module, prepared)
            return
        compiler = Jac.get_compiler()
        program = Jac.get_program()
        if prepared is None:
            containing_lookup = getattr(registry, "containing_application", None)
            containing = (
                containing_lookup(file_path, module.__name__) if containing_lookup is not None else None
            )
            if containing is not None:
                from jaclang.compiler.driver.application import prepare_dynamic_module

                prepared = prepare_dynamic_module(file_path, program, containing)
        codeobj = (
            prepared.code.get(prepared_path)
            if prepared is not None
            else compiler.get_bytecode(full_target=file_path, target_program=program)
        )
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return
            alerts = _module_scoped_alerts(program, file_path)
            details = "\n".join(a.pretty_print() for a in alerts)
            if details:
                raise JacSourceCompileError(
                    f"{file_path} failed to compile:\n{details}", file_path
                )
            raise JacSourceCompileError(
                f"No bytecode found for {file_path}", file_path
            )

        # MTIR is written keyed by file stem but byllm looks up by func.__module__;
        # re-key to the fullname so submodule imports resolve. __main__ is already
        # resolved back to its stem at lookup time.
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

        # Inject native interop infrastructure if needed (sv↔na interop)
        native_engine, interop_py_funcs = (
            prepared.native.get(prepared_path, (None, None))
            if prepared is not None
            else compiler.get_native_interop_setup(file_path, program)
        )
        if native_engine is not None:
            module.__dict__["__jac_native_engine__"] = native_engine
        # Always inject interop_py_funcs if it's the actual dict from compilation
        # (not None). The dict may be empty initially but will be populated when
        # bytecode executes. Late-binding callbacks reference this same dict.
        if interop_py_funcs is not None:
            module.__dict__["__jac_interop_py_funcs__"] = interop_py_funcs

        # Bind local imports to this app's compiled closure.
        if prepared is not None and (
            module.__name__ == registry.application_namespace(prepared)
            or module.__name__.startswith(registry.application_namespace(prepared) + ".")
        ):
            module.__dict__["__builtins__"] = registry.module_builtins(prepared, file_path)
        # Execute the bytecode directly in the module's namespace
        exec(codeobj, module.__dict__)

        # An inferred-native module keeps its plain python side for python
        # callers (the preference must not route sv-side calls through the
        # marshal bridge); sv->na calls go through the interop stubs the
        # manifest generates. Sealed compiler-native modules bind through
        # the AOT artifact instead.

    def get_source(self, fullname: str) -> str | None:
        """Return module source text when available.

        For sealed modules the ``.jac`` file is absent, but a ``--debug-src``
        image embeds the source in the JIR; ``linecache`` calls this to render
        source lines in tracebacks. Returns None when no debug source exists
        (release images), which leaves tracebacks with file:line but no echo.
        """
        return _sealed.source_for(fullname)

    def get_code(self, fullname: str) -> object | None:
        """Get the code object for a module.

        This method is required by runpy when using `python -m module`.
        """
        from jaclang.runtime.runtime import JacRuntime as Jac

        # Sealed image is authoritative (see find_spec): resolve a sealed module
        # by name from the manifest, no filesystem probing.
        found = _sealed.find_module(fullname)
        if found is not None:
            image, entry, src_rel = found
            if not _runtime_ready():
                return image.module_code(fullname)
            return Jac.get_compiler().get_bytecode(
                full_target=image.virtual_origin(src_rel),
                target_program=Jac.get_program(),
            )

        # Find the .jac file for this module
        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

        compiler = Jac.get_compiler()
        program = Jac.get_program()

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package (shared __init__ precedence).
            if os.path.isdir(candidate_path):
                for init_name in ext_registry.INIT_FILES:
                    init_file = os.path.join(candidate_path, init_name)
                    if os.path.isfile(init_file):
                        return compiler.get_bytecode(
                            full_target=init_file,
                            target_program=program,
                        )
            # Check for a module file in codespace precedence order.
            for suffix in ext_registry.MODULE_SUFFIXES:
                module_file = candidate_path + suffix
                if os.path.isfile(module_file):
                    return compiler.get_bytecode(
                        full_target=module_file,
                        target_program=program,
                    )

        return None
