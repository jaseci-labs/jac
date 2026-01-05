"""Jac Machine module."""

from __future__ import annotations

import ast as py_ast
import marshal
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
    Alert,
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
    from jaclang.compiler.type_system.type_evaluator import TypeEvaluator


# Lazy schedule getters - enables converting analysis passes to Jac
def get_symtab_ir_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return symbol table build schedule with lazy imports."""
    return [SymTabBuildPass, DeclImplMatchPass]


def get_ir_gen_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return full IR generation schedule with lazy imports."""
    from jaclang.compiler.passes.main import CFGBuildPass, SemDefMatchPass

    return [
        SymTabBuildPass,
        DeclImplMatchPass,
        SemanticAnalysisPass,
        SemDefMatchPass,
        CFGBuildPass,
    ]


def get_type_check_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return type checking schedule with lazy imports."""
    from jaclang.compiler.passes.main import TypeCheckPass

    return [TypeCheckPass]


def get_py_code_gen() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return Python code generation schedule with lazy imports."""
    from jaclang.compiler.passes.ecmascript import EsastGenPass
    from jaclang.compiler.passes.main import PyJacAstLinkPass

    return [EsastGenPass, PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass]


def get_minimal_ir_gen_sched() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return minimal IR generation schedule (no CFG for faster bootstrap).

    This schedule is used for bootstrap-critical modules that need basic
    semantic analysis but don't need full control flow analysis.
    """
    return [SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass]


def get_minimal_py_code_gen() -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return minimal Python code generation schedule (bytecode only, no JS/type analysis).

    This schedule is used for bootstrap-critical modules (like runtimelib) that must
    be compiled without triggering imports that could cause circular dependencies.
    """
    return [PyastGenPass, PyBytecodeGenPass]


