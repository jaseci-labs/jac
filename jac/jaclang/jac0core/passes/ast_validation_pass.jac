"""AST Validation Pass - structural validity checks after parsing.

Validates AST invariants that the parser deliberately does not enforce,
following the modern compiler philosophy of 'parse permissively, validate later'.
This keeps the parser focused on tree construction while this pass provides
precise, context-rich error messages for structural violations.

Runs immediately after parsing, before SymTabBuildPass. Requires no symbol
table or type information - only the raw AST structure.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

"""Validates structural AST invariants after parsing."""
class ASTValidationPass(UniPass) {
    def enter_try_stmt(self: ASTValidationPass, nd: uni.TryStmt) -> None;
    def enter_match_stmt(self: ASTValidationPass, nd: uni.MatchStmt) -> None;
    def enter_module_code(self: ASTValidationPass, nd: uni.ModuleCode) -> None;
    def enter_binary_expr(self: ASTValidationPass, nd: uni.BinaryExpr) -> None;
    def enter_name(self: ASTValidationPass, nd: uni.Name) -> None;
    def enter_func_signature(self: ASTValidationPass, nd: uni.FuncSignature) -> None;
    def enter_iter_for_stmt(self: ASTValidationPass, nd: uni.IterForStmt) -> None;
    def enter_import(self: ASTValidationPass, nd: uni.Import) -> None;
    def enter_enum(self: ASTValidationPass, nd: uni.Enum) -> None;
    def enter_switch_stmt(self: ASTValidationPass, nd: uni.SwitchStmt) -> None;
}
