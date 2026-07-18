import ast as ast3;
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { SymbolType }
import from jaclang.jac0core.diagnostics {
    W1103,
    W1104,
    W2001,
    W2002,
    W2003,
    W2058,
    W2063,
    W2070,
    W2074,
    W2075,
    E2018,
    E2027,
    E2055,
    E2083
}

obj StaticAnalysisPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('static-checks', );

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _check_unused_symbols(scope: uni.UniScopeNode) -> None;
    def _check_undefined_names(mod: uni.Module) -> None;
    def _literal_case_suggestion(name: str) -> (str | None);
    def _osp_shape_position(name_nd: uni.Name) -> (str | None);
    def _native_type_position(name_nd: uni.Name) -> (str | None);
    def _check_unreachable_code(mod: uni.Module) -> None;
    def _check_semantic_patterns(mod: uni.Module) -> None;
    def _check_redundant_imports(mod: uni.Module) -> None;
}
