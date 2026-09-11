import type from jaclang.compiler.passes.transform { Alert }

enum DiagChannel { JAC = "jac", VITE = "vite", BROWSER = "browser", SERVER = "server" }

obj ClientDiagnostic {
    has code: str = "",
        severity: str = "error",
        category: str = "runtime",
        message: str = "",
        help_text: str = "",
        file: str = "",
        line: int = 0,
        column: int = 0,
        channel: str = "jac",
        raw_location: str = "",
        unmapped_reason: str = "",
        related: list[dict[str, any]] = [],
        stack: str = "",
        component_stack: str = "",
        resolved_stack: str = "",
        resolved_component_stack: str = "",
        base_path: str = "",
        rendered_cache: str = "";

    def key -> str;
    def abs_file -> str;
    def render(colors: bool = False) -> str;
    def to_dict -> dict[str, any];
    static def from_dict(data: dict[str, any]) -> ClientDiagnostic;
}

def related_location(
    label: str, file: str, line: int = 0, column: int = 0
) -> dict[str, any];

def diagnostic_from_alert(alert: Alert, base_path: str = "") -> ClientDiagnostic;

def diagnostics_from_alerts(
    alerts: list[Alert], base_path: str = ""
) -> list[ClientDiagnostic];

def build_failure_diagnostic(
    base_path: str, file_path: str, message: str, line: int = 0, column: int = 0
) -> ClientDiagnostic;

def classify_client_payload(
    base_path: str,
    payload: dict[str, any],
    channel: str = "browser",
    verbose: bool = False
) -> ClientDiagnostic;

def log_client_error(
    base_path: str, data: dict[str, any], verbose: bool = False
) -> ClientDiagnostic;

def render_diagnostics(
    diagnostics: list[ClientDiagnostic], colors: bool = False
) -> str;

def classify_build_output(
    base_path: str, error_output: str, verbose: bool = False
) -> list[ClientDiagnostic];

def format_build_diagnostics(
    base_path: str, error_output: str, config: object = None
) -> str;

def is_debug_mode(config: object = None) -> bool;
