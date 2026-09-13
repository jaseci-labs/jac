import json;
import sys;

import from jaclang.dist.payload.fsutil { die }

impl load_pins(path: str | None = None) -> Pins {
    p = PINS_FILE if path is None else path;
    try {
        with open(p, "r", encoding="utf-8") as f {
            raw = json.load(f);
        }
    } except (OSError, ValueError) as e {
        die(f"pins: cannot read {p}: {e}");
    }
    python_pins = os.path.join(os.path.dirname(p), "python-sources.json");
    if not os.path.exists(python_pins) {
        python_pins = os.path.join(os.path.dirname(p), "python", "sources.json");
    }
    try {
        with open(python_pins, "r", encoding="utf-8") as f {
            python_raw = json.load(f);
        }
    } except (OSError, ValueError) as e {
        die(f"pins: cannot read {python_pins}: {e}");
    }
    llvm_raw = raw["llvm"];
    slices: dict[str, LlvmSlice] = {};
    for (key, s) in llvm_raw["slices"].items() {
        slices[key] = LlvmSlice(
            dirname=str(s["dirname"]),
            triple=str(s["triple"]),
            manifest_sha256=str(s["manifest_sha256"]),
            zip_size=int(s["zip_size"]),
            upstream=bool(s["upstream"])
        );
    }
    loaded = Pins(
        python=str(python_raw["cpython"]["version"]),
        llvm=LlvmPins(
            version=str(llvm_raw["version"]),
            slice_base=str(llvm_raw["slice_base"]),
            slices=slices
        )
    );
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

impl llvm_release(osarch: str) -> LlvmSlice | None {
    return pins().llvm.slices.get(osarch);
}

impl is_libcxx(rel: LlvmSlice) -> bool {
    return rel.triple.endswith("-libcxx");
}
