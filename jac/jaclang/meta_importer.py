"""Jac meta path importer.

This module implements PEP 451-compliant import hooks for .jac modules.
It leverages Python's modern import machinery (importlib.abc) to seamlessly
integrate Jac modules into Python's import system.
"""

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

# Cache jac0 transpiler hash for bootstrap cache invalidation
import jaclang.jac0 as _jac0_mod
from jaclang.jac0 import compile_jac as _jac0_compile  # noqa: E402
from jaclang.jac0 import discover_impl_files as _jac0_discover_impls  # noqa: E402

_jac0_source_path = getattr(_jac0_mod, "__file__", "")
_jac0_hash = (
    hashlib.sha256(Path(_jac0_source_path).read_bytes()).digest()
    if _jac0_source_path and os.path.isfile(_jac0_source_path)
    else b""
)

# Inline logging config (previously in jaclang.jac0core.log)
logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")


# ---------------------------------------------------------------------------
# Bootstrap bytecode cache (JIR format)
#
# jac0core .jac files are transpiled by jac0 on every invocation.  Caching
# the resulting bytecode avoids ~200 ms of repeated work when the sources
# haven't changed.  The cache lives at ~/.cache/jac/jir/bootstrap/ and uses
# a minimal JIR file (FLAG_BOOTSTRAP set, no AST payload, SEC_BYTECODE only).
# This is implemented in pure Python so it works before the JIR Jac modules
# have been bootstrapped.
# ---------------------------------------------------------------------------

_BOOTSTRAP_JIR_MAGIC = b"JIR\x00"
_BOOTSTRAP_JIR_FMT_VER = 8
_BOOTSTRAP_JIR_HEADER_FMT = "<4sHHIIIIII"
_BOOTSTRAP_JIR_HEADER_SIZE = 32
_BOOTSTRAP_JIR_SECTIONS_MAGIC = b"JIRX"
_BOOTSTRAP_SEC_BYTECODE = 0x02
_BOOTSTRAP_SEC_NATIVE_OBJ = 0x06
_BOOTSTRAP_SEC_NATIVE_LAYOUT = 0x08
_BOOTSTRAP_SEC_TERMINATOR = 0xFF
_BOOTSTRAP_FLAG_BOOTSTRAP = 0x04


def _get_bootstrap_cache_dir() -> Path:
    """Return the platform-appropriate bootstrap JIR cache directory."""
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache" / "jir" / "bootstrap"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac" / "jir" / "bootstrap"
    else:
        xdg = os.environ.get("XDG_CACHE_HOME")
        base = Path(xdg) if xdg else (Path.home() / ".cache")
        return base / "jac" / "jir" / "bootstrap"


def _write_bootstrap_jir(
    bytecode: bytes,
    source_hash: int,
    extra_sections: dict[int, bytes] | None = None,
) -> bytes:
    """Build a minimal JIR with FLAG_BOOTSTRAP set and a SEC_BYTECODE section.

    If extra_sections is provided, those TLV entries are written after
    SEC_BYTECODE and before the terminator.
    """
    import struct
    import zlib

    py_ver = (sys.version_info.major << 8) | sys.version_info.minor
    header = struct.pack(
        _BOOTSTRAP_JIR_HEADER_FMT,
        _BOOTSTRAP_JIR_MAGIC,
        _BOOTSTRAP_JIR_FMT_VER,
        py_ver,
        0,  # jaclang_version_hash (not available at bootstrap)
        source_hash & 0xFFFFFFFF,
        0,  # node_count
        0,  # symbol_count
        0,  # string_pool_size
        _BOOTSTRAP_FLAG_BOOTSTRAP,
    )
    # Empty AST payload: a single varint 0x00 (empty string pool), compressed
    empty_payload = zlib.compress(b"\x00", 1)
    # TLV sections
    import struct as _struct

    sec_parts = [
        _BOOTSTRAP_JIR_SECTIONS_MAGIC,
        bytes([_BOOTSTRAP_SEC_BYTECODE]),
        _struct.pack("<I", len(bytecode)),
        bytecode,
    ]
    if extra_sections:
        for sec_type, sec_data in extra_sections.items():
            sec_parts.append(bytes([sec_type]))
            sec_parts.append(_struct.pack("<I", len(sec_data)))
            sec_parts.append(sec_data)
    sec_parts.append(bytes([_BOOTSTRAP_SEC_TERMINATOR]))
    sec_parts.append(b"\x00\x00\x00\x00")
    return header + empty_payload + b"".join(sec_parts)


