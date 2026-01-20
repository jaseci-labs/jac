"""Implementation of config commands.

Direct implementations - no delegation.
"""

import sys;

# Configuration groups available in jac.toml
glob CONFIG_GROUPS = [
         "project",
         "run",
         "build",
         "test",
         "serve",
         "format",
         "check",
         "dot",
         "cache",
         "plugins",
         "environment"
     ];

"""Manage Jac plugins - list, disable, or enable plugins."""
impl plugins(action: str = 'list', names: list = [], verbose: bool = False) -> int {
    import from jaclang.pycore.runtime { plugin_manager }
    import from jaclang.cli.registry { get_registry }
    import from jaclang.project.config { get_config, JacConfig, find_project_root }
    import from pathlib { Path }
    # Build a mapping from plugin object to its distribution info using pluggy's tracking
    plugin_to_dist: dict[int, tuple[str, str]] = {};
    for (plugin, dist_facade) in plugin_manager.list_plugin_distinfo() {
        dist_name = dist_facade.project_name;
        dist_version = dist_facade.version;
        plugin_to_dist[id(plugin)] = (dist_name, dist_version);
    }
    # Build mappings for plugin identification
    plugin_list = plugin_manager.list_name_plugin();
    # Map: short_name -> list of (qualified_name, plugin) for detecting ambiguity
    short_to_qualified: dict[str, list[tuple[str, object]]] = {};
    # Map: qualified_name -> plugin
    qualified_to_plugin: dict[str, object] = {};
    # Map: package_name -> list of qualified_names
    package_to_qualified: dict[str, list[str]] = {};
    for (short_name, plugin) in plugin_list {
        if short_name.isdigit() {
            continue;  # Skip unnamed plugins
        }
        if id(plugin) in plugin_to_dist {
            (pkg_name, pkg_version) = plugin_to_dist[id(plugin)];
            qualified_name = f"{pkg_name}:{short_name}";
            # Track qualified name
            qualified_to_plugin[qualified_name] = plugin;
            # Track short name -> qualified mappings (for ambiguity detection)
            if short_name not in short_to_qualified {
                short_to_qualified[short_name] = [];
            }
            short_to_qualified[short_name].append((qualified_name, plugin));
            # Track package -> qualified names
            if pkg_name not in package_to_qualified {
                package_to_qualified[pkg_name] = [];
            }
            package_to_qualified[pkg_name].append(qualified_name);
            # Also support version-qualified package names
            pkg_with_version = f"{pkg_name}=={pkg_version}";
            if pkg_with_version not in package_to_qualified {
                package_to_qualified[pkg_with_version] = [];
            }
            package_to_qualified[pkg_with_version].append(qualified_name);
        } else {
            # Core plugin - use jaclang:name as qualified name
            qualified_name = f"jaclang:{short_name}";
            qualified_to_plugin[qualified_name] = plugin;
            if short_name not in short_to_qualified {
                short_to_qualified[short_name] = [];
            }
            short_to_qualified[short_name].append((qualified_name, plugin));
            # Also track under jaclang package
            if "jaclang" not in package_to_qualified {
                package_to_qualified["jaclang"] = [];
            }
            package_to_qualified["jaclang"].append(qualified_name);
        }
    }
    # Get config for disabled plugins info
    config = get_config();
    disabled_plugins: list[str] = [];
    if config {
        disabled_plugins = config.plugins_config.disabled;
    }
    # Helper to check if a plugin is from an external package (can be disabled)
    def is_external_plugin(plugin: object) -> bool {
        return id(plugin) in plugin_to_dist;
    }
    # Helper to check if a qualified name is disabled
    def is_disabled(qualified_name: str) -> bool {
        return qualified_name in disabled_plugins;
    }
    # Handle disable action
    if action == 'disable' {
        import from jaclang.cli.console { console }
        if not names {
            console.error("Plugin or package name required for disable action.");
            console.print(
                "Usage: jac plugins disable <package> | <package:plugin> | *",
                style="muted"
            );
            return 1;
        }
        # Get or create config - auto-create jac.toml if needed
        if not config {
            result = find_project_root();
            if result {
                (_, toml_path) = result;
                config = JacConfig.load(toml_path);
            } else {
                toml_path = Path.cwd() / "jac.toml";
                config = JacConfig();
                config.toml_path = toml_path;
                config.project_root = Path.cwd();
                console.info(f"Creating {toml_path}...");
            }
        }
        for target in names {
            # Case 0: Wildcard - disable all external plugins
            if target == '*' {
                if '*' not in config.plugins_config.disabled {
                    config.plugins_config.disabled = ['*'];  # Replace with just wildcard
                    console.success("Disabled: * (all external plugins)", emoji=False);
                } else {
                    console.warning(
                        "Already disabled: * (all external plugins)", emoji=False
                    );
                }
                continue;
            }
            # Case 1: Qualified name (package:plugin)
            if ':' in target {
                if target in qualified_to_plugin {
                    plugin = qualified_to_plugin[target];
                    if not is_external_plugin(plugin) {
                        console.error(f"Cannot disable core plugin '{target}'.");
                        continue;
                    }
                    if target not in config.plugins_config.disabled {
                        config.plugins_config.disabled.append(target);
                        console.success(f"Disabled: {target}", emoji=False);
                    } else {
                        console.warning(f"Already disabled: {target}", emoji=False);
                    }
                } else {
                    console.warning(f"'{target}' not found.");
                }
                # Case 2: Package name (disable all plugins from package)
            } elif target in package_to_qualified {
                qualified_names = package_to_qualified[target];
                for qname in qualified_names {
                    if qname not in config.plugins_config.disabled {
                        config.plugins_config.disabled.append(qname);
                        console.success(f"Disabled: {qname}", emoji=False);
                    } else {
                        console.warning(f"Already disabled: {qname}", emoji=False);
                    }
                }
                # Case 3: Short name - check for ambiguity
            } elif target in short_to_qualified {
                matches = short_to_qualified[target];
                if len(matches) == 1 {
                    (qname, plugin) = matches[0];
                    if not is_external_plugin(plugin) {
                        console.error(f"Cannot disable core plugin '{target}'.");
                        continue;
                    }
                    if qname not in config.plugins_config.disabled {
                        config.plugins_config.disabled.append(qname);
                        console.success(f"Disabled: {qname}", emoji=False);
                    } else {
                        console.warning(f"Already disabled: {qname}", emoji=False);
                    }
                } else {
                    console.warning(
                        f"Ambiguous: '{target}' exists in multiple packages. Use qualified name:"
                    );
                    for (qname, _) in matches {
                        console.print(f"  jac plugins disable {qname}", style="muted");
                    }
                }
            } else {
                console.warning(f"'{target}' not found as a plugin or package name.");
            }
        }
        config.save();
        console.success(f"Saved to {config.toml_path}");
        return 0;
    }
    # Handle enable action
    if action == 'enable' {
        import from jaclang.cli.console { console }
        if not names {
            console.error("Plugin or package name required for enable action.");
            console.print(
                "Usage: jac plugins enable <package> | <package:plugin> | *",
                style="muted"
            );
            return 1;
        }
        if not config {
            console.error("No jac.toml found. Nothing to enable.");
            return 1;
        }
        enabled_any = False;
        for target in names {
            # Case 0: Wildcard - enable all (remove wildcard from disabled list)
            if target == '*' {
                if '*' in config.plugins_config.disabled {
                    config.plugins_config.disabled.remove('*');
                    console.success(
                        "Enabled: * (all external plugins will now load)", emoji=False
                    );
                    enabled_any = True;
                } else {
                    console.warning(
                        "Wildcard '*' is not currently disabled.", emoji=False
                    );
                }
                continue;
            }
            # Case 1: Exact match in disabled list (qualified or legacy short name)
            if target in config.plugins_config.disabled {
                config.plugins_config.disabled.remove(target);
                console.success(f"Enabled: {target}", emoji=False);
                enabled_any = True;
                # Case 2: Package name - enable all from that package
            } elif target in package_to_qualified {
                for qname in package_to_qualified[target] {
                    if qname in config.plugins_config.disabled {
                        config.plugins_config.disabled.remove(qname);
                        console.success(f"Enabled: {qname}", emoji=False);
                        enabled_any = True;
                    }
                }
                # Case 3: Check if it's a package prefix in disabled entries
            } else {
                # Find all disabled entries that start with this package
                matching = [
                    m
                    for m in config.plugins_config.disabled
                    if m.startswith(f"{target}:")
                ];
                if matching {
                    for qname in matching {
                        config.plugins_config.disabled.remove(qname);
                        console.success(f"Enabled: {qname}", emoji=False);
                        enabled_any = True;
                    }
                } else {
                    console.warning(
                        f"'{target}' is not disabled. Use 'jac plugins disabled' to see disabled plugins."
                    );
                }
            }
        }
        if not enabled_any {
            console.info("No plugins were enabled.");
            return 0;
        }
        config.save();
        console.success(f"Saved to {config.toml_path}");
        return 0;
    }
    # Handle disabled action - show currently disabled plugins
    if action == 'disabled' {
        import from jaclang.cli.console { console }
        if not disabled_plugins {
            console.info("No plugins are currently disabled");
        } elif '*' in disabled_plugins {
            console.print(
                "\n⚠ [yellow]All external plugins are disabled (wildcard *)[/yellow]"
            );
            if config and config.toml_path {
                console.print(f"   Configured in: {config.toml_path}", style="muted");
            }
        } else {
            console.print(
                f"\n⚠ [yellow]Currently disabled ({len(disabled_plugins)})[/yellow]"
            );
            for name in sorted(disabled_plugins) {
                console.print(f"  ✖ [dim]{name}[/dim]");
            }
            if config and config.toml_path {
                console.print(f"\n   Configured in: {config.toml_path}", style="muted");
            }
        }
        console.print();
        return 0;
    }
    # Handle list action (default)
    if action != 'list' {
        import from jaclang.cli.console { console }
        console.error(
            f"Unknown action '{action}'. Use 'list', 'disable', 'enable', or 'disabled'."
        );
        return 1;
    }
    # Organize plugins by PyPI distribution for display
    # Use the already-built mappings from above
    plugins_by_dist: dict[str, list[tuple[str, str, object, str]]] = {};  # dist_key -> [(short_name, qualified_name, plugin, class_name)]
    named_plugin_count = 0;
    for (short_name, plugin) in plugin_list {
        if short_name.isdigit() {
            continue;
        }
        named_plugin_count += 1;

        if id(plugin) in plugin_to_dist {
            (dist_name, dist_version) = plugin_to_dist[id(plugin)];
            dist_key = f"{dist_name}=={dist_version}" if dist_version else dist_name;
            qualified_name = f"{dist_name}:{short_name}";
        } else {
            dist_key = "jaclang (built-in)";
            qualified_name = f"jaclang:{short_name}";
        }

        if dist_key not in plugins_by_dist {
            plugins_by_dist[dist_key] = [];
        }
        plugin_type = type(plugin);
        plugin_class_name = plugin_type?.__name__ or str(plugin_type);
        plugins_by_dist[dist_key].append(
            (short_name, qualified_name, plugin, plugin_class_name)
        );
    }
    if not plugins_by_dist {
        import from jaclang.cli.console { console }
        console.info("No Jac plugins installed");
        return 0;
    }
    # Build mapping of package -> commands for display
    commands_by_package: dict[str, list[str]] = {};
    registry = get_registry();
    for command in registry.get_all() {
        if command.source and command.source != 'jaclang' {
            pkg = command.source;
            if pkg not in commands_by_package {
                commands_by_package[pkg] = [];
            }
            commands_by_package[pkg].append(command.name);
        }
    }
    import from jaclang.cli.console { console }
    console.print(
        f"\n🔌 [bold cyan]Installed Jac Plugins[/bold cyan] ({named_plugin_count} plugins from {len(
            plugins_by_dist
        )} packages)\n"
    );
    # Print plugins organized by distribution
    for dist_key in sorted(plugins_by_dist.keys()) {
        plugins_in_dist = plugins_by_dist[dist_key];

        # Style package name based on type
        if "(built-in)" in dist_key {
            console.print(f"  📦 [dim]{dist_key}[/dim]");
        } else {
            console.print(f"  📦 [cyan]{dist_key}[/cyan]");
        }

        # Extract package name from dist_key (remove version if present)
        pkg_name = dist_key.split("==")[0].strip();
        if pkg_name.endswith(" (built-in)") {
            pkg_name = pkg_name.replace(" (built-in)", "");
        }

        for (short_name, qualified_name, plugin, plugin_class_name) in plugins_in_dist {
            # Check disabled status using qualified name
            if qualified_name in disabled_plugins {
                console.print(
                    f"     ✖ [dim]{qualified_name}[/dim] [red][DISABLED][/red]"
                );
            } else {
                console.print(f"     ✔ [green]{qualified_name}[/green]");
            }

            if verbose {
                plugin_type = type(plugin);
                module = getattr(plugin_type, '__module__', 'unknown');
                console.print(f"       Class: {plugin_class_name}", style="muted");
                console.print(f"       Module: {module}", style="muted");
                # Show implemented hooks
                hooks = [];
                for attr_name in dir(plugin) {
                    if not attr_name.startswith('_') {
                        attr = getattr(plugin, attr_name, None);
                        if callable(attr)
                        and attr?.__wrapped__
                        or (hasattr(plugin_manager.hook, attr_name)) {
                            try {
                                hook = getattr(plugin_manager.hook, attr_name, None);
                                if hook is not None {
                                    impls = hook.get_hookimpls();
                                    for impl in impls {
                                        if impl.plugin is plugin {
                                            hooks.append(attr_name);
                                            break;
                                        }
                                    }
                                }
                            } except Exception { }
                        }
                    }
                }
                if hooks {
                    console.print(
                        f"       Hooks: {', '.join(sorted(hooks))}", style="muted"
                    );
                }
                console.print();
            }
        }

        # Show commands provided by this package
        pkg_commands = commands_by_package.get(pkg_name, []);
        if pkg_commands {
            console.print(
                f"     💻 Commands: [yellow]{', '.join(sorted(pkg_commands))}[/yellow]"
            );
        }

        console.print();
    }
    # Show disabled plugins summary if any
    if disabled_plugins {
        if '*' in disabled_plugins {
            console.print(
                "⚠ [yellow]All external plugins are disabled (wildcard *)[/yellow]"
            );
        } else {
            console.print(
                f"\n⚠ [yellow]Disabled plugins ({len(disabled_plugins)})[/yellow]"
            );
            for name in sorted(disabled_plugins) {
                console.print(f"  ✖ [dim]{name}[/dim]");
            }
        }
    }
    return 0;
}

