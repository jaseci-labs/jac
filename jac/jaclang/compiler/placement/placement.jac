import os;

glob PLACEMENT_SCHEMA: int = 4,
     PLACEMENT_SV_SIGNAL_NODES: list[tuple[str, type[uni.UniNode]]] = [
         ("TypedCtxBlock", uni.TypedCtxBlock),
         ("PyInlineCode", uni.PyInlineCode),
         ("JsxElement", uni.JsxElement)
     ],
     PLACEMENT_NATIVE_REJECT_NODES: list[tuple[str, type[uni.UniNode]]] = [],
     PLACEMENT_INFERENCE_HELD: dict[str, str] = {
         "compiler/frontend/codeinfo.jac": (
             "runtime JIT inference stays conservative: admitting codeinfo "
             "opens the jaclang-internal import universe to default-native "
             "flips (walker identity splits, sv envelopes). The compiler's "
             "own roots are exempt via PLACEMENT_HOLD_EXEMPT_ROOTS, which "
             "is what B4 (#8323) actually needed"
         )
     },
     PLACEMENT_HOLD_EXEMPT_ROOTS: tuple[str, ...] = (
         "/jaclang/compiler/",
         "/jaclang/runtime/",
         "/jaclang/lib/",
         "/jaclang/jac0core/"
     );

obj NativeBlockerScan {
    has module: str = '',
        sites: list[tuple[uni.UniNode, str]] = [],
        deps: list[str] = [],
        dep_imports: list[tuple[uni.Import, str]] = [],
        tests: list[tuple[uni.Test, str]] = [],
        test_dep_imports: list[tuple[uni.Test, uni.Import, str]] = [];

    def first -> str;
}

obj ElementSummary {
    has index: int = -1,
        kind: str = '',
        name: str = '',
        pinned: str = '',
        is_pub: bool = False,
        sv_import: bool = False,
        import_eco: str = '',
        import_jac_target: str = '',
        import_items: list[str] = [],
        import_py_targets: list[str] = [],
        reqs: list[list[str]] = [],
        refs: list[int] = [],
        escapes: list[tuple[int, str]] = [],
        glob_writes: list[int] = [];
}

obj PlacementSummary {
    has schema: int = PLACEMENT_SCHEMA,
        mod_path: str = '',
        decided: str = '',
        anchors: list[str] = [],
        native_blocker: str = '',
        jac_deps: list[str] = [],
        has_refs: bool = False,
        elements: list[ElementSummary] = [];

    def element_at(index: int) -> (ElementSummary | None);
}

def element_display_name(stmt: uni.UniNode) -> str;

def _endpoint_evidence(stmt: uni.UniNode) -> str;

def project_kind_name(module: (uni.Module | None)) -> str;

def project_has_server(module: (uni.Module | None)) -> bool;

def _resolve_import_path(nd: (uni.ModulePath | uni.ModuleItem)) -> (str | None);

def _fill_import_facts(es: ElementSummary, imp: uni.Import);

def module_has_root_access(stmt: uni.UniNode) -> bool;

def _element_reqs(stmt: uni.UniNode) -> list[list[str]];


def _element_ref_ids(module: uni.Module, elem: uni.UniNode) -> set[int];

def _escape_kind(nm: uni.Name, elem: uni.UniNode) -> str;

def _element_escape_edges(
    module: uni.Module, elem: uni.UniNode
) -> list[tuple[int, str]];

def _element_glob_write_ids(module: uni.Module, elem: uni.UniNode) -> set[int];

def _is_filter_field_name(nm: uni.Name) -> bool;

def _names_a_member(nm: uni.Name) -> bool;

def _references_browser_seed_global(elem: uni.UniNode) -> str;

def module_anchor_reasons(module: uni.Module) -> list[str];

def _erased_only_import(imp: uni.Import) -> bool;

def native_blocker_scan(
    module: uni.Module,
    base_dir: str,
    allow_pub: bool = False,
    hold_exempt: bool = False
) -> NativeBlockerScan;

def _scan_blockers_under(
    scan: NativeBlockerScan,
    scope_node: uni.UniNode,
    module: uni.Module,
    base_dir: str,
    allow_pub: bool
);

def scan_native_blockers(
    module: uni.Module,
    base_dir: str,
    allow_pub: bool = False,
    hold_exempt: bool = False
) -> tuple[str, list[str]];

def summarize_module(
    module: uni.Module, with_refs: bool = True, prog: (JacProgram | None) = None
) -> PlacementSummary;

def summary_store(prog: JacProgram) -> dict[str, PlacementSummary];

def record_decided(prog: JacProgram, module: uni.Module);

def jac_import_targets(module: uni.Module) -> list[str];

def record_placement_evidence(prog: JacProgram, mod_path: str, index: int, note: str);

def placement_evidence_for(prog: JacProgram, mod_path: str, index: int) -> list[str];

def get_module_summary(
    module: uni.Module, prog: JacProgram, with_refs: bool = True
) -> PlacementSummary;