def _read_bootstrap_jir(data: bytes) -> tuple[bytes | None, dict[int, bytes]]:
    """Extract all sections from a bootstrap JIR file.

    Returns (bytecode_or_None, {sec_type: sec_data, ...}).
    """
    import struct

    empty: dict[int, bytes] = {}
    if len(data) < _BOOTSTRAP_JIR_HEADER_SIZE:
        return None, empty
    try:
        magic, fmt_ver = struct.unpack_from("<4sH", data, 0)
        if magic != _BOOTSTRAP_JIR_MAGIC or fmt_ver != _BOOTSTRAP_JIR_FMT_VER:
            return None, empty
        # Find SECTIONS_MAGIC after the header
        pos = data.find(_BOOTSTRAP_JIR_SECTIONS_MAGIC, _BOOTSTRAP_JIR_HEADER_SIZE)
        if pos < 0:
            return None, empty
        pos += len(_BOOTSTRAP_JIR_SECTIONS_MAGIC)
        sections: dict[int, bytes] = {}
        while pos < len(data):
            sec_type = data[pos]
            pos += 1
            if sec_type == _BOOTSTRAP_SEC_TERMINATOR:
                break
            if pos + 4 > len(data):
                break
            (sec_len,) = struct.unpack_from("<I", data, pos)
            pos += 4
            if pos + sec_len > len(data):
                break
            sections[sec_type] = data[pos : pos + sec_len]
            pos += sec_len
        bytecode = sections.get(_BOOTSTRAP_SEC_BYTECODE)
        return bytecode, sections
    except Exception:
        return None, empty


def _bootstrap_compile(
    file_path: str,
    jac_source: str,
    impl_sources: list[tuple[str, str]] | None = None,
) -> tuple[types.CodeType, dict[int, bytes]]:
    """Compile a bootstrap .jac file, using a JIR disk cache when possible.

    Returns (code_object, extra_sections) where extra_sections may contain
    SEC_NATIVE_OBJ and SEC_NATIVE_LAYOUT from a previous native caching run.
    """
    import zlib

    # Build the hash key from all source inputs + Python version + transpiler
    h = hashlib.sha256()
    h.update(sys.version.encode())
    h.update(_jac0_hash)
    h.update(jac_source.encode())
    if impl_sources:
        for src, path in impl_sources:
            h.update(path.encode())
            h.update(src.encode())
    digest = h.hexdigest()[:16]
    source_hash = zlib.crc32(jac_source.encode()) & 0xFFFFFFFF

    # Derive a human-readable cache filename (.jir extension)
    base_name = os.path.splitext(os.path.basename(file_path))[0]
    cache_file = _get_bootstrap_cache_dir() / f"{base_name}.{digest}.jir"

    # Try loading from JIR cache
    if cache_file.is_file():
        try:
            data = cache_file.read_bytes()
            bc, sections = _read_bootstrap_jir(data)
            if bc is not None:
                return marshal.loads(bc), sections  # noqa: S302
        except Exception:
            cache_file.unlink(missing_ok=True)

    # Cache miss — transpile with jac0 and compile
    py_source = _jac0_compile(jac_source, file_path, impl_sources=impl_sources)
    code = compile(py_source, file_path, "exec")

    # Write JIR cache (best-effort)
    try:
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        jir_data = _write_bootstrap_jir(marshal.dumps(code), source_hash)
        cache_file.write_bytes(jir_data)
    except OSError:
        pass

    return code, {}


# Bootstrap modresolver.jac with jac0 before JacMetaImporter is registered.
# This module must be available for find_spec()/get_code(), but normal
# .jac imports are not yet operational at this point.
_jac0core_dir = os.path.join(os.path.dirname(__file__), "jac0core")
_modresolver_jac = os.path.join(_jac0core_dir, "modresolver.jac")
with open(_modresolver_jac, encoding="utf-8") as _f:
    _modresolver_code, _ = _bootstrap_compile(_modresolver_jac, _f.read())
_modresolver = types.ModuleType("jaclang.jac0core.modresolver")
_modresolver.__file__ = _modresolver_jac
_modresolver.__package__ = "jaclang.jac0core"
exec(_modresolver_code, _modresolver.__dict__)  # noqa: S102
sys.modules["jaclang.jac0core.modresolver"] = _modresolver
get_jac_search_paths = _modresolver.get_jac_search_paths


