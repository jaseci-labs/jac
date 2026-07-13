"""Library module whose accessors return module globs (issue #7320, 1d/1e).

APP_NAME is a computed (heap-allocated) glob string and _CMDS a glob list:
returning either from a def hands the caller a reference it will release,
so the callee must retain on return or the glob's only reference dies.
"""

glob APP_NAME: str = "jac" + "tui",
     _CMDS: list[str] = ["help", "quit", "model"];

def:pub app_name -> str {
    return APP_NAME;
}

def:pub cmd_defs -> list[str] {
    return _CMDS;
}
