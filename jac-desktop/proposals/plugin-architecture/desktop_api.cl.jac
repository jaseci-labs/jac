"""Typed client SDK for jac-desktop plugins (DRAFT STUB).

Importable from `cl` code so consumers stop hand-writing
`window.__jac.invoke("jac.fs", "read_file", {...})` with magic strings.

Short term: hand-written (this file). Long term: GENERATED from each plugin's
PluginManifest.commands at build time and staged beside the user's client code,
so the host and the SDK can never drift.

Binding note: `window.__jac` is injected by the host's BOOTSTRAP_JS and treated
here as an ambient browser global. If the jac-client compiler does not resolve a
bare `window`, declare it with a tiny ambient/extern shim — that is the only
open binding detail for this piece.
"""

"""Thin wrapper over the injected JS bridge. Resolves to data or throws an
Error carrying `.code` (the host's structured PluginError code)."""
async def _invoke(plugin: str, command: str, args: dict) -> any {
    return await window.__jac.invoke(plugin, command, args);
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
# Usage from a .cl.jac component:
#
#   import from "@jac/desktop" { fs, dialog, clipboard }
#
#   async def export_notes() -> None {
#       picked = await dialog.save_file(title="Export", default_name="notes.txt");
#       if not picked["canceled"] {
#           await fs.write_file(picked["path"], current_text);
#           await dialog.message("Saved", "Notes exported.");
#       }
#   }
