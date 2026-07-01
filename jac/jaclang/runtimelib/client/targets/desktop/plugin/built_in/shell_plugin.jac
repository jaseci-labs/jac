import fnmatch;
import shlex;
import subprocess;
import from desktop_plugin { PluginError, ErrorCode, DesktopPlugin }
import from manifest { PluginManifest, PluginContext }


def _pattern_matches(pattern_argv: list, argv: list) -> bool {
    for (i, ptok) in enumerate(pattern_argv) {
        if ptok == "*" and i == len(pattern_argv) - 1 {
            return True;
        }
        if i >= len(argv) {
            return False;
        }
        if not fnmatch.fnmatch(argv[i], ptok) {
            return False;
        }
    }

    return len(argv) == len(pattern_argv);
}


def _is_allowed(allow: list, argv: list) -> bool {
    for pattern in allow {
        pattern_argv = shlex.split(pattern);
        if not pattern_argv {
            continue;
        }
        if _pattern_matches(pattern_argv, argv) {
            return True;
        }
    }
    return False;
}


obj ShellPlugin(DesktopPlugin) {
    has _allow: list = [];

    static def manifest -> PluginManifest {
        return PluginManifest(
            name="jac.shell",
            config_key="shell",
            module="built_in.shell_plugin",
            class_name="ShellPlugin",
            default_on=False
        );
    }

    static def build(ctx: PluginContext, config: object) -> DesktopPlugin {
        return ShellPlugin(DesktopPlugin._coerce_config(config));
    }

    def init(config: dict) {
        self.plugin_name = "jac.shell";

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
            raise PluginError(
                ErrorCode.INVALID_ARGS, "'command' is required for 'exec'"
            );
        }
        try {
            argv = shlex.split(cmd);
        } except ValueError as e {
            raise PluginError(ErrorCode.INVALID_ARGS, f"Invalid command: {e}");
        }
        if not argv {
            raise PluginError(ErrorCode.INVALID_ARGS, "'command' must not be empty");
        }
        allowed = _is_allowed(self._allow, argv);
        if not allowed {
            raise PluginError(
                ErrorCode.FORBIDDEN, f"Command '{argv[0]}' is not in the allowed list."
            );
        }
        try {
            timeout = int(args.get("timeout", 30));
        } except (ValueError, TypeError) {
            raise PluginError(
                ErrorCode.INVALID_ARGS, "timeout must be a positive integer"
            );
        }
        if timeout <= 0 or timeout > 3600 {
            raise PluginError(
                ErrorCode.INVALID_ARGS, "timeout must be between 1 and 3600"
            );
        }
        cwd = None;
        cwd_raw = args.get("cwd");
        if cwd_raw {
            import pathlib;
            cwd_path = pathlib.Path(cwd_raw).resolve();
            if not cwd_path.is_dir() {
                raise PluginError(
                    ErrorCode.INVALID_ARGS,
                    f"cwd '{cwd_raw}' is not an existing directory"
                );
            }
            cwd = str(cwd_path);
        }
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
            raise PluginError(
                ErrorCode.TIMEOUT, f"Command timed out after {timeout}s: {cmd}"
            );
        }
    }
}
