import os;
import json;
import from collections.abc { Callable }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.placement.placement {
    PLACEMENT_SCHEMA,
    ElementSummary,
    PlacementSummary,
    element_display_name,
    get_module_summary,
    placement_evidence_for
}

def element_to_dict(es: ElementSummary) -> dict[str, any] {
    return {
        'index': es.index,
        'kind': es.kind,
        'name': es.name,
        'pinned': es.pinned,
        'is_pub': es.is_pub,
        'sv_import': es.sv_import,
        'import_eco': es.import_eco,
        'import_jac_target': es.import_jac_target,
        'import_items': list(es.import_items),
        'import_py_targets': list(es.import_py_targets),
        'reqs': [list(r) for r in es.reqs],
        'refs': list(es.refs),
        'escapes': [list(e) for e in es.escapes],
        'glob_writes': list(es.glob_writes)
    };
}

def element_from_dict(d: dict[str, any]) -> ElementSummary {
    es = ElementSummary();
    es.index = int(d.get('index', -1));
    es.kind = str(d.get('kind', ''));
    es.name = str(d.get('name', ''));
    es.pinned = str(d.get('pinned', ''));
    es.is_pub = bool(d.get('is_pub', False));
    es.sv_import = bool(d.get('sv_import', False));
    es.import_eco = str(d.get('import_eco', ''));
    es.import_jac_target = str(d.get('import_jac_target', ''));
    es.import_items = [str(x) for x in d.get('import_items', [])];
    es.import_py_targets = [str(x) for x in d.get('import_py_targets', [])];
    es.reqs = [[str(x) for x in r] for r in d.get('reqs', [])];
    es.refs = [int(x) for x in d.get('refs', [])];
    es.escapes = [(int(e[0]), str(e[1])) for e in d.get('escapes', [])];
    es.glob_writes = [int(x) for x in d.get('glob_writes', [])];
    return es;
}

def summary_to_dict(ps: PlacementSummary) -> dict[str, any] {
    return {
        'schema': ps.schema,
        'mod_path': ps.mod_path,
        'decided': ps.decided,
        'anchors': list(ps.anchors),
        'native_blocker': ps.native_blocker,
        'native_verdict': ps.native_verdict,
        'native_verdict_code': ps.native_verdict_code,
        'jac_deps': list(ps.jac_deps),
        'has_refs': ps.has_refs,
        'elements': [element_to_dict(e) for e in ps.elements]
    };
}

def summary_from_dict(d: dict[str, any]) -> (PlacementSummary | None) {
    if not isinstance(d, dict) or d.get('schema') != PLACEMENT_SCHEMA {
        return None;
    }
    ps = PlacementSummary();
    ps.mod_path = str(d.get('mod_path', ''));
    ps.decided = str(d.get('decided', ''));
    ps.anchors = [str(x) for x in d.get('anchors', [])];
    ps.native_blocker = str(d.get('native_blocker', ''));
    ps.native_verdict = str(d.get('native_verdict', ''));
    ps.native_verdict_code = str(d.get('native_verdict_code', ''));
    ps.jac_deps = [str(x) for x in d.get('jac_deps', [])];
    ps.has_refs = bool(d.get('has_refs', False));
    ps.elements = [
        element_from_dict(e)
        for e in d.get('elements', [])
        if isinstance(e, dict)
    ];
    return ps;
}

def summary_to_bytes(ps: PlacementSummary) -> bytes {
    return json.dumps(summary_to_dict(ps)).encode('utf-8');
}

def summary_from_bytes(
    data: bytes, path_mapper: Callable[[str], str] | None = None
) -> (PlacementSummary | None) {
    try {
        parsed = json.loads(data.decode('utf-8'));
        if not isinstance(parsed, dict) {
            return None;
        }
        summary = summary_from_dict(parsed);
        if summary is not None and path_mapper is not None {
            summary.mod_path = path_mapper(summary.mod_path);
            summary.jac_deps = [path_mapper(p) for p in summary.jac_deps];
            for element in summary.elements {
                element.import_jac_target = path_mapper(element.import_jac_target);
                element.import_py_targets = [
                    path_mapper(p) for p in element.import_py_targets
                ];
            }
        }
        return summary;
    } except Exception {
        return None;
    }
}

def collect_placement_rows(prog: JacProgram) -> dict[str, dict[str, any]] {
    rows_by_module: dict[str, dict[str, any]] = {};
    hub = prog.mod.hub;
    if not hub {
        return rows_by_module;
    }
    for (path, mod) in list(hub.items()) {
        if not isinstance(mod, uni.Module) {
            continue;
        }
        mod_path = mod.loc.mod_path or path;
        if not str(mod_path).endswith('.jac') {
            continue;
        }
        ps = get_module_summary(mod, prog);
        mod_rows: list[dict[str, any]] = [];
        for (idx, stmt) in enumerate(mod.body) {
            if not isinstance(stmt, uni.ContextAwareNode) {
                continue;
            }
            es = ps.elements[idx] if idx < len(ps.elements) else None;
            notes: list[str] = [];
            if es is not None {
                if es.pinned {
                    notes.append(f"pinned '{es.pinned}' ([placement.pins])");
                }
                for req in es.reqs {
                    if len(req) >= 2 {
                        notes.append(f"{req[0]}: {req[1]}");
                    }
                }
            }
            for extra in placement_evidence_for(prog, str(mod_path), idx) {
                if extra not in notes {
                    notes.append(extra);
                }
            }
            rname = element_display_name(stmt);
            if idx < len(ps.elements) {
                rname = ps.elements[idx].name;
            }
            mod_rows.append(
                {
                    'name': rname,
                    'kind': type(stmt).__name__,
                    'space': stmt.code_context.value,
                    'dual': stmt.codespace_dual,
                    'evidence': notes
                }
            );
        }
        crossings = 0;
        for stmt in mod.body {
            if not (
                isinstance(stmt, uni.Import) and stmt.code_context == CodeContext.CLIENT
            ) {
                continue;
            }
            try {
                import from jaclang.compiler.symbol_utils {
                    ClientImportVerdict,
                    classify_client_import_item,
                    is_client_boundary_import,
                    resolve_import_source_module
                }
                if is_client_boundary_import(stmt) {
                    src = resolve_import_source_module(prog, stmt);
                    if src is not None {
                        for item in stmt.items {
                            verdict = classify_client_import_item(src, item);
                            if verdict == ClientImportVerdict.BRIDGED {
                                crossings += 1;
                            }
                        }
                    }
                }
            } except Exception {}
        }
        rows_by_module[os.path.abspath(str(mod_path))] = {
            'decided': mod.decided_codespace or '',
            'rows': mod_rows,
            'crossings': crossings
        };
    }
    return rows_by_module;
}

def sealed_spaces_for(source_path: str) -> (set[str] | None) {
    ap = os.path.abspath(source_path);
    d = os.path.dirname(ap);
    while True {
        mf = os.path.join(d, "_precompiled", "MANIFEST.json");
        if os.path.isfile(mf) {
            break;
        }
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
    try {
        with open(mf, "r") as f {
            manifest = json.load(f);
        }
    } except Exception {
        return None;
    }
    placement: any = manifest.get("placement") or {};
    rel = os.path.relpath(ap, d).replace(os.sep, "/");
    spaces = placement.get(rel);
    if spaces is None {
        return None;
    }
    return set(spaces);
}
