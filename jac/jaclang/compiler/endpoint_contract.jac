import os;
import json;
import from jaclang.compiler.driver.boundary_classify { owner_app_name_for_path }
import from jaclang.compiler.placement.workspace { workspace_for_path }

def endpoint_descriptor(module: any, kind: str, name: str) -> dict {
    path = module.loc.mod_path;
    workspace = workspace_for_path(path);
    app = owner_app_name_for_path(path) or module.owner_app or "";
    source = os.path.relpath(path, workspace.project_root) if workspace else module.name;
    source = source.replace(os.sep, "/");
    return {"app": app, "module": source, "kind": kind, "name": name};
}

def endpoint_key(module: any, kind: str, name: str) -> str {
    d = endpoint_descriptor(module, kind, name);
    return json.dumps([d["app"], d["module"], kind, name], separators=(",", ":"));
}
