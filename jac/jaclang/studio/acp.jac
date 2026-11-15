import os;
import json;
import shlex;
import signal;
import subprocess;
import threading;
import time;

glob ACP_PROTOCOL_VERSION: int = 1,
     CLIENT_NAME: str = "jac-hack",
     HANDSHAKE_SECS: float = 120.0,
     CANCEL_GRACE_SECS: float = 10.0,
     TERMINAL_DEFAULT_LIMIT: int = 262144,
     ERR_METHOD_NOT_FOUND: int = -32601,
     ERR_INVALID_PARAMS: int = -32602,
     ERR_INTERNAL: int = -32603,
     ERR_RESOURCE_NOT_FOUND: int = -32002,
     SIGKILL: int = 9,
     LOG_MAX_BYTES: int = 4000000,
     TOOL_UPDATE_FIELDS: list[tuple[str, str]] = [
         ("title", "title"),
         ("kind", "kind"),
         ("status", "status"),
         ("content", "content"),
         ("locations", "locations"),
         ("rawInput", "raw_input"),
         ("rawOutput", "raw_output")
     ];

obj AcpError(Exception) {
    has method: str = "",
        code: int = 0,
        message: str = "",
        data: any = None;

    def postinit -> None;
}

obj PendingCall {
    has done: any = None,
        result: any = None,
        error: (dict[str, any] | None) = None;

    def postinit -> None;
}

obj AcpTerminal {
    has terminal_id: str,
        command: str = "",
        proc: any = None,
        output: str = "",
        limit: int = TERMINAL_DEFAULT_LIMIT,
        truncated: bool = False,
        exit_code: (int | None) = None,
        signal_name: (str | None) = None,
        done: any = None,
        lock: any = None;

    def postinit -> None;
    def append(chunk: str) -> None;
    def status -> (dict[str, any] | None);
}

obj AcpSession(AgentSession) {
    has command: list[str] = [],
        env: dict[str, str] = {},
        load_session_id: str = "",
        client_version: str = "",
        proc: any = None,
        agent_info: dict[str, any] = {},
        agent_caps: dict[str, any] = {},
        auth_methods: list[any] = [],
        models: dict[str, any] = {},
        modes: dict[str, any] = {},
        commands: list[dict[str, any]] = [],
        stop_reason: str = "",
        _pending: dict[int, PendingCall] = {},
        _next_id: int = 0,
        _wlock: any = None,
        _reader: any = None,
        _alive: bool = False,
        _terminals: dict[str, AcpTerminal] = {},
        _turn: any = None,
        _cancel_at: float = 0.0,
        _stderr: any = None,
        _replaying: bool = False;

    override def emit(kind: str, data: (dict[str, any] | None) = None) -> AgentEvent;
    override def start(cwd: str, mcp_servers: list[dict[str, any]]) -> None;
    override def prompt(blocks: list[dict[str, any]]) -> None;
    override def cancel -> None;
    override def stop -> None;
    def alive -> bool;
    def request(method: str, params: dict[str, any], timeout: float = 0.0) -> any;
    def notify(method: str, params: dict[str, any]) -> None;
    def _spawn -> None;
    def _send(msg: dict[str, any]) -> None;
    def _reply(rid: any, result: any) -> None;
    def _reply_error(rid: any, code: int, message: str) -> None;
    def _read_loop -> None;
    def _on_response(msg: dict[str, any]) -> None;
    def _on_exit -> None;
    def _on_notification(method: str, params: dict[str, any]) -> None;
    def _on_update(upd: dict[str, any]) -> None;
    def _serve_request(msg: dict[str, any]) -> None;
    def _handle(method: str, params: dict[str, any], rid: any) -> any;
    def _run_turn(blocks: list[dict[str, any]]) -> None;
    def _adapt_blocks(blocks: list[dict[str, any]]) -> list[dict[str, any]];
    def _permission(params: dict[str, any], rid: any) -> dict[str, any];
    def _fs_read(params: dict[str, any]) -> dict[str, any];
    def _fs_write(params: dict[str, any]) -> dict[str, any];
    def _terminal_create(params: dict[str, any]) -> dict[str, any];
    def _terminal_pump(term: AcpTerminal) -> None;
    def _terminal_event(term: AcpTerminal) -> None;
    def _terminal(params: dict[str, any]) -> AcpTerminal;
    def _kill_terminal(term: AcpTerminal) -> None;
    def _trace(direction: str, text: str) -> None;
}

def chunk_text(content: any) -> str;

def jac_version -> str;
