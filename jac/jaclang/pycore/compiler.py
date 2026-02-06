"""Jac Compiler - handles all compilation operations separate from program state."""

from __future__ import annotations

import ast as py_ast
import atexit
import marshal
import os
import re
import sys
import types
from threading import Event
from typing import TYPE_CHECKING

import jaclang.pycore.unitree as uni
from jaclang.pycore.bccache import (
    BytecodeCache,
    CacheKey,
    DiskBytecodeCache,
    get_bytecode_cache,
)
from jaclang.pycore.compile_options import CompileOptions
from jaclang.pycore.helpers import read_file_with_encoding
from jaclang.pycore.jac_parser import JacParser
from jaclang.pycore.passes import (
    DeclImplMatchPass,
    InteropAnalysisPass,
    JacAnnexPass,
    PyastGenPass,
    PyBytecodeGenPass,
    SemanticAnalysisPass,
    SymTabBuildPass,
    Transform,
)
from jaclang.pycore.tsparser import TypeScriptParser

if TYPE_CHECKING:
    from jaclang.pycore.program import JacProgram


def get_symtab_ir_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Symbol table build schedule."""
    return [SymTabBuildPass, DeclImplMatchPass]


def get_ir_gen_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Full IR generation schedule."""
    from jaclang.compiler.passes.main import CFGBuildPass, MTIRGenPass, SemDefMatchPass

    return [
        SymTabBuildPass,
        DeclImplMatchPass,
        SemanticAnalysisPass,
        SemDefMatchPass,
        CFGBuildPass,
        MTIRGenPass,
    ]


def get_type_check_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Type checking schedule."""
    from jaclang.compiler.passes.main import TypeCheckPass

    return [TypeCheckPass]


def get_py_code_gen() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Full Python code generation schedule."""
    from jaclang.compiler.passes.ecmascript import EsastGenPass
    from jaclang.compiler.passes.main import PyJacAstLinkPass

    passes: list[type[Transform[uni.Module, uni.Module]]] = [
        InteropAnalysisPass,
        EsastGenPass,
    ]

    # Include native compilation passes
    from jaclang.compiler.passes.native import NaIRGenPass, NativeCompilePass

    passes.extend([NaIRGenPass, NativeCompilePass])

    passes.extend([PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass])
    return passes


def get_minimal_ir_gen_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Minimal IR schedule (no CFG) for bootstrap modules."""
    return [SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass]


def get_minimal_py_code_gen() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Minimal codegen (bytecode only, no JS) for bootstrap modules."""
    return [PyastGenPass, PyBytecodeGenPass]


def get_format_sched(
    auto_lint: bool = False,
) -> list[type[Transform[uni.Module, uni.Module]]]:
    """Format schedule. If auto_lint=True, includes auto-linting pass."""
    from jaclang.compiler.passes.tool.comment_injection_pass import (
        CommentInjectionPass,
    )
    from jaclang.compiler.passes.tool.doc_ir_gen_pass import DocIRGenPass
    from jaclang.compiler.passes.tool.jac_auto_lint_pass import JacAutoLintPass
    from jaclang.compiler.passes.tool.jac_formatter_pass import JacFormatPass
    from jaclang.pycore.passes.annex_pass import JacAnnexPass

    if auto_lint:
        return [
            JacAnnexPass,
            JacAutoLintPass,
            DocIRGenPass,
            CommentInjectionPass,
            JacFormatPass,
        ]
    else:
        return [
            DocIRGenPass,
            CommentInjectionPass,
            JacFormatPass,
        ]


