import base64;
import json;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo {
    ClientArtifact,
    ClientManifest,
    InteropBinding,
    InteropContext,
    InteropManifest
}
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.runtime.semantic { info_graph_to_json }
import from jaclang.runtime.surface { SurfaceEntry }

glob CLIENT_RECORD_VERSION: int = 4;

obj UnitProducts {
    has path: str,
        jcir: bytes = b"",
        mtir: str = "",
        interop: str = "",
        client: str = "",
        placement: str = "",
        ct_file_deps: list[str] = [],
        ct_body_deps: list[str] = [];
}

def interop_record(module: uni.Module) -> dict[str, any] {
    gen = module.gen;
    manifest = gen.interop_manifest;
    if manifest is None {
        return {};
    }
    bindings: dict[str, dict[str, any]] = {};
    for (name, binding) in manifest.bindings.items() {
        bindings[name] = {
            'name': binding.name,
            'source_context': binding.source_context.value,
            'callers': [c.value for c in binding.callers],
            'ret_type': binding.ret_type,
            'param_types': binding.param_types,
            'param_names': binding.param_names,
            'source_module': binding.source_module,
            'kind': binding.kind,
            'provider_app': binding.provider_app,
            'native_contract': binding.native_contract,
            'endpoint_id': binding.endpoint_id
        };
    }
    return {
        'bindings': bindings,
        'clib_paths': list(gen._clib_paths),
        'clib_symbol_lib': dict(gen._clib_symbol_lib),
        'exported_symbols': list(gen._exported_symbols),
        'surface': {name: rec.to_dict() for (name, rec) in manifest.surface.items()},
        'endpoint_effects': dict(manifest.endpoint_effects),
        'native_host_imports': dict(manifest.native_host_imports),
        'app_edges': list(manifest.app_edges),
        'provider_routes': dict(manifest.provider_routes)
    };
}

def interop_manifest_of(record: dict[str, any]) -> InteropManifest {
    manifest = InteropManifest();
    bindings: dict[str, dict[str, any]] = record.get('bindings', {});
    for (name, data) in bindings.items() {
        manifest.bindings[name] = InteropBinding(
            name=data['name'],
            source_context=InteropContext(data['source_context']),
            callers={InteropContext(c) for c in data.get('callers', [])},
            ret_type=data.get('ret_type', 'int'),
            param_types=data.get('param_types', []),
            param_names=data.get('param_names', []),
            source_module=data.get('source_module'),
            kind=data.get('kind', 'function'),
            provider_app=data['provider_app'],
            native_contract=data['native_contract'],
            endpoint_id=data['endpoint_id']
        );
    }
    surface: dict[str, dict[str, any]] = record.get('surface', {}) or {};
    for (name, rec) in surface.items() {
        manifest.surface[str(name)] = SurfaceEntry.from_dict(str(name), dict(rec));
    }
    manifest.endpoint_effects.update(record.get('endpoint_effects', {}));
    manifest.native_host_imports.update(record['native_host_imports']);
    manifest.app_edges.extend(record['app_edges']);
    manifest.provider_routes.update(record['provider_routes']);
    return manifest;
}

def literal_to_json(value: object) -> dict[str, object] {
    if value is None or isinstance(value, (bool, int, float, str)) {
        return {"v": value};
    }
    if isinstance(value, bytes) {
        return {"b": base64.b64encode(value).decode("ascii")};
    }
    if isinstance(value, tuple) {
        return {"t": [literal_to_json(item) for item in value]};
    }
    if isinstance(value, list) {
        return {"l": [literal_to_json(item) for item in value]};
    }
    if isinstance(value, dict) {
        return {"d": [[str(k), literal_to_json(v)] for (k, v) in value.items()]};
    }
    return {"v": str(value)};
}