"""View and modify jac.toml configuration settings."""
impl config(
    action: str = 'show',
    key: str = '',
    value: str = '',
    group: str = '',
    output: str = 'table'
) -> int {
    import json;
    import from jaclang.project.config { get_config, JacConfig }
    # Handle 'path' action first - doesn't need config
    if action == 'path' {
        _config_path();
        return 0;
    }
    # Handle 'groups' action - list available groups
    if action == 'groups' {
        _config_groups();
        return 0;
    }
    # Load configuration
    config = get_config();
    # Validate group if specified
    if group and group not in CONFIG_GROUPS {
        import from jaclang.cli.console { console }
        console.error(f"Unknown group '{group}'.");
        console.print(f"Available groups: {', '.join(CONFIG_GROUPS)}", style="muted");
        return 1;
    }
    # Route to appropriate handler
    if action == 'list' {
        _config_list(config, group, output, True);
    } elif action == 'show' {
        _config_list(config, group, output, False);
    } elif action == 'get' {
        return _config_get(config, key);
    } elif action == 'set' {
        return _config_set(config, key, value);
    } elif action == 'unset' {
        return _config_unset(config, key);
    } else {
        import from jaclang.cli.console { console }
        console.error(f"Unknown action '{action}'.");
        console.print(
            "Available actions: list, show, get, set, unset, path, groups",
            style="muted"
        );
        return 1;
    }
    return 0;
}

