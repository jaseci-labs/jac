import from pathlib { Path }

impl run_shadcn_add(packages: list) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.shadcn_handler { add_shadcn_components }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create --use jac-shadcn' first."
        );
        return 1;
    }

    if not packages {
        console.error(
            "No components specified",
            hint="Usage: jac install --shadcn button card dialog"
        );
        return 1;
    }

    try {
        result = add_shadcn_components(config, packages);
        return 0 if result else 1;
    } except Exception as e {
        console.error("Failed to add components: " + str(e));
        return 1;
    }
}

impl run_shadcn_remove(packages: list) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.shadcn_handler { remove_shadcn_components }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create --use jac-shadcn' first."
        );
        return 1;
    }

    if not packages {
        console.error(
            "No components specified", hint="Usage: jac remove --shadcn button"
        );
        return 1;
    }

    try {
        result = remove_shadcn_components(config, packages);
        return 0 if result else 1;
    } except Exception as e {
        console.error("Failed to remove components: " + str(e));
        return 1;
    }
}

impl stash_create_theme(overrides: dict) -> None {
    _PENDING_THEME.clear();
    _PENDING_THEME.update(overrides);
}

impl _shadcn_post_create(project_path: any, project_name: str) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.theme_handler {
        normalize_shadcn_config,
        materialize_themed_starter
    }

    try {
        shadcn_config = normalize_shadcn_config(dict(_PENDING_THEME));
        materialize_themed_starter(project_path, project_name, shadcn_config);
    } except Exception as e {
        console.warning("Could not apply shadcn theme: " + str(e));
    } finally {
        _PENDING_THEME.clear();
    }
}

impl _build_shadcn_template_info -> dict[str, any] | None {
    import from jaclang.project.template_loader { load_template_from_directory }
    import from jaclang.cli.console { console }

    module_dir = Path(__file__).parent.parent;
    template_dir = module_dir / "templates" / "jac-shadcn";

    if not template_dir.exists() {
        import from importlib.resources { files }
        try {
            package_root = str(files("jaclang.cli.shadcn"));
            template_dir = Path(package_root) / "templates" / "jac-shadcn";
        } except (TypeError, ModuleNotFoundError) as e {
            console.warning(f"Failed to locate jac-shadcn template directory: {e}");
            return None;
        }
    }

    if not template_dir.exists() or not template_dir.is_dir() {
        return None;
    }

    try {
        template = load_template_from_directory(template_dir);
        info = template.to_dict();

        info["kind"] = "web-app";
        info["is_default_for_kind"] = False;

        info["post_create"] = _shadcn_post_create;
        return info;
    } except Exception as e {
        console.warning(f"Could not load jac-shadcn template: {e}");
        return None;
    }
}

impl register_project_template -> dict[str, any] | None {
    return _build_shadcn_template_info();
}