def literal_from_json(raw: object) -> object {
    import from jaclang.compiler.frontend.kernel_inputs { json_map }
    record = json_map(raw);
    if "b" in record {
        return base64.b64decode(str(record["b"]).encode("ascii"));
    }
    if "t" in record {
        return tuple(literal_from_json(item) for item in list(record["t"]));
    }
    if "l" in record {
        return [literal_from_json(item) for item in list(record["l"])];
    }
    if "d" in record {
        out: dict[str, object] = {};
        for pair in list(record["d"]) {
            parts = list(pair);
            if len(parts) == 2 {
                out[str(parts[0])] = literal_from_json(parts[1]);
            }
        }
        return out;
    }
    return record.get("v");
}

def str_list_map(value: object) -> dict[str, list[str]] {
    import from jaclang.compiler.frontend.kernel_inputs { json_map, json_str_list }
    return {key: json_str_list(item) for (key, item) in json_map(value).items()};
}

def manifest_record(manifest: ClientManifest) -> dict[str, object] {
    return {
        "exports": list(manifest.exports),
        "globals": list(manifest.globals),
        "params": {k: list(v) for (k, v) in manifest.params.items()},
        "globals_values": {
            k: literal_to_json(v) for (k, v) in manifest.globals_values.items()
        },
        "has_client": manifest.has_client,
        "imports": dict(manifest.imports),
        "runtime_imports": {k: list(v) for (k, v) in manifest.runtime_imports.items()},
        "endpoint_effects": dict(manifest.endpoint_effects),
        "tests": [dict(t) for t in manifest.tests],
        "server_imports": list(manifest.server_imports),
        "server_import_routes": {
            k: dict(v) for (k, v) in manifest.server_import_routes.items()
        },
        "page_export": manifest.page_export,
        "layout_export": manifest.layout_export
    };
}

def manifest_from_record(raw: dict[str, object]) -> ClientManifest {
    import from jaclang.compiler.frontend.kernel_inputs {
        json_map,
        json_maps,
        json_opt_str,
        json_str_list,
        json_str_map
    }
    return ClientManifest(
        exports=json_str_list(raw.get("exports")),
        globals=json_str_list(raw.get("globals")),
        params=str_list_map(raw.get("params")),
        globals_values={
            key: literal_from_json(item)
            for (key, item) in json_map(raw.get("globals_values")).items()
        },
        has_client=bool(raw.get("has_client", False)),
        imports=json_str_map(raw.get("imports")),
        runtime_imports=str_list_map(raw.get("runtime_imports")),
        endpoint_effects={
            key: json_map(item)
            for (key, item) in json_map(raw.get("endpoint_effects")).items()
        },
        tests=[json_str_map(t) for t in json_maps(raw.get("tests"))],
        server_imports=json_str_list(raw.get("server_imports")),
        server_import_routes={
            key: json_str_map(item)
            for (key, item) in json_map(raw.get("server_import_routes")).items()
        },
        page_export=json_opt_str(raw.get("page_export")),
        layout_export=json_opt_str(raw.get("layout_export"))
    );
}

def client_artifact_json(artifact: ClientArtifact) -> str {
    return json.dumps(
        {
            "version": CLIENT_RECORD_VERSION,
            "js": artifact.js,
            "manifest": manifest_record(artifact.manifest),
            "native_import_sources": list(artifact.native_import_sources),
            "source_map": [list(seg) for seg in artifact.source_map],
            "dep_digests": dict(artifact.dep_digests),
            "framework": artifact.framework,
            "boundary_contracts": dict(artifact.boundary_contracts)
        },
        sort_keys=True
    );
}

def source_segment(raw: object) -> (tuple[int, int, int, int, str] | None) {
    if not isinstance(raw, list) or len(raw) != 5 {
        return None;
    }
    return (int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]), str(raw[4]));
}

