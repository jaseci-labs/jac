import os;
import subprocess;
import from desktop_plugin { PluginError, ErrorCode, OsPlugin, DesktopPlugin }
import from manifest { PluginManifest, PluginContext }


obj NotificationPlugin(OsPlugin) {
    has _enabled: bool = True;

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.notification",
            config_key="notification",
            module="built_in.notification_plugin",
            class_name="NotificationPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return NotificationPlugin(config);
    }

    def init(config: dict) {
        self.plugin_name = "jac.notification";

        self._enabled = DesktopPlugin._config_enabled(config);
    }

    def handle(command: str, args: dict) -> dict {
        if not self._enabled {
            raise PluginError(ErrorCode.FORBIDDEN, "Notifications are not enabled.");
        }
        if command == "send" {
            return self._send(args);
        }
        return super.handle(command, args);
    }

    def _send(args: dict) -> dict {
        title = args.get("title", "");
        body = args.get("body", "");
        if not title {
            raise PluginError(ErrorCode.INVALID_ARGS, "'title' is required for 'send'");
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
                self._run_powershell(ps_script, timeout=10);
            } else {
                raise PluginError(
                    ErrorCode.UNSUPPORTED, f"Platform '{platform}' not supported"
                );
            }
        } except FileNotFoundError {
            raise PluginError(
                ErrorCode.UNAVAILABLE, f"Notification tool not found on {platform}"
            );
        } except subprocess.TimeoutExpired {
            raise PluginError(ErrorCode.TIMEOUT, "Notification command timed out");
        } except subprocess.CalledProcessError as e {
            raise PluginError(ErrorCode.FAILED, f"Notification failed: {e.stderr}");
        }
        return {};
    }
}
