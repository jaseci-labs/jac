import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchSpec,
    Archetype,
    AtomTrailer,
    Assignment,
    CtrlStmt,
    EdgeOpRef,
    EdgeRefTrailer,
    ElementStmt,
    Enum,
    EventSignature,
    Expr,
    FString,
    FilterCompr,
    FormattedValue,
    FuncCall,
    FuncSignature,
    ImplDef,
    Import,
    KWPair,
    LambdaExpr,
    Module,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    ParamVar,
    PyInlineCode,
    String,
    SubTag,
    Token,
    UnaryExpr,
    TupleVal,
    ListVal,
    UniNode,
    YieldExpr
}
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.module_facts {
    ModuleFacts,
    client_capability_violations
}
import from jaclang.compiler.frontend.constant { SymbolType }
import from jaclang.compiler.frontend.diagnostics {
    E5090,
    E5096,
    W6001,
    W6002,
    W6003,
    W6004
}
import from jaclang.compiler.frontend.codeinfo { NATIVE_SUPPORTED_STDLIB }

glob NATIVE_REJECT_NODES: tuple[type[PyInlineCode]] = (PyInlineCode, );

def classify_native_import(item: UniNode) -> tuple[((str | None), bool)];

def import_bound_name(item: UniNode) -> (str | None);

def from_import_jac_source(imp: Import) -> (str | None);

def node_within(name_nd: UniNode, top: (UniNode | None)) -> bool;

def base_expr_is_erased(base: UniNode) -> bool;

def name_in_type_position(name_nd: UniNode) -> bool;

def static_fstring_spec_text(spec: UniNode) -> (str | None);

def call_has_kwargs_sink(call: FuncCall) -> bool;

def native_capability_violations(
    mod: Module
) -> list[tuple[(UniNode, str, str, (str | None))]];

def native_capability_demotion_owner(viol_node: UniNode) -> (Ability | None);

def partition_native_capability_violations(
    viols: list[tuple[(UniNode, str, str, (str | None))]]
) -> tuple[
    (
        list[tuple[(UniNode, str, str, (str | None))]],
        dict[int, list[tuple[(UniNode, str, str, (str | None))]]]
    )
];

walker PortabilityWarnPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('portability', );

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _check_js_globals(mod: Module) -> None;
    def _check_js_methods(mod: Module) -> None;
    def _find_call_is_js_style(call: FuncCall) -> bool;
    def _check_js_keywords(mod: Module) -> None;
    def _check_js_properties(mod: Module) -> None;
}

walker NativeCapabilityCheckPass(Transform) {
    static has PROVIDES: tuple = ('capability', );
    has ir_in: Module,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
}

walker ClientCapabilityCheckPass(Transform) {
    static has PROVIDES: tuple = ('client_capability', );
    has ir_in: Module,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
}