def client_artifact_from_json(text: str) -> (ClientArtifact | None) {
    import from jaclang.compiler.frontend.kernel_inputs {
        json_map,
        json_str_list,
        json_str_map
    }
    try {
        raw = json_map(json.loads(text));
    } except ValueError {
        return None;
    }
    js = raw.get("js");
    manifest = raw.get("manifest");
    if raw.get("version") != CLIENT_RECORD_VERSION
        or not isinstance(js, str)
        or not isinstance(manifest, dict) {
        return None;
    }
    segments: list[tuple[int, int, int, int, str]] = [];
    raw_map = raw.get("source_map");
    if isinstance(raw_map, list) {
        for item in raw_map {
            segment = source_segment(item);
            if segment is not None {
                segments.append(segment);
            }
        }
    }
    return ClientArtifact(
        js=js,
        manifest=manifest_from_record(json_map(manifest)),
        native_import_sources=json_str_list(raw.get("native_import_sources")),
        source_map=segments,
        dep_digests=json_str_map(raw.get("dep_digests")),
        framework=str(raw.get("framework", "")),
        boundary_contracts=json_map(raw.get("boundary_contracts"))
    );
}

def client_artifact_of(module: uni.Module) -> (ClientArtifact | None) {
    js = module.gen.js;
    if not js {
        return None;
    }
    native_sources: list[str] = [];
    if module.declares_codespace(CodeContext.NATIVE) {
        native_sources.append(module.loc.mod_path);
    }
    for binding in module.gen.interop_manifest.client_native_imports {
        if binding.source_module {
            native_sources.append(str(binding.source_module));
        }
    }
    segments: list[tuple[int, int, int, int, str]] = [];
    import from jaclang.compiler.backends.es.estree { Node as EsNode }
    es_ast = module.gen.es_ast;
    if isinstance(es_ast, EsNode) {
        try {
            import from jaclang.compiler.backends.es.es_unparse { es_to_js_with_map }
            (_, segments) = es_to_js_with_map(es_ast);
        } except Exception {
            segments = [];
        }
    }
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_active_backend
    }
    return ClientArtifact(
        js=js,
        manifest=module.gen.client_manifest,
        native_import_sources=native_sources,
        source_map=segments,
        boundary_contracts=interop_record(module),
        framework=resolve_active_backend().name()
    );
}

def placement_record(module: uni.Module, program: JacProgram) -> str {
    import from jaclang.compiler.placement.placement { get_module_summary }
    import from jaclang.compiler.placement.placement_export { summary_to_dict }
    try {
        return json.dumps(summary_to_dict(get_module_summary(module, program)));
    } except Exception {
        return "";
    }
}

def unit_products(module: uni.Module, program: JacProgram) -> UnitProducts {
    products = UnitProducts(
        path=module.loc.mod_path,
        jcir=module.gen.jcir or b"",
        ct_file_deps=list(module.ct_file_deps),
        ct_body_deps=list(module.ct_body_deps)
    );
    if program.mtir_map {
        products.mtir = info_graph_to_json(program.mtir_map);
    }
    record = interop_record(module);
    if record {
        products.interop = json.dumps(record);
    }
    artifact = client_artifact_of(module);
    if artifact is not None {
        products.client = client_artifact_json(artifact);
    }
    products.placement = placement_record(module, program);
    return products;
}

def products_record(products: UnitProducts) -> dict[str, object] {
    return {
        "path": products.path,
        "jcir": base64.b64encode(products.jcir).decode("ascii"),
        "mtir": products.mtir,
        "interop": products.interop,
        "client": products.client,
        "placement": products.placement,
        "ct_file_deps": list(products.ct_file_deps),
        "ct_body_deps": list(products.ct_body_deps)
    };
}

def products_from_record(raw: dict[str, object]) -> UnitProducts {
    import from jaclang.compiler.frontend.kernel_inputs { json_str_list }
    return UnitProducts(
        path=str(raw.get("path", "")),
        jcir=base64.b64decode(str(raw.get("jcir", "")).encode("ascii")),
        mtir=str(raw.get("mtir", "")),
        interop=str(raw.get("interop", "")),
        client=str(raw.get("client", "")),
        placement=str(raw.get("placement", "")),
        ct_file_deps=json_str_list(raw.get("ct_file_deps")),
        ct_body_deps=json_str_list(raw.get("ct_body_deps"))
    );
}
