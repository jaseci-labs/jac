impl escapes_record(escapes: list[tuple[int, str]]) -> list[any] {
    rows: list[any] = [];
    for (index, name) in escapes {
        row: list[any] = [index, name];
        rows.append(row);
    }
    return rows;
}

impl element_to_dict(es: ElementSummary) -> dict[str, any] {
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
        'escapes': escapes_record(es.escapes),
        'glob_writes': list(es.glob_writes)
    };
}

impl _str_list(value: object) -> list[str] {
    out: list[str] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(str(item));
        }
    }
    return out;
}

impl _int_list(value: object) -> list[int] {
    out: list[int] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(int(item));
        }
    }
    return out;
}

impl _str_rows(value: object) -> list[list[str]] {
    out: list[list[str]] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(_str_list(item));
        }
    }
    return out;
}

impl _escape_rows(value: object) -> list[tuple[int, str]] {
    out: list[tuple[int, str]] = [];
    if isinstance(value, list) {
        for item in value {
            if isinstance(item, list) and len(item) >= 2 {
                out.append((int(item[0]), str(item[1])));
            }
        }
    }
    return out;
}

impl _maps(value: object) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    if isinstance(value, list) {
        for item in value {
            if isinstance(item, dict) {
                row: dict[str, any] = {};
                for (key, field) in item.items() {
                    row[str(key)] = field;
                }
                out.append(row);
            }
        }
    }
    return out;
}

impl element_from_dict(d: dict[str, any]) -> ElementSummary {
    es = ElementSummary();
    es.index = int(d.get('index', -1));
    es.kind = str(d.get('kind', ''));
    es.name = str(d.get('name', ''));
    es.pinned = str(d.get('pinned', ''));
    es.is_pub = bool(d.get('is_pub', False));
    es.sv_import = bool(d.get('sv_import', False));
    es.import_eco = str(d.get('import_eco', ''));
    es.import_jac_target = str(d.get('import_jac_target', ''));
    es.import_items = _str_list(d.get('import_items'));
    es.import_py_targets = _str_list(d.get('import_py_targets'));
    es.reqs = _str_rows(d.get('reqs'));
    es.refs = _int_list(d.get('refs'));
    es.escapes = _escape_rows(d.get('escapes'));
    es.glob_writes = _int_list(d.get('glob_writes'));
    return es;
}

impl summary_to_dict(ps: PlacementSummary) -> dict[str, any] {
    return {
        'schema': ps.schema,
        'mod_path': ps.mod_path,
        'decided': ps.decided,
        'anchors': list(ps.anchors),
        'native_blocker': ps.native_blocker,
        'jac_deps': list(ps.jac_deps),
        'has_refs': ps.has_refs,
        'client_declared': ps.client_declared,
        'native_declared': ps.native_declared,
        'native_anchor': ps.native_anchor,
        'spaces': list(ps.spaces),
        'elements': [element_to_dict(e) for e in ps.elements]
    };
}

impl summary_from_dict(d: dict[str, any]) -> (PlacementSummary | None) {
    if not isinstance(d, dict) or d.get('schema') != PLACEMENT_SCHEMA {
        return None;
    }
    ps = PlacementSummary();
    ps.mod_path = str(d.get('mod_path', ''));
    ps.decided = str(d.get('decided', ''));
    ps.anchors = _str_list(d.get('anchors'));
    ps.native_blocker = str(d.get('native_blocker', ''));
    ps.jac_deps = _str_list(d.get('jac_deps'));
    ps.has_refs = bool(d.get('has_refs', False));
    ps.client_declared = bool(d.get('client_declared', False));
    ps.native_declared = bool(d.get('native_declared', False));
    ps.native_anchor = bool(d.get('native_anchor', False));
    ps.spaces = _str_list(d.get('spaces'));
    ps.elements = [element_from_dict(e) for e in _maps(d.get('elements'))];
    return ps;
}

impl summary_to_bytes(ps: PlacementSummary) -> bytes {
    return json.dumps(summary_to_dict(ps)).encode('utf-8');
}

impl summary_from_bytes(
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

impl collect_placement_rows(prog: JacProgram) -> dict[str, dict[str, any]] {
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
            if not isinstance(stmt, uni.ContextAwareNode)
                or stmt.top_element is not stmt {
                continue;
            }
            es = ps.element_at(idx);
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
            rname = es.name if es is not None else element_display_name(stmt);
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
        for stmt in mod.elements {
            if not (
                isinstance(stmt, uni.Import) and stmt.code_context == CodeContext.CLIENT
            ) {
                continue;
            }
            try {
                import from jaclang.compiler.driver.boundary_classify {
                    ClientImportVerdict,
                    classify_client_import_item,
                    is_client_boundary_import
                }
                import from jaclang.compiler.symbol_utils {
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
