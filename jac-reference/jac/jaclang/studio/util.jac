import os;
import sys;
import shutil;
import difflib;
import threading;

glob COMPILE_LOCK: any = threading.RLock();

def jac_executable -> str;

def jac_mcp_server -> dict[str, any];

def unified_diff(path: str, old: str, new: str, root_dir: str) -> str;

def permission_diffs(
    tool_call: dict[str, any], root_dir: str, known: (dict[str, any] | None) = None
) -> list[str];

def read_or_empty(path: str) -> str;
