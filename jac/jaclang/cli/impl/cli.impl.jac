"""Start the command line interface.

Uses the new registry infrastructure for command registration,
help formatting, and execution with plugin hook support.
"""

import os;
import sys;
import from importlib.metadata { version as pkg_version }
import from pathlib { Path }

impl start_cli -> None {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.cli.registry { get_registry }
    import from jaclang.cli.executor { get_executor }
    import from jaclang.cli.help { get_help_formatter }
    import from jaclang.cli.console { console }
    # Auto-discover and load jac.toml project configuration
    _load_project_config();
    # Load plugins which may register additional commands
    Jac.create_cmd();
    # Get the registry and finalize it (builds argparse parser)
    registry = get_registry();
    parser = registry.finalize();
    # Handle implicit 'run' command for .jac files
    raw_argv = sys.argv[1:];
    if (
        raw_argv
        and not raw_argv[0].startswith('-')
        and raw_argv[0].lower().endswith(('.jac', '.py'))
    ) {
        sys.argv = [sys.argv[0], 'run'] + raw_argv;
    }
    # Parse arguments
    args = parser.parse_args();
    # Handle --version flag
    if args.version {
        import from jaclang.cli.banners { print_version_banner }
        print_version_banner(pkg_version('jaclang'));
        return;
    }
    # Handle no command specified
    if (args.command is None) {
        # Display custom help with grouped commands
        formatter = get_help_formatter();
        help_text = formatter.format_main_help(
            registry.get_all(), prog="jac", version=pkg_version('jaclang')
        );
        console.print(help_text);
        return;
    }
    # Get the command specification
    command_spec = registry.get(args.command);
    if not command_spec {
        console.error(f"Unknown command: {args.command}");
        parser.print_help();
        return;
    }
    # Prepare arguments for execution
    args_dict = vars(args);
    args_dict.pop('command');
    args_dict.pop('version', None);
    _apply_profile(args_dict);
    # Execute using the new executor with hook support
    executor = get_executor();
    result = executor.execute(command_spec, args_dict);
    # Exit with the command's return code
    if result.error {
        console.error(f"{result.error}");
    }
    if result.return_code != 0 {
        sys.exit(result.return_code);
    }
}

"""Load project configuration from jac.toml if present."""
def _load_project_config -> None {
    try {
        import from jaclang.project.config { get_config, set_config }
        import from jaclang.project.dependencies { add_venv_to_path }

        # Auto-discover jac.toml
        config = get_config();
        if config is not None {
            # Add venv site-packages to Python path
            add_venv_to_path(config);
        }

        # Initialize plugin-registered dependency types
        _initialize_dependency_registry();

        # Initialize plugin-registered project templates
        _initialize_template_registry();
    } except Exception {
    # Silently ignore if project module not available or config discovery fails
    }
}

"""Initialize the dependency registry from plugin hooks."""
def _initialize_dependency_registry -> None {
    try {
        import from jaclang.project.dep_registry { initialize_dependency_registry }
        initialize_dependency_registry();
    } except Exception {
    # Silently ignore if registry initialization fails
    }
}

"""Initialize the template registry from plugin hooks."""
def _initialize_template_registry -> None {
    try {
        import from jaclang.project.template_registry { initialize_template_registry }
        initialize_template_registry();
    } except Exception {
    # Silently ignore if registry initialization fails
    }
}

"""Resolve the active profile name and apply multi-file config overlay.

Profile priority: --profile flag > JAC_PROFILE > JAC_ENV (deprecated) > default_profile
"""
def _apply_profile(args_dict: dict) -> None {
    import from jaclang.cli.console { console }
    try {
        import from jaclang.project.config { get_config }

        config = get_config();
        if config is None {
            return;
        }

        # Determine profile name: --profile flag > JAC_PROFILE > JAC_ENV (deprecated) > default
        profile = args_dict.pop('profile', None);
        if not profile {
            profile = os.environ.get('JAC_PROFILE');
        }
        if not profile {
            jac_env = os.environ.get('JAC_ENV');
            if jac_env {
                console.print(
                    "Warning: JAC_ENV is deprecated, use JAC_PROFILE instead.",
                    style="warning"
                );
                profile = jac_env;
            }
        }
        if not profile and config.environment.default_profile {
            profile = config.environment.default_profile;
        }

        config.apply_profile_overlay(profile or None);

        # Bridge config values into args_dict when the CLI arg is at its
        # argparse default so that config file values take effect.
        # Only override when the config explicitly sets the value (in _raw_data
        # or via profile overlay) — otherwise leave the argparse default alone.
        _apply_config_defaults(config, args_dict);
    } except (KeyError, ValueError, OSError) as e {
        console.print(f"Warning: Failed to apply profile: {e}", style="warning");
    }
}

"""Apply config values to args_dict for keys still at their argparse defaults.

Maps config fields to CLI arg names with their argparse defaults.
Only overrides an arg if:
  1. The arg exists in args_dict (the command accepts it)
  2. The arg value equals the argparse default (user didn't explicitly pass it)
  3. The config has an explicitly-set value (from file or profile, not just the object default)
"""
def _apply_config_defaults(config: object, args_dict: dict) -> None {
    # (arg_name, argparse_default, config_value, raw_data_section, raw_data_key)
    bridges: list = [
        ("port", 8000, config.serve.port, "serve", "port"),
        ("cache", True, config.run.cache, "run", "cache"),
        ("main", True, config.run.main, "run", "main"),
        ("verbose", False, config.test.verbose, "test", "verbose"),

    ];
    for (arg_name, arg_default, config_value, section, key) in bridges {
        if arg_name not in args_dict {
            continue;
        }
        if args_dict[arg_name] != arg_default {
            continue;  # User explicitly passed this arg
        }
        # Check if the config explicitly sets this value
        raw = config._raw_data.get(section, {});
        if isinstance(raw, dict) and key in raw {
            args_dict[arg_name] = config_value;
        }
    }
}
