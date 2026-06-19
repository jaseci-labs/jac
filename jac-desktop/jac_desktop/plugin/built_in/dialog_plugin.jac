"""Dialog plugin for the Jac desktop IPC system.

Shows native OS dialogs (open file, save file, message) via platform tools:
  Linux:   zenity
  macOS:   osascript
  Windows: PowerShell

Transpiled to dependency-free Python at build time.
"""
import subprocess;
import from desktop_plugin { PluginError, ErrorCode, OsPlugin, DesktopPlugin }
import from manifest { PluginManifest, PluginContext }


"""Native dialog capability via platform tools."""
obj DialogPlugin(OsPlugin) {
    has _enabled: bool = True;

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.dialog",
            config_key="dialog",
            module="built_in.dialog_plugin",
            class_name="DialogPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return DialogPlugin(config);
    }

    def init(config: dict) {
        self.plugin_name = "jac.dialog";
        # If this plugin is instantiated at all, it's enabled.
        # config may be True (from `dialog = true`), {} (from empty
        # `[plugins.desktop.plugins.dialog]`), or a dict with sub-settings.
        self._enabled = DesktopPlugin._config_enabled(config);
    }

    def handle(command: str, args: dict) -> dict {
        if not self._enabled {
            raise PluginError(ErrorCode.FORBIDDEN, "Dialogs are not enabled.");
        }
        if command == "open_file" {
            return self._open_file(args);
        }
        if command == "save_file" {
            return self._save_file(args);
        }
        if command == "message" {
            return self._message(args);
        }
        return super.handle(command, args);
    }

    def _open_file(args: dict) -> dict {
        platform = self._detect_platform();
        title = args.get("title", "Open File");
        filters = args.get("filters", []);
        try {
            if platform == "linux" {
                cmd = ["zenity", "--file-selection", "--title", title];
                for f in filters {
                    if isinstance(f, str) {
                        cmd.extend(["--file-filter", f]);
                    }
                }
                result = subprocess.run(cmd, capture_output=True, timeout=60);
                if result.returncode != 0 {
                    return {"canceled": True, "path": ""};
                }
                return {
                    "canceled": False,
                    "path": result.stdout.decode("utf-8").strip()
                };
            }
            if platform == "darwin" {
                escaped_title = self._escape_applescript(title);
                script = f'POSIX path of (choose file with prompt "{escaped_title}")';
                result = subprocess.run(
                    ["osascript", "-e", script], capture_output=True, timeout=60
                );
                if result.returncode != 0 {
                    return {"canceled": True, "path": ""};
                }
                path = result.stdout.decode("utf-8").strip();
                return {"canceled": False, "path": path};
            }
            if platform == "windows" {
                escaped_title = self._escape_powershell(title);
                ps = (
                    "Add-Type -AssemblyName System.Windows.Forms;"
                    "$d = New-Object System.Windows.Forms.OpenFileDialog;"
                    f"$d.Title = '{escaped_title}';"
                    "if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { '' }"
                );
                result = self._run_powershell(ps);
                path = result.stdout.decode("utf-8").strip();
                return {"canceled": path == "", "path": path};
            }
            raise PluginError(
                ErrorCode.UNSUPPORTED, f"Platform '{platform}' not supported"
            );
        } except FileNotFoundError {
            raise PluginError(ErrorCode.UNAVAILABLE, "Dialog tool not found");
        } except subprocess.TimeoutExpired {
            raise PluginError(ErrorCode.TIMEOUT, "Dialog timed out");
        }
    }

    def _save_file(args: dict) -> dict {
        platform = self._detect_platform();
        title = args.get("title", "Save File");
        default_name = args.get("default_name", "");
        try {
            if platform == "linux" {
                cmd = ["zenity", "--file-selection", "--save", "--title", title];
                if default_name {
                    cmd.extend(["--filename", default_name]);
                }
                result = subprocess.run(cmd, capture_output=True, timeout=60);
                if result.returncode != 0 {
                    return {"canceled": True, "path": ""};
                }
                return {
                    "canceled": False,
                    "path": result.stdout.decode("utf-8").strip()
                };
            }
            if platform == "darwin" {
                escaped_title = self._escape_applescript(title);
                script = f'POSIX path of (choose file name with prompt "{escaped_title}")';
                if default_name {
                    escaped_default = self._escape_applescript(default_name);
                    script = f'POSIX path of (choose file name with prompt "{escaped_title}" default name "{escaped_default}")';
                }
                result = subprocess.run(
                    ["osascript", "-e", script], capture_output=True, timeout=60
                );
                if result.returncode != 0 {
                    return {"canceled": True, "path": ""};
                }
                return {
                    "canceled": False,
                    "path": result.stdout.decode("utf-8").strip()
                };
            }
            if platform == "windows" {
                escaped_title = self._escape_powershell(title);
                ps = (
                    "Add-Type -AssemblyName System.Windows.Forms;"
                    "$d = New-Object System.Windows.Forms.SaveFileDialog;"
                    f"$d.Title = '{escaped_title}';"
                    "if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { '' }"
                );
                result = self._run_powershell(ps);
                path = result.stdout.decode("utf-8").strip();
                return {"canceled": path == "", "path": path};
            }
            raise PluginError(
                ErrorCode.UNSUPPORTED, f"Platform '{platform}' not supported"
            );
        } except FileNotFoundError {
            raise PluginError(ErrorCode.UNAVAILABLE, "Dialog tool not found");
        } except subprocess.TimeoutExpired {
            raise PluginError(ErrorCode.TIMEOUT, "Dialog timed out");
        }
    }

    def _message(args: dict) -> dict {
        platform = self._detect_platform();
        title = args.get("title", "Message");
        body = args.get("body", "");
        kind = args.get("kind", "info");  # info, warning, error
        try {
            if platform == "linux" {
                flag = "--info";
                if kind == "warning" {
                    flag = "--warning";
                } elif kind == "error" {
                    flag = "--error";
                }
                cmd = ["zenity", flag, "--title", title, "--text", body];
                subprocess.run(cmd, capture_output=True, timeout=60);
                return {};
            }
            if platform == "darwin" {
                icon = "note";
                if kind == "warning" {
                    icon = "caution";
                } elif kind == "error" {
                    icon = "stop";
                }
                escaped_body = self._escape_applescript(body);
                escaped_title = self._escape_applescript(title);
                script = f'display dialog "{escaped_body}" with title "{escaped_title}" buttons {{"OK"}} default button "OK" with icon {icon}';
                subprocess.run(
                    ["osascript", "-e", script], capture_output=True, timeout=60
                );
                return {};
            }
            if platform == "windows" {
                icon_flag = "Information";
                if kind == "warning" {
                    icon_flag = "Warning";
                } elif kind == "error" {
                    icon_flag = "Error";
                }
                escaped_body = self._escape_powershell(body);
                escaped_title = self._escape_powershell(title);
                ps = (
                    "Add-Type -AssemblyName System.Windows.Forms;"
                    f"[System.Windows.Forms.MessageBox]::Show('{escaped_body}', '{escaped_title}', 'OK', '{icon_flag}')"
                );
                self._run_powershell(ps);
                return {};
            }
            raise PluginError(
                ErrorCode.UNSUPPORTED, f"Platform '{platform}' not supported"
            );
        } except FileNotFoundError {
            raise PluginError(ErrorCode.UNAVAILABLE, "Dialog tool not found");
        } except subprocess.TimeoutExpired {
            raise PluginError(ErrorCode.TIMEOUT, "Dialog timed out");
        }
    }
}