"""Show the path to the active jac.toml configuration file."""
def _config_path -> None {
    import from jaclang.project.config { get_config, find_project_root }
    import from jaclang.cli.console { console }

    config = get_config();
    if config and config.toml_path {
        console.print(f"Config file: {config.toml_path}", style="info");
        console.print(f"Project root: {config.project_root}", style="muted");
    } else {
        result = find_project_root();
        if result {
            (proj_root, toml_path) = result;
            console.print(f"Config file: {toml_path}", style="info");
            console.print(f"Project root: {proj_root}", style="muted");
        } else {
            console.warning("No jac.toml found in current directory or parents.");
            console.print("Run 'jac create' to initialize a project.", style="muted");
        }
    }
}

"""List available configuration groups."""
def _config_groups -> None {
    import from jaclang.cli.console { console }
    console.print("\nAvailable configuration groups:\n", style="info");
    group_descriptions = {
        "project": "Project metadata (name, version, description, authors)",
        "run": "Run command defaults (session, main, cache)",
        "build": "Build command defaults (typecheck, dir)",
        "test": "Test command defaults (directory, filter, verbose, fail_fast)",
        "serve": "Serve command defaults (port, session, main, cl_route_prefix)",
        "format": "Format command defaults (outfile, fix)",
        "check": "Check command defaults (print_errs, warnonly)",
        "dot": "Dot/graph visualization defaults (depth, traverse, format)",
        "cache": "Cache settings (enabled, dir)",
        "plugins": "Plugin settings (discovery, enabled, disabled)",
        "environment": "Environment profile settings (default_profile)"
    };
    for grp in CONFIG_GROUPS {
        desc = group_descriptions.get(grp, "");
        console.print("  {:<12} {}".format(grp, desc));
    }
}

