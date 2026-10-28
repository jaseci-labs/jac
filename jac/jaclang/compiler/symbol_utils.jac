import os;

enum CallKind {
    METHOD = "method",
    INSTANTIATION = "instantiation",
    BUILTIN = "builtin",
    CLIB = "clib",
    FUNCTION = "function",
    INTRINSIC = "intrinsic"
}

def import_binds_name(nd: UniNode, name: str) -> bool;

def resolve_expr_symbol(expr: Expr, module: (Module | None) = None) -> (Symbol | None);

def imported_module_name(expr: Expr) -> str | None;

def _is_user_symbol(sym: Symbol) -> bool;

def intrinsic_registry_if_ready -> (IntrinsicRegistry | None);

def resolved_callee(nd: FuncCall) -> (Ability | None);

def classify_call(nd: FuncCall) -> CallKind;

def symbol_owner_archetype(sym: Symbol) -> (Archetype | None);

def collect_field_names(
    sym: (Symbol | None), arch_type_filter: (str | None) = None
) -> list[str];

def collect_method_names(arch: Archetype) -> set[str];

def resolve_importer_path_from_node(nd: UniNode) -> (str | None);

def resolve_import_source_module(prog: JacProgram, nd: Import) -> (Module | None);

def _already_reported(
    program: JacProgram, reporter: CompilerPass, diag: DiagnosticInfo, nd: UniNode
) -> bool;

def report_dead_client_import(
    reporter: CompilerPass,
    nd: Import,
    item: ModuleItem,
    unbound: (set[str] | None) = None
) -> None;

def report_client_bare_import_uses(
    reporter: CompilerPass, mod: Module, unbound: (set[str] | None) = None
);

def _bare_py_import_bindings(mod: Module) -> dict[str, tuple[ModuleItem, Import]];

def _shadows_bare_import(nm: Name) -> bool;

def _report_client_bare_import_uses(
    reporter: CompilerPass,
    mod: Module,
    stmt: UniNode,
    unbound: (set[str] | None) = None
);

def report_placement_warnings(reporter: CompilerPass, mod: Module);

def element_display_name(top: UniNode) -> str;

def _client_emitted_top(stmt: UniNode, extra_bound: set[str]) -> bool;


def client_bridged_endpoint(mod: Module, top: UniNode) -> bool;

def client_value_ref_targets(
    mod: Module, extra_bound: (set[str] | None) = None
) -> list[tuple[Name, UniNode]];

def _import_bound_names(imp: Import) -> set[str];

def _import_used_as_value(mod: Module, imp: Import) -> bool;

def serverless_server_evidence(
    mod: Module, prog: JacProgram
) -> list[tuple[str, str, UniNode]];

def report_serverless_kind_errors(reporter: CompilerPass, mod: Module);

def return_type_is_jsx(rt: (Expr | None)) -> bool;
