"""Jac Compiler - handles all compilation operations separate from program state."""

from __future__ import annotations

import ast as py_ast
import marshal
import os
import types
from threading import Event
from typing import TYPE_CHECKING

import jaclang.pycore.unitree as uni
from jaclang.pycore.bccache import (
    BytecodeCache,
    CacheKey,
    get_bytecode_cache,
)
from jaclang.pycore.helpers import read_file_with_encoding
from jaclang.pycore.jac_parser import JacParser
from jaclang.pycore.passes import (
    DeclImplMatchPass,
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
    from jaclang.compiler.passes.main import CFGBuildPass, SemDefMatchPass

    return [
        SymTabBuildPass,
        DeclImplMatchPass,
        SemanticAnalysisPass,
        SemDefMatchPass,
        CFGBuildPass,
    ]


def get_type_check_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Type checking schedule."""
    from jaclang.compiler.passes.main import TypeCheckPass

    return [TypeCheckPass]


def get_py_code_gen() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Full Python code generation schedule."""
    from jaclang.compiler.passes.ecmascript import EsastGenPass
    from jaclang.compiler.passes.main import PyJacAstLinkPass

    return [EsastGenPass, PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass]


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

    def get_bytecode(
        self, full_target: str, target_program: JacProgram, minimal: bool = False
    ) -> types.CodeType | None:
        """Get bytecode using 3-tier cache: in-memory -> disk -> compile."""
        actual_program = self._resolve_program(full_target, target_program)

        # Tier 1: In-memory cache
        if (
            full_target in actual_program.mod.hub
            and actual_program.mod.hub[full_target].gen.py_bytecode
        ):
            codeobj = actual_program.mod.hub[full_target].gen.py_bytecode
            return marshal.loads(codeobj) if isinstance(codeobj, bytes) else None

        # Tier 2: Disk cache
        cache_key = CacheKey.for_source(full_target, minimal)
        cached_code = self._bytecode_cache.get(cache_key)
        if cached_code is not None:
            return cached_code

        # Tier 3: Compile
        result = self.compile(
            file_path=full_target, target_program=actual_program, minimal=minimal
        )
        if result.gen.py_bytecode:
            self._bytecode_cache.put(cache_key, result.gen.py_bytecode)
            return marshal.loads(result.gen.py_bytecode)
        return None

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
                root_ir=source, prog=target_program
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
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        minimal: bool = False,
        cancel_token: Event | None = None,
    ) -> uni.Module:
        """Compile a Jac file into module AST."""
        actual_program = self._resolve_program(file_path, target_program)

        keep_str = use_str or read_file_with_encoding(file_path)
        mod_targ = self.parse_str(
            keep_str, file_path, actual_program, cancel_token=cancel_token
        )
        if symtab_ir_only:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_symtab_ir_sched(),
                cancel_token=cancel_token,
            )
        elif minimal:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_minimal_ir_gen_sched(),
                cancel_token=cancel_token,
            )
        else:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_ir_gen_sched(),
                cancel_token=cancel_token,
            )
        if type_check and not minimal:
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_type_check_sched(),
                cancel_token=cancel_token,
            )
        if (not mod_targ.has_syntax_errors) and (not no_cgen):
            codegen_sched = get_minimal_py_code_gen() if minimal else get_py_code_gen()
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=codegen_sched,
                cancel_token=cancel_token,
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
        from jaclang.compiler.passes.main import JacImportDepsPass

        actual_program = self._resolve_program(file_path, target_program)

        mod_targ = self.compile(
            file_path, actual_program, use_str, type_check=type_check
        )
        JacImportDepsPass(ir_in=mod_targ, prog=actual_program)
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
