import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo { HDR_RC_OFF, RC_SENTINEL }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenOsp(NaIRGenState) {
    def _codegen_chained_filter(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _compute_osp_model(archetypes: list[uni.Archetype]) -> None;
    def _osp_active -> bool;
    def _xmod_osp_help(names: list) -> (str | None);
    def _register_osp_kernel_module -> None;
    def _osp_kernel_init_fns -> list[ir.Function];
    def _emit_osp_thunk(arch_name: str, method: uni.Ability) -> None;
    def _emit_osp_setup -> None;
    def _osp_rc_new(struct_name: str) -> (ir.Value | None);
    def _osp_make_immortal(ptr: ir.Value) -> None;
    def _osp_build_slot(trig_tag: int, thunk: ir.Function) -> (ir.Value | None);
    def _osp_build_descriptor(
        struct_name: str, type_tag: int, entry_slots: list, exit_slots: list
    ) -> (ir.Value | None);

    def _osp_build_slot_list(pairs: list) -> ir.Value;
    def _osp_collect_slots(arch_name: str, is_entry: bool) -> list;
    def _osp_emit_callbacks -> dict;
    def _osp_pred_pair(
        arch_name: str, compares: list[uni.CompareExpr], nd: uni.UniNode
    ) -> (ir.Value | None);

    def _osp_type_pair(ntag: int) -> (ir.Value | None);
    def _codegen_visit(nd: uni.VisitStmt) -> None;
    def _codegen_disengage(nd: uni.DisengageStmt) -> None;
    def _codegen_report(nd: uni.ReportStmt) -> None;
    def _codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_disconnect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _osp_disc_list_operand(expr: (uni.UniNode | None)) -> bool;
    def _codegen_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> (ir.Value | None);
    def _elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _osp_visit_targets(target: uni.UniNode) -> (ir.Value | None);
    def _osp_generic_edge -> (ir.Value | None);
}
