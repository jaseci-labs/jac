"""Jac Machine module."""

from __future__ import annotations

import ast as py_ast
import marshal
import types
from threading import Event
from typing import TYPE_CHECKING

import jaclang.compiler.unitree as uni
from jaclang.compiler.parser import JacParser
from jaclang.compiler.passes.ecmascript import EsastGenPass
from jaclang.compiler.passes.main import (
    Alert,
    CFGBuildPass,
    DeclImplMatchPass,
    JacAnnexPass,
    JacImportDepsPass,
    PreDynamoPass,
    PyastBuildPass,
    PyastGenPass,
    PyBytecodeGenPass,
    PyJacAstLinkPass,
    SemanticAnalysisPass,
    SemDefMatchPass,
    SymTabBuildPass,
    Transform,
    TypeCheckPass,
)
from jaclang.compiler.passes.tool import (
    CommentInjectionPass,
    DocIRGenPass,
    JacFormatPass,
)
from jaclang.compiler.ts_parser import TypeScriptParser
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.settings import settings

if TYPE_CHECKING:
    from jaclang.compiler.type_system.type_evaluator import TypeEvaluator

ir_gen_sched: list[type[Transform[uni.Module, uni.Module]]] = [
    SymTabBuildPass,
    DeclImplMatchPass,
    SemanticAnalysisPass,
    SemDefMatchPass,
    CFGBuildPass,
]
type_check_sched: list[type[Transform[uni.Module, uni.Module]]] = [
    TypeCheckPass,
]
py_code_gen: list[type[Transform[uni.Module, uni.Module]]] = [
    EsastGenPass,
    PyastGenPass,
    PyJacAstLinkPass,
    PyBytecodeGenPass,
]
format_sched: list[type[Transform[uni.Module, uni.Module]]] = [
    DocIRGenPass,
    CommentInjectionPass,
    JacFormatPass,
]


class JacProgram:
    """JacProgram to handle the Jac program-related functionalities."""

    def __init__(
        self,
        main_mod: uni.ProgramModule | None = None,
    ) -> None:
        """Initialize the JacProgram object."""
        self.mod: uni.ProgramModule = main_mod if main_mod else uni.ProgramModule()
        self.py_raise_map: dict[str, str] = {}
        self.errors_had: list[Alert] = []
        self.warnings_had: list[Alert] = []
        self.type_evaluator: TypeEvaluator | None = None

    def get_type_evaluator(self) -> TypeEvaluator:
        """Return the type evaluator."""
        from jaclang.compiler.type_system.type_evaluator import TypeEvaluator

        if not self.type_evaluator:
            self.type_evaluator = TypeEvaluator(program=self)
        return self.type_evaluator

    def get_bytecode(self, full_target: str) -> types.CodeType | None:
        """Get the bytecode for a specific module."""
        if full_target in self.mod.hub and self.mod.hub[full_target].gen.py_bytecode:
            codeobj = self.mod.hub[full_target].gen.py_bytecode
            return marshal.loads(codeobj) if isinstance(codeobj, bytes) else None
        result = self.compile(file_path=full_target)
        return marshal.loads(result.gen.py_bytecode) if result.gen.py_bytecode else None

    def parse_str(
        self, source_str: str, file_path: str, cancel_token: Event | None = None
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        had_error = False
        if file_path.endswith(".py") or file_path.endswith(".pyi"):
            parsed_ast = py_ast.parse(source_str)
            py_ast_ret = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    parsed_ast,
                    orig_src=uni.Source(source_str, mod_path=file_path),
                ),
                prog=self,
                cancel_token=cancel_token,
            )
            had_error = len(py_ast_ret.errors_had) > 0
            mod = py_ast_ret.ir_out
        elif file_path.endswith((".js", ".ts", ".jsx", ".tsx")):
            # Parse TypeScript/JavaScript files
            source = uni.Source(source_str, mod_path=file_path)
            ts_ast_ret = TypeScriptParser(
                root_ir=source, prog=self, cancel_token=cancel_token
            )
            had_error = len(ts_ast_ret.errors_had) > 0
            mod = ts_ast_ret.ir_out
        else:
            source = uni.Source(source_str, mod_path=file_path)
            jac_ast_ret: Transform[uni.Source, uni.Module] = JacParser(
                root_ir=source, prog=self
            )
            had_error = len(jac_ast_ret.errors_had) > 0
            mod = jac_ast_ret.ir_out
        if had_error:
            return mod
        if self.mod.main.stub_only:
            self.mod = uni.ProgramModule(mod)
        self.mod.hub[mod.loc.mod_path] = mod
        JacAnnexPass(ir_in=mod, prog=self)
        return mod

    def compile(
        self,
        file_path: str,
        use_str: str | None = None,
        # TODO: Create a compilation options class and put the bellow
        # options in it.
        no_cgen: bool = False,
        type_check: bool = False,
        cancel_token: Event | None = None,
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        keep_str = use_str or read_file_with_encoding(file_path)
        mod_targ = self.parse_str(keep_str, file_path, cancel_token=cancel_token)
        self.run_schedule(mod=mod_targ, passes=ir_gen_sched, cancel_token=cancel_token)
        if type_check:
            self.run_schedule(
                mod=mod_targ, passes=type_check_sched, cancel_token=cancel_token
            )
        # If the module has syntax errors, we skip code generation.
        if (not mod_targ.has_syntax_errors) and (not no_cgen):
            if settings.predynamo_pass and PreDynamoPass not in py_code_gen:
                py_code_gen.insert(0, PreDynamoPass)
            self.run_schedule(
                mod=mod_targ, passes=py_code_gen, cancel_token=cancel_token
            )
        return mod_targ

    def build(
        self, file_path: str, use_str: str | None = None, type_check: bool = False
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        mod_targ = self.compile(file_path, use_str, type_check=type_check)
        JacImportDepsPass(ir_in=mod_targ, prog=self)
        SemanticAnalysisPass(ir_in=mod_targ, prog=self)
        return mod_targ

    def run_schedule(
        self,
        mod: uni.Module,
        passes: list[type[Transform[uni.Module, uni.Module]]],
        cancel_token: Event | None = None,
    ) -> None:
        """Run the passes on the module."""
        for current_pass in passes:
            current_pass(ir_in=mod, prog=self, cancel_token=cancel_token)  # type: ignore

    @staticmethod
    def jac_file_formatter(file_path: str) -> str:
        """Convert a Jac file to an AST."""
        prog = JacProgram()
        source_str = read_file_with_encoding(file_path)
        source = uni.Source(source_str, mod_path=file_path)
        parser_pass = JacParser(root_ir=source, prog=prog)
        current_mod = parser_pass.ir_out
        for pass_cls in format_sched:
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out
        parser_pass.errors_had = prog.errors_had
        parser_pass.warnings_had = prog.warnings_had
        return current_mod.gen.jac if not parser_pass.errors_had else source_str

    @staticmethod
    def jac_str_formatter(source_str: str, file_path: str) -> str:
        """Convert a Jac file to an AST."""
        prog = JacProgram()
        source = uni.Source(source_str, mod_path=file_path)
        parser_pass = JacParser(root_ir=source, prog=prog)
        current_mod = parser_pass.ir_out
        for pass_cls in format_sched:
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out
        parser_pass.errors_had = prog.errors_had
        parser_pass.warnings_had = prog.warnings_had
        return current_mod.gen.jac if not parser_pass.errors_had else source_str
