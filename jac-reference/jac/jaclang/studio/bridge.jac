import os;
import json;
import time;
import queue;
import socket;
import hashlib;
import tempfile;
import threading;

glob SOCKET_ENV: str = "JAC_STUDIO_SOCKET",
     MAX_SOCK_PATH: int = 100,
     QUERY_METHODS: list[str] = [
         "wiring",
         "rules",
         "graph",
         "symbol",
         "search",
         "locate"
     ],
     UI_METHODS: list[str] = ["selection", "focus", "link_plan"],
     MAX_SLICE_LINES: int = 400;

class BridgeUnavailable(Exception) {}

class BridgeError(Exception) {}

obj BridgeConn {
    has sock: any,
        lock: any postinit,
        alive: bool = True;

    def postinit;
    def send(payload: dict[str, any]) -> bool;
    def close;
}

obj BridgeRequest {
    has id: any,
        method: str,
        params: dict[str, any] = {},
        conn: (BridgeConn | None) = None,
        answered: bool = False;

    def reply(result: any) -> None;
    def fail(message: str) -> None;
}

obj BridgeServer {
    has root_dir: str,
        session: str = "",
        path: str = "",
        queries: any = None,
        requests: queue.Queue postinit,
        lock: any postinit,
        sock: any = None,
        running: bool = False,
        conns: list[BridgeConn] = [],
        pointer: str = "",
        started: float = 0.0;

    def postinit;
    def run_dir -> str;
    def slug -> str;
    def socket_path -> str;
    def start -> str;
    def stop;
    def drain(handler: any, limit: int = 16) -> int;
    def answer_with(handler: any) -> any;
    def _accept_loop;
    def _serve(conn: BridgeConn);
    def _dispatch(conn: BridgeConn, line: bytes);
}

obj BridgeClient {
    has path: str,
        timeout: float = 20.0,
        seq: int = 0;

    def call(
        method: str, params: (dict[str, any] | None) = None, timeout: float = 0.0
    ) -> any;

    def alive -> bool;
}

obj StudioQueries {
    has model: ProjectModel,
        read_text: any = None;

    def handle(method: str, params: dict[str, any]) -> any;
    def resolve(key: str) -> (StNode | None);
    def require(key: str) -> StNode;
    def symbol_at(path: str, line: int) -> (StNode | None);
    def module_key_of(key: str) -> str;
    def local_name(key: str) -> str;
    def brief(nd: StNode) -> dict[str, any];
    def brief_key(key: str) -> dict[str, any];
    def wire_dict(w: any, side: str) -> dict[str, any];
    def module_wiring(key: str, with_symbols: bool = True) -> dict[str, any];
    def neighbourhood(key: str) -> dict[str, any];
    def rule_coverage -> dict[str, any];
    def symbol(key: str) -> dict[str, any];
    def search(query: str, limit: int = 20) -> dict[str, any];
    def locate(key: str, line: int = 0) -> dict[str, any];
    def link_plan(entries: list[dict[str, any]]) -> list[dict[str, any]];
    def selection(
        tray: list[str],
        code_path: str = "",
        cursor: tuple[int, int] = (0, 0),
        cursor_symbol: str = "",
        wiring_module: str = "",
        extra: (dict[str, any] | None) = None
    ) -> dict[str, any];

    def source(path: str, start: int, end: int) -> dict[str, any];
}

def socket_alive(path: str) -> bool;

def find_studio_socket(root_dir: str) -> str;

def pattern_matches(text: str, local: str) -> bool;
