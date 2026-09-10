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
    import from jaclang.runtime.prepared { application_for }
    module = sys.modules.get(target.__module__);
    path = getattr(module, "__file__", "");
    application = application_for(path, target.__module__) if path else None;
    if application is not None {
        app = application.manifests.get(os.path.realpath(path), {}).get('app', app);
    }
    source = os.path.relpath(path, application.root).replace(os.sep, "/")
        if application is not None
        else getattr(module, "__name__", "");
    try {
        parts = json.loads(identity);
        if isinstance(parts, list)
            and len(parts) == 4
            and parts[2] == kind
            and parts[3] == name
            and parts[1] == source
            and (not parts[0] or parts[0] == app) {
            return None;
        }
    } except (ValueError, TypeError) {}
    return TransportResponse.fail(
        code="ENDPOINT_CONTRACT_MISMATCH",
        message="The requested contract does not identify this endpoint",
        meta=Meta(extra={"http_status": 409})
    );
}
