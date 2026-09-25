import hashlib;
import json;
import os;

glob STAGE0_PIN_ENV: str = "JAC_STAGE0_PIN",
     STAGE0_ROOT_ENV: str = "JAC_STAGE0_ROOT",
     STAGE0_STRICT_ENV: str = "JAC_STAGE0_STRICT",
     STAGE0_PIN_REL: str = "bootstrap/stage0.json",
     STAGE0_PIN_FORMAT: int = 1,
     STAGE0_SELF: str = "self",
     STAGE0_PIN_FIELDS: tuple[str, ...] = (
         "commit",
         "jaclang_tree",
         "compiler_digest",
         "native_tree",
         "typeshed_pin"
     ),
     _STAGE0_OBJECT_FIELDS: tuple[str, ...] = ("commit", "jaclang_tree", "native_tree");

obj Stage0Pin {
    has commit: str = "",
        jaclang_tree: str = "",
        compiler_digest: str = "",
        native_tree: str = "",
        typeshed_pin: str = "";

    def is_self -> bool {
        return not self.commit;
    }

    def to_dict -> dict[str, object] {
        if self.is_self() {
            return {"stage0": STAGE0_SELF};
        }
        return {
            "format": STAGE0_PIN_FORMAT,
            "commit": self.commit,
            "jaclang_tree": self.jaclang_tree,
            "compiler_digest": self.compiler_digest,
            "native_tree": self.native_tree,
            "typeshed_pin": self.typeshed_pin
        };
    }
}

class Stage0PinError(ValueError) {}

def _is_object_name(value: str) -> bool {
    return len(value) in (40, 64) and all(c in "0123456789abcdef" for c in value);
}

def parse_stage0_pin(data: object) -> Stage0Pin {
    if not isinstance(data, dict) {
        raise Stage0PinError("a stage-0 pin is a JSON object");
    }
    if "stage0" in data {
        if data.get("stage0") != STAGE0_SELF or len(data) != 1 {
            raise Stage0PinError(
                f'a stage-0 pin names no commit only as {{"stage0": "{STAGE0_SELF}"}}'
            );
        }
        return Stage0Pin();
    }
    fmt = data.get("format");
    if not isinstance(fmt, int) or fmt != STAGE0_PIN_FORMAT {
        raise Stage0PinError(
            f"stage-0 pin format {fmt!r} is not format {STAGE0_PIN_FORMAT}"
        );
    }
    values: dict[str, str] = {};
    for field in STAGE0_PIN_FIELDS {
        value = data.get(field);
        if not isinstance(value, str) or not value.strip() {
            raise Stage0PinError(f"stage-0 pin field {field!r} is missing or empty");
        }
        values[field] = value.strip();
    }
    for field in _STAGE0_OBJECT_FIELDS {
        if not _is_object_name(values[field]) {
            raise Stage0PinError(
                f"stage-0 pin field {field!r} is not a full git object name"
            );
        }
    }
    return Stage0Pin(
        commit=values["commit"],
        jaclang_tree=values["jaclang_tree"],
        compiler_digest=values["compiler_digest"],
        native_tree=values["native_tree"],
        typeshed_pin=values["typeshed_pin"]
    );
}

def stage0_source_dir -> str {
    explicit = os.environ.get(STAGE0_ROOT_ENV, "").strip();
    if explicit {
        return os.path.realpath(explicit);
    }
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    return os.path.dirname(os.path.realpath(jaclang_pkg_root()));
}

def stage0_pin_path -> str {
    explicit = os.environ.get(STAGE0_PIN_ENV, "").strip();
    if explicit {
        return os.path.abspath(explicit);
    }
    return os.path.join(stage0_source_dir(), *STAGE0_PIN_REL.split("/"));
}

def read_stage0_pin(path: str = "") -> Stage0Pin {
    pin_path = path or stage0_pin_path();
    if not os.path.isfile(pin_path) {
        return Stage0Pin();
    }
    try {
        with open(pin_path, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
    } except ValueError as e {
        raise Stage0PinError(f"{pin_path} is not JSON: {e}");
    }
    return parse_stage0_pin(data);
}

def write_stage0_pin(pin: Stage0Pin, path: str) {
    with open(path, "w", encoding="utf-8") as f {
        f.write(json.dumps(pin.to_dict(), indent=1, sort_keys=True) + "\n");
    }
}

def stage0_strict -> bool {
    return os.environ.get(STAGE0_STRICT_ENV, "").strip().lower()
        in ("1", "true", "yes");
}

def _contract_file_sha(path: str) -> str {
    try {
        with open(path, "rb") as f {
            return hashlib.sha256(f.read()).hexdigest();
        }
    } except OSError {
        return "missing";
    }
}

def abi_contract_digest(pkg_root: str) -> str {
    import from jaclang.compiler.native_scope { KERNEL_ABI_CONTRACT_REL }
    h = hashlib.sha256();
    for rel in KERNEL_ABI_CONTRACT_REL {
        h.update(rel.encode("utf-8"));
        h.update(
            _contract_file_sha(os.path.join(pkg_root, *rel.split("/"))).encode("utf-8")
        );
    }
    return h.hexdigest();
}

def abi_contract_differences(pkg_root: str, other_root: str) -> list[str] {
    import from jaclang.compiler.native_scope { KERNEL_ABI_CONTRACT_REL }
    return [
        rel
        for rel in KERNEL_ABI_CONTRACT_REL
        if _contract_file_sha(os.path.join(pkg_root, *rel.split("/")))
            != _contract_file_sha(os.path.join(other_root, *rel.split("/")))
    ];
}

def stage0_sidecar_matches(sidecar: dict[str, object]) -> bool {
    record = sidecar.get("stage0");
    if not isinstance(record, dict) {
        return False;
    }
    try {
        pin = read_stage0_pin();
    } except (Stage0PinError, OSError) {
        return False;
    }
    if pin.is_self()
        or str(record.get("commit", "")) != pin.commit
        or str(record.get("digest", "")) != pin.compiler_digest {
        return False;
    }
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ABI_VERSION }
    abi = sidecar.get("abi");
    if not isinstance(abi, int) or abi != NATIVE_ABI_VERSION {
        return False;
    }
    import from jaclang.compiler.kernel_target { target_pkg_root }
    return str(sidecar.get("abi_contract", ""))
        == abi_contract_digest(target_pkg_root());
}
