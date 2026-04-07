import os;
import threading;

glob _tls: object = threading.local();

def set_sandbox_root(sroot: str) -> None;
def get_sandbox_root() -> str;
def sandbox_path(path: str) -> tuple;
def set_browser_exec(fn: object) -> None;
def get_browser_exec() -> object;
