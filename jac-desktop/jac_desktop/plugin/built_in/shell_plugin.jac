"""Shell plugin for the Jac desktop IPC system.

Runs subprocess commands with a deny-all default. Commands must be explicitly
allowed in jac.toml via glob patterns:

  [plugins.desktop.plugins.shell]
  allow = ["git *", "jac *"]

The executable name (first token) is matched against the allow list before
execution. Commands run without a shell to prevent operator injection.

Transpiled to dependency-free Python at build time.
"""
import fnmatch;
import shlex;
import subprocess;
import from desktop_plugin { PluginError, DesktopPlugin }


"""Shell command execution with glob-based allow-list."""
obj ShellPlugin(DesktopPlugin) {
    has _allow: list = [];

    def init(config: dict) {
        super.init("jac.shell");
        # Normalize non-dict config (e.g. `shell = true`) to empty dict.
        if not isinstance(config, dict) {
            config = {};
        }
        self._allow = config.get("allow", []);
    }

    def handle(command: str, args: dict) -> dict {
        if command == "exec" {
            return self._exec(args);
        }
        return super.handle(command, args);
    }

    def _exec(args: dict) -> dict {
        cmd = args.get("command", "");
        if not cmd {
            raise PluginError("INVALID_ARGS", "'command' is required for 'exec'");
        }
        try {
            argv = shlex.split(cmd);
        } except ValueError as e {
            raise PluginError("INVALID_ARGS", f"Invalid command: {e}");
        }
        if not argv {
            raise PluginError("INVALID_ARGS", "'command' must not be empty");
        }
        cmd_name = argv[0];
        # Match only the executable name against each pattern's first token.
        # Full-string fnmatch is unsafe because * matches shell metacharacters.
        allowed = False;
        for pattern in self._allow {
            pattern_argv = shlex.split(pattern);
            if not pattern_argv {
                continue;
            }
            if fnmatch.fnmatch(cmd_name, pattern_argv[0]) {
                allowed = True;
                break;
            }
        }
        if not allowed {
            raise PluginError(
                "FORBIDDEN", f"Command '{cmd_name}' is not in the allowed list."
            );
        }
        try {
            timeout = int(args.get("timeout", 30));
        } except (ValueError, TypeError) {
            raise PluginError("INVALID_ARGS", "timeout must be a positive integer");
        }
        if timeout <= 0 or timeout > 3600 {
            raise PluginError("INVALID_ARGS", "timeout must be between 1 and 3600");
        }
        cwd = args.get("cwd") or None;
        try {
            result = subprocess.run(
                argv,
                shell=False,
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
