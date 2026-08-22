import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.constants {
    RC_BUFFERED_BIT,
    RC_COLOR_BLACK,
    RC_COLOR_GRAY,
    RC_COLOR_SHIFT,
    RC_COLOR_WHITE,
    RC_CYCLE_THRESHOLD
}
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_RC_OFF,
    RC_SENTINEL,
    STR_LEN_TAG_BIT
}

obj NaIRGenCycleCollector(NaIRGenState) {
    def _emit_rc_roots_globals -> None;
    def _emit_rc_collect_cycles -> None;
    def _emit_rc_color_load(
        b: ir.IRBuilder, obj_i8: ir.Value
    ) -> tuple[ir.Value, ir.Value];

    def _emit_rc_color_store(
        b: ir.IRBuilder, csp: ir.Value, cb: ir.Value, color: int
    ) -> None;

    def _emit_rc_color_reset(b: ir.IRBuilder, csp: ir.Value) -> None;
    def _emit_rc_clear_buffered(b: ir.IRBuilder, csp: ir.Value) -> None;
    def _emit_rc_is_buffered(
        b: ir.IRBuilder, obj_i8: ir.Value, name_prefix: str = "buf"
    ) -> ir.Value;

    def _emit_rc_trace_dispatch(
        fn: ir.Function,
        b: ir.IRBuilder,
        obj_i8: ir.Value,
        visitor_fn: ir.Function,
        done_block: ir.Block
    ) -> None;

    def _emit_rc_simple_visitor(name: str, phase_fn: ir.Function) -> ir.Function;
    def _emit_rc_mark_gray_phase -> ir.Function;
    def _emit_rc_scan_black_phase -> ir.Function;
    def _emit_rc_scan_phase(scan_black_fn: ir.Function) -> ir.Function;
    def _emit_rc_collect_white_phase -> ir.Function;
    def _emit_rc_collect_white_reclaim(
        fn: ir.Function, done_bb: ir.Block, ptr: ir.Value
    ) -> ir.Block;

    def _emit_rc_root_pass(
        prefix: str,
        count: ir.Value,
        next_bb: ir.Block,
        phase_fn: ir.Function,
        clear_purple: bool
    ) -> ir.Block;

    def _emit_rc_collect_loop(
        mark_gray_fn: ir.Function, scan_fn: ir.Function, collect_white_fn: ir.Function
    ) -> None;
}
