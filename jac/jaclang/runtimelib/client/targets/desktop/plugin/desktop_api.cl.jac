async def _invoke(plugin: str, command: str, args: dict) -> any {
    return await globalThis.__jac.invoke(plugin, command, args);
}


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


obj clipboard {
    static async def read -> str {
        r = await _invoke("jac.clipboard", "read", {});
        return r["text"];
    }

    static async def write(text: str) {
        await _invoke("jac.clipboard", "write", {"text": text});
    }
}


obj notification {
    static async def send(title: str, body: str = "") {
        await _invoke("jac.notification", "send", {"title": title, "body": body});
    }
}


obj app_window {
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


obj shell {
    static async def exec(command: str, timeout: int = 30, cwd: str = "") -> dict {
        args: dict = {"command": command, "timeout": timeout};
        if cwd {
            args["cwd"] = cwd;
        }
        return await _invoke("jac.shell", "exec", args);
    }
}


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
