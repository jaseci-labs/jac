"""Notification plugin for the Jac desktop IPC system.

Sends desktop notifications via platform-native tools:
  Linux:   notify-send
  macOS:   osascript
  Windows: PowerShell toast

Transpiled to dependency-free Python at build time.
"""
import os;
import subprocess;
import sys;
import from desktop_plugin { PluginError, DesktopPlugin }


"""Desktop notification capability via platform tools."""
class NotificationPlugin(DesktopPlugin) {
    def init(self: NotificationPlugin, config: dict) {
        super.init("jac.notification");
        # If this plugin is instantiated at all, it's enabled.
        # config may be True (from `notification = true` in TOML),
        # {} (from empty `[plugins.desktop.plugins.notification]`),
        # or a dict with sub-settings.
        self._enabled = config is not False;
    }

    def handle(self: NotificationPlugin, command: str, args: dict) -> dict {
        if not self._enabled {
            raise PluginError("FORBIDDEN", "Notifications are not enabled.");
        }
        if command == "send" {
            return self._send(args);
        }
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin 'jac.notification' has no command '{command}'"
        );
    }

    def _send(self: NotificationPlugin, args: dict) -> dict {
        title = args.get("title", "");
        body = args.get("body", "");
        if not title {
            raise PluginError("INVALID_ARGS", "'title' is required for 'send'");
        }
        platform = self._detect_platform();
        try {
            if platform == "linux" {
                cmd = ["notify-send", title];
                if body {
                    cmd.append(body);
                }
                subprocess.run(cmd, check=True, capture_output=True, timeout=5);
            } elif platform == "darwin" {
                script = f'display notification "{body}" with title "{title}"';
                subprocess.run(
                    ["osascript", "-e", script],
                    check=True,
                    capture_output=True,
                    timeout=5
                );
            } elif platform == "windows" {
                ps_script = (
                    f'[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms");'
                    f'$n = New-Object System.Windows.Forms.NotifyIcon;'
                    f'$n.Icon = [System.Drawing.SystemIcons]::Information;'
                    f'$n.Visible = $true;'
                    f'$n.ShowBalloonTip(5000, "{title}", "{body}", "Info")'
                );
                subprocess.run(
                    ["powershell", "-Command", ps_script],
                    check=True,
                    capture_output=True,
                    timeout=10
                );
            } else {
                raise PluginError(
                    "UNSUPPORTED", f"Platform '{platform}' not supported"
                );
            }
        } except FileNotFoundError {
            raise PluginError(
                "UNAVAILABLE", f"Notification tool not found on {platform}"
            );
        } except subprocess.TimeoutExpired {
            raise PluginError("TIMEOUT", "Notification command timed out");
        } except subprocess.CalledProcessError as e {
            raise PluginError("FAILED", f"Notification failed: {e.stderr}");
        }
        return {};
    }

    def _detect_platform(self: NotificationPlugin) -> str {
        if sys.platform.startswith("linux") {
            return "linux";
        }
        if sys.platform == "darwin" {
            return "darwin";
        }
        if sys.platform == "win32" {
            return "windows";
        }
        return sys.platform;
    }
}