"""Get the default values for a configuration group."""
def _get_group_defaults(group_name: str) -> dict {
    import from jaclang.project.config {
        ProjectConfig,
        RunConfig,
        BuildConfig,
        TestConfig,
        ServeConfig,
        FormatConfig,
        CheckConfig,
        DotConfig,
        CacheConfig,
        PluginsConfig,
        EnvironmentConfig
    }

    defaults_map = {
        "project": ProjectConfig(),
        "run": RunConfig(),
        "build": BuildConfig(),
        "test": TestConfig(),
        "serve": ServeConfig(),
        "format": FormatConfig(),
        "check": CheckConfig(),
        "dot": DotConfig(),
        "cache": CacheConfig(),
        "plugins": PluginsConfig(),
        "environment": EnvironmentConfig()
    };

    default_obj = defaults_map.get(group_name);
    if default_obj is None {
        return {};
    }

    # Convert object to dict
    result: dict = {};
    for attr in dir(default_obj) {
        if not attr.startswith('_') {
            val = getattr(default_obj, attr, None);
            if not callable(val) {
                result[attr] = val;
            }
        }
    }
    return result;
}

"""Get the JacConfig attribute name for a config group."""
def _get_group_attr(group_name: str) -> str {
    # Most groups have same name, except plugins -> plugins_config
    return "plugins_config" if group_name == "plugins" else group_name;
}

