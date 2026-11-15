glob _SCRIPT: list[dict[str, any]] = [
         {"k": "cmd", "t": "jac create trailmate --use jac-shadcn"},
         {"k": "out", "t": "  Themed starter ready (nova / orange / geist)"},
         {"k": "cmd", "t": "jac scale deploy"},
         {"k": "ok", "t": "✔ REST API · auth · Swagger · graph persistence"},
         {"k": "ok", "t": "✔ React client compiled from Jac"},
         {"k": "ok", "t": "✔ Kubernetes: images built, cluster provisioned"},
         {"k": "out", "t": "  Serving on http://localhost:8000  —  0 lines of YAML"},

     ];

def:pub TerminalDemo(className: str = "") -> JsxElement;
