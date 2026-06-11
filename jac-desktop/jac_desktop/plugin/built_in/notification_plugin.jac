"""Notification plugin for the Jac desktop IPC system.

Sends desktop notifications via platform-native tools:
  Linux:   notify-send
  macOS:   osascript
  Windows: PowerShell toast

Transpiled to dependency-free Python at build time.
"""
import base64;
import os;
import subprocess;
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

    def _escape_applescript(self: NotificationPlugin, s: str) -> str {
        return s.replace("\\", "\\\\").replace('"', '\\"');
    }

    def _escape_powershell(self: NotificationPlugin, s: str) -> str {
        return s.replace("'", "''");
    }

    def _run_powershell(self: NotificationPlugin, ps: str) {
        encoded = base64.b64encode(ps.encode("utf-16-le")).decode("ascii");
        return subprocess.run(
            ["powershell", "-EncodedCommand", encoded],
            check=True,
            capture_output=True,
            timeout=10
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
                escaped_body = self._escape_applescript(body);
                escaped_title = self._escape_applescript(title);
                script = f'display notification "{escaped_body}" with title "{escaped_title}"';
                subprocess.run(
                    ["osascript", "-e", script],
                    check=True,
                    capture_output=True,
                    timeout=5
                );
            } elif platform == "windows" {
                escaped_title = self._escape_powershell(title);
                escaped_body = self._escape_powershell(body);
                ps_script = (
                    "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');"
                    "$n = New-Object System.Windows.Forms.NotifyIcon;"
                    "$n.Icon = [System.Drawing.SystemIcons]::Information;"
                    "$n.Visible = $true;"
                    f"$n.ShowBalloonTip(5000, '{escaped_title}', '{escaped_body}', 'Info')"
                );
                self._run_powershell(ps_script);
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
}