"""Get the current values for a configuration group from config."""
def _get_group_values(config: object, group_name: str) -> dict {
    attr_name = _get_group_attr(group_name);
    group_obj = getattr(config, attr_name, None);
    if group_obj is None {
        return {};
    }

    # Convert object to dict
    result: dict = {};
    for attr in dir(group_obj) {
        if not attr.startswith('_') {
            val = getattr(group_obj, attr, None);
            if not callable(val) {
                result[attr] = val;
            }
        }
    }
    return result;
}

"""Check if a setting was explicitly set in the TOML file."""
def _is_explicitly_set(config: object, group_name: str, key: str) -> bool {
    if not config?._raw_data or config._raw_data is None {
        return False;
    }

    # Group names match TOML section names
    raw_data = config._raw_data;
    if group_name not in raw_data {
        return False;
    }

    section_data = raw_data[group_name];
    if not isinstance(section_data, dict) {
        return False;
    }

    return key in section_data;
}

"""List configuration settings."""
def _config_list(config: object, group: str, output: str, show_all: bool) -> None {
    import json;
    import from jaclang.cli.console { console }

    if config is None {
        console.warning("No jac.toml found. Run 'jac create' to initialize a project.");
        return;
    }

    # Determine which groups to show
    groups_to_show = [group] if group else CONFIG_GROUPS;

    # Collect all settings data
    all_settings: dict = {};

    for grp in groups_to_show {
        defaults = _get_group_defaults(grp);
        current = _get_group_values(config, grp);

        group_settings: dict = {};
        for (key, default_val) in defaults.items() {
            current_val = current.get(key, default_val);
            is_set = _is_explicitly_set(config, grp, key);

            # For 'show' action, only include explicitly set values
            if not show_all and not is_set {
                continue;
            }

            group_settings[key] = {
                "value": current_val,
                "default": default_val,
                "is_set": is_set
            };
        }

        if group_settings {
            all_settings[grp] = group_settings;
        }
    }

    # Output in requested format
    if output == 'json' {
        _output_json(all_settings);
    } elif output == 'toml' {
        _output_toml(all_settings, show_all);
    } else {
        _output_table(all_settings, show_all);
    }
}

"""Output settings as a formatted table."""
def _output_table(settings: dict, show_all: bool) -> None {
    import from jaclang.cli.console { console }
    if not settings {
        if show_all {
            console.info("No configuration settings found.");
        } else {
            console.info("No settings have been explicitly set.");
            console.print(
                "Use 'jac config list' to see all settings with defaults.",
                style="muted"
            );
        }
        return;
    }

    # Calculate column widths
    max_group = max(len(g) for g in settings.keys());
    max_key = 0;
    max_value = 0;
    max_default = 0;

    for (grp, grp_settings) in settings.items() {
        for (key, data) in grp_settings.items() {
            max_key = max(max_key, len(key));
            max_value = max(max_value, len(str(data["value"])));
            max_default = max(max_default, len(str(data["default"])));
        }
    }

    # Ensure minimum widths
    max_group = max(max_group, 5);
    max_key = max(max_key, 3);
    max_value = max(max_value, 5);
    max_default = max(max_default, 7);

    # Print header using format method
    if show_all {
        fmt_str = "{:<" + str(max_group) + "}  {:<" + str(max_key) + "}  {:<" + str(
            max_value
        ) + "}  {:<" + str(max_default) + "}  {}";
        header = fmt_str.format("Group", "Key", "Value", "Default", "Set");
        separator = "-" * len(header);
    } else {
        fmt_str = "{:<" + str(max_group) + "}  {:<" + str(max_key) + "}  {:<" + str(
            max_value
        ) + "}";
        header = fmt_str.format("Group", "Key", "Value");
        separator = "-" * len(header);
    }

    print(header);
    print(separator);

    # Print settings
    for grp in sorted(settings.keys()) {
        grp_settings = settings[grp];
        for key in sorted(grp_settings.keys()) {
            data = grp_settings[key];
            value_str = _format_value(data["value"]);
            default_str = _format_value(data["default"]);
            is_set = data["is_set"];

            if show_all {
                set_marker = "*" if is_set else "";
                fmt_str = "{:<" + str(max_group) + "}  {:<" + str(max_key) + "}  {:<" + str(
                    max_value
                ) + "}  {:<" + str(max_default) + "}  {}";
                print(fmt_str.format(grp, key, value_str, default_str, set_marker));
            } else {
                fmt_str = "{:<" + str(max_group) + "}  {:<" + str(max_key) + "}  {:<" + str(
                    max_value
                ) + "}";
                print(fmt_str.format(grp, key, value_str));
            }
        }
    }

    if show_all {
        print();
        print("* = explicitly set in jac.toml");
    }
}

