import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo { HDR_DTOR_OFF }
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;

obj NaIRGenFunc(NaIRGenState) {
    def _forward_declare_functions(module: uni.Module) -> None;
    def _nogc_owned_param(p: uni.ParamVar) -> bool;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None;
    def _apply_ownership_param_attrs(
        func: ir.Function, params: list[uni.ParamVar], base: int
    ) -> None;

    def _codegen_ability(nd: uni.Ability) -> None;
    def _codegen_nested_ability(nd: uni.Ability) -> None;
    def _predeclare_nested_siblings(nd: uni.Ability) -> None;
    def _codegen_test(nd: uni.Test) -> None;
    def _apply_static_decorators -> None;
    def _ability_is_generator(nd: uni.Ability) -> bool;
    def _generator_elem_type(nd: uni.Ability) -> (ir.Type | None);
    def _codegen_generator(nd: uni.Ability, func: ir.Function) -> None;
    def _emit_generator_drop_fn(name: str, slots: list[tuple]) -> ir.Function;
    def _define_function(name: str, fnty: ir.FunctionType) -> ir.Function;
    def _codegen_entry(nodes: list[uni.ModuleCode]) -> None;
    def _declare_clib_ability(nd: uni.Ability) -> None;
    def _normalize_type_key(key: str) -> str;
    def _elem_keys_of_annotation(ann: (uni.UniNode | None)) -> (list | None);
    def _record_ret_facts(name: str, sig: uni.FuncSignature) -> None;
    def _emit_glob_init_func -> None;
}
