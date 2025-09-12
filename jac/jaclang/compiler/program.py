"""Jac Machine module."""

from __future__ import annotations

import ast as py_ast
import marshal
import types
from typing import Optional

import jaclang.compiler.unitree as uni
from jaclang.compiler.parser import JacParser
from jaclang.compiler.passes.main import (
    Alert,
    BinderPass,
    CFGBuildPass,
    DeclImplMatchPass,
    DefUsePass,
    InheritancePass,
    JacAnnexPass,
    JacImportDepsPass,
    PyBytecodeGenPass,
    PyJacAstLinkPass,
    PyastBuildPass,
    PyastGenPass,
    SemDefMatchPass,
    SymTabBuildPass,
    SymTabLinkPass,
    Transform,
    TypeCheckPass,
)
from jaclang.compiler.passes.tool import (
    DocIRGenPass,
    FuseCommentsPass,
    JacFormatPass,
)
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.utils.log import logging


logger = logging.getLogger(__name__)

ir_gen_sched = [
    SymTabBuildPass,
    DeclImplMatchPass,
    DefUsePass,
    SemDefMatchPass,
    CFGBuildPass,
    InheritancePass,
]
type_check_sched: list = [
    TypeCheckPass,
]
py_code_gen = [
    PyastGenPass,
    PyJacAstLinkPass,
    PyBytecodeGenPass,
]
format_sched = [FuseCommentsPass, DocIRGenPass, JacFormatPass]


class JacProgram:
    """JacProgram to handle the Jac program-related functionalities."""

    def __init__(self, main_mod: Optional[uni.ProgramModule] = None) -> None:
        """Initialize the JacProgram object."""
        self.mod: uni.ProgramModule = main_mod if main_mod else uni.ProgramModule()
        self.py_raise_map: dict[str, str] = {}
        self.errors_had: list[Alert] = []
        self.warnings_had: list[Alert] = []

    def get_bytecode(self, full_target: str) -> Optional[types.CodeType]:
        """Get the bytecode for a specific module."""
        if full_target in self.mod.hub and self.mod.hub[full_target].gen.py_bytecode:
            codeobj = self.mod.hub[full_target].gen.py_bytecode
            return marshal.loads(codeobj) if isinstance(codeobj, bytes) else None
        result = self.compile(file_path=full_target)
        return marshal.loads(result.gen.py_bytecode) if result.gen.py_bytecode else None

    def parse_str(self, source_str: str, file_path: str) -> uni.Module:
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
            )
            had_error = len(py_ast_ret.errors_had) > 0
            mod = py_ast_ret.ir_out
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
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        keep_str = use_str or read_file_with_encoding(file_path)
        mod_targ = self.parse_str(keep_str, file_path)
        self.run_schedule(mod=mod_targ, passes=ir_gen_sched)
        if type_check:
            self.run_schedule(mod=mod_targ, passes=type_check_sched)
        if not no_cgen:
            self.run_schedule(mod=mod_targ, passes=py_code_gen)
        return mod_targ

    def bind(self, file_path: str, use_str: str | None = None) -> uni.Module:
        """Bind the Jac module."""
        keep_str = use_str or read_file_with_encoding(file_path)
        mod_targ = self.parse_str(keep_str, file_path)
        BinderPass(ir_in=mod_targ, prog=self)
        return mod_targ

    def build(
        self, file_path: str, use_str: str | None = None, type_check: bool = False
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        mod_targ = self.compile(file_path, use_str, type_check=type_check)
        JacImportDepsPass(ir_in=mod_targ, prog=self)
        for mod in self.mod.hub.values():
            SymTabLinkPass(ir_in=mod, prog=self)
        for mod in self.mod.hub.values():
            DefUsePass(mod, prog=self)
        return mod_targ

    def run_schedule(
        self,
        mod: uni.Module,
        passes: list[type[Transform[uni.Module, uni.Module]]],
    ) -> None:
        """Run the passes on the module."""
        final_pass: Optional[type[Transform[uni.Module, uni.Module]]] = None
        for current_pass in passes:
            if current_pass == PyBytecodeGenPass:
                final_pass = current_pass
                break
            current_pass(ir_in=mod, prog=self)  # type: ignore
        if final_pass:
            final_pass(mod, prog=self)

    @staticmethod
    def jac_file_formatter(file_path: str) -> str:
        """Convert a Jac file to an AST."""
        prog = JacProgram()
        source_str = read_file_with_encoding(file_path)
        source = uni.Source(source_str, mod_path=file_path)
        prse: Transform = JacParser(root_ir=source, prog=prog)
        for i in format_sched:
            prse = i(ir_in=prse.ir_out, prog=prog)
        prse.errors_had = prog.errors_had
        prse.warnings_had = prog.warnings_had
        return prse.ir_out.gen.jac

    @staticmethod
    def jac_str_formatter(source_str: str, file_path: str) -> str:
        """Convert a Jac file to an AST."""
        prog = JacProgram()
        source = uni.Source(source_str, mod_path=file_path)
        prse: Transform = JacParser(root_ir=source, prog=prog)
        for i in format_sched:
            prse = i(ir_in=prse.ir_out, prog=prog)
        prse.errors_had = prog.errors_had
        prse.warnings_had = prog.warnings_had
        return prse.ir_out.gen.jac if not prse.errors_had else source_str