class JacMetaImporter(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    """Meta path importer to load .jac modules via Python's import system."""

    # Directory containing the jaclang package (for bootstrap detection)
    _jaclang_dir: str = str(Path(__file__).parent)

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
                # No __init__.jac found — treat as Jac namespace package if
                # the directory contains .jac files but no __init__.py
                # (which would make it a regular Python package).  Without
                # this, Python's PathFinder must create the namespace
                # package, which only works when the parent directory
                # happens to be on sys.path at that moment.
                if not os.path.isfile(
                    os.path.join(candidate_path, "__init__.py")
                ) and any(f.endswith(".jac") for f in os.listdir(candidate_path)):
                    spec = importlib.machinery.ModuleSpec(
                        fullname, loader=None, is_package=True
                    )
                    spec.submodule_search_locations = [candidate_path]
                    return spec
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
        """Execute a bootstrap .jac module using jac0 with bytecode caching.

        Bootstrap modules are part of the jaclang compiler infrastructure.
        They are compiled with the lightweight jac0 transpiler rather than
        the full Jac compiler, which depends on them.

        For .na.jac files, if native bitcode has been cached from a prior run,
        the MCJIT engine is loaded and native wrappers are installed immediately
        after executing the Python bytecode (which is still needed for module
        registration and class definitions).
        """
        with open(file_path, encoding="utf-8") as f:
            jac_source = f.read()

        impl_sources: list[tuple[str, str]] = []
        for impl_path in _jac0_discover_impls(file_path):
            with open(impl_path, encoding="utf-8") as f:
                impl_sources.append((f.read(), impl_path))

        code, sections = _bootstrap_compile(file_path, jac_source, impl_sources or None)
        exec(code, module.__dict__)

        # For .na.jac files, attempt to load cached native bitcode
        if (
            file_path.endswith(".na.jac")
            and _BOOTSTRAP_SEC_NATIVE_OBJ in sections
            and _BOOTSTRAP_SEC_NATIVE_LAYOUT in sections
        ):
            self._load_bootstrap_native(module, sections)

    @staticmethod
    def _load_bootstrap_native(module: ModuleType, sections: dict[int, bytes]) -> None:
        """Load cached native bitcode and install native wrappers on a module.

        Called from _exec_bootstrap for .na.jac files that have cached bitcode.
        The Python bytecode has already been executed, so the module has all its
        Python-side objects (classes, enums). This overlays native function
        implementations via ctypes wrappers.

        Silently falls back to Python if anything goes wrong (no llvmlite,
        platform mismatch, corrupt bitcode, etc.).
        """
        try:
            import struct as _struct

            import llvmlite.binding as llvm

            llvm.initialize_native_target()
            llvm.initialize_native_asmprinter()

            # Parse SEC_NATIVE_OBJ: [triple_len:2LE][triple:UTF-8][bitcode]
            native_obj_data = sections[_BOOTSTRAP_SEC_NATIVE_OBJ]
            if len(native_obj_data) < 2:
                return
            (triple_len,) = _struct.unpack_from("<H", native_obj_data, 0)
            if len(native_obj_data) < 2 + triple_len:
                return
            cached_triple = native_obj_data[2 : 2 + triple_len].decode("utf-8")
            if cached_triple != llvm.get_default_triple():
                return  # Platform mismatch — fall back to Python

            bitcode = native_obj_data[2 + triple_len :]

            # Load libc for symbol resolution
            import ctypes
            import ctypes.util

            libc_name = ctypes.util.find_library("c")
            if libc_name:
                llvm.load_library_permanently(libc_name)

            # Deserialize NativeModuleLayout from SEC_NATIVE_LAYOUT first
            # so we can use layout.init_functions for global initialization.
            from jaclang.jac0core.codeinfo import deserialize_native_layout
            from jaclang.jac0core.native_marshal import install_native_wrappers

            layout_data = sections[_BOOTSTRAP_SEC_NATIVE_LAYOUT]
            layout = deserialize_native_layout(layout_data)

            # Create MCJIT engine from cached bitcode (already optimized)
            llvm_mod = llvm.parse_bitcode(bitcode)
            target = llvm.Target.from_default_triple()
            target_machine = target.create_target_machine(jit=True)
            engine = llvm.create_mcjit_compiler(llvm_mod, target_machine)

            # Run native global initializers in the order specified by
            # the layout metadata (imported module inits first, then
            # the module's own __jac_glob_init).
            for init_name in layout.init_functions:
                addr = engine.get_function_address(init_name)
                if addr:
                    ctypes.CFUNCTYPE(None)(addr)()

            count = install_native_wrappers(module, engine, layout)
            if count > 0:
                module.__jac_native_engine__ = engine  # type: ignore[attr-defined]
                module.__jac_native_layout__ = layout  # type: ignore[attr-defined]
        except Exception:
            pass  # Graceful fallback — Python bytecode already executed

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

        # Get and execute bytecode using the compiler singleton
        compiler = Jac.get_compiler()
        program = Jac.get_program()
        codeobj = compiler.get_bytecode(
            full_target=file_path,
            target_program=program,
        )
        if not codeobj:
            if is_pkg:
                # Empty package is OK - just register it
                return
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

        # Auto-install native wrappers if native engine is available
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

        # Find the .jac file for this module
        paths_to_search = get_jac_search_paths()
        module_path_parts = fullname.split(".")

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
                    )
                init_cl_file = os.path.join(candidate_path, "__init__.cl.jac")
                if os.path.isfile(init_cl_file):
                    return compiler.get_bytecode(
                        full_target=init_cl_file,
                        target_program=program,
                    )
            # Check for .jac file
            jac_file = candidate_path + ".jac"
            if os.path.isfile(jac_file):
                return compiler.get_bytecode(
                    full_target=jac_file,
                    target_program=program,
                )
            cl_jac_file = candidate_path + ".cl.jac"
            if os.path.isfile(cl_jac_file):
                return compiler.get_bytecode(
                    full_target=cl_jac_file,
                    target_program=program,
                )

        return None
