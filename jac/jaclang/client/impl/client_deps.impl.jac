impl ensure_client_deps(config_loader: JacClientConfig) -> bool {
    package_config = config_loader.get_package_config();
    dependencies = package_config.get('dependencies', {});
    dev_dependencies = package_config.get('devDependencies', {});

    if dependencies or dev_dependencies {
        return True;
    }

    return prompt_install_client_deps(config_loader);
}

def _resolve_client_framework -> str {
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
        if cfg and cfg.client {
            return cfg.client.framework;
        }
    } except Exception {}
    return "react";
}

def _default_client_deps(framework: str) -> tuple[dict[str, str], dict[str, str]] {
    if framework == "solid" {
        runtime_deps: dict[str, str] = {
            'solid-js': '^1.9.13',
            '@solidjs/router': '^0.16.1',
            '@tanstack/solid-form': '^1.33.0',
            'zod': '^4.3.6'
        };

        dev_deps: dict[str, str] = {
            'vite': '^6.4.1',
            'vite-plugin-solid': '^0.5.0',
            'typescript': '^5.3.3'
        };
        return (runtime_deps, dev_deps);
    }

    import from jaclang.client.npm_provider {
        CORE_DEV_DEPS,
        CORE_RUNTIME_DEPS,
        OPTIONAL_RUNTIME_DEPS
    }
    return ({** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS}, {** CORE_DEV_DEPS});
}

def prompt_install_client_deps(config_loader: JacClientConfig) -> bool {
    import sys;
    import from jaclang.cli.console { console }
    framework = _resolve_client_framework();
    console.error("\n  ⚠ Client dependencies are not configured.");
    console.error(
        f"  jac-client requires npm packages ({framework}, vite, etc.) to build client pages."
    );
    console.error("  These will be added to your jac.toml file.\n");
    try {
        response = input(
            "  Install default client dependencies now? [Y/n]: "
        ).strip().lower();
    } except (EOFError, KeyboardInterrupt) {
        console.error("");
        return False;
    }
    if response and response not in ('y', 'yes', '') {
        console.error(
            "\n  To configure manually, add [dependencies.npm] to your jac.toml."
        );
        console.error("  Or create a new project with: jac create --kind web-app\n");
        return False;
    }
    (default_deps, default_dev_deps) = _default_client_deps(framework);
    console.print("\n  ⏳ Adding default client dependencies to jac.toml...");
    try {
        for (name, version) in default_deps.items() {
            config_loader.add_dependency(name, version, is_dev=False);
        }
        for (name, version) in default_dev_deps.items() {
            config_loader.add_dependency(name, version, is_dev=True);
        }
        config_loader.save();
        config_loader.invalidate();
        console.print("  ✔ Default client dependencies added to jac.toml\n");
        return True;
    } except Exception as e {
        console.error(f"  ✖ Failed to add dependencies: {e}");
        return False;
    }
}
