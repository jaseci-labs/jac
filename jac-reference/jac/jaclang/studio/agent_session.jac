import os;
import queue;
import threading;
import time;

glob STUDIO_DIR: str = os.path.join(".jac", "studio"),
     REJECTED_WRITE: str = "The user rejected this write.",
     CANCELLED_WRITE: str = "The turn was cancelled before this write was approved.";

obj AgentEvent {
    has kind: str,
        data: dict[str, any] = {};

    def to_dict -> dict[str, any];
}

obj AgentSession {
    has name: str = "",
        root_dir: str = "",
        cwd: str = "",
        events: queue.Queue = queue.Queue(),
        write_gate: any = None,
        read_hook: any = None,
        agent_session_id: str = "",
        log_path: str = "",
        _busy: bool = False,
        _stopped: bool = False,
        _lock: any = None,
        _waits: dict[str, any] = {},
        _answers: dict[str, any] = {},
        _wait_kinds: dict[str, str] = {},
        _seq: int = 0;

    def postinit;
    def emit(kind: str, data: (dict[str, any] | None) = None) -> AgentEvent;
    def start(cwd: str, mcp_servers: list[dict[str, any]]) -> None;
    def prompt(blocks: list[dict[str, any]]) -> None;
    def cancel -> None;
    def respond_permission(request_id: any, option_id: (str | None)) -> None;
    def resolve_write(request_id: any, accept: bool, message: str = "") -> None;
    def busy -> bool;
    def stop -> None;
    def next_request_id(prefix: str) -> str;
    def expect(request_id: any, kind: str) -> None;
    def wait_answer(request_id: any) -> any;
    def answer(request_id: any, value: any) -> bool;
    def cancel_waits -> None;
    def pending_requests -> list[str];
    def resolve_path(path: str) -> str;
    def read_text(path: str) -> str;
    def gate_write(path: str, content: str) -> (str | None);
    def log(text: str) -> None;
}

def studio_dir(root_dir: str, sub: str = "") -> str;

def blocks_text(blocks: list[dict[str, any]]) -> str;
