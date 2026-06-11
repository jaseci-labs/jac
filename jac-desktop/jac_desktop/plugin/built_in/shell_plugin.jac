"""Shell plugin for the Jac desktop IPC system.

Runs subprocess commands with a deny-all default. Commands must be explicitly
allowed in jac.toml via glob patterns:

  [plugins.desktop.plugins.shell]
  allow = ["git *", "jac *"]

Each command is matched against the allow list before execution.

Transpiled to dependency-free Python at build time.
"""
import fnmatch;
import subprocess;
import from desktop_plugin { PluginError, DesktopPlugin }


"""Shell command execution with glob-based allow-list."""
class ShellPlugin(DesktopPlugin) {
    def init(self: ShellPlugin, config: dict) {
        super.init("jac.shell");
        # Normalize non-dict config (e.g. `shell = true`) to empty dict.
        if not isinstance(config, dict) {
            config = {};
        }
        self._allow: list = config.get("allow", []);
    }

    def handle(self: ShellPlugin, command: str, args: dict) -> dict {
        if command == "exec" {
            return self._exec(args);
        }
        return super.handle(command, args);
    }

    def _exec(self: ShellPlugin, args: dict) -> dict {
        cmd = args.get("command", "");
        if not cmd {
            raise PluginError("INVALID_ARGS", "'command' is required for 'exec'");
        }
        # Check against allow list
        allowed = False;
        for pattern in self._allow {
            if fnmatch.fnmatch(cmd, pattern) {
                allowed = True;
                break;
            }
        }
        if not allowed {
            raise PluginError(
                "FORBIDDEN", f"Command '{cmd}' is not in the allowed list."
            );
        }
        timeout = int(args.get("timeout", 30));
        cwd = args.get("cwd") or None;
        try {
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=cwd
            );
            return {
                "exit_code": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr
            };
        } except subprocess.TimeoutExpired {
            raise PluginError("TIMEOUT", f"Command timed out after {timeout}s: {cmd}");
        }
    }
}
