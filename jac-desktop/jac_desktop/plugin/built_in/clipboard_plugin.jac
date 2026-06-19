"""Clipboard plugin for the Jac desktop IPC system.

Reads/writes the system clipboard via platform-native tools:
  Linux:   xclip (xsel as fallback)
  macOS:   pbcopy / pbpaste
  Windows: clip.exe / Get-Clipboard

Transpiled to dependency-free Python at build time.
"""
import subprocess;
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from manifest { PluginManifest, PluginContext }


"""System clipboard read/write via platform tools."""
obj ClipboardPlugin(DesktopPlugin) {
    has _allow_read: bool = True,
        _allow_write: bool = True;

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.clipboard",
            config_key="clipboard",
            module="built_in.clipboard_plugin",
            class_name="ClipboardPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return ClipboardPlugin(DesktopPlugin._coerce_config(config));
    }

    def init(config: dict) {
        self.plugin_name = "jac.clipboard";
        # Normalize non-dict config (e.g. `clipboard = true`) to empty dict.
        if not isinstance(config, dict) {
            config = {};
        }
        self._allow_read = bool(config.get("allow_read", True));
        self._allow_write = bool(config.get("allow_write", True));
    }

    def handle(command: str, args: dict) -> dict {
        if command == "read" {
            return self._read();
        }
        if command == "write" {
            return self._write(args);
        }
        return super.handle(command, args);
    }

    def _read -> dict {
        if not self._allow_read {
            raise PluginError(ErrorCode.FORBIDDEN, "Clipboard read is not allowed.");
        }
        platform = self._detect_platform();
        try {
            if platform == "linux" {
                # Try xclip first, fall back to xsel
                try {
                    result = subprocess.run(
                        ["xclip", "-selection", "clipboard", "-o"],
                        capture_output=True,
                        timeout=5
                    );
                } except FileNotFoundError {
                    result = subprocess.run(
                        ["xsel", "--clipboard", "--output"],
                        capture_output=True,
                        timeout=5
                    );
                }
                return {"text": result.stdout.decode("utf-8", errors="replace")};
            }
            if platform == "darwin" {
                result = subprocess.run(["pbpaste"], capture_output=True, timeout=5);
                return {"text": result.stdout.decode("utf-8", errors="replace")};
            }
            if platform == "windows" {
                result = subprocess.run(
                    ["powershell", "-Command", "Get-Clipboard"],
                    capture_output=True,
                    timeout=5
                );
                return {"text": result.stdout.decode("utf-8", errors="replace")};
            }
            raise PluginError(
                ErrorCode.UNSUPPORTED, f"Platform '{platform}' not supported"
            );
        } except FileNotFoundError {
            raise PluginError(ErrorCode.UNAVAILABLE, "Clipboard tool not found");
        } except subprocess.TimeoutExpired {
            raise PluginError(ErrorCode.TIMEOUT, "Clipboard command timed out");
        }
    }

    def _write(args: dict) -> dict {
        if not self._allow_write {
            raise PluginError(ErrorCode.FORBIDDEN, "Clipboard write is not allowed.");
        }
        text = args.get("text", "");
        platform = self._detect_platform();
        try {
            if platform == "linux" {
                try {
                    subprocess.run(
                        ["xclip", "-selection", "clipboard"],
                        input=text.encode("utf-8"),
                        check=True,
                        capture_output=True,
                        timeout=5
                    );
                } except FileNotFoundError {
                    subprocess.run(
                        ["xsel", "--clipboard", "--input"],
                        input=text.encode("utf-8"),
                        check=True,
                        capture_output=True,
                        timeout=5
                    );
                }
            } elif platform == "darwin" {
                subprocess.run(
                    ["pbcopy"],
                    input=text.encode("utf-8"),
                    check=True,
                    capture_output=True,
                    timeout=5
                );
            } elif platform == "windows" {
                subprocess.run(
                    ["clip.exe"],
                    input=text.encode("utf-8"),
                    check=True,
                    capture_output=True,
                    timeout=5
                );
            } else {
                raise PluginError(
                    ErrorCode.UNSUPPORTED, f"Platform '{platform}' not supported"
                );
            }
        } except FileNotFoundError {
            raise PluginError(ErrorCode.UNAVAILABLE, "Clipboard tool not found");
        } except subprocess.TimeoutExpired {
            raise PluginError(ErrorCode.TIMEOUT, "Clipboard command timed out");
        } except subprocess.CalledProcessError as e {
            raise PluginError(ErrorCode.FAILED, f"Clipboard write failed: {e.stderr}");
        }
        return {};
    }
}
