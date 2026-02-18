"""
Type checker pass.

This will perform type checking on the Jac program and accumulate any type
errors found during the process in the pass's had_errors, had_warnings list.

Reference:
    Pyright: packages/pyright-internal/src/analyzer/checker.ts
    craizy_type_expr branch: type_checker_pass.py
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }

"""Type checker pass for JacLang."""
class TypeCheckPass(UniPass) {
    def before_pass(self: TypeCheckPass) -> None;
    def _add_diagnostic(
        self: TypeCheckPass, nd: uni.UniNode, message: str, warning: bool
    ) -> None;

    def _insert_builtin_symbols(self: TypeCheckPass) -> None;
    def enter_ability(self: TypeCheckPass, nd: uni.Ability) -> None;
    def exit_ability(self: TypeCheckPass, nd: uni.Ability) -> None;
    def exit_type_alias(self: TypeCheckPass, nd: uni.TypeAlias) -> None;
    def exit_archetype(self: TypeCheckPass, nd: uni.Archetype) -> None;
    def exit_enum(self: TypeCheckPass, nd: uni.Enum) -> None;
    def exit_import(self: TypeCheckPass, nd: uni.Import) -> None;
    def exit_assignment(self: TypeCheckPass, nd: uni.Assignment) -> None;
    def exit_atom_trailer(self: TypeCheckPass, nd: uni.AtomTrailer) -> None;
    def exit_binary_expr(self: TypeCheckPass, nd: uni.BinaryExpr) -> None;
    def exit_func_call(self: TypeCheckPass, nd: uni.FuncCall) -> None;
    def exit_filter_compr(self: TypeCheckPass, nd: uni.FilterCompr) -> None;
    def exit_return_stmt(self: TypeCheckPass, nd: uni.ReturnStmt) -> None;
    def exit_formatted_value(self: TypeCheckPass, nd: uni.FormattedValue) -> None;
    def exit_edge_ref_trailer(self: TypeCheckPass, nd: uni.EdgeRefTrailer) -> None;
    def exit_special_var_ref(self: TypeCheckPass, nd: uni.SpecialVarRef) -> None;
    def exit_name(self: TypeCheckPass, nd: uni.Name) -> None;
}