def get_format_sched(
    auto_lint: bool = False,
) -> list[type[Transform[uni.Module, uni.Module]]]:
    """Return format schedule with lazy imports to allow doc_ir.jac conversion.

    Args:
        auto_lint: If True, include auto-linting pass before formatting. Defaults to False.
    """
    from jaclang.compiler.passes.tool.comment_injection_pass import (
        CommentInjectionPass,
    )
    from jaclang.compiler.passes.tool.doc_ir_gen_pass import DocIRGenPass
    from jaclang.compiler.passes.tool.jac_auto_lint_pass import JacAutoLintPass
    from jaclang.compiler.passes.tool.jac_formatter_pass import JacFormatPass
    from jaclang.pycore.passes.annex_pass import JacAnnexPass
    from jaclang.pycore.passes.sym_tab_build_pass import SymTabBuildPass

    if auto_lint:
        return [
            JacAnnexPass,
            SymTabBuildPass,
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


class JacProgram:
    """JacProgram to handle the Jac program-related functionalities."""

    def __init__(
        self,
        main_mod: uni.ProgramModule | None = None,
        bytecode_cache: BytecodeCache | None = None,
    ) -> None:
        """Initialize the JacProgram object.

        Args:
            main_mod: Optional main module to initialize with.
            bytecode_cache: Optional custom bytecode cache. If None, uses default.
        """
        self.mod: uni.ProgramModule = main_mod if main_mod else uni.ProgramModule()
        self.py_raise_map: dict[str, str] = {}
        self.errors_had: list[Alert] = []
        self.warnings_had: list[Alert] = []
        self.type_evaluator: TypeEvaluator | None = None
        self._bytecode_cache: BytecodeCache = bytecode_cache or get_bytecode_cache()

    def get_type_evaluator(self) -> TypeEvaluator:
        """Return the type evaluator."""
        from jaclang.compiler.type_system.type_evaluator import TypeEvaluator

        if not self.type_evaluator:
            self.type_evaluator = TypeEvaluator(program=self)
        return self.type_evaluator

    def clear_type_system(self, clear_hub: bool = False) -> None:
        """Clear all type information from the program.

        This method resets the type evaluator and clears cached type information
        from all AST nodes. This is useful for test isolation when running multiple
        tests in the same process, as type information attached to AST nodes can
        persist in sys.modules and pollute subsequent tests.

        Args:
            clear_hub: If True, also clear all modules from mod.hub. Use with
                       caution as this removes all compiled modules.
        """
        # Clear the type evaluator (will be recreated lazily if needed)
        self.type_evaluator = None

        # Optionally clear the entire module hub (skip node traversal if clearing hub)
        if clear_hub:
            self.mod.hub.clear()
        else:
            # Clear .type attributes from all Expr nodes in all modules
            for mod in self.mod.hub.values():
                for node in mod.get_all_sub_nodes(uni.Expr, brute_force=True):
                    node.type = None

    def get_bytecode(
        self, full_target: str, minimal: bool = False
    ) -> types.CodeType | None:
        """Get the bytecode for a specific module.

        This method implements a three-tier caching strategy:
        1. In-memory cache (mod.hub) - fastest, within current process
        2. Disk cache (__jaccache__/) - persists across restarts
        3. Full compilation - slowest, only when cache misses

        Args:
            full_target: The full path to the module file.
            minimal: If True, use minimal compilation (no JS/type analysis).
                     This avoids circular imports for bootstrap-critical modules.
        """
        # Tier 1: Check in-memory cache (mod.hub)
        if full_target in self.mod.hub and self.mod.hub[full_target].gen.py_bytecode:
            codeobj = self.mod.hub[full_target].gen.py_bytecode
            return marshal.loads(codeobj) if isinstance(codeobj, bytes) else None

        # Tier 2: Check disk cache (__jaccache__/)
        cache_key = CacheKey.for_source(full_target, minimal)
        cached_code = self._bytecode_cache.get(cache_key)
        if cached_code is not None:
            return cached_code

        # Tier 3: Compile and cache bytecode
        result = self.compile(file_path=full_target, minimal=minimal)
        if result.gen.py_bytecode:
            self._bytecode_cache.put(cache_key, result.gen.py_bytecode)
            return marshal.loads(result.gen.py_bytecode)
        return None

    def parse_str(
        self, source_str: str, file_path: str, cancel_token: Event | None = None
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        had_error = False
        if file_path.endswith(".py") or file_path.endswith(".pyi"):
            from jaclang.compiler.passes.main import PyastBuildPass

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
        symtab_ir_only: bool = False,
        minimal: bool = False,
        cancel_token: Event | None = None,
    ) -> uni.Module:
        """Convert a Jac file to an AST.

        Args:
            file_path: Path to the Jac file to compile.
            use_str: Optional source string to use instead of reading from file.
            no_cgen: If True, skip code generation entirely.
            type_check: If True, run type checking pass.
            symtab_ir_only: If True, only build symbol table (skip semantic analysis).
            minimal: If True, use minimal compilation mode (bytecode only, no JS).
                     This avoids circular imports for bootstrap-critical modules.
            cancel_token: Optional event to cancel compilation.
        """
        keep_str = use_str or read_file_with_encoding(file_path)
        mod_targ = self.parse_str(keep_str, file_path, cancel_token=cancel_token)
        if symtab_ir_only:
            # only build symbol table and match decl/impl (skip semantic analysis and CFG)
            self.run_schedule(
                mod=mod_targ, passes=get_symtab_ir_sched(), cancel_token=cancel_token
            )
        elif minimal:
            # Minimal IR generation (skip CFG for faster bootstrap)
            self.run_schedule(
                mod=mod_targ,
                passes=get_minimal_ir_gen_sched(),
                cancel_token=cancel_token,
            )
        else:
            # Full IR generation
            self.run_schedule(
                mod=mod_targ, passes=get_ir_gen_sched(), cancel_token=cancel_token
            )
        if type_check and not minimal:
            self.run_schedule(
                mod=mod_targ, passes=get_type_check_sched(), cancel_token=cancel_token
            )
        # If the module has syntax errors, we skip code generation.
        if (not mod_targ.has_syntax_errors) and (not no_cgen):
            codegen_sched = get_minimal_py_code_gen() if minimal else get_py_code_gen()
            self.run_schedule(
                mod=mod_targ, passes=codegen_sched, cancel_token=cancel_token
            )
        return mod_targ

    def build(
        self, file_path: str, use_str: str | None = None, type_check: bool = False
    ) -> uni.Module:
        """Convert a Jac file to an AST."""
        mod_targ = self.compile(file_path, use_str, type_check=type_check)
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
    def jac_file_formatter(file_path: str, auto_lint: bool = False) -> JacProgram:
        """Format a Jac file and return the JacProgram.

        Args:
            file_path: Path to the Jac file to format.
            auto_lint: If True, apply auto-linting corrections before formatting. Defaults to False.
        """
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
        """Format a Jac string and return the JacProgram.

        Args:
            source_str: The Jac source code string to format.
            file_path: Path to use for error messages.
            auto_lint: If True, apply auto-linting corrections before formatting. Defaults to False.
        """
        prog = JacProgram()
        source = uni.Source(source_str, mod_path=file_path)
        parser_pass = JacParser(root_ir=source, prog=prog)
        current_mod = parser_pass.ir_out
        for pass_cls in get_format_sched(auto_lint=auto_lint):
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out
        prog.mod = uni.ProgramModule(current_mod)
        return prog
