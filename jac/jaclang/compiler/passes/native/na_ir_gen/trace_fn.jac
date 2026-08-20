import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E9002 }

obj NaIRGenTraceFn(NaIRGenState) {
    def _emit_trace_fn(arch_name: str) -> None;
    def _register_trace_pair(dtor_fn: object, trace_fn: ir.Function) -> bool;
    def _finalize_trace_lookup -> None;
    def _require_trace_fn(type_name: str, participates: bool, has_trace: bool) -> None;
    def _struct_has_ref_fields(arch_name: str) -> bool;
}
