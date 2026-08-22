import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo { HDR_RC_OFF, RC_SENTINEL }
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.type_system.types { ClassType }

obj NaIRGenOsp(NaIRGenState) {
    def _codegen_chained_filter(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _compute_osp_model(archetypes: list[uni.Archetype]) -> None;
    def _osp_active -> bool;
    def _xmod_osp_help(names: list) -> (str | None);
    def _register_osp_kernel_module -> None;
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
    def _osp_emit_h2i_fn(hash_global: ir.GlobalVariable, n: int) -> ir.Function;
    def _osp_emit_callbacks(isa_global: ir.GlobalVariable, n: int) -> dict;
    def _osp_emit_filter_fn(
        isa_global: ir.GlobalVariable, n: int
    ) -> (ir.Function | None);

    def _osp_isa_bases(arch_name: str) -> list[int];
    def _codegen_visit(nd: uni.VisitStmt) -> None;
    def _codegen_disengage(nd: uni.DisengageStmt) -> None;
    def _codegen_report(nd: uni.ReportStmt) -> None;
    def _codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _codegen_disconnect(nd: uni.BinaryExpr) -> (ir.Value | None);
    def _osp_disc_list_operand(expr: (uni.UniNode | None)) -> bool;
    def _codegen_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> (ir.Value | None);
    def _emit_osp_predicate_filter(
        src: ir.Value, arch_name: str, compares: list[uni.CompareExpr], nd: uni.UniNode
    ) -> (ir.Value | None);

    def _emit_osp_edge_pred_hop(
        origins: ir.Value,
        dir_val: int,
        edge_tag: int,
        edge_arch: str,
        compares: list[uni.CompareExpr],
        nd: uni.UniNode
    ) -> (ir.Value | None);

    def _elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _osp_visit_targets(target: uni.UniNode) -> (ir.Value | None);
    def _osp_generic_edge -> (ir.Value | None);
}
