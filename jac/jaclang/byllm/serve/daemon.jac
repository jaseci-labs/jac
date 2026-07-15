"""The `jac model serve` daemon.

A machine-wide, stdlib-only (`http.server`, no FastAPI/uvicorn) OpenAI-compatible
gateway on 127.0.0.1. It routes `/v1/chat/completions` by model name to a
per-alias `llama-server` runner (spawned on demand via RunnerSupervisor),
evicts idle runners, and NEVER downloads weights -- an un-pulled model returns
a structured error telling the caller to `jac model pull`.
"""

import from http.server { BaseHTTPRequestHandler }
import from jaclang.byllm.serve.supervisor { RunnerSupervisor }

"""HTTP handler; delegates all routing to the ModelDaemon on the server."""
class _Handler(BaseHTTPRequestHandler) {
    def log_message(self: _Handler, fmt: str, *args: any) -> None;
    def _send_json(self: _Handler, status: int, payload: dict) -> None;
    def do_GET(self: _Handler) -> None;
    def do_POST(self: _Handler) -> None;
}

obj ModelDaemon {
    has serve_cfg: dict,
        port: int = 0,
        supervisor: RunnerSupervisor | None = None,
        _httpd: object = None,
        _stop: object = None,
        _evictor: object = None;

    def postinit -> None;
    def list_models -> dict;
    def handle_show(handler: object, body: dict) -> None;
    def handle_chat(handler: object, body: dict) -> None;
    def _alias_of(model: str) -> str;
    def _proxy(handler: object, base_url: str, body: dict) -> None;
    def _evict_loop -> None;
    def serve -> int;
    def shutdown -> None;
}
