def endpoint_descriptor(module: any, kind: str, name: str) -> dict {
    import os;
    import from jaclang.compiler.session.workspace { workspace_for_path }
    path = module.loc.mod_path;
    project_root = module.jac_project_root;
    workspace = workspace_for_path(path);
    entry_app = workspace.app_for_path(path) if workspace else None;
    app = entry_app.name if entry_app is not None else "";
    source = os.path.relpath(path, project_root) if project_root else module.name;
    source = source.replace(os.sep, "/");
    return {"app": app, "module": source, "kind": kind, "name": name};
}

def endpoint_key(module: any, kind: str, name: str) -> str {
    import json;
    d = endpoint_descriptor(module, kind, name);
    return "["
        + ",".join([json.dumps(part) for part in [d["app"], d["module"], kind, name]])
        + "]";
}
