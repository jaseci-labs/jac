import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core.helpers { read_toml_with_encoding }

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
         "environment"
     ];

impl config(
    action: str = 'show',
    key: str = '',
    value: str = '',
    group: str = '',
    output: str = 'table'
) -> int {
    import json;
    import from jaclang.project.config { get_config, JacConfig }

    if action == 'path' {
        _config_path();
        return 0;
    }

    if action == 'groups' {
        _config_groups();
        return 0;
    }

    config = get_config();

    if group and group not in CONFIG_GROUPS {
        console.error(f"Unknown group '{group}'.");
        console.print(f"Available groups: {', '.join(CONFIG_GROUPS)}", style="muted");
        return 1;
    }

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
        console.error(f"Unknown action '{action}'.");
        console.print(
            "Available actions: list, show, get, set, unset, path, groups",
            style="muted"
        );
        return 1;
    }
    return 0;
}

def _config_file_label(path: Path, active_profile: str) -> str {
    fname = path.name;
    if fname == "jac.toml" {
        return " (base)";
    }
    if fname == "jac.local.toml" {
        return " (local)";
    }
    if active_profile {
        return f" (profile: {active_profile})";
    }
    return "";
}

def _config_path {
    import from jaclang.project.config { get_config, find_project_root }

    config = get_config();
    if config and config.toml_path {
        console.print(f"Project root: {config.project_root}", style="muted");
        if config.active_profile {
            console.print(f"Active profile: {config.active_profile}", style="info");
        }
        if config.config_files and len(config.config_files) > 1 {
            console.print(
                f"\nLoaded config files (lowest to highest priority):", style="info"
            );
            for (i, path) in enumerate(config.config_files) {
                label = _config_file_label(path, config.active_profile);
                console.print(f"  {i + 1}. {path}{label}");
            }
        } else {
            console.print(f"Config file: {config.toml_path}", style="info");
        }
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

def _config_groups {
    console.print("\nAvailable configuration groups:\n", style="info");
    group_descriptions = {
        "project": "Project metadata (name, version, description, authors)",
        "run": "Run command defaults (session, main, cache)",
        "build": "Build command defaults (typecheck, dir)",
        "test": "Test command defaults (directory, filter, verbose, fail_fast)",
        "serve": "Serve command defaults (port, session, main, cl_route_prefix)",
        "format": "Format command defaults (outfile, fix)",
        "check": "Check command defaults (print_errs)",
        "dot": "Dot/graph visualization defaults (depth, traverse, format)",
        "cache": "Cache settings (enabled, dir)",
        "environment": "Environment profile settings (default_profile)"
    };
    for grp in CONFIG_GROUPS {
        desc = group_descriptions.get(grp, "");
        console.print("  {:<12} {}".format(grp, desc));
    }
}

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
        "environment": EnvironmentConfig()
    };

    default_obj = defaults_map.get(group_name);
    if default_obj is None {
        return {};
    }

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

def _get_group_attr(group_name: str) -> str {
    return group_name;
}

def _get_group_values(config: object, group_name: str) -> dict {
    attr_name = _get_group_attr(group_name);
    group_obj = getattr(config, attr_name, None);
    if group_obj is None {
        return {};
    }

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

def _is_explicitly_set(config: object, group_name: str, key: str) -> bool {
    if not config?._raw_data or config._raw_data is None {
        return False;
    }

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

def _config_list(config: object, group: str, output: str, show_all: bool) -> None {
    import json;

    if config is None {
        console.warning("No jac.toml found. Run 'jac create' to initialize a project.");
        return;
    }

    groups_to_show = [group] if group else CONFIG_GROUPS;

    all_settings: dict = {};

    for grp in groups_to_show {
        defaults = _get_group_defaults(grp);
        current = _get_group_values(config, grp);

        group_settings: dict = {};
        for (key, default_val) in defaults.items() {
            current_val = current.get(key, default_val);
            is_set = _is_explicitly_set(config, grp, key);

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

    if output == 'json' {
        _output_json(all_settings);
    } elif output == 'toml' {
        _output_toml(all_settings, show_all);
    } else {
        _output_table(all_settings, show_all);
    }
}

def _output_table(settings: dict, show_all: bool) -> None {
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

    max_group = max(max_group, 5);
    max_key = max(max_key, 3);
    max_value = max(max_value, 5);
    max_default = max(max_default, 7);

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

    console.print(header);
    console.print(separator);

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
                console.print(
                    fmt_str.format(grp, key, value_str, default_str, set_marker)
                );
            } else {
                fmt_str = "{:<" + str(max_group) + "}  {:<" + str(max_key) + "}  {:<" + str(
                    max_value
                ) + "}";
                console.print(fmt_str.format(grp, key, value_str));
            }
        }
    }

    if show_all {
        console.print();
        console.print("* = explicitly set in jac.toml");
    }
}

def _output_json(settings: dict) {
    import json;

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
    console.print(json.dumps(output, indent=2, default=str));
}

def _output_toml(settings: dict, show_all: bool) {
    import from jaclang.project.config { toml_value }
    lines: list[str] = [];

    for grp in sorted(settings.keys()) {
        grp_settings = settings[grp];
        group_lines: list[str] = [];

        for key in sorted(grp_settings.keys()) {
            data = grp_settings[key];

            if show_all or data["is_set"] {
                value = data["value"];
                rendered = toml_value(value);
                group_lines.append(f"{key} = {rendered}");
            }
        }

        if group_lines {
            lines.append(f"[{grp}]");
            lines.extend(group_lines);
            lines.append("");
        }
    }

    if lines {
        console.print("\n".join(lines));
    } else {
        console.print("# No settings explicitly set");
    }
}

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

def _config_get(config: object, key: str) -> int {
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

    console.print(_format_value(value).strip('"'));

    if is_set {
        console.print("  (explicitly set in jac.toml)", style="muted");
    } else {
        console.print("  (default value)", style="muted");
    }
    return 0;
}

def _config_set(config: object, key: str, value: str) -> int {
    import from jaclang.project.config { JacConfig, find_project_root }

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

    default_values = _get_group_defaults(group_name);
    if setting_name not in default_values {
        console.error(f"Unknown setting '{setting_name}' in group '{group_name}'.");
        console.print(
            f"Available settings: {', '.join(sorted(default_values.keys()))}",
            style="muted"
        );
        return 1;
    }

    default_val = default_values[setting_name];
    typed_value = _parse_value(value, type(default_val));

    group_obj = getattr(config, _get_group_attr(group_name), None);
    if group_obj is None {
        console.error(f"Could not access group '{group_name}'.");
        return 1;
    }

    setattr(group_obj, setting_name, typed_value);

    if not config?._raw_data or config._raw_data is None {
        config._raw_data = {};
    }

    toml_section = group_name;
    if toml_section not in config._raw_data {
        config._raw_data[toml_section] = {};
    }
    config._raw_data[toml_section][setting_name] = typed_value;

    _save_config_with_setting(config, group_name, setting_name, typed_value);

    console.success(f"Set {key} = {_format_value(typed_value)}");
    return 0;
}

def _config_unset(config: object, key: str) -> int {
    import from jaclang.project.config { find_project_root }

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

    if not _is_explicitly_set(config, group_name, setting_name) {
        console.info(f"Setting '{key}' is not explicitly set (already using default).");
        return 0;
    }

    toml_section = group_name;
    if config?._raw_data and config._raw_data and toml_section in config._raw_data {
        if setting_name in config._raw_data[toml_section] {
            del config._raw_data[toml_section][setting_name];

            if not config._raw_data[toml_section] {
                del config._raw_data[toml_section];
            }
        }
    }

    default_values = _get_group_defaults(group_name);
    default_val = default_values.get(setting_name);

    group_obj = getattr(config, _get_group_attr(group_name), None);
    if group_obj {
        setattr(group_obj, setting_name, default_val);
    }

    _save_config_without_setting(config, group_name, setting_name);

    console.success(f"Unset {key} (reverted to default: {_format_value(default_val)})");
    return 0;
}

def _parse_value(value: str, target_type: type) -> object {
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

    if target_type == int {
        try {
            return int(value);
        } except ValueError {
            console.error(f"Invalid integer value '{value}'.");
            return 0;
        }
    }

    if target_type == float {
        try {
            return float(value);
        } except ValueError {
            console.error(f"Invalid float value '{value}'.");
            return 0.0;
        }
    }

    if target_type == list
    or (target_type?.__origin__ and target_type.__origin__ == list) {
        if value == '[]' or value == '' {
            return [];
        }

        if value.startswith('[') and value.endswith(']') {
            value = value[1:-1];
        }
        return [
            item.strip().strip('"\'')
            for item in value.split(',')
            if item.strip()
        ];
    }

    return value;
}

def _save_config_with_setting(
    config: object, group_name: str, setting_name: str, value: object
) -> None {
    if config.toml_path is None {
        console.error("No toml_path set, cannot save configuration.");
        return;
    }

    if config.toml_path.exists() {
        doc = read_toml_with_encoding(str(config.toml_path));
    } else {
        doc = {};
    }

    toml_section = group_name;

    if toml_section not in doc {
        doc[toml_section] = {};
    }

    doc[toml_section][setting_name] = value;

    config.persist_doc(doc);
}

def _save_config_without_setting(
    config: object, group_name: str, setting_name: str
) -> None {
    if config.toml_path is None {
        console.error("No toml_path set, cannot save configuration.");
        return;
    }

    if not config.toml_path.exists() {
        return;
    }

    doc = read_toml_with_encoding(str(config.toml_path));

    toml_section = group_name;

    if toml_section in doc and setting_name in doc[toml_section] {
        del doc[toml_section][setting_name];

        if not doc[toml_section] {
            del doc[toml_section];
        }
    }

    config.persist_doc(doc);
}