"""Output settings as JSON."""
def _output_json(settings: dict) -> None {
    import json;

    # Convert to simpler structure for JSON output
    output: dict = {};
    for (grp, grp_settings) in settings.items() {
        output[grp] = {};
        for (key, data) in grp_settings.items() {
            output[grp][key] = {
                "value": data["value"],
                "default": data["default"],
                "is_set": data["is_set"]
            };
        }
    }
    print(json.dumps(output, indent=2, default=str));
}

"""Output settings as TOML (only explicitly set values)."""
def _output_toml(settings: dict, show_all: bool) -> None {
    lines: list[str] = [];

    for grp in sorted(settings.keys()) {
        grp_settings = settings[grp];
        group_lines: list[str] = [];

        for key in sorted(grp_settings.keys()) {
            data = grp_settings[key];
            # For TOML output, only show set values (or all if show_all)
            if show_all or data["is_set"] {
                value = data["value"];
                toml_value = _to_toml_value(value);
                group_lines.append(f"{key} = {toml_value}");
            }
        }

        if group_lines {
            lines.append(f"[{grp}]");
            lines.extend(group_lines);
            lines.append("");
        }
    }

    if lines {
        print("\n".join(lines));
    } else {
        print("# No settings explicitly set");
    }
}

"""Format a value for table display."""
def _format_value(value: object) -> str {
    if value is None {
        return "null";
    } elif isinstance(value, bool) {
        return "true" if value else "false";
    } elif isinstance(value, str) {
        if value == "" {
            return '""';
        }
        return f'"{value}"' if len(value) < 20 else f'"{value[:17]}..."';
    } elif isinstance(value, list) {
        if not value {
            return "[]";
        }
        return f"[{len(value)} items]";
    } elif isinstance(value, dict) {
        if not value {
            return "{}";
        }
        return f"{{{len(value)} keys}}";
    } else {
        return str(value);
    }
}

"""Convert a Python value to TOML representation."""
def _to_toml_value(value: object) -> str {
    if value is None {
        return '""';  # TOML doesn't have null, use empty string

    } elif isinstance(value, bool) {
        return "true" if value else "false";
    } elif isinstance(value, int) {
        return str(value);
    } elif isinstance(value, float) {
        return str(value);
    } elif isinstance(value, str) {
        escaped = value.replace("\\", "\\\\").replace('"', '\\"');
        return f'"{escaped}"';
    } elif isinstance(value, list) {
        items = [_to_toml_value(item) for item in value];
        return f"[{', '.join(items)}]";
    } elif isinstance(value, dict) {
        # For inline tables
        pairs = [f"{k} = {_to_toml_value(v)}" for (k, v) in value.items()];
        return f"{{ {', '.join(pairs)} }}";
    } else {
        return f'"{value}"';
    }
}

"""Get a specific configuration setting."""
def _config_get(config: object, key: str) -> int {
    import from jaclang.cli.console { console }
    if not key {
        console.error("Key required for 'get' action.");
        console.print("Usage: jac config get <group>.<key>", style="muted");
        console.print("Example: jac config get serve.port", style="muted");
        return 1;
    }

    if config is None {
        console.warning("No jac.toml found. Run 'jac create' to initialize a project.");
        return 1;
    }

    # Parse the key
    if '.' not in key {
        console.error("Key must be in 'group.name' format.");
        console.print("Example: jac config get serve.port", style="muted");
        return 1;
    }

    parts = key.split('.', 1);
    group_name = parts[0];
    setting_name = parts[1];

    if group_name not in CONFIG_GROUPS {
        console.error(f"Unknown group '{group_name}'.");
        console.print(f"Available groups: {', '.join(CONFIG_GROUPS)}", style="muted");
        return 1;
    }

    # Get the value
    current_values = _get_group_values(config, group_name);
    default_values = _get_group_defaults(group_name);

    if setting_name not in default_values {
        console.error(f"Unknown setting '{setting_name}' in group '{group_name}'.");
        console.print(
            f"Available settings: {', '.join(sorted(default_values.keys()))}",
            style="muted"
        );
        return 1;
    }

    value = current_values.get(setting_name, default_values.get(setting_name));
    is_set = _is_explicitly_set(config, group_name, setting_name);

    # Output the value
    print(_format_value(value).strip('"'));

    if is_set {
        console.print("  (explicitly set in jac.toml)", style="muted");
    } else {
        console.print("  (default value)", style="muted");
    }
    return 0;
}

