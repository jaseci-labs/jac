"""Jac Auto Linting Pass for automatic code pattern corrections.

This pass applies automatic linting corrections to Jac code, including:
- Converting `with entry` blocks to `glob` declarations (in-place)
- Converting `@staticmethod` decorator to `static` keyword
- Combining consecutive `has` statements with same modifiers into single statement
- Combining consecutive `glob` statements with same modifiers into single statement
- Converting `def __init__` to `can init` (Jac style)
- Converting `def __post_init__` to `can postinit` (Jac style)
- Removing empty parentheses from function/method declarations (def foo() -> def foo)
- Removing unnecessary angle bracket escaping from names that are not actual keywords
- Converting hasattr(obj, "attr") to null-safe access
- Propagating null-safe access consistency
- Simplifying ternary expressions (x if x else default -> x or default)
- (Future) Import organization
- (Future) Redundant code removal
"""
import keyword;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes { UniPass }
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.jac_parser { TOKEN_MAP }
"""Auto linting pass that applies code style corrections to Jac AST."""
class JacAutoLintPass(UniPass) {
    """Initialize the pass with linting options."""
    with entry {
        lint_enabled: bool = True;
    }

    def enter_module(self: JacAutoLintPass, node: uni.Module) -> None;
    def can_convert_to_glob(self: JacAutoLintPass, assignment: uni.Assignment) -> bool;
    def is_module_level_construct(self: JacAutoLintPass, stmt: uni.UniNode) -> bool;
    def create_glob_from_assignment(
        self: JacAutoLintPass, assignment: uni.Assignment
    ) -> uni.GlobalVars;

    def create_entry_block(self: JacAutoLintPass, stmts: list) -> uni.ModuleCode;
    def can_combine_has(
        self: JacAutoLintPass, has1: uni.ArchHas, has2: uni.ArchHas
    ) -> bool;

    def can_combine_glob(
        self: JacAutoLintPass, glob1: uni.GlobalVars, glob2: uni.GlobalVars
    ) -> bool;

    def combine_consecutive_has(self: JacAutoLintPass, body: list) -> list;
    def combine_consecutive_glob(self: JacAutoLintPass, body: list) -> list;
    def enter_archetype(self: JacAutoLintPass, node: uni.Archetype) -> None;
    def enter_enum(self: JacAutoLintPass, node: uni.Enum) -> None;
    def enter_impl_def(self: JacAutoLintPass, node: uni.ImplDef) -> None;
    def enter_ability(self: JacAutoLintPass, ability_node: uni.Ability) -> None;
    def _remove_staticmethod_from_kids(
        self: JacAutoLintPass, ability_node: uni.Ability
    ) -> None;

    def exit_ability(self: JacAutoLintPass, ability_node: uni.Ability) -> None;
    def enter_name(self: JacAutoLintPass, <>node: uni.Name) -> None;
    def enter_special_var_ref(self: JacAutoLintPass, <>node: uni.SpecialVarRef) -> None;
    def enter_builtin_type(self: JacAutoLintPass, <>node: uni.BuiltinType) -> None;
    def exit_func_call(self: JacAutoLintPass, node: uni.FuncCall) -> None;
    def _convert_hasattr_to_null_ok(
        self: JacAutoLintPass, node: uni.FuncCall
    ) -> (uni.AtomTrailer | None);

    def _is_matching_attr_access(
        self: JacAutoLintPass,
        trailer: uni.AtomTrailer,
        obj_expr: uni.Expr,
        attr_name: str
    ) -> bool;

    def _make_null_ok(self: JacAutoLintPass, trailer: uni.AtomTrailer) -> None;
    def _collect_atom_trailers(
        self: JacAutoLintPass, uni_node: uni.UniNode, results: list
    ) -> None;

    def _get_trailer_key(
        self: JacAutoLintPass, trailer: uni.AtomTrailer
    ) -> (str | None);

    def _exprs_are_identical(
        self: JacAutoLintPass, expr1: uni.Expr, expr2: uni.Expr
    ) -> bool;

    def _convert_ternary_to_or(
        self: JacAutoLintPass, if_else_node: uni.IfElseExpr
    ) -> bool;

    def exit_if_else_expr(self: JacAutoLintPass, if_else_node: uni.IfElseExpr) -> None;
    def exit_bool_expr(self: JacAutoLintPass, bool_node: uni.BoolExpr) -> None;
}
