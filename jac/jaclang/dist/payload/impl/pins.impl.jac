import json;
import sys;

impl load_pins(path: str | None = None) -> Pins {
    p = PINS_FILE if path is None else path;
    try {
        with open(p, "r", encoding="utf-8") as f {
            raw = json.load(f);
        }
    } except (OSError, ValueError) as e {
        die(f"pins: cannot read {p}: {e}");
    }
    loaded = Pins(python=str(raw["pbs"]["python"]));
    py_minor(loaded.python);
    return loaded;
}

impl pins -> Pins {
    cached = _pins_cache.get("pins");
    if cached is None {
        cached = load_pins();
        _pins_cache["pins"] = cached;
    }
    return cached;
}

impl py_minor(python: str) -> str {
    parts = python.split(".");
    if len(parts) != 3 or not all(part.isdigit() for part in parts) {
        die(
            f"pins: Python version must be a MAJOR.MINOR.PATCH release, got '{python}'"
        );
    }
    return parts[0] + "." + parts[1];
}

impl py_ver -> str {
    return py_minor(pins().python);
}

impl host_py_minor -> str {
    return f"{sys.version_info[0]}.{sys.version_info[1]}";
}
