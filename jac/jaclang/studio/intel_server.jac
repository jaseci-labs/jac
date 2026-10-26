import os;
import sys;

import from jaclang.lsp.protocol { uris }

obj StudioLangServer(JacLangServer) {
    has last_error: str = "";

    def debug(msg: str) -> None;
    def log_error(message: str) -> None;
    def log_warning(message: str) -> None;
    def log_info(message: str) -> None;
}

def new_server(root_dir: str) -> StudioLangServer;

def uri_of(path: str) -> str;

def path_of(uri: str) -> str;

def head_of(path: str) -> str;

def unit_files(head: str) -> list[str];

def read_lines(path: str) -> list[str];

def sem_style(types: list[str], mods: list[str], tok_type: int, tok_mods: int) -> str;

def decode_tokens(data: list[int]) -> list[tuple[int, int, int, str]];

def defining_symbol(sym: any) -> any;

def symbol_info(nd: any) -> dict[str, any];

def alert_tuple(
    alert: any, severity: str
) -> tuple[str, str, str, str, int, int, int, int];

def new_cancel_token -> CancelToken;

def check_head(
    ls: StudioLangServer,
    head: str,
    max_apps: int = 0,
    cancel: (CancelToken | None) = None
) -> dict[str, any];

def hover_at(ls: StudioLangServer, path: str, line: int, col: int) -> (str | None);

def location_dict(loc: any, with_text: bool = False) -> dict[str, any];

def definition_at(
    ls: StudioLangServer, path: str, line: int, col: int
) -> (dict[str, any] | None);

def references_at(
    ls: StudioLangServer, path: str, line: int, col: int
) -> list[dict[str, any]];

def invalidate_path(ls: StudioLangServer, path: str) -> list[str];

def shutdown_server(ls: StudioLangServer);

def type_hints(ls: StudioLangServer, path: str) -> list[tuple[int, int, str]];