def get_lint_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Lint-only schedule. Runs lint rules for error reporting without formatting."""
    from jaclang.compiler.passes.tool.jac_auto_lint_pass import JacAutoLintPass
    from jaclang.pycore.passes.annex_pass import JacAnnexPass

    return [
        JacAnnexPass,
        JacAutoLintPass,
    ]


class _SetupProgress:
    """Tracks and displays progress during first-run compilation of internal modules."""

    def __init__(self) -> None:
        self._banner_shown = False
        self._compile_count = 0
        self._seen_files: set[str] = set()
        self._jaclang_root: str | None = None

    def _get_jaclang_root(self) -> str:
        if self._jaclang_root is None:
            self._jaclang_root = os.path.dirname(os.path.dirname(__file__))
        return self._jaclang_root

    def _atexit_handler(self) -> None:
        """Print the completion summary when the process exits."""
        if self._banner_shown and self._compile_count > 0:
            print(  # noqa: T201
                f"Jac setup complete!"
                f" ({self._compile_count} modules compiled and cached)",
                file=sys.stderr,
                flush=True,
            )

    def on_internal_compile(self, file_path: str) -> None:
        """Called when an internal jaclang module needs compilation (cache miss)."""
        normalized = os.path.normpath(file_path)
        if normalized in self._seen_files:
            return
        self._seen_files.add(normalized)
        if not self._banner_shown:
            self._banner_shown = True
            atexit.register(self._atexit_handler)
            print(  # noqa: T201
                "\nSetting up Jac for first use (compiling and caching compiler)...",
                file=sys.stderr,
                flush=True,
            )
        # Show relative path from jaclang root for readability
        jaclang_root = self._get_jaclang_root()
        rel_path = file_path
        if normalized.startswith(jaclang_root + os.sep):
            rel_path = os.path.relpath(normalized, os.path.dirname(jaclang_root))
        self._compile_count += 1
        print(  # noqa: T201
            f"  Compiling {rel_path}...",
            file=sys.stderr,
            flush=True,
        )

    @property
    def is_active(self) -> bool:
        """Whether we're currently in a first-run setup."""
        return self._banner_shown


# Module-level singleton shared between JacCompiler and JacMetaImporter
setup_progress = _SetupProgress()


