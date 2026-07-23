import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics { E5090, W6001, W6002, W6003, W6004 }
import from jaclang.jac0core.codeinfo { NATIVE_SUPPORTED_STDLIB }

glob NATIVE_REJECT_NODES: tuple = (uni.DisconnectOp, uni.PyInlineCode, );

def classify_native_import(item: uni.UniNode) -> tuple;

def import_bound_name(item: uni.UniNode) -> (str | None);

def name_in_type_position(name_nd: uni.UniNode) -> bool;

def static_fstring_spec_text(spec: uni.UniNode) -> (str | None);

def native_capability_violations(mod: uni.Module) -> list;

obj PortabilityWarnPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('portability', );

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _check_js_globals(mod: uni.Module) -> None;
    def _check_js_methods(mod: uni.Module) -> None;
    def _check_js_keywords(mod: uni.Module) -> None;
    def _check_js_properties(mod: uni.Module) -> None;
}

obj NativeCapabilityCheckPass(Transform[uni.Module, uni.Module]) {
    static has PROVIDES: tuple = ('capability', );
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
}
