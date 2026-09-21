import json;

def boundary_audit(program: any, artifacts: list[dict[str, any]]) -> dict[str, any] {
    boundaries: dict[str, dict[str, any]] = {};
    effects: dict[str, dict[str, any]] = {};
    host_imports: dict[str, dict[str, any]] = {};
    manifests = list(artifacts);
    compiler = program._get_compiler();
    for hub in program._search_hubs() {
        for module in hub.values() {
            if module is not None and module.gen is not None {
                manifests.append(compiler._build_interop_dict(module));
            }
        }
    }
    surface: dict[str, dict[str, any]] = {};
    for manifest in manifests {
        if not manifest {
            continue;
        }
        for (name, rec) in (manifest.get("surface") or {}).items() {
            module = str(rec.get("module") or "");
            key = f"{module}:{name}" if module else name;
            surface.setdefault(key, dict(rec));
        }
        effects.update(manifest["endpoint_effects"]);
        host_imports.update(manifest["native_host_imports"]);
        for binding in manifest["bindings"].values() {
            identity = binding["endpoint_id"];
            if not identity {
                continue;
            }
            (app, source, kind, name) = json.loads(identity);
            native = binding["native_contract"];
            parameters = dict(zip(binding["param_names"], binding["param_types"]));
            result = binding["ret_type"];
            if native {
                parameters = {p["name"]: p["type"] for p in native["params"]};
                result = native["result"]["type"];
            }
            callers = set(binding["callers"]);
            if identity in boundaries {
                callers.update(boundaries[identity]["callers"]);
            }
            boundaries[identity] = {
                "app": app,
                "module": source,
                "kind": kind,
                "name": name,
                "placement": binding["source_context"],
                "callers": sorted(callers),
                "parameters": parameters,
                "result": result,
                "native_contract": native,
                "unchecked": ["dynamic value shape"]
                    if "any" in parameters.values() or result == "any"
                    else []
            };
        }
    }
    return {
        "version": 2,
        "boundaries": boundaries,
        "surface": surface,
        "effects": effects,
        "native_host_imports": host_imports
    };
}
