import json;
import sys;

import from jaclang.payload.fsutil { die }

impl load_pins(path: str | None = None) -> Pins {
    p = PINS_FILE if path is None else path;
    try {
        with open(p, "r", encoding="utf-8") as f {
            raw = json.load(f);
        }
    } except (OSError, ValueError) as e {
        die(f"pins: cannot read {p}: {e}");
    }
    pbs_raw = raw["pbs"];
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
        pbs=PbsPins(
            tag=str(pbs_raw["tag"]),
            python=str(pbs_raw["python"]),
            flavor=str(pbs_raw["flavor"]),
            base=str(pbs_raw["base"])
        ),
        llvm=LlvmPins(
            version=str(llvm_raw["version"]),
            slice_base=str(llvm_raw["slice_base"]),
            slices=slices
        )
    );
    py_minor(loaded.pbs.python);
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
        die(f"pins: pbs.python must be a MAJOR.MINOR.PATCH release, got '{python}'");
    }
    return parts[0] + "." + parts[1];
}

impl py_ver -> str {
    return py_minor(pins().pbs.python);
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
