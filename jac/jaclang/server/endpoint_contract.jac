import json;
import os;
import sys;
import from jaclang.server.transport { Meta, TransportResponse }

def check_endpoint_contract(
    request: any, target: any, kind: str, name: str, app: str
) -> any {
    identity = request.headers.get("X-Jac-Endpoint");
    if not identity {
        return None;
    }
    import from jaclang.compiler.placement.workspace { workspace_for_path }
    module = sys.modules.get(target.__module__);
    path = getattr(module, "__file__", "");
    import from jaclang.compiler.driver.boundary_classify { owner_app_name_for_path }
    owner = owner_app_name_for_path(path) if path else None;
    workspace = workspace_for_path(path) if path else None;
    source = os.path.relpath(path, workspace.project_root).replace(os.sep, "/")
        if workspace
        else getattr(module, "__name__", "");
    try {
        parts = json.loads(identity);
        if isinstance(parts, list)
            and len(parts) == 4
            and parts[2] == kind
            and parts[3] == name
            and parts[1] == source
            and (not parts[0] or parts[0] == (owner or app)) {
            return None;
        }
    } except (ValueError, TypeError) {}
    return TransportResponse.fail(
        code="ENDPOINT_CONTRACT_MISMATCH",
        message="The requested contract does not identify this endpoint",
        meta=Meta(extra={"http_status": 409})
    );
}
