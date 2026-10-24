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

impl jac_executable -> str {
    argv0 = sys.argv[0] if sys.argv else "";
    cand = "";
    if argv0 {
        cand = argv0 if os.sep in argv0 else (shutil.which(argv0) or "");
    }
    if cand
        and os.path.isfile(cand)
        and os.access(cand, os.X_OK)
        and not cand.endswith((".py", ".jac")) {
        return os.path.realpath(cand);
    }
    return shutil.which("jac") or "jac";
}

impl jac_mcp_server -> dict[str, any] {
    return {"name": "jac", "command": jac_executable(), "args": ["mcp"], "env": []};
}

impl unified_diff(path: str, old: str, new: str, root_dir: str) -> str {
    name = os.path.relpath(path, root_dir) if os.path.isabs(path) else path;
    lines = difflib.unified_diff(
        old.splitlines(keepends=True),
        new.splitlines(keepends=True),
        fromfile=f"a/{name}",
        tofile=f"b/{name}"
    );
    text = "".join(lines);
    if text and not text.endswith("\n") {
        text += "\n";
    }
    return text or f"(no change to {name})\n";
}

impl permission_diffs(
    tool_call: dict[str, any], root_dir: str, known: (dict[str, any] | None) = None
) -> list[str] {
    diffs: list[str] = [];
    prior = known or {};
    contents = tool_call.get("content") or prior.get("content") or [];
    for c in contents {
        if isinstance(c, dict) and c.get("type") == "diff" {
            path = str(c.get("path", ""));
            old = str(c.get("oldText") or "");
            new = str(c.get("newText") or "");
            whole = read_or_empty(path);
            if whole and old and old != whole and old in whole {
                (old, new) = (whole, whole.replace(old, new, 1));
            }
            diffs.append(unified_diff(path, old, new, root_dir));
        }
    }
    raw = tool_call.get("rawInput") or prior.get("raw_input") or {};
    path = str(raw.get("file_path") or raw.get("path") or "")
        if isinstance(raw, dict)
        else "";
    if diffs or not path {
        return diffs;
    }
    old = read_or_empty(path);
    if "old_string" in raw and "new_string" in raw {
        count = -1 if raw.get("replace_all") else 1;
        new = old.replace(str(raw["old_string"]), str(raw["new_string"]), count);
        diffs.append(unified_diff(path, old, new, root_dir));
    } elif "content" in raw {
        diffs.append(unified_diff(path, old, str(raw["content"]), root_dir));
    }
    return diffs;
}

impl read_or_empty(path: str) -> str {
    try {
        with open(path, encoding="utf-8", errors="replace") as f {
            return f.read();
        }
    } except OSError {
        return "";
    }
}
