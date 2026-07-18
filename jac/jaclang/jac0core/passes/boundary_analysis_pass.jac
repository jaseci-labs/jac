import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolType, Tokens as Tok }
import from jaclang.jac0core.codeinfo {
    BoundaryTypeInfo,
    InteropBinding,
    InteropContext
}
import from jaclang.jac0core.passes.uni_pass { UniPass }

class BoundaryAnalysisPass(UniPass) {
    def before_pass(self: BoundaryAnalysisPass) -> None;
    def _resolved_native_decl(
        self: BoundaryAnalysisPass, name_node: (uni.UniNode | None)
    ) -> (uni.Ability | None);

    def _get_context(self: BoundaryAnalysisPass, nd: uni.UniNode) -> InteropContext;
    def _extract_type_name(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> str;

    def _resolve_native_module(
        self: BoundaryAnalysisPass, module_name: str
    ) -> (str | None);

    def _in_native_module(self: BoundaryAnalysisPass) -> bool;
    def enter_import(self: BoundaryAnalysisPass, nd: uni.Import) -> None;
    def _register_sv_import(
        self: BoundaryAnalysisPass,
        nd: uni.Import,
        module_name: str,
        caller_ctx: InteropContext
    ) -> None;

    def _collect_abilities(
        self: BoundaryAnalysisPass, nd: any, out: dict[str, any]
    ) -> None;

    def _collect_pub_walkers(
        self: BoundaryAnalysisPass, nd: any, out: dict[str, any]
    ) -> None;

    def _extract_walker_has_fields(
        self: BoundaryAnalysisPass, walker_nd: any
    ) -> tuple[list[str], list[str]];

    def _find_archetype(self: BoundaryAnalysisPass, nd: any, target: str) -> any;
    def _parse_only_source_module(self: BoundaryAnalysisPass, file_path: str) -> any;
    def enter_ability(self: BoundaryAnalysisPass, nd: uni.Ability) -> None;
    def enter_func_call(self: BoundaryAnalysisPass, nd: uni.FuncCall) -> None;
    def _extract_subscript_inner(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> str;

    def _extract_all_subscript_types(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> list[str];

    def _extract_all_type_names(
        self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
    ) -> list[str];

    def _collect_boundary_type(
        self: BoundaryAnalysisPass, type_name: str, source_mod: (uni.Module | None)
    ) -> None;

    def after_pass(self: BoundaryAnalysisPass) -> None;
    def _record_access_levels(self: BoundaryAnalysisPass, manifest: any) -> None;
    def enter_archetype(self: BoundaryAnalysisPass, nd: uni.Archetype) -> None;
    def _classify(self: BoundaryAnalysisPass, body_nodes: list) -> dict;
    def _scan(self: BoundaryAnalysisPass, nd: (uni.UniNode | None)) -> None;
    def _call_target_symbol(
        self: BoundaryAnalysisPass, call: uni.FuncCall
    ) -> (uni.Symbol | None);

    def _callee_body(self: BoundaryAnalysisPass, call: uni.FuncCall) -> list;
    def _resolved_body(self: BoundaryAnalysisPass, owner: uni.UniNode) -> list;
}
