# ruff: noqa
"""Dialog plugin for the Jac desktop IPC system.

Shows native OS dialogs (open file, save file, message) via platform tools:
  Linux:   zenity
  macOS:   osascript
  Windows: PowerShell

Transpiled to dependency-free Python at build time.
"""

import subprocess
import sys

from desktop_plugin import DesktopPlugin, PluginError


class DialogPlugin(DesktopPlugin):
    def __init__(self, config):
        super().__init__("jac.dialog")
        # If this plugin is instantiated at all, it's enabled.
        # config may be True (from `dialog = true`), {} (from empty
        # `[plugins.desktop.plugins.dialog]`), or a dict with sub-settings.
        self._enabled = config is not False

    def handle(self, command, args):
        if not self._enabled:
            raise PluginError("FORBIDDEN", "Dialogs are not enabled.")
        if command == "open_file":
            return self._open_file(args)
        if command == "save_file":
            return self._save_file(args)
        if command == "message":
            return self._message(args)
        raise PluginError(
            "UNKNOWN_COMMAND", f"Plugin 'jac.dialog' has no command '{command}'"
        )

    def _open_file(self, args):
        platform = self._detect_platform()
        title = args.get("title", "Open File")
        filters = args.get("filters", [])
        try:
            if platform == "linux":
                cmd = ["zenity", "--file-selection", "--title", title]
                for f in filters:
                    if isinstance(f, str):
                        cmd.extend(["--file-filter", f])
                result = subprocess.run(cmd, capture_output=True, timeout=60)
                if result.returncode != 0:
                    return {"canceled": True, "path": ""}
                return {
                    "canceled": False,
                    "path": result.stdout.decode("utf-8").strip(),
                }
            if platform == "darwin":
                script = f'POSIX path of (choose file with prompt "{title}")'
                result = subprocess.run(
                    ["osascript", "-e", script], capture_output=True, timeout=60
                )
                if result.returncode != 0:
                    return {"canceled": True, "path": ""}
                path = result.stdout.decode("utf-8").strip()
                return {"canceled": False, "path": path}
            if platform == "windows":
                ps = (
                    "Add-Type -AssemblyName System.Windows.Forms;"
                    "$d = New-Object System.Windows.Forms.OpenFileDialog;"
                    f"$d.Title = '{title}';"
                    "if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { '' }"
                )
                result = subprocess.run(
                    ["powershell", "-Command", ps], capture_output=True, timeout=60
                )
                path = result.stdout.decode("utf-8").strip()
                return {"canceled": path == "", "path": path}
            raise PluginError("UNSUPPORTED", f"Platform '{platform}' not supported")
        except FileNotFoundError:
            raise PluginError("UNAVAILABLE", "Dialog tool not found")
        except subprocess.TimeoutExpired:
            raise PluginError("TIMEOUT", "Dialog timed out")

    def _save_file(self, args):
        platform = self._detect_platform()
        title = args.get("title", "Save File")
        default_name = args.get("default_name", "")
        try:
            if platform == "linux":
                cmd = ["zenity", "--file-selection", "--save", "--title", title]
                if default_name:
                    cmd.extend(["--filename", default_name])
                result = subprocess.run(cmd, capture_output=True, timeout=60)
                if result.returncode != 0:
                    return {"canceled": True, "path": ""}
                return {
                    "canceled": False,
                    "path": result.stdout.decode("utf-8").strip(),
                }
            if platform == "darwin":
                if default_name:
                    script = f'POSIX path of (choose file name with prompt "{title}" default name "{default_name}")'
                else:
                    script = f'POSIX path of (choose file name with prompt "{title}")'
                result = subprocess.run(
                    ["osascript", "-e", script], capture_output=True, timeout=60
                )
                if result.returncode != 0:
                    return {"canceled": True, "path": ""}
                return {
                    "canceled": False,
                    "path": result.stdout.decode("utf-8").strip(),
                }
            if platform == "windows":
                ps = (
                    "Add-Type -AssemblyName System.Windows.Forms;"
                    "$d = New-Object System.Windows.Forms.SaveFileDialog;"
                    f"$d.Title = '{title}';"
                    "if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { '' }"
                )
                result = subprocess.run(
                    ["powershell", "-Command", ps], capture_output=True, timeout=60
                )
                path = result.stdout.decode("utf-8").strip()
                return {"canceled": path == "", "path": path}
            raise PluginError("UNSUPPORTED", f"Platform '{platform}' not supported")
        except FileNotFoundError:
            raise PluginError("UNAVAILABLE", "Dialog tool not found")
        except subprocess.TimeoutExpired:
            raise PluginError("TIMEOUT", "Dialog timed out")

    def _message(self, args):
        platform = self._detect_platform()
        title = args.get("title", "Message")
        body = args.get("body", "")
        kind = args.get("kind", "info")
        try:
            if platform == "linux":
                flag = "--info"
                if kind == "warning":
                    flag = "--warning"
                elif kind == "error":
                    flag = "--error"
                cmd = ["zenity", flag, "--title", title, "--text", body]
                subprocess.run(cmd, capture_output=True, timeout=60)
                return {}
            if platform == "darwin":
                icon = "note"
                if kind == "warning":
                    icon = "caution"
                elif kind == "error":
                    icon = "stop"
                script = f'display dialog "{body}" with title "{title}" buttons {{"OK"}} default button "OK" with icon {icon}'
                subprocess.run(
                    ["osascript", "-e", script], capture_output=True, timeout=60
                )
                return {}
            if platform == "windows":
                icon_flag = "Information"
                if kind == "warning":
                    icon_flag = "Warning"
                elif kind == "error":
                    icon_flag = "Error"
                ps = (
                    "Add-Type -AssemblyName System.Windows.Forms;"
                    f'[System.Windows.Forms.MessageBox]::Show("{body}", "{title}", "OK", "{icon_flag}")'
                )
                subprocess.run(
                    ["powershell", "-Command", ps], capture_output=True, timeout=60
                )
                return {}
            raise PluginError("UNSUPPORTED", f"Platform '{platform}' not supported")
        except FileNotFoundError:
            raise PluginError("UNAVAILABLE", "Dialog tool not found")
        except subprocess.TimeoutExpired:
            raise PluginError("TIMEOUT", "Dialog timed out")

    def _detect_platform(self):
        if sys.platform.startswith("linux"):
            return "linux"
        if sys.platform == "darwin":
            return "darwin"
        if sys.platform == "win32":
            return "windows"
        return sys.platform
