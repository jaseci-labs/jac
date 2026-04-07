import os;
import threading;

import from jac_coder.tool.shell { bash_exec }
import from jac_coder.util.colors { YELLOW, DIM, RESET }
import from jac_coder.permission { permission_engine }
import from jac_coder.events { check_tool_loop }
import from jac_coder.tool.filesystem { write_file, edit_file }
import from jac_coder.events { emit_event }

# Thread context — maps thread ident → session_id so guarded tools know which
# session they belong to when emitting permission.request events in IDE mode.
glob _chat_contexts: dict = {};

# Thread context — maps thread ident → edit_mode ("auto"|"ask"|"plan")
glob _edit_mode_contexts: dict = {};

# IDE-mode permission gate — server blocks the tool thread here until the
# VS Code UI sends back a permission.response notification.
glob _permission_events: dict = {};   # session_id → threading.Event
glob _permission_decisions: dict = {}; # session_id → "allow"|"always"|"deny"

"""Store the current session_id and edit_mode for the running chat thread."""
def _set_chat_session(session_id: str, edit_mode: str = "auto") -> None;

"""Retrieve the session_id for the running chat thread."""
def _get_chat_session() -> str;

"""Retrieve the edit_mode for the running chat thread."""
def _get_edit_mode() -> str;

"""Clear session context for the current thread (call in finally block)."""
def _clear_chat_session() -> None;

def _check_permission(tool_id: str, resource: str, content: str = "") -> str;
def _ask_user(tool_id: str, resource: str, content: str = "") -> str;
def _ask_ide(tool_id: str, resource: str, content: str = "") -> str;

"""Write a file with permission check."""
def write_file_guarded(file_path: str, content: str) -> str;

"""Find-and-replace with permission check."""
def edit_file_guarded(
    file_path: str, old_string: str, new_string: str, replace_all: bool = False
) -> str;

"""Run a shell command with permission check."""
def run_command(
    command: str, workdir: str = ".", timeout: int = 120, background: bool = False
) -> str;
