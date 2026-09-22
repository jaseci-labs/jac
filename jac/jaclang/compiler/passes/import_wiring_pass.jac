import os;
import from jaclang.compiler.passes.context { CompileContext }
import from jaclang.compiler.frontend.unitree {
    EmptyToken,
    ImplImport,
    Import,
    ImportRule,
    ImportWire,
    Module,
    ModuleItem,
    ModulePath,
    ModulePattern,
    String,
    UniNode
}
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.driver.wiring {
    WireBinding,
    WiringSpec,
    is_arch_file,
    wiring_for_path
}
import from jaclang.project.source { pascal_to_snake }
import from jaclang.compiler.frontend.diagnostics {
    E1140,
    E1141,
    E1142,
    E1143,
    E1144,
    E2088,
    E2089,
    E2090,
    E2091,
    E2092,
    E2093,
    W2083
}

walker ImportWiringPass {
    has ctx: CompileContext,
        module: Module;

    can run_walk with Module entry;
    def _check_arch_module(mod: Module) -> None;
    def _check_scope(spec: WiringSpec, block: ImplImport, seen: set[int]) -> None;
    def _check_wire(spec: WiringSpec, wire: ImportWire) -> None;
    def _check_rule_liveness(spec: WiringSpec, rule: ImportRule) -> None;
    def _check_edge(
        spec: WiringSpec,
        provider: str,
        consumer: str,
        names: (list[tuple[str, UniNode]] | None),
        at: UniNode
    ) -> None;

    def _check_module(mod: Module, spec: WiringSpec) -> None;
    def _check_import(
        spec: WiringSpec,
        imp: Import,
        consumer: str,
        provided: dict[tuple[str, str, str, str], ImportWire],
        enforce: bool
    ) -> None;

    static def _rule_names(rules: list[ImportRule]) -> str;
}
