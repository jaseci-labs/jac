"""Implementation of `jac shadcn` action dispatcher."""

import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import from jac_shadcn.shadcn_handler {
    add_shadcn_components,
    remove_shadcn_components,
    init_shadcn_theme,
    upgrade_shadcn_components,
    list_shadcn_components,
    prune_orphan_deps,
    _read_shadcn_config,
}
import from jac_shadcn.validation { validate_theme_params }

glob _VALID_ACTIONS: list = ["init", "add", "remove", "list", "upgrade", "prune"];

glob _THEME_DEFAULTS: dict = {
         "style": "nova",
         "baseColor": "neutral",
         "theme": "neutral",
         "font": "figtree",
         "radius": "default",
         "menuAccent": "subtle",

     };


"""Resolve the project config or print an actionable error. Returns None on
failure; callers should return code 1."""
def _require_config() -> any {
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found in the current directory.",
            hint="cd into a Jac project, or run 'jac create <name>' first."
        );
        return None;
    }
    return config;
}


"""Three-level fallback: CLI flag > [jac-shadcn] in jac.toml > hardcoded
default. Returns the fully resolved theme params dict."""
def _resolve_theme_params(
    config: any,
    style: str,
    base_color: str,
    theme: str,
    font: str,
    radius: str,
    menu_accent: str
) -> dict {
    existing = _read_shadcn_config(config) or {};
    flags: dict = {
        "style": style,
        "baseColor": base_color,
        "theme": theme,
        "font": font,
        "radius": radius,
        "menuAccent": menu_accent,

    };
    resolved: dict = {};
    for (k, v) in flags.items() {
        if v {
            resolved[k] = v;
        } elif k in existing and existing[k] {
            resolved[k] = str(existing[k]);
        } else {
            resolved[k] = _THEME_DEFAULTS[k];
        }
    }
    return resolved;
}


"""Look up the registry URL the way the handler will -- existing config
takes precedence, fall back to public default."""
def _resolve_registry(config: any) -> str {
    existing = _read_shadcn_config(config) or {};
    return str(existing.get("registry", "https://jac-shadcn.jaseci.org"));
}


impl shadcn(
    action: str = "list",
    packages: list = [],
    style: str = "",
    base_color: str = "",
    theme: str = "",
    font: str = "",
    radius: str = "",
    menu_accent: str = "",
    keep_deps: bool = False,
    installed_only: bool = False,
    all: bool = False,
    bare: bool = False
) -> int {
    if action not in _VALID_ACTIONS {
        console.error(
            "Unknown action '" + action + "'",
            hint="Valid actions: " + ", ".join(_VALID_ACTIONS)
        );
        return 1;
    }

    if action == "init" {
        config = _require_config();
        if config is None {
            return 1;
        }
        if all and bare {
            console.error(
                "--all and --bare are mutually exclusive",
                hint="Pick one: --all installs every component; --bare installs none."
            );
            return 1;
        }
        install_set = "essential";
        if all {
            install_set = "all";
        } elif bare {
            install_set = "bare";
        }
        params = _resolve_theme_params(
            config, style, base_color, theme, font, radius, menu_accent
        );
        registry_url = _resolve_registry(config);
        errors = validate_theme_params(params, registry_url);
        if errors {
            for err in errors {
                console.error(err);
            }
            console.print(
                "Hint: jac shadcn list --installed-only shows what you have today; "
                "the customizer at " + registry_url + " has the full picker.",
                style="muted"
            );
            return 1;
        }
        try {
            return 0
                if init_shadcn_theme(
                    config,
                    style=params["style"],
                    base_color=params["baseColor"],
                    theme=params["theme"],
                    font=params["font"],
                    radius=params["radius"],
                    menu_accent=params["menuAccent"],
                    install_set=install_set
                )
                else 1;
        } except Exception as e {
            console.error("Failed to initialize theme: " + str(e));
            return 1;
        }
    }

    if action == "add" {
        config = _require_config();
        if config is None {
            return 1;
        }
        if not packages {
            console.error(
                "No components specified",
                hint="Usage: jac shadcn add button card dialog"
            );
            return 1;
        }
        try {
            return 0 if add_shadcn_components(config, packages) else 1;
        } except Exception as e {
            console.error("Failed to add components: " + str(e));
            return 1;
        }
    }

    if action == "remove" {
        config = _require_config();
        if config is None {
            return 1;
        }
        if not packages {
            console.error(
                "No components specified", hint="Usage: jac shadcn remove button"
            );
            return 1;
        }
        try {
            return 0
                if remove_shadcn_components(config, packages, keep_deps=keep_deps)
                else 1;
        } except Exception as e {
            console.error("Failed to remove components: " + str(e));
            return 1;
        }
    }

    if action == "list" {
        config = _require_config();
        if config is None {
            return 1;
        }
        try {
            return 0
                if list_shadcn_components(config, installed_only=installed_only)
                else 1;
        } except Exception as e {
            console.error("Failed to list components: " + str(e));
            return 1;
        }
    }

    if action == "upgrade" {
        config = _require_config();
        if config is None {
            return 1;
        }
        # Validate only the params the user actually passed (so empty flags
        # aren't treated as bogus values to reject).
        registry_url = _resolve_registry(config);
        explicit: dict = {};
        if style {
            explicit["style"] = style;
        }
        if base_color {
            explicit["baseColor"] = base_color;
        }
        if theme {
            explicit["theme"] = theme;
        }
        if font {
            explicit["font"] = font;
        }
        if radius {
            explicit["radius"] = radius;
        }
        if menu_accent {
            explicit["menuAccent"] = menu_accent;
        }
        if explicit {
            errors = validate_theme_params(explicit, registry_url);
            if errors {
                for err in errors {
                    console.error(err);
                }
                return 1;
            }
        }
        try {
            return 0
                if upgrade_shadcn_components(
                    config,
                    list(packages),
                    style=style or None,
                    base_color=base_color or None,
                    theme=theme or None,
                    font=font or None,
                    radius=radius or None,
                    menu_accent=menu_accent or None
                )
                else 1;
        } except Exception as e {
            console.error("Failed to upgrade components: " + str(e));
            return 1;
        }
    }

    if action == "prune" {
        config = _require_config();
        if config is None {
            return 1;
        }
        try {
            return 0 if prune_orphan_deps(config) else 1;
        } except Exception as e {
            console.error("Failed to prune deps: " + str(e));
            return 1;
        }
    }

    # Unreachable: validated against _VALID_ACTIONS above.
    return 1;
}
