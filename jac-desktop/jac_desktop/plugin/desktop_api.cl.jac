"""Typed client SDK for jac-desktop plugins.

Importable from `cl` code so consumers stop hand-writing
`window.__jac.invoke("jac.fs", "read_file", {...})` with magic strings.

Short term: hand-written (this file). Long term: GENERATED from each plugin's
PluginManifest.commands at build time and staged beside the user's client code,
so the host and the SDK can never drift.

Binding note: the bridge is injected by the host's BOOTSTRAP_JS onto the browser
global. It is reached via `globalThis.__jac` (see `_invoke`) rather than bare
`window.__jac`, because this module declares `obj window` for the window-control
facade, which shadows the ambient `window` global — `globalThis` is the same
object in the webview and is never shadowed.
"""

"""Thin wrapper over the injected JS bridge. Resolves to data or throws an
Error carrying `.code` (the host's structured PluginError code).

Uses `globalThis` (not bare `window`) deliberately: this module declares
`obj window` for the window-control facade, which shadows the ambient browser
`window` global — so `window.__jac` would bind to that class. `globalThis` is
the same object as `window` in the webview and is never shadowed."""
async def _invoke(plugin: str, command: str, args: dict) -> any {
    return await globalThis.__jac.invoke(plugin, command, args);
}


"""Filesystem capability (mirrors jac.fs). Gated by [plugins.desktop.plugins.fs]."""
obj fs {
    static async def read_file(path: str, encoding: str = "utf-8") -> str {
        r = await _invoke("jac.fs", "read_file", {"path": path, "encoding": encoding});
        return r["content"];
    }

    static async def write_file(path: str, content: str) {
        await _invoke("jac.fs", "write_file", {"path": path, "content": content});
    }

    static async def list_dir(path: str) -> list {
        r = await _invoke("jac.fs", "list_dir", {"path": path});
        return r["entries"];
    }

    static async def exists(path: str) -> bool {
        r = await _invoke("jac.fs", "exists", {"path": path});
        return r["exists"];
    }

    static async def mkdir(path: str) {
        await _invoke("jac.fs", "mkdir", {"path": path});
    }

    static async def remove(path: str) {
        await _invoke("jac.fs", "remove", {"path": path});
    }

    static async def stat(path: str) -> dict {
        return await _invoke("jac.fs", "stat", {"path": path});
    }
}


"""Native dialogs (mirrors jac.dialog)."""
obj dialog {
    static async def open_file(title: str = "Open File") -> dict {
        return await _invoke("jac.dialog", "open_file", {"title": title});
    }

    static async def save_file(
        title: str = "Save File", default_name: str = ""
    ) -> dict {
        return await _invoke(
            "jac.dialog", "save_file", {"title": title, "default_name": default_name}
        );
    }

    static async def message(title: str, body: str, kind: str = "info") {
        await _invoke(
            "jac.dialog", "message", {"title": title, "body": body, "kind": kind}
        );
    }
}


"""System clipboard (mirrors jac.clipboard)."""
obj clipboard {
    static async def read -> str {
        r = await _invoke("jac.clipboard", "read", {});
        return r["text"];
    }

    static async def write(text: str) {
        await _invoke("jac.clipboard", "write", {"text": text});
    }
}


"""Desktop notifications (mirrors jac.notification)."""
obj notification {
    static async def send(title: str, body: str = "") {
        await _invoke("jac.notification", "send", {"title": title, "body": body});
    }
}


"""Window control (mirrors jac.window)."""
obj window {
    static async def set_title(title: str) {
        await _invoke("jac.window", "set_title", {"title": title});
    }

    static async def set_size(width: int, height: int, hint: int = 0) {
        await _invoke(
            "jac.window", "set_size", {"width": width, "height": height, "hint": hint}
        );
    }

    static async def fullscreen {
        await _invoke("jac.window", "fullscreen", {});
    }

    static async def terminate {
        await _invoke("jac.window", "terminate", {});
    }
}


"""Shell execution (mirrors jac.shell)."""
obj shell {
    static async def exec(command: str, timeout: int = 30, cwd: str = "") -> dict {
        args: dict = {"command": command, "timeout": timeout};
        if cwd {
            args["cwd"] = cwd;
        }
        return await _invoke("jac.shell", "exec", args);
    }
}


"""Path resolution (mirrors jac.path)."""
obj path {
    static async def home -> str {
        r = await _invoke("jac.path", "home", {});
        return r["path"];
    }

    static async def data -> str {
        r = await _invoke("jac.path", "data", {});
        return r["path"];
    }

    static async def config -> str {
        r = await _invoke("jac.path", "config", {});
        return r["path"];
    }

    static async def cache -> str {
        r = await _invoke("jac.path", "cache", {});
        return r["path"];
    }

    static async def temp -> str {
        r = await _invoke("jac.path", "temp", {});
        return r["path"];
    }

    static async def resolve(p: str) -> str {
        r = await _invoke("jac.path", "resolve", {"path": p});
        return r["path"];
    }
}
# Usage from a .cl.jac component:
#
#   import from "@jac/desktop" { fs, dialog, clipboard }
#
#   async def export_notes() -> None {
#       picked = await dialog.save_file("Export", "notes.txt");
#       if not picked["canceled"] {
#           await fs.write_file(picked["path"], current_text);
#           await dialog.message("Saved", "Notes exported.");
#       }
#   }
#
# Call these with POSITIONAL arguments, not keywords. The cl compiler can't
# resolve param names across the @jac/desktop module boundary, so a keyword call
# like `dialog.save_file(title="Export", default_name="notes.txt")` silently
# compiles to a single options object passed as the first positional arg — the
# host then receives `title={...}` and fails. Tracked in jaseci-labs/jaseci#6675;
# until fixed, pass positionally.
