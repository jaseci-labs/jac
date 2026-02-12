"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
It leverages Python's modern import machinery (importlib.abc) to seamlessly
integrate Jac modules into Python's import system.
"""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import importlib.util
import logging
import os
import sys
import types
from collections.abc import Sequence
from functools import cache
from pathlib import Path
from types import ModuleType

from jaclang.jac0 import compile_jac as _jac0_compile

# Inline logging config (previously in jaclang.jac0core.log)
logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")

# Bootstrap modresolver.jac with jac0 before JacMetaImporter is registered.
# This module must be available for find_spec()/get_code(), but normal
# .jac imports are not yet operational at this point.
_jac0core_dir = os.path.join(os.path.dirname(__file__), "jac0core")
_modresolver_jac = os.path.join(_jac0core_dir, "modresolver.jac")
with open(_modresolver_jac, encoding="utf-8") as _f:
    _py_src = _jac0_compile(_f.read(), _modresolver_jac)
_modresolver = types.ModuleType("jaclang.jac0core.modresolver")
_modresolver.__file__ = _modresolver_jac
_modresolver.__package__ = "jaclang.jac0core"
exec(compile(_py_src, _modresolver_jac, "exec"), _modresolver.__dict__)  # noqa: S102
sys.modules["jaclang.jac0core.modresolver"] = _modresolver
get_jac_search_paths = _modresolver.get_jac_search_paths


@cache
def _discover_minimal_compile_modules() -> frozenset[str]:
    """Auto-discover .jac compiler passes that need minimal compilation."""
    jaclang_dir = Path(__file__).parent
    passes_dir = jaclang_dir / "compiler" / "passes"
    modules = set()

    for subdir in ["main", "ecmascript", "native"]:
        for jac_file in (passes_dir / subdir).rglob("*.jac"):
            if jac_file.name.endswith(".impl.jac"):
                continue
            module_path = jac_file.relative_to(jaclang_dir).with_suffix("")
            modules.add(f"jaclang.{module_path.as_posix().replace('/', '.')}")

    return frozenset(modules)


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    # Directory containing the jaclang package (for bootstrap detection)
    _jaclang_dir: str = str(Path(__file__).parent)

    @property
    def MINIMAL_COMPILE_MODULES(self) -> frozenset[str]:  # noqa: N802
        """Compiler passes written in Jac that need minimal compilation."""
        return _discover_minimal_compile_modules()

    # Directory containing bootstrap .jac files (jac0core infrastructure)
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
            # Top-level import
            paths_to_search = get_jac_search_paths()
            module_path_parts = fullname.split(".")
        else:
            # Submodule import
            paths_to_search = [*path]
            module_path_parts = fullname.split(".")[-1:]

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package
            if os.path.isdir(candidate_path):
                init_file = os.path.join(candidate_path, "__init__.jac")
                if os.path.isfile(init_file):
                    return importlib.util.spec_from_file_location(
                        fullname,
                        init_file,
                        loader=self,
                        submodule_search_locations=[candidate_path],
                    )
                init_sv_file = os.path.join(candidate_path, "__init__.sv.jac")
                if os.path.isfile(init_sv_file):
                    return importlib.util.spec_from_file_location(
                        fullname,
                        init_sv_file,
                        loader=self,
                        submodule_search_locations=[candidate_path],
                    )
                init_cl_file = os.path.join(candidate_path, "__init__.cl.jac")
                if os.path.isfile(init_cl_file):
                    return importlib.util.spec_from_file_location(
                        fullname,
                        init_cl_file,
                        loader=self,
                        submodule_search_locations=[candidate_path],
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, jac_file, loader=self
                )
            # Check for .sv.jac file (server-side explicit)
            sv_jac_file = candidate_path + ".sv.jac"
            if os.path.isfile(sv_jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, sv_jac_file, loader=self
                )
            # Check for .cl.jac file (client-side)
            cl_jac_file = candidate_path + ".cl.jac"
            if os.path.isfile(cl_jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, cl_jac_file, loader=self
                )
            # Check for .na.jac file (native)
            na_jac_file = candidate_path + ".na.jac"
            if os.path.isfile(na_jac_file):
                return importlib.util.spec_from_file_location(
                    fullname, na_jac_file, loader=self
                )

        return None

    def create_module(self, spec: importlib.machinery.ModuleSpec) -> ModuleType | None:
        """Create the module."""
        return None  # use default machinery

    def _exec_bootstrap(self, module: ModuleType, file_path: str) -> None:
        """Execute a bootstrap .jac module using jac0 (in-memory, no disk I/O).

        Bootstrap modules are part of the jaclang compiler infrastructure.
        They are compiled with the lightweight jac0 transpiler rather than
        the full Jac compiler, which depends on them.
        """
        from jaclang.jac0 import compile_jac

        with open(file_path, encoding="utf-8") as f:
            jac_source = f.read()

        py_source = compile_jac(jac_source, file_path)
        code = compile(py_source, file_path, "exec")
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

        # Bootstrap path: .jac files inside jaclang/ are compiled with jac0
        if self._is_bootstrap_jac(file_path):
            self._exec_bootstrap(module, file_path)
            return

        from jaclang.jac0core.runtime import JacRuntime as Jac

        is_pkg = module.__spec__.submodule_search_locations is not None

        # Register module in JacRuntime's tracking (skip internal jaclang modules)
        if not module.__name__.startswith("jaclang."):
            Jac.load_module(module.__name__, module)

        # Use minimal compilation for compiler passes to avoid circular imports
        use_minimal = module.__name__ in self.MINIMAL_COMPILE_MODULES

        # Get and execute bytecode using the compiler singleton
        compiler = Jac.get_compiler()
        program = Jac.get_program()
        codeobj = compiler.get_bytecode(
            full_target=file_path,
            target_program=program,
            minimal=use_minimal,
        )
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return

            # If no bytecode is found, check if there were compilation errors
            if program.errors_had:
                error_msg = ""
                # Collect errors to process
                errors = program.errors_had

                for i, e in enumerate(errors):
                    # specific filtering for redundant errors
                    if e.msg == "Unexpected token ''":
                        continue

                    # If this is an "Unexpected token" error, check if there's a "Missing SEMI"
                    # error at the same location (or very close). If so, skip this one as it's likely a side effect.
                    if e.msg.startswith("Unexpected token"):
                        is_redundant = False
                        for other in errors:
                            if other is not e and other.msg == "Missing SEMI":
                                if (
                                    hasattr(e, "loc")
                                    and hasattr(other, "loc")
                                    and e.loc
                                    and other.loc
                                    and e.loc.mod_path == other.loc.mod_path
                                    and e.loc.first_line == other.loc.first_line
                                ):
                                    is_redundant = True
                                    break
                        if is_redundant:
                            continue

                    if hasattr(e, "loc") and e.loc:
                        file_path = e.loc.mod_path
                        line_no = e.loc.first_line
                        col_no = e.loc.col_start
                        msg = e.msg

                        # Heuristic for Missing SEMI at the start of a line (handling indentation)
                        moved_to_prev_line = False
                        if e.loc.orig_src and e.loc.orig_src.code:
                            source_lines = e.loc.orig_src.code.splitlines()

                            if 0 <= line_no - 1 < len(source_lines):
                                current_line = source_lines[line_no - 1]
                                # Check if token is at start of line (ignoring whitespace)
                                prefix = current_line[: col_no - 1]
                                if not prefix.strip() and msg == "Missing SEMI":
                                    # Start checking from the previous line
                                    prev_line_idx = line_no - 2
                                    while prev_line_idx >= 0:
                                        prev_line = source_lines[prev_line_idx]
                                        if prev_line.strip():
                                            # Found a non-empty previous line
                                            line_no = prev_line_idx + 1
                                            moved_to_prev_line = True
                                            break
                                        prev_line_idx -= 1

                        # Format like Python SyntaxError
                        error_msg += f'\n  File "{file_path}", line {line_no}\n'

                        # Display the (possibly updated) line
                        if e.loc.orig_src and e.loc.orig_src.code:
                            source_lines = e.loc.orig_src.code.splitlines()
                            if 0 <= line_no - 1 < len(source_lines):
                                display_line = source_lines[line_no - 1]
                                error_msg += f"    {display_line}\n"

                                # Calculate caret position
                                if moved_to_prev_line:
                                    # Point to the character after the last non-whitespace character
                                    stripped_len = len(display_line.rstrip())
                                    caret_col = stripped_len + 1
                                else:
                                    caret_col = col_no

                                error_msg += f"    {' ' * (caret_col - 1)}^\n"

                        error_msg += f"SyntaxError: {msg}\n"
                    else:
                        error_msg += f"\nError: {e}\n"

                raise ImportError(
                    f"Errors occurred during compilation of {file_path}:{error_msg}"
                )

            raise ImportError(f"No bytecode found for {file_path}")

        # Inject native interop infrastructure if needed (sv↔na interop)
        native_engine, interop_py_funcs = compiler.get_native_interop_setup(
            file_path, program
        )
        if native_engine is not None:
            module.__dict__["__jac_native_engine__"] = native_engine
        # Always inject interop_py_funcs if it's the actual dict from compilation
        # (not None). The dict may be empty initially but will be populated when
        # bytecode executes. Late-binding callbacks reference this same dict.
        if interop_py_funcs is not None:
            module.__dict__["__jac_interop_py_funcs__"] = interop_py_funcs

        # Execute the bytecode directly in the module's namespace
        exec(codeobj, module.__dict__)

    def get_code(self, fullname: str) -> object | None:
        """Get the code object for a module.

        This method is required by runpy when using `python -m module`.
        """
        from jaclang.jac0core.runtime import JacRuntime as Jac

        # Find the .jac file for this module
        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

        # Use minimal compilation for compiler passes to avoid circular imports
        use_minimal = fullname in self.MINIMAL_COMPILE_MODULES

        compiler = Jac.get_compiler()
        program = Jac.get_program()

        for search_path in paths_to_search:
            candidate_path = os.path.join(search_path, *module_path_parts)
            # Check for directory package
            if os.path.isdir(candidate_path):
                init_file = os.path.join(candidate_path, "__init__.jac")
                if os.path.isfile(init_file):
                    return compiler.get_bytecode(
                        full_target=init_file,
                        target_program=program,
                        minimal=use_minimal,
                    )
                init_cl_file = os.path.join(candidate_path, "__init__.cl.jac")
                if os.path.isfile(init_cl_file):
                    return compiler.get_bytecode(
                        full_target=init_cl_file,
                        target_program=program,
                        minimal=use_minimal,
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                return compiler.get_bytecode(
                    full_target=jac_file,
                    target_program=program,
                    minimal=use_minimal,
                )
            cl_jac_file = candidate_path + ".cl.jac"
            if os.path.isfile(cl_jac_file):
                return compiler.get_bytecode(
                    full_target=cl_jac_file,
                    target_program=program,
                    minimal=use_minimal,
                )

        return None
