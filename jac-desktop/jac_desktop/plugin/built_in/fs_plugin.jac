"""Filesystem plugin for the Jac desktop IPC system.

File operations gated by allow-lists from jac.toml (baked at build time).
Canonicalizes paths with resolve() before checking allow-lists to prevent
traversal attacks.

Transpiled to dependency-free Python at build time.
"""
import os;
import stat;
import from pathlib { Path }
import from desktop_plugin { PluginError, DesktopPlugin }
import from built_in.path_plugin { PathPlugin }


"""Filesystem operations with allow-list enforcement."""
class FsPlugin(DesktopPlugin) {
    def init(self: FsPlugin, config: dict, path_plugin: PathPlugin) {
        super.init("jac.fs");
        # Normalize non-dict config (e.g. `fs = true`) to empty dict.
        if not isinstance(config, dict) {
            config = {};
        }
        self._allow_read: list = config.get("allow_read", []);
        self._allow_write: list = config.get("allow_write", []);
        self._path_plugin = path_plugin;
        # Pre-resolve allow-list entries ($HOME, $APP_DATA etc.)
        self._resolved_read = [self._resolve_pattern(p) for p in self._allow_read];
        self._resolved_write = [self._resolve_pattern(p) for p in self._allow_write];
    }

    def handle(self: FsPlugin, command: str, args: dict) -> dict {
        if command == "read_file" {
            return self._read_file(args);
        }
        if command == "write_file" {
            return self._write_file(args);
        }
        if command == "list_dir" {
            return self._list_dir(args);
        }
        if command == "mkdir" {
            return self._mkdir(args);
        }
        if command == "remove" {
            return self._remove(args);
        }
        if command == "exists" {
            return self._exists(args);
        }
        if command == "stat" {
            return self._stat(args);
        }
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin 'jac.fs' has no command '{command}'"
        );
    }

    def _read_file(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "read");
        encoding = args.get("encoding", "utf-8");
        try {
            content = path.read_text(encoding=encoding);
        } except FileNotFoundError {
            raise PluginError("NOT_FOUND", f"File not found: {path}");
        } except PermissionError {
            raise PluginError("FORBIDDEN", f"Permission denied: {path}");
        }
        return {"content": content};
    }

    def _write_file(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        content = args.get("content", "");
        self._check_allowed(path, "write");
        path.parent.mkdir(parents=True, exist_ok=True);
        try {
            path.write_text(content, encoding=args.get("encoding", "utf-8"));
        } except PermissionError {
            raise PluginError("FORBIDDEN", f"Permission denied: {path}");
        }
        return {};
    }

    def _list_dir(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "read");
        if not path.is_dir() {
            raise PluginError("NOT_FOUND", f"Not a directory: {path}");
        }
        entries = [];
        for entry in sorted(path.iterdir()) {
            entries.append(
                {
                    "name": entry.name,
                    "is_dir": entry.is_dir(),
                    "is_file": entry.is_file(),
                    "size": entry.stat().st_size if entry.is_file() else 0
                }
            );
        }
        return {"entries": entries};
    }

    def _mkdir(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "write");
        path.mkdir(parents=True, exist_ok=True);
        return {};
    }

    def _remove(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "write");
        if path.is_dir() {
            import shutil;
            shutil.rmtree(str(path));
        } else {
            path.unlink();
        }
        return {};
    }

    def _exists(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        # Allow exists check without full read permission — just check the
        # path is within a readable root so we don't leak arbitrary FS info.
        self._check_allowed(path, "read");
        return {"exists": path.exists()};
    }

    def _stat(self: FsPlugin, args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "read");
        if not path.exists() {
            raise PluginError("NOT_FOUND", f"Path not found: {path}");
        }
        st = path.stat();
        return {
            "size": st.st_size,
            "is_dir": stat.S_ISDIR(st.st_mode),
            "is_file": stat.S_ISREG(st.st_mode),
            "modified": st.st_mtime
        };
    }

    """Resolve a user-provided path string to an absolute canonical Path."""
    def _resolve_path(self: FsPlugin, raw: str) -> Path {
        if not raw {
            raise PluginError("INVALID_ARGS", "'path' is required");
        }
        return Path(raw).expanduser().resolve();
    }

    """Resolve allow-list pattern entries ($HOME, $APP_DATA, etc.)."""
    def _resolve_pattern(self: FsPlugin, pattern: str) -> str {
        if pattern == "$HOME" {
            return str(Path.home());
        }
        if pattern == "$APP_DATA" {
            return self._path_plugin._resolve_xdg("XDG_DATA_HOME", ".local/share");
        }
        if pattern.startswith("$HOME/") {
            return str(Path.home() / pattern[6:]);
        }
        if pattern.startswith("$APP_DATA/") {
            base = self._path_plugin._resolve_xdg("XDG_DATA_HOME", ".local/share");
            return str(Path(base) / pattern[10:]);
        }
        return str(Path(pattern).expanduser().resolve());
    }

    """Check that a resolved path is within an allowed list."""
    def _check_allowed(self: FsPlugin, path: Path, mode: str) -> None {
        allowed = self._resolved_read if mode == "read" else self._resolved_write;
        if not allowed {
            raise PluginError(
                "FORBIDDEN",
                f"No {mode} paths are allowed. Configure allow_{mode} in jac.toml."
            );
        }
        path_str = str(path);
        for prefix in allowed {
            if path_str == prefix or path_str.startswith(prefix + os.sep) {
                return;
            }
        }
        raise PluginError(
            "FORBIDDEN", f"Path '{path}' is outside the allowed {mode} directories."
        );
    }
}
