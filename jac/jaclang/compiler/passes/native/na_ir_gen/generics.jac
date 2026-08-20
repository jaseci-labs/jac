import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;
import os;

obj NaIRGenGenerics(NaIRGenState) {
    def _mangled_of(t: any) -> (str | None);
    def _solve_generic_call(ability: uni.Ability, nd: uni.FuncCall) -> (dict | None);
    def _instantiate_generic(nd: uni.FuncCall, func_name: str) -> (ir.Function | None);
    def _stamp_mono_fn(
        ability: uni.Ability, spec_name: str, memo_key: str
    ) -> (ir.Function | None);

    def _instantiate_generic_method(
        nd: uni.FuncCall, owner_arch: str, method_name: str
    ) -> (ir.Function | None);

    def _instantiate_generic_for_target(
        func_name: str, tag_node: uni.UniNode
    ) -> (ir.Function | None);

    def _stamp_mono_method(
        ability: uni.Ability,
        arch_name: str,
        method_name: str,
        spec_name: str,
        memo_key: str
    ) -> (ir.Function | None);

    def _find_source_ability(mod_name: str, func_name: str) -> (uni.Ability | None);
}