class JacCompiler:
    """Jac Compiler singleton.

    Maintains separate module hub for jaclang.* modules (internal_program)
    vs user modules (target_program passed to methods).
    """

    _jaclang_root: str | None = None

    def __init__(self, bytecode_cache: BytecodeCache | None = None) -> None:
        """Initialize with optional custom bytecode cache."""
        self._bytecode_cache: BytecodeCache = bytecode_cache or get_bytecode_cache()
        self._internal_program: JacProgram | None = None

    @property
    def internal_program(self) -> JacProgram:
        """Module hub for jaclang.* modules (lazily initialized)."""
        if self._internal_program is None:
            from jaclang.pycore.program import JacProgram

            self._internal_program = JacProgram()
        return self._internal_program

    @classmethod
    def _get_jaclang_root(cls) -> str:
        """Get the jaclang package root path."""
        if cls._jaclang_root is None:
            cls._jaclang_root = os.path.dirname(os.path.dirname(__file__))
        return cls._jaclang_root

    def _resolve_program(
        self, file_path: str, target_program: JacProgram
    ) -> JacProgram:
        """Route jaclang.* files to internal_program, others to target_program."""
        normalized_path = os.path.normpath(file_path)
        jaclang_root = self._get_jaclang_root()
        if normalized_path.startswith(jaclang_root + os.sep):
            return self.internal_program
        return target_program

    def _load_mtir_cache(self, cache_key: CacheKey, program: JacProgram) -> None:
        """Load MTIR map from cache if available."""
        try:
            from jaclang.pycore.bccache import DiskBytecodeCache

            if isinstance(self._bytecode_cache, DiskBytecodeCache):
                cached_mtir = self._bytecode_cache.get_mtir(cache_key)
                if cached_mtir is not None:
                    # Merge cached MTIR into program's mtir_map
                    program.mtir_map.update(cached_mtir)
        except Exception:
            # Silently ignore MTIR cache loading failures
            pass

    def _save_mtir_cache(self, cache_key: CacheKey, program: JacProgram) -> None:
        """Save MTIR map to cache if available."""
        try:
            from jaclang.pycore.bccache import DiskBytecodeCache

            if isinstance(self._bytecode_cache, DiskBytecodeCache) and program.mtir_map:
                self._bytecode_cache.put_mtir(cache_key, program.mtir_map)
        except Exception:
            # Silently ignore MTIR cache saving failures
            pass

    def get_native_interop_setup(
        self, full_target: str, target_program: JacProgram
    ) -> tuple[object | None, dict[str, object] | None]:
        """Get native interop setup for a module.

        Returns:
            Tuple of (native_engine, interop_py_funcs_dict).
            native_engine is None if no native code.
            interop_py_funcs_dict is None if module not found in hub
            (caller should not inject into module dict in this case).
        """
        actual_program = self._resolve_program(full_target, target_program)
        if full_target in actual_program.mod.hub:
            mod = actual_program.mod.hub[full_target]
            native_engine = getattr(mod.gen, "native_engine", None)
            # IMPORTANT: Don't use `x or {}` - empty dict is falsy but we need
            # the SAME dict object that callbacks reference for late-binding
            interop_py_funcs = getattr(mod.gen, "interop_py_funcs", None)
            if interop_py_funcs is None:
                interop_py_funcs = {}
            return (native_engine, interop_py_funcs)
        return (None, None)

    def get_bytecode(
        self, full_target: str, target_program: JacProgram, minimal: bool = False
    ) -> types.CodeType | None:
        """Get bytecode using 3-tier cache: in-memory -> disk -> compile.

        For native modules (.na.jac or files with na {} blocks), also handles
        LLVM IR caching to avoid full recompilation while still creating fresh
        JIT engines each process (required since engines can't be serialized).
        """
        actual_program = self._resolve_program(full_target, target_program)

        # Tier 1: In-memory cache
        if (
            full_target in actual_program.mod.hub
            and actual_program.mod.hub[full_target].gen.py_bytecode
        ):
            codeobj = actual_program.mod.hub[full_target].gen.py_bytecode
            return marshal.loads(codeobj) if isinstance(codeobj, bytes) else None

        # Check if this might be a native module
        might_have_native = self._might_have_native_code(full_target)
        cache_key = CacheKey.for_source(full_target, minimal)

        # Tier 2: Disk cache
        if isinstance(self._bytecode_cache, DiskBytecodeCache):
            cached_code = self._bytecode_cache.get(cache_key)
            if cached_code is not None:
                if might_have_native:
                    # For native modules: also need cached LLVM IR
                    cached_ir = self._bytecode_cache.get_llvmir(cache_key)
                    cached_interop = self._bytecode_cache.get_interop(cache_key)
                    if cached_ir is not None:
                        # Create module stub in hub for native engine storage
                        self._load_native_from_cache(
                            full_target, actual_program, cached_ir, cached_interop
                        )
                        if not minimal:
                            self._load_mtir_cache(cache_key, actual_program)
                        return cached_code
                    # If no cached IR, fall through to full compile
                else:
                    # Non-native modules: just bytecode is enough
                    if not minimal:
                        self._load_mtir_cache(cache_key, actual_program)
                    return cached_code

        # Tier 3: Compile
        is_internal = actual_program is self._internal_program
        if is_internal:
            setup_progress.on_internal_compile(full_target)
        options = CompileOptions(minimal=minimal)
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        )
        if result.gen.py_bytecode:
            # Cache bytecode
            if isinstance(self._bytecode_cache, DiskBytecodeCache):
                self._bytecode_cache.put(cache_key, result.gen.py_bytecode)
                if not minimal:
                    self._save_mtir_cache(cache_key, actual_program)
                # For native modules: also cache LLVM IR and interop manifest
                if might_have_native and result.gen.llvm_ir is not None:
                    self._bytecode_cache.put_llvmir(cache_key, str(result.gen.llvm_ir))
                    self._cache_interop_manifest(cache_key, result)
            return marshal.loads(result.gen.py_bytecode)
        return None

    def _load_native_from_cache(
        self,
        full_target: str,
        target_program: JacProgram,
        cached_ir: str,
        cached_interop: dict | None,
    ) -> None:
        """Load native module from cached LLVM IR.

        Creates a fresh MCJIT engine from the cached IR string and sets up
        interop callbacks. This is much faster than full recompilation since
        we skip the Jac→AST→LLVM IR pipeline.
        """
        try:
            import llvmlite.binding as llvm

            # Initialize LLVM (idempotent)
            llvm.initialize_native_target()
            llvm.initialize_native_asmprinter()

            # Load required shared libraries
            import ctypes
            import ctypes.util

            libc_name = ctypes.util.find_library("c")
            if libc_name:
                llvm.load_library_permanently(libc_name)
            libgc_name = ctypes.util.find_library("gc")
            if libgc_name:
                llvm.load_library_permanently(libgc_name)
            else:
                # Fallback: map GC_malloc to libc malloc
                libc = ctypes.CDLL(libc_name)
                malloc_addr = ctypes.cast(libc.malloc, ctypes.c_void_p).value
                llvm.add_symbol("GC_malloc", malloc_addr)

            # Parse cached IR and create engine
            llvm_mod = llvm.parse_assembly(cached_ir)
            llvm_mod.verify()
            target = llvm.Target.from_default_triple()
            target_machine = target.create_target_machine()
            engine = llvm.create_mcjit_compiler(llvm_mod, target_machine)

            # Create a lightweight stub for get_native_interop_setup
            # Only needs: gen.native_engine, gen.interop_py_funcs
            from jaclang.pycore.codeinfo import CodeGenTarget, InteropManifest

            class _NativeModuleStub:
                """Minimal stub to hold native compilation artifacts."""

                def __init__(self) -> None:
                    self.gen = CodeGenTarget()

            stub_mod = _NativeModuleStub()
            stub_mod.gen.native_engine = engine

            # Always initialize interop_py_funcs - generated bytecode may reference it
            py_func_table: dict = {}
            callbacks_list: list = []
            stub_mod.gen.interop_py_funcs = py_func_table
            stub_mod.gen._interop_callbacks = callbacks_list

            # Restore interop callbacks if we have cached manifest
            if cached_interop:
                from jaclang.pycore.codeinfo import InteropBinding, InteropContext
                from jaclang.pycore.interop_bridge import register_py_callbacks

                manifest = InteropManifest()
                # Reconstruct bindings from cached data
                for name, data in cached_interop.get("bindings", {}).items():
                    binding = InteropBinding(
                        name=name,
                        source_context=InteropContext(data["source_context"]),
                        callers={InteropContext(c) for c in data.get("callers", [])},
                        ret_type=data.get("ret_type", "int"),
                        param_types=data.get("param_types", []),
                        param_names=data.get("param_names", []),
                        source_module=data.get("source_module"),
                    )
                    manifest.bindings[name] = binding

                stub_mod.gen.interop_manifest = manifest

                # Register Python callbacks for sv↔na interop
                if manifest.native_imports:
                    register_py_callbacks(manifest, py_func_table, callbacks_list)

            target_program.mod.hub[full_target] = stub_mod  # type: ignore

        except Exception as e:
            # If loading from cache fails, log and fall through to full compile
            import logging

            logging.getLogger(__name__).debug(
                f"Failed to load native module from cache: {e}"
            )

    def _cache_interop_manifest(self, cache_key: CacheKey, result: uni.Module) -> None:
        """Cache interop manifest data for native module.

        Serializes the interop bindings to a pickle-able format.
        """
        if not isinstance(self._bytecode_cache, DiskBytecodeCache):
            return

        manifest = getattr(result.gen, "interop_manifest", None)
        if manifest is None:
            return

        # Serialize bindings to dict format
        interop_data: dict = {"bindings": {}}
        for name, binding in manifest.bindings.items():
            interop_data["bindings"][name] = {
                "source_context": binding.source_context.value,
                "callers": [c.value for c in binding.callers],
                "ret_type": binding.ret_type,
                "param_types": binding.param_types,
                "param_names": binding.param_names,
                "source_module": binding.source_module,
            }

        self._bytecode_cache.put_interop(cache_key, interop_data)

    def _might_have_native_code(self, file_path: str) -> bool:
        """Check if a file might contain native code.

        Returns True for:
        - .na.jac files (fully native modules)
        - .jac files that contain 'na {' or 'na{' blocks

        This is a heuristic check to determine if we need full compilation
        (including native JIT) rather than using cached bytecode.
        """
        # .na.jac files are always native
        if file_path.endswith(".na.jac"):
            return True

        # For regular .jac files, do a quick text scan for na blocks
        if file_path.endswith(".jac"):
            try:
                with open(file_path, encoding="utf-8") as f:
                    content = f.read()
                # Quick heuristic: check for 'na {' or 'na{' pattern
                if re.search(r"\bna\s*\{", content):
                    return True
            except OSError:
                pass

        return False

    def parse_str(
        self,
        source_str: str,
        file_path: str,
        target_program: JacProgram,
        cancel_token: Event | None = None,
    ) -> uni.Module:
        """Parse source string into AST module."""
        had_error = False
        if file_path.endswith(".py") or file_path.endswith(".pyi"):
            from jaclang.compiler.passes.main import PyastBuildPass

            parsed_ast = py_ast.parse(source_str)
            py_ast_ret = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    parsed_ast,
                    orig_src=uni.Source(source_str, mod_path=file_path),
                ),
                prog=target_program,
                cancel_token=cancel_token,
            )
            had_error = len(py_ast_ret.errors_had) > 0
            mod = py_ast_ret.ir_out
        elif file_path.endswith((".js", ".ts", ".jsx", ".tsx")):
            source = uni.Source(source_str, mod_path=file_path)
            ts_ast_ret = TypeScriptParser(
                root_ir=source, prog=target_program, cancel_token=cancel_token
            )
            had_error = len(ts_ast_ret.errors_had) > 0
            mod = ts_ast_ret.ir_out
        else:
            source = uni.Source(source_str, mod_path=file_path)
            jac_ast_ret: Transform[uni.Source, uni.Module] = JacParser(
                root_ir=source, prog=target_program, cancel_token=cancel_token
            )
            had_error = len(jac_ast_ret.errors_had) > 0
            mod = jac_ast_ret.ir_out
        if had_error:
            return mod
        if target_program.mod.main.stub_only:
            target_program.mod = uni.ProgramModule(mod)
        target_program.mod.hub[mod.loc.mod_path] = mod
        JacAnnexPass(ir_in=mod, prog=target_program)
        return mod

    def compile(
        self,
        file_path: str,
        target_program: JacProgram,
        use_str: str | None = None,
        options: CompileOptions | None = None,
    ) -> uni.Module:
        """Compile a Jac file into module AST.

        Args:
            file_path: Path to the Jac file to compile.
            target_program: JacProgram to store compiled module in.
            use_str: Optional source string instead of reading from file.
            options: CompileOptions controlling compilation behavior.
        """
        if options is None:
            options = CompileOptions()

        actual_program = self._resolve_program(file_path, target_program)

        # Store options on program so passes can access them
        actual_program._compile_options = options

        keep_str = use_str or read_file_with_encoding(file_path)
        mod_targ = self.parse_str(
            keep_str, file_path, actual_program, cancel_token=options.cancel_token
        )
        if options.symtab_ir_only:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_symtab_ir_sched(),
                cancel_token=options.cancel_token,
            )
        elif options.minimal:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_minimal_ir_gen_sched(),
                cancel_token=options.cancel_token,
            )
        else:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_ir_gen_sched(),
                cancel_token=options.cancel_token,
            )
        if options.type_check and not options.minimal:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_type_check_sched(),
                cancel_token=options.cancel_token,
            )
        if (not mod_targ.has_syntax_errors) and (not options.no_cgen):
            codegen_sched = (
                get_minimal_py_code_gen() if options.minimal else get_py_code_gen()
            )
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=codegen_sched,
                cancel_token=options.cancel_token,
            )
        return mod_targ

    def build(
        self,
        file_path: str,
        target_program: JacProgram,
        use_str: str | None = None,
        type_check: bool = False,
    ) -> uni.Module:
        """Build a Jac file with import dependency resolution."""

        actual_program = self._resolve_program(file_path, target_program)

        options = CompileOptions(type_check=type_check)
        mod_targ = self.compile(file_path, actual_program, use_str, options=options)
        SemanticAnalysisPass(ir_in=mod_targ, prog=actual_program)
        return mod_targ

    def run_schedule(
        self,
        mod: uni.Module,
        target_program: JacProgram,
        passes: list[type[Transform[uni.Module, uni.Module]]],
        cancel_token: Event | None = None,
    ) -> None:
        """Run a list of passes on a module."""
        for current_pass in passes:
            if cancel_token and cancel_token.is_set():
                break
            current_pass(ir_in=mod, prog=target_program, cancel_token=cancel_token)  # type: ignore

    @staticmethod
    def jac_file_formatter(file_path: str, auto_lint: bool = False) -> JacProgram:
        """Format a Jac file."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        source_str = read_file_with_encoding(file_path)
        source = uni.Source(source_str, mod_path=file_path)
        parser_pass = JacParser(root_ir=source, prog=prog)
        current_mod = parser_pass.ir_out
        for pass_cls in get_format_sched(auto_lint=auto_lint):
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out
        prog.mod = uni.ProgramModule(current_mod)
        return prog

    @staticmethod
    def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram:
        """Format a Jac source string."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        source = uni.Source(source_str, mod_path=file_path)
        parser_pass = JacParser(root_ir=source, prog=prog)
        current_mod = parser_pass.ir_out
        for pass_cls in get_format_sched(auto_lint=auto_lint):
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out
        prog.mod = uni.ProgramModule(current_mod)
        return prog

    @staticmethod
    def jac_file_linter(file_path: str) -> JacProgram:
        """Lint a Jac file (report only, no formatting or output generation)."""
        from jaclang.pycore.program import JacProgram

        prog = JacProgram()
        source_str = read_file_with_encoding(file_path)
        source = uni.Source(source_str, mod_path=file_path)
        parser_pass = JacParser(root_ir=source, prog=prog)
        current_mod = parser_pass.ir_out
        for pass_cls in get_lint_sched():
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out
        prog.mod = uni.ProgramModule(current_mod)
        return prog