"""Set a specific configuration setting."""
def _config_set(config: object, key: str, value: str) -> int {
    import from jaclang.project.config { JacConfig, find_project_root }
    import from jaclang.cli.console { console }

    if not key {
        console.error("Key required for 'set' action.");
        console.print("Usage: jac config set <group>.<key> <value>", style="muted");
        console.print("Example: jac config set serve.port 9000", style="muted");
        return 1;
    }

    if not value {
        console.error("Value required for 'set' action.");
        console.print("Usage: jac config set <group>.<key> <value>", style="muted");
        return 1;
    }

    # Parse the key
    if '.' not in key {
        console.error("Key must be in 'group.name' format.");
        console.print("Example: jac config set serve.port 9000", style="muted");
        return 1;
    }

    parts = key.split('.', 1);
    group_name = parts[0];
    setting_name = parts[1];

    if group_name not in CONFIG_GROUPS {
        console.error(f"Unknown group '{group_name}'.");
        console.print(f"Available groups: {', '.join(CONFIG_GROUPS)}", style="muted");
        return 1;
    }

    # Get or create config
    if config is None {
        result = find_project_root();
        if result {
            (proj_root, cfg_path) = result;
            config = JacConfig.load(cfg_path);
        } else {
            console.error(
                "No jac.toml found. Run 'jac create' to initialize a project."
            );
            return 1;
        }
    }

    # Validate setting exists
    default_values = _get_group_defaults(group_name);
    if setting_name not in default_values {
        console.error(f"Unknown setting '{setting_name}' in group '{group_name}'.");
        console.print(
            f"Available settings: {', '.join(sorted(default_values.keys()))}",
            style="muted"
        );
        return 1;
    }

    # Convert value to appropriate type
    default_val = default_values[setting_name];
    typed_value = _parse_value(value, type(default_val));

    # Get the group object and set the value
    group_obj = getattr(config, _get_group_attr(group_name), None);
    if group_obj is None {
        console.error(f"Could not access group '{group_name}'.");
        return 1;
    }

    # Set the value
    setattr(group_obj, setting_name, typed_value);

    # Update raw_data for persistence
    if not config?._raw_data or config._raw_data is None {
        config._raw_data = {};
    }

    toml_section = group_name;  # Group names match TOML section names
    if toml_section not in config._raw_data {
        config._raw_data[toml_section] = {};
    }
    config._raw_data[toml_section][setting_name] = typed_value;

    # Save the configuration
    _save_config_with_setting(config, group_name, setting_name, typed_value);

    console.success(f"Set {key} = {_format_value(typed_value)}");
    return 0;
}

"""Unset (remove) a specific configuration setting."""
def _config_unset(config: object, key: str) -> int {
    import from jaclang.project.config { find_project_root }
    import from jaclang.cli.console { console }

    if not key {
        console.error("Key required for 'unset' action.");
        console.print("Usage: jac config unset <group>.<key>", style="muted");
        console.print("Example: jac config unset serve.port", style="muted");
        return 1;
    }

    if config is None {
        console.error("No jac.toml found. Nothing to unset.");
        return 1;
    }

    # Parse the key
    if '.' not in key {
        console.error("Key must be in 'group.name' format.");
        console.print("Example: jac config unset serve.port", style="muted");
        return 1;
    }

    parts = key.split('.', 1);
    group_name = parts[0];
    setting_name = parts[1];

    if group_name not in CONFIG_GROUPS {
        console.error(f"Unknown group '{group_name}'.");
        console.print(f"Available groups: {', '.join(CONFIG_GROUPS)}", style="muted");
        return 1;
    }

    # Check if setting is currently set
    if not _is_explicitly_set(config, group_name, setting_name) {
        console.info(f"Setting '{key}' is not explicitly set (already using default).");
        return 0;
    }

    # Remove from raw_data
    toml_section = group_name;  # Group names match TOML section names
    if config?._raw_data and config._raw_data and toml_section in config._raw_data {
        if setting_name in config._raw_data[toml_section] {
            del config._raw_data[toml_section][setting_name] ;
            # Remove empty section
            if not config._raw_data[toml_section] {
                del config._raw_data[toml_section] ;
            }
        }
    }

    # Reset to default value in config object
    default_values = _get_group_defaults(group_name);
    default_val = default_values.get(setting_name);

    group_obj = getattr(config, _get_group_attr(group_name), None);
    if group_obj {
        setattr(group_obj, setting_name, default_val);
    }

    # Save updated configuration
    _save_config_without_setting(config, group_name, setting_name);

    console.success(f"Unset {key} (reverted to default: {_format_value(default_val)})");
    return 0;
}

