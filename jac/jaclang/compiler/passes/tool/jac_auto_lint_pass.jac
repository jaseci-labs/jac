"""Jac Auto Linting Pass for automatic code pattern corrections.

This pass applies automatic linting corrections to Jac code, including:
- Converting `with entry` blocks to `glob` declarations (in-place)
- Converting `@staticmethod` decorator to `static` keyword
- Combining consecutive `has` statements with same modifiers into single statement
- Combining consecutive `glob` statements with same modifiers into single statement
- Converting `def __init__` to `can init` (Jac style)
- Converting `def __post_init__` to `can postinit` (Jac style)
- Removing empty parentheses from function/method declarations (def foo() -> def foo)
- Removing unnecessary backtick escaping from names that are not actual keywords
- Converting hasattr(obj, "attr") to null-safe access
- Propagating null-safe access consistency
- Simplifying ternary expressions (x if x else default -> x or default)
- Removing `import from __future__ { annotations }` (not needed in Jac)
- Fixing signature mismatches between declarations and implementations
- Removing trailing semicolons from `import from X { ... }` style imports
- (Future) Import organization
- (Future) Redundant code removal
"""
import keyword;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.constant { TOKEN_MAP }
import from jaclang.project.config { LintRule }

"""Auto linting pass that applies code style corrections to Jac AST."""
obj JacAutoLintPass(UniPass) {
    """Initialize the pass with linting options."""
    def init(ir_in: uni.Module, prog: Any) -> None;

    def _load_lint_config -> None;
    def is_rule_enabled(rule: LintRule) -> bool;
    def _is_file_excluded(file_path: str) -> bool;
    def enter_module(nd: uni.Module) -> None;
    def can_convert_to_glob(assignment: uni.Assignment) -> bool;
    def is_module_level_construct(stmt: uni.UniNode) -> bool;
    def create_glob_from_assignment(assignment: uni.Assignment) -> uni.GlobalVars;
    def create_entry_block(stmts: list) -> uni.ModuleCode;
    def can_combine_has(has1: uni.ArchHas, has2: uni.ArchHas) -> bool;
    def can_combine_glob(glob1: uni.GlobalVars, glob2: uni.GlobalVars) -> bool;
    def combine_consecutive_has(body: list) -> list;
    def combine_consecutive_glob(body: list) -> list;
    def enter_archetype(nd: uni.Archetype) -> None;
    def enter_enum(nd: uni.Enum) -> None;
    def enter_impl_def(nd: uni.ImplDef) -> None;
    def exit_impl_def(nd: uni.ImplDef) -> None;
    def enter_ability(ability_node: uni.Ability) -> None;
    def _remove_staticmethod_from_kids(ability_node: uni.Ability) -> None;
    def exit_ability(ability_node: uni.Ability) -> None;
    def enter_name(nd: uni.Name) -> None;
    def enter_special_var_ref(nd: uni.SpecialVarRef) -> None;
    def enter_builtin_type(nd: uni.BuiltinType) -> None;
    def exit_func_call(nd: uni.FuncCall) -> None;
    def _convert_hasattr_to_null_ok(nd: uni.FuncCall) -> (uni.AtomTrailer | None);
    def _is_matching_attr_access(
        trailer: uni.AtomTrailer, obj_expr: uni.Expr, attr_name: str
    ) -> bool;

    def _make_null_ok(trailer: uni.AtomTrailer) -> None;
    def _bool_expr_has_matching_access(
        parent: uni.BoolExpr,
        hasattr_node: uni.FuncCall,
        obj_expr: uni.Expr,
        attr_name: str
    ) -> bool;

    def _collect_atom_trailers(uni_node: uni.UniNode, results: list) -> None;
    def _expr_to_key(expr: uni.Expr) -> (str | None);
    def _get_trailer_key(trailer: uni.AtomTrailer) -> (str | None);
    def _exprs_are_identical(expr1: uni.Expr, expr2: uni.Expr) -> bool;
    def _convert_ternary_to_or(if_else_node: uni.IfElseExpr) -> bool;
    def exit_if_else_expr(if_else_node: uni.IfElseExpr) -> None;
    def exit_bool_expr(bool_node: uni.BoolExpr) -> None;
    def _is_future_annotations_import(stmt: uni.UniNode) -> bool;
    def _fix_impl_signature_mismatch(impl_node: uni.ImplDef) -> None;
    def _signatures_match(
        decl_sig: uni.FuncSignature, impl_sig: uni.FuncSignature
    ) -> bool;

    def enter_import(import_node: uni.Import) -> None;
    def _remove_empty_parens_from_sig(
        target_node: uni.UniNode, sig: uni.FuncSignature, sig_attr: str
    ) -> None;

    def _extract_string_literal_value(expr: uni.Expr) -> (str | None);
    def _check_no_print(nd: uni.FuncCall) -> None;
}
