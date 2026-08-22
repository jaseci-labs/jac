import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5092, E9002 }
import jaclang.jac0core.unitree as uni;
import os;
import from jaclang.jac0core.constant { OwnershipKind }

obj NaIRGenStmt(NaIRGenState) {
    def _codegen_body(stmts: (list | tuple)) -> None;
    def _codegen_stmt(nd: uni.UniNode) -> None;
    def _codegen_return(nd: uni.ReturnStmt) -> None;
    def _codegen_if(nd: uni.IfStmt) -> None;
    def _codegen_switch(nd: uni.SwitchStmt) -> None;
    def _codegen_while(nd: uni.WhileStmt) -> None;
    def _codegen_open_stmt(nd: uni.OpenStmt) -> None;
    def _codegen_forever(nd: uni.ForeverStmt) -> None;
    def _codegen_assignment(nd: uni.Assignment) -> None;
    def _codegen_ctrl(nd: uni.CtrlStmt) -> None;
    def _codegen_for(nd: uni.InForStmt) -> None;
    def _codegen_for_indexed(
        nd: uni.InForStmt,
        kind: str,
        collection_val: ir.Value,
        helpers: (dict | None),
        var_names: list,
        var_types: list,
        rc_vars: bool,
        coll_release_op: str,
        range_start: (ir.Value | None) = None,
        elem_cast: (ir.Type | None) = None,
        unpack_target: (uni.TupleVal | None) = None,
        range_step: (ir.Value | None) = None
    ) -> None;

    def _codegen_iter_for(nd: uni.IterForStmt) -> None;
    def _codegen_match(nd: uni.MatchStmt) -> None;
    def _match_pattern_cond(
        pat: uni.MatchPattern, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_seq_cond(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_tuple_seq_cond(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_map_cond(
        pat: uni.MatchMapping, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_arch_cond(
        pat: uni.MatchArch, subj: ir.Value, subj_ty: (object | None) = None
    ) -> (ir.Value | None);

    def _match_seq_parts(pat: uni.MatchSequence) -> tuple;
    def _match_subj_ty(expr: (uni.UniNode | None)) -> (object | None);
    def _match_elem_ty_of(
        subj_ty: (object | None), prefix: str, idx: int
    ) -> (object | None);

    def _match_cast_elem(elem: ir.Value, elem_ty: (object | None)) -> ir.Value;
    def _match_map_key(kv: uni.MatchKVPair, helpers: dict) -> (ir.Value | None);
    def _match_arch_fields(pat: uni.MatchArch, arch_name: str) -> (list | None);
    def _match_value_eq(subj: ir.Value, value_node: uni.UniNode) -> (ir.Value | None);
    def _bind_match_pattern(
        pat: uni.MatchPattern, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _bind_match_capture(cap_name: str, val: ir.Value, owned: bool = False) -> None;
    def _bind_match_seq(
        pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _bind_match_map(
        pat: uni.MatchMapping, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _bind_match_arch(
        pat: uni.MatchArch, subj: ir.Value, subj_ty: (object | None) = None
    ) -> None;

    def _apply_scalar_aug_op(
        current: ir.Value,
        rhs: ir.Value,
        aug_op: str,
        rhs_node: (uni.Expr | None) = None
    ) -> (ir.Value | None);

    def _try_flow_for_parallel(nd: uni.InForStmt) -> bool;
    def _na_chunks_shape(expr: object) -> (tuple | None);
    def _try_chunked_for(nd: uni.InForStmt) -> bool;
    def _emit_chunk_header(
        coll: ir.Value,
        n_val: ir.Value,
        ci: ir.Value,
        hdr: ir.Value,
        len_fn: ir.Function
    ) -> None;

    def _emit_last_use_releases(stmt: uni.UniNode) -> None;
}