"""Parse a string value into the appropriate type."""
def _parse_value(value: str, target_type: type) -> object {
    import from jaclang.cli.console { console }
    # Handle boolean
    if target_type == bool {
        lower = value.lower();
        if lower in ('true', '1', 'yes', 'on') {
            return True;
        } elif lower in ('false', '0', 'no', 'off') {
            return False;
        } else {
            console.error(f"Invalid boolean value '{value}'. Use true/false.");
            return False;
        }
    }

    # Handle integer
    if target_type == int {
        try {
            return int(value);
        } except ValueError {
            console.error(f"Invalid integer value '{value}'.");
            return 0;
        }
    }

    # Handle float
    if target_type == float {
        try {
            return float(value);
        } except ValueError {
            console.error(f"Invalid float value '{value}'.");
            return 0.0;
        }
    }

    # Handle list (simple comma-separated)
    if target_type == list
    or (target_type?.__origin__ and target_type.__origin__ == list) {
        if value == '[]' or value == '' {
            return [];
        }
        # Remove brackets if present
        if value.startswith('[') and value.endswith(']') {
            value = value[1:-1];
        }
        return [
            item.strip().strip('"\'')
            for item in value.split(',')
            if item.strip()
        ];
    }

    # Default to string
    return value;
}

"""Save config with a new or updated setting."""
def _save_config_with_setting(
    config: object, group_name: str, setting_name: str, value: object
) -> None {
    import tomllib;
    import from jaclang.cli.console { console }

    if config.toml_path is None {
        console.error("No toml_path set, cannot save configuration.");
        return;
    }

    # Load existing file content
    if config.toml_path.exists() {
        with open(config.toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } else {
        doc = {};
    }

    # Map group name to TOML section
    toml_section = group_name;  # Group names match TOML section names

    # Ensure section exists
    if toml_section not in doc {
        doc[toml_section] = {};
    }

    # Set the value
    doc[toml_section][setting_name] = value;

    # Write back
    _write_toml(config.toml_path, doc);
}

"""Save config without a specific setting (remove it)."""
def _save_config_without_setting(
    config: object, group_name: str, setting_name: str
) -> None {
    import tomllib;
    import from jaclang.cli.console { console }

    if config.toml_path is None {
        console.error("No toml_path set, cannot save configuration.");
        return;
    }

    if not config.toml_path.exists() {
        return;  # Nothing to remove

    }

    # Load existing file content
    with open(config.toml_path, "rb") as f {
        doc = tomllib.load(f);
    }

    # Map group name to TOML section
    toml_section = group_name;  # Group names match TOML section names

    # Remove the setting if it exists
    if toml_section in doc and setting_name in doc[toml_section] {
        del doc[toml_section][setting_name] ;
        # Remove empty section
        if not doc[toml_section] {
            del doc[toml_section] ;
        }
    }

    # Write back
    _write_toml(config.toml_path, doc);
}

"""Write a dictionary to a TOML file."""
def _write_toml(path: object, data: dict) -> None {
    lines: list[str] = [];
    tables: list[tuple[str, dict]] = [];

    # First pass: write top-level key-value pairs
    for (key, value) in data.items() {
        if isinstance(value, dict) {
            tables.append((key, value));
        } else {
            lines.append(f"{_quote_toml_key(key)} = {_to_toml_value(value)}");
        }
    }

    # Add blank line before tables if we had values
    if lines and tables {
        lines.append("");
    }

    # Second pass: write tables
    for (table_name, table_data) in tables {
        if not table_data {
            continue;  # Skip empty tables
        }

        # Check for nested tables
        simple_values: list[tuple[str, object]] = [];
        nested_tables: list[tuple[str, dict]] = [];

        for (k, v) in table_data.items() {
            if isinstance(v, dict) {
                nested_tables.append((k, v));
            } else {
                simple_values.append((k, v));
            }
        }

        # Write simple values under table header
        if simple_values {
            lines.append(f"[{table_name}]");
            for (k, v) in simple_values {
                lines.append(f"{_quote_toml_key(k)} = {_to_toml_value(v)}");
            }
            lines.append("");
        }

        # Write nested tables
        for (nested_name, nested_data) in nested_tables {
            lines.append(f"[{table_name}.{nested_name}]");
            for (k, v) in nested_data.items() {
                if not isinstance(v, dict) {
                    lines.append(f"{_quote_toml_key(k)} = {_to_toml_value(v)}");
                }
            }
            lines.append("");
        }
    }

    with open(path, "w") as f {
        f.write("\n".join(lines));
    }
}

"""Quote a TOML key if necessary."""
def _quote_toml_key(key: str) -> str {
    import re;
    # Bare keys can only contain A-Za-z0-9_-
    if re.match(r'^[A-Za-z0-9_-]+$', key) {
        return key;
    }
    escaped = key.replace("\\", "\\\\").replace('"', '\\"');
    return f'"{escaped}"';
}
