import from jaclang.compiler.session.import_paths { resolve_import_path }
import from jaclang.compiler.ir.schema {
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
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.analysis.binding.module_facts {
    ModuleFacts,
    client_capability_violations
}
import from jaclang.compiler.ir.enums { SymbolType }
import from jaclang.compiler.frontend.diagnostics {
    E5090,
    E5096,
    W6001,
    W6002,
    W6003,
    W6004
}
import from jaclang.compiler.analysis.capabilities.native_policy {
    NATIVE_SUPPORTED_STDLIB
}

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
    has ir_in: Module,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
}

walker ClientCapabilityCheckPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
}

glob JS_GLOBALS: dict[str, str] = {
         "console": "print()",
         "Math": "Jac builtins (abs, round, min, max, pow, etc.)",
         "JSON": "Jac serialization primitives",
         "Array": "list",
         "Object": "dict",
         "Map": "dict",
         "Set": "set",
         "Promise": "async/await",
         "setTimeout": "async patterns",
         "setInterval": "async patterns",
         "clearTimeout": "async patterns",
         "clearInterval": "async patterns",
         "fetch": "Jac HTTP primitives",
         "document": "Jac DOM abstractions",
         "window": "Jac platform abstractions",
         "Buffer": "bytes",
         "Symbol": "Jac types",
         "WeakMap": "dict",
         "WeakSet": "set",
         "RegExp": "str methods or re module",
         "Infinity": "float('inf')",
         "NaN": "float('nan')"
     },
     JS_METHODS: dict[str, str] = {
         "push": ".append()",
         "forEach": "for loop",
         "indexOf": ".index() or 'in' operator",
         "lastIndexOf": ".index() with reverse",
         "splice": "slice assignment",
         "unshift": ".insert(0, val)",
         "shift": ".pop(0)",
         "includes": "'in' operator",
         "findIndex": "enumerate() with condition",
         "find": "next() with generator",
         "every": "all()",
         "some": "any()",
         "flat": "list flattening",
         "flatMap": "list comprehension",
         "fill": "list multiplication or comprehension",
         "from": "list()",
         "isArray": "isinstance(x, list)",
         "charAt": "string indexing s[i]",
         "charCodeAt": "ord()",
         "fromCharCode": "chr()",
         "substring": "string slicing s[a:b]",
         "substr": "string slicing s[a:a+n]",
         "slice": "slicing [a:b]",
         "padStart": ".rjust() or .zfill()",
         "padEnd": ".ljust()",
         "trimStart": ".lstrip()",
         "trimEnd": ".rstrip()",
         "trim": ".strip()",
         "repeat": "'str * n'",
         "replaceAll": ".replace()",
         "toFixed": "format() or round()",
         "toPrecision": "format()",
         "toString": "str()",
         "parseInt": "int()",
         "parseFloat": "float()",
         "hasOwnProperty": "hasattr() or 'in' operator",
         "assign": "dict unpacking {**a, **b}",
         "freeze": "frozenset or tuple",
         "stringify": "str() or json.dumps()",
         "parse": "json.loads()"
     },
     JS_KEYWORDS: dict[str, str] = {
         "undefined": "None",
         "typeof": "type()",
         "void": "None"
     },
     JS_PROPERTIES: dict[str, str] = {
         "length": "len()",
         "prototype": "Jac inheritance",
         "constructor": "type() or __init__",
         "__proto__": "Jac inheritance"
     },
     _NATIVE_SKIP_HELP: str = (
         "`skip` is an object-spatial walker statement; native lowers it only "
         "inside a walker `with` event ability (a body that returns no value). "
         "In a value-returning function, use an explicit `return` to exit early."
     ),
     _NATIVE_DECORATOR_HELP: str = (
         "Native lowers decorators only on module-level, non-generator "
         "functions, and only when each decorator is a plain name resolving "
         "to a native function (applied at module glob-init). Method, "
         "archetype, and dynamically-computed decorators would silently run "
         "the undecorated body; remove the decorator or move the definition "
         "to a @sv/Python context."
     ),
     _NATIVE_UNPACK_HELP: str = (
         "Unpacking arguments at a native call site is not lowered yet; "
         "pass the elements explicitly or move the call to a @sv/Python "
         "context."
     );
