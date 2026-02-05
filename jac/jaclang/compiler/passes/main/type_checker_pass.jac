"""
Type checker pass.

This will perform type checking on the Jac program and accumulate any type
errors found during the process in the pass's had_errors, had_warnings list.

Reference:
    Pyright: packages/pyright-internal/src/analyzer/checker.ts
    craizy_type_expr branch: type_checker_pass.py
"""
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }

"""Type checker pass for JacLang."""
class TypeCheckPass(UniPass) {
    def before_pass(self: TypeCheckPass) -> None;
    def _add_diagnostic(
        self: TypeCheckPass, <>node: uni.UniNode, message: str, warning: bool
    ) -> None;

    def _insert_builtin_symbols(self: TypeCheckPass) -> None;
    def enter_ability(self: TypeCheckPass, <>node: uni.Ability) -> None;
    def exit_ability(self: TypeCheckPass, <>node: uni.Ability) -> None;
    def exit_archetype(self: TypeCheckPass, <>node: uni.Archetype) -> None;
    def exit_enum(self: TypeCheckPass, <>node: uni.Enum) -> None;
    def exit_import(self: TypeCheckPass, <>node: uni.Import) -> None;
    def exit_assignment(self: TypeCheckPass, <>node: uni.Assignment) -> None;
    def exit_atom_trailer(self: TypeCheckPass, <>node: uni.AtomTrailer) -> None;
    def exit_binary_expr(self: TypeCheckPass, <>node: uni.BinaryExpr) -> None;
    def exit_func_call(self: TypeCheckPass, <>node: uni.FuncCall) -> None;
    def exit_filter_compr(self: TypeCheckPass, <>node: uni.FilterCompr) -> None;
    def exit_return_stmt(self: TypeCheckPass, <>node: uni.ReturnStmt) -> None;
    def exit_formatted_value(self: TypeCheckPass, <>node: uni.FormattedValue) -> None;
    def exit_edge_ref_trailer(self: TypeCheckPass, <>node: uni.EdgeRefTrailer) -> None;
    def exit_special_var_ref(self: TypeCheckPass, <>node: uni.SpecialVarRef) -> None;
    def exit_name(self: TypeCheckPass, <>node: uni.Name) -> None;
}
