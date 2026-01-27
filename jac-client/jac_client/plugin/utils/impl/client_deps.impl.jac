"""Implementation of client dependency checker utility."""

"""Check if client npm dependencies are configured, prompt to install if missing."""
impl ensure_client_deps(config_loader: object) -> bool {
    package_config = config_loader.get_package_config();
    dependencies = package_config.get('dependencies', {});
    dev_dependencies = package_config.get('devDependencies', {});
    # If either deps or devDeps has entries, assume configured
    if dependencies or dev_dependencies {
        return True;
    }
    # No deps configured — prompt the user
    return prompt_install_client_deps(config_loader);
}

"""Prompt user to install default jac-client npm dependencies."""
def prompt_install_client_deps(config_loader: object) -> bool {
    import sys;
    print("\n  ⚠ Client dependencies are not configured.", file=sys.stderr);
    print(
        "  jac-client requires npm packages (react, vite, etc.) to build client pages.",
        file=sys.stderr
    );
    print("  These will be added to your jac.toml file.\n", file=sys.stderr);
    try {
        response = input("  Install default client dependencies now? [Y/n]: ").strip().lower();
    } except (EOFError, KeyboardInterrupt) {
        print("", file=sys.stderr);
        return False;
    }
    if response and response not in ('y', 'yes', '') {
        print(
            "\n  To configure manually, add [dependencies.npm] to your jac.toml.",
            file=sys.stderr
        );
        print(
            "  Or create a new project with: jac create --use client\n",
            file=sys.stderr
        );
        return False;
    }
    # Default runtime dependencies
    default_deps: dict[str, str] = {
        'react': '^18.2.0',
        'react-dom': '^18.2.0',
        'react-router-dom': '^6.22.0',
        'react-error-boundary': '^5.0.0'
    };
    # Default build infrastructure dependencies
    default_dev_deps: dict[str, str] = {
        'vite': '^6.4.1',
        '@vitejs/plugin-react': '^4.2.1',
        'typescript': '^5.3.3',
        '@types/react': '^18.2.0',
        '@types/react-dom': '^18.2.0'
    };
    print("\n  ⏳ Adding default client dependencies to jac.toml...", flush=True);
    try {
        for (name, version) in default_deps.items() {
            config_loader.add_dependency(name, version, is_dev=False);
        }
        for (name, version) in default_dev_deps.items() {
            config_loader.add_dependency(name, version, is_dev=True);
        }
        config_loader.save();
        config_loader.invalidate();
        print("  ✔ Default client dependencies added to jac.toml\n", flush=True);
        return True;
    } except Exception as e {
        print(f"  ✖ Failed to add dependencies: {e}", file=sys.stderr);
        return False;
    }
}
