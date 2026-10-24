import json;
import logging;
import time;

glob logger: logging.Logger = logging.getLogger(__name__),
     GITHUB_SCHEME: str = 'github',
     GITHUB_EVENT_HEADER: str = 'X-GitHub-Event',
     GITHUB_DELIVERY_HEADER: str = 'X-GitHub-Delivery';


def _fail(code: str, message: str, status: int) -> TransportResponse;


def walker_scheme(server: JacAPIServer, walker_name: str) -> str;


def github_signature_header(cfg: dict[str, any]) -> str;


def header_param_name(header: str) -> str;


obj WebhookExtension(ServerExtension) {
    has manager: (ApiKeyManager | None) = None,
        _scheme_rate: dict[str, list[int]] = {},
        _system_user_id: str = '';

    def api_keys -> ApiKeyManager;
    def webhook_parameters(
        server: JacAPIServer, walker_name: str
    ) -> list[APIParameter];

    def parameter_source(
        server: JacAPIServer, walker_name: str
    ) -> Callable[[], list[APIParameter]];

    def github_gate(
        request: Request, raw_body: bytes, cfg: dict[str, any]
    ) -> TransportResponse | None;

    async def run_walker(
        server: JacAPIServer,
        walker_name: str,
        raw_body: bytes,
        user_id: str,
        header_fields: dict[str, str]
    ) -> TransportResponse;

    async def process_github(
        server: JacAPIServer, walker_name: str, request: Request
    ) -> TransportResponse;

    async def process_api_key(
        server: JacAPIServer, walker_name: str, request: Request
    ) -> TransportResponse;

    def webhook_callback(
        server: JacAPIServer, walker_name: str
    ) -> Callable[..., TransportResponse];

    def github_prerequisites(server: JacAPIServer, walker_name: str) -> str;
    def register(server: JacAPIServer);
}
