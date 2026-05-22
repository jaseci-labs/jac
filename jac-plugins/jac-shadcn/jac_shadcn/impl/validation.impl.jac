"""Implementation of jac-shadcn theme parameter validation."""

import difflib;
import from jac_shadcn.shadcn_handler { _fetch_json }


"""Mapping from field name to hardcoded fallback list."""
def _hardcoded_for(field: str) -> list {
    if field == "style" {
        return KNOWN_STYLES;
    }
    if field == "baseColor" {
        return KNOWN_BASE_COLORS;
    }
    if field == "theme" {
        return KNOWN_THEMES;
    }
    if field == "font" {
        return KNOWN_FONTS;
    }
    if field == "radius" {
        return KNOWN_RADII;
    }
    if field == "menuAccent" {
        return KNOWN_MENU_ACCENTS;
    }
    return [];
}


"""Translate field name to the key the registry's /options response uses."""
def _options_key(field: str) -> str {
    if field == "baseColor" {
        return "base_colors";
    }
    if field == "menuAccent" {
        return "menu_accents";
    }
    # styles/themes/fonts/radii are pluralized straightforwardly.
    return field + "s" if not field.endswith("s") else field;
}


impl _load_registry_options(registry_url: str) -> any {
    if registry_url in _options_cache {
        cached = _options_cache[registry_url];
        return cached if cached else None;
    }
    # silent=True: the /options endpoint is opt-in on the registry side;
    # we don't want a "404 not found" message every time someone validates
    # against a registry that hasn't shipped /options yet.
    try {
        data = _fetch_json(registry_url + "/options", silent=True);
    } except Exception {
        data = None;
    }
    # Cache the result (including None) so we don't re-hit on every field.
    _options_cache[registry_url] = data if data else {};
    return data if data else None;
}


impl _valid_values(field: str, registry_url: str) -> list {
    opts = _load_registry_options(registry_url);
    if opts {
        key = _options_key(field);
        if key in opts {
            entries = opts[key];
            # Registry may return either list[str] or list[dict] with a "name" key;
            # accept both.
            names: list = [];
            for entry in entries {
                if isinstance(entry, str) {
                    names.append(entry);
                } elif isinstance(entry, dict) and "name" in entry {
                    names.append(str(entry["name"]));
                }
            }
            if names {
                return names;
            }
        }
    }
    return _hardcoded_for(field);
}


impl validate_field(field: str, value: any, registry_url: str) -> tuple {
    if value is None or value == "" {
        return (True, []);
    }
    val_str = str(value);
    valid = _valid_values(field, registry_url);
    if val_str in valid {
        return (True, []);
    }
    suggestions = difflib.get_close_matches(val_str, valid, n=3, cutoff=0.5);
    return (False, suggestions);
}


impl validate_theme_params(params: dict, registry_url: str) -> list {
    errors: list = [];
    fields = ["style", "baseColor", "theme", "font", "radius", "menuAccent"];
    for field in fields {
        value = params.get(field);
        (ok, suggestions) = validate_field(field, value, registry_url);
        if not ok {
            msg = "Invalid " + field + " '" + str(value) + "'";
            if suggestions {
                msg = msg + " (did you mean: " + ", ".join(suggestions) + "?)";
            } else {
                valid = _valid_values(field, registry_url);
                msg = msg + ". Valid: " + ", ".join(sorted(valid));
            }
            errors.append(msg);
        }
    }
    return errors;
}
