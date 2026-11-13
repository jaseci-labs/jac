glob _RPC_MAX_ATTEMPTS: int = 3,
     _RPC_INITIAL_BACKOFF_SECONDS: float = 0.1;

def _rpc_with_retries(module_name: str, label: str, send: any) -> any;


def _rpc_headers(extra: dict[str, str] | None = None) -> dict[str, str];


def _provider_url(app_name: str) -> str;


def _resolve_call_target(module_name: str) -> tuple[str, str | None];


def service_call(
    module_name: str,
    func_name: str,
    args: dict[str, any],
    headers: dict[str, str] | None = None
) -> any;


def walker_call(
    module_name: str,
    walker_name: str,
    args: dict[str, any],
    stub_cls: any = None,
    headers: dict[str, str] | None = None
) -> any;


def _iter_sse_text(text: str, func_label: str) -> any;

glob _SV_DEFAULT_RPC_TIMEOUT: float = 10.0;


def _sv_rpc_timeout(app_name: str) -> float;
