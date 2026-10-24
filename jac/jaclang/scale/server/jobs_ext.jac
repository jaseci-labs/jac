import asyncio;
import logging;

glob logger: logging.Logger = logging.getLogger(__name__);


def _fail(code: str, message: str, status: int) -> TransportResponse;


def _err_response(e: Exception) -> TransportResponse;


def _build_spec(
    body: dict[str, any]
) -> tuple[(TriggerSpec | None), (TransportResponse | None)];


obj JobsExtension(ServerExtension) {
    def register(server: JacAPIServer);
    def on_worker_start(server: JacAPIServer);
}
