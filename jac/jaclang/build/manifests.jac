import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.keys { SERVING }
import os;
import type from jaclang.compiler.session.services { AnalysisServices }
import type from jaclang.compiler.ir.schema { Module }


def _project_modules(program: AnalysisServices, `root: str) -> dict[str, Module] {
    result: dict[str, Module] = {};
    hub = program.mod.hub;
    for (path, module) in `list(hub.items()) {
        if (module and os.path.realpath(path).startswith((`root + os.sep))) {
            result[os.path.realpath(path)] = module;
        }
    }
    return result;
}

def _manifest(
    program: AnalysisServices, path: str, `root: str, mod: Module | None = None
) -> dict {
    import from jaclang.compiler.pipeline.products { require_product }
    import from jaclang.compiler.pipeline.contracts { CompilationProduct }
    mod = mod if mod is not None else program.find_module(path);
    if mod is None {
        raise RuntimeError(f'Preparation did not produce metadata for {path}');
    }
    program = program.module_context(mod);
    require_product(program, mod, CompilationProduct.IMPORTS);
    sources = {os.path.realpath(path)};
    sources.update(
        edge.target
        for edge in program.deps.imports.get(os.path.realpath(path), [])
        if edge.jac and edge.top_level and edge.from_import
    );
    (funcs, walkers, effects) = ({}, {}, {});
    (cross, seen) = ([], `set());
    project_modules = _project_modules(program, `root);
    sources_by_path = dict(project_modules);
    for source_path in sources {
        source = program.find_module(source_path);
        if source is not None {
            sources_by_path[source_path] = source;
        }
    }
    for (source_path, source) in sources_by_path.items() {
        actual = program.module_context(source);
        require_product(actual, source, CompilationProduct.SERVING);
        facts = actual.analysis.result(source_path, SERVING);
        if source_path in sources {
            for (name, access) in facts.func_access.items() {
                funcs.setdefault(name, access);
            }
            for (name, access) in facts.walker_access.items() {
                walkers.setdefault(name, access);
            }
        }
        if source_path not in project_modules {
            continue;
        }
        effects.update(facts.effects);
        for binding in facts.cross_bindings {
            identity = (binding.name, binding.kind);
            if identity in seen or not binding.source.startswith(`root + os.sep) {
                continue;
            }
            seen.add(identity);
            cross.append(
                `dict(
                    name=binding.name,
                    kind=binding.kind,
                    src=os.path.relpath(binding.source, `root),
                    auth=binding.auth
                )
            );
        }
    }
    client = artifact_for(mod).client_manifest;
    return `dict(
        `root=`root,
        app=mod.app or '',
        client=`dict(
            exports=`list(client.exports),
            globals=`list(client.globals),
            params=client.params,
            globals_values=client.globals_values,
            has_client=client.has_client
        )
            if client
            else {},
        func_access=funcs,
        walker_access=walkers,
        endpoint_effects=effects,
        cross_bindings=cross
    );
}


import from jaclang.compiler.session.cache.interop_codec { interop_record }
import json;

def boundary_audit(program: AnalysisServices, artifacts: list[dict]) -> dict {
    boundaries: dict = {};
    effects: dict = {};
    host_imports: dict = {};
    manifests = list(artifacts);
    hub = program.mod.hub;
    for module in hub.values() {
        context = program.module_context(module);
        record = context.analysis.artifacts.records.get(module);
        manifest = record.peek_interop() if record is not None else None;
        if manifest is not None {
            manifests.append(interop_record(manifest));
        }
    }
    for manifest in manifests {
        if not manifest {
            continue;
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
        "version": 1,
        "boundaries": boundaries,
        "effects": effects,
        "native_host_imports": host_imports
    };
}
