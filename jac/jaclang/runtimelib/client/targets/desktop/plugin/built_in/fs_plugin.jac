import os;
import stat;
import from pathlib { Path }
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from built_in.path_plugin { PathPlugin }
import from manifest { PluginManifest, PluginContext }


glob _RMTREE_ENTRY_LIMIT: int = 500;

obj FsPlugin(DesktopPlugin) {
    has _path_plugin: PathPlugin,
        _allow_read: list = [],
        _allow_write: list = [],
        _resolved_read: list = [],
        _resolved_write: list = [];

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.fs",
            config_key="fs",
            module="built_in.fs_plugin",
            class_name="FsPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return FsPlugin(DesktopPlugin._coerce_config(config), ctx.path_plugin);
    }

    def init(config: dict, path_plugin: PathPlugin) {
        self.plugin_name = "jac.fs";

        if not isinstance(config, dict) {
            config = {};
        }
        self._allow_read = config.get("allow_read", []);
        self._allow_write = config.get("allow_write", []);
        self._path_plugin = path_plugin;

        self._resolved_read = [self._resolve_pattern(p) for p in self._allow_read];
        self._resolved_write = [self._resolve_pattern(p) for p in self._allow_write];
    }

    def handle(command: str, args: dict) -> dict {
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
        return super.handle(command, args);
    }

    def _read_file(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "read");
        encoding = args.get("encoding", "utf-8");
        try {
            content = path.read_text(encoding=encoding);
        } except FileNotFoundError {
            raise PluginError(ErrorCode.NOT_FOUND, f"File not found: {path}");
        } except PermissionError {
            raise PluginError(ErrorCode.FORBIDDEN, f"Permission denied: {path}");
        } except LookupError {
            raise PluginError(ErrorCode.INVALID_ARGS, f"Unknown encoding: {encoding}");
        } except UnicodeDecodeError {
            raise PluginError(
                ErrorCode.INVALID_ARGS, f"File is not valid {encoding} text: {path}"
            );
        }
        return {"content": content};
    }

    def _write_file(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        content = args.get("content", "");
        self._check_allowed(path, "write");
        encoding = args.get("encoding", "utf-8");
        path.parent.mkdir(parents=True, exist_ok=True);
        try {
            path.write_text(content, encoding=encoding);
        } except PermissionError {
            raise PluginError(ErrorCode.FORBIDDEN, f"Permission denied: {path}");
        } except LookupError {
            raise PluginError(ErrorCode.INVALID_ARGS, f"Unknown encoding: {encoding}");
        } except UnicodeEncodeError {
            raise PluginError(
                ErrorCode.INVALID_ARGS, f"Content cannot be encoded as {encoding}"
            );
        }
        return {};
    }

    def _list_dir(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "read");
        if not path.is_dir() {
            raise PluginError(ErrorCode.NOT_FOUND, f"Not a directory: {path}");
        }
        entries = [];
        try {
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
        } except PermissionError {
            raise PluginError(ErrorCode.FORBIDDEN, f"Permission denied: {path}");
        }
        return {"entries": entries};
    }

    def _mkdir(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "write");
        path.mkdir(parents=True, exist_ok=True);
        return {};
    }

    def _remove(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "write");
        if path.is_dir() {
            import shutil;
            count = 0;
            for (_, dirs, files) in os.walk(str(path)) {
                count += len(dirs) + len(files);
                if count > _RMTREE_ENTRY_LIMIT {
                    raise PluginError(
                        ErrorCode.FORBIDDEN,
                        f"Directory '{path}' contains more than {_RMTREE_ENTRY_LIMIT} entries; "
                        "recursive removal refused."
                    );
                }
            }
            shutil.rmtree(str(path));
        } else {
            path.unlink();
        }
        return {};
    }

    def _exists(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));

        self._check_allowed(path, "read");
        return {"exists": path.exists()};
    }

    def _stat(args: dict) -> dict {
        path = self._resolve_path(args.get("path", ""));
        self._check_allowed(path, "read");
        if not path.exists() {
            raise PluginError(ErrorCode.NOT_FOUND, f"Path not found: {path}");
        }
        try {
            st = path.stat();
        } except FileNotFoundError {
            raise PluginError(ErrorCode.NOT_FOUND, f"Path not found: {path}");
        } except PermissionError {
            raise PluginError(ErrorCode.FORBIDDEN, f"Permission denied: {path}");
        } except OSError as e {
            raise PluginError(ErrorCode.FAILED, f"Failed to stat path: {path}: {e}");
        }
        return {
            "size": st.st_size,
            "is_dir": stat.S_ISDIR(st.st_mode),
            "is_file": stat.S_ISREG(st.st_mode),
            "modified": st.st_mtime
        };
    }

    def _resolve_path(raw: str) -> Path {
        if not raw {
            raise PluginError(ErrorCode.INVALID_ARGS, "'path' is required");
        }
        return Path(raw).expanduser().resolve();
    }

    def _resolve_pattern(pattern: str) -> str {
        if pattern == "$HOME" {
            return str(Path.home().resolve());
        }
        if pattern == "$APP_DATA" {
            base = self._path_plugin.resolve_xdg("XDG_DATA_HOME", ".local/share");
            return str(Path(base).resolve());
        }
        if pattern.startswith("$HOME/") {
            return str((Path.home() / pattern[6:]).resolve());
        }
        if pattern.startswith("$APP_DATA/") {
            base = self._path_plugin.resolve_xdg("XDG_DATA_HOME", ".local/share");
            return str((Path(base) / pattern[10:]).resolve());
        }
        return str(Path(pattern).expanduser().resolve());
    }

    def _check_allowed(path: Path, mode: str) -> None {
        allowed = self._resolved_read if mode == "read" else self._resolved_write;
        if not allowed {
            raise PluginError(
                ErrorCode.FORBIDDEN,
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
            ErrorCode.FORBIDDEN,
            f"Path '{path}' is outside the allowed {mode} directories."
        );
    }
}
