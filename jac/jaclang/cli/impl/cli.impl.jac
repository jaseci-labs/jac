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
        and raw_argv[0].lower().endswith(('.jac', '.jir', '.py'))
    ) {
        sys.argv = [sys.argv[0], 'run'] + raw_argv;
    }
    # Parse arguments
    args = parser.parse_args();
    # Handle --version flag
    if args.version {
        print(f"Jac version {pkg_version('jaclang')}");
        print('Jac path:', __file__);
        return;
    }
    # Handle no command specified
    if (args.command is None) {
        # Display custom help with grouped commands
        formatter = get_help_formatter();
        help_text = formatter.format_main_help(
            registry.get_all(), prog="jac", version=pkg_version('jaclang')
        );
        print(help_text);
        return;
    }
    # Get the command specification
    command_spec = registry.get(args.command);
    if not command_spec {
        print(f"Unknown command: {args.command}", file=sys.stderr);
        parser.print_help();
        return;
    }
    # Prepare arguments for execution
    args_dict = vars(args);
    args_dict.pop('command');
    args_dict.pop('version', None);
    # Apply environment profile if specified
    _apply_env_profile(args_dict);
    # Execute using the new executor with hook support
    executor = get_executor();
    result = executor.execute(command_spec, args_dict);
    # Exit with the command's return code
    if result.error {
        print(f"Error: {result.error}", file=sys.stderr);
    }
    if result.return_code != 0 {
        sys.exit(result.return_code);
    }
}

"""Load project configuration from jac.toml if present."""
def _load_project_config -> None {
    try {
        import from jaclang.project.config { get_config, set_config }
        import from jaclang.project.dependencies { add_packages_to_path }

        # Auto-discover jac.toml
        config = get_config();
        if config is not None {
            # Add packages/ directory to Python path
            add_packages_to_path(config);
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

"""Apply environment profile from --env flag or JAC_ENV environment variable."""
def _apply_env_profile(args_dict: dict) -> None {
    try {
        import from jaclang.project.config { get_config }

        config = get_config();
        if config is None {
            return;
        }

        # Check for --env argument or JAC_ENV environment variable
        profile = args_dict.pop('env', None);
        if profile is None {
            profile = os.environ.get('JAC_ENV');
        }
        if profile is None and config.environment.default_profile {
            profile = config.environment.default_profile;
        }

        if profile {
            config.apply_profile(profile);
        }
    } except Exception {
    # Silently ignore profile loading errors
    }
}
