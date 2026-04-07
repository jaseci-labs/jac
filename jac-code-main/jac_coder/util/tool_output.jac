import os;
import re;
import sys;
import time;

import from jac_coder.util.colors { DIM, CYAN, RESET }
import from jac_coder.util.sandbox { get_sandbox_root }
import from jac_coder.events {
    emit_event,
    next_step,
    get_active_tool,
    set_active_tool,
    track_file,
    track_error,
    get_agent_prefix
}

glob MAX_LINES: int = 2000;
glob MAX_CHARS: int = 50000;

def tool_status(tool_name: str, detail: str = "") -> None;

def tool_end(result_preview: str = "", error: bool = False) -> None;

def smart_path(path: str) -> str;

def truncate_output(
    text: str, max_lines: int = MAX_LINES, max_chars: int = MAX_CHARS
) -> tuple;
