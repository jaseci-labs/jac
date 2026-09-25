import json;
import os;

glob KERNEL_TARGET_ENV: str = "JAC_KERNEL_TARGET",
     KERNEL_TARGET_FORMAT: int = 1;

obj KernelTarget {
    has format: int = KERNEL_TARGET_FORMAT,
        `root: str = "",
        scope_modules: list[str] = [],
        root_module: str = "",
        kernel_unit_rel: list[str] = [],
        native_lowered_rel: list[str] = [],
        native_only_rel: list[str] = [],
        link_mode: str = "";

    def to_dict -> dict[str, object] {
        return {
            "format": self.format,
            "root": self.root,
            "scope_modules": list(self.scope_modules),
            "root_module": self.root_module,
            "kernel_unit_rel": list(self.kernel_unit_rel),
            "native_lowered_rel": list(self.native_lowered_rel),
            "native_only_rel": list(self.native_only_rel),
            "link_mode": self.link_mode
        };
    }

    def to_json -> str {
        return json.dumps(self.to_dict(), sort_keys=True, indent=1);
    }

    def module_path(module: str) -> str {
        rel = module.split(".", 1)[1] if "." in module else module;
        return os.path.join(self.root, rel.replace(".", os.sep) + ".jac");
    }

    def root_module_path -> str {
        return self.module_path(self.root_module);
    }

    def is_native_only(rel: str) -> bool {
        return _rel_under(rel, self.native_only_rel);
    }

    def is_native_lowered(rel: str) -> bool {
        return _rel_under(rel, self.native_lowered_rel);
    }
}

glob _TARGET: list[KernelTarget] = [],
     _ENV_READ: list[bool] = [],
     _GENERATION: list[int] = [0],
     _ROOT_REAL: list[tuple[int, str]] = [];

def _rel_under(rel: str, entries: list[str]) -> bool {
    p = rel.replace(os.sep, "/");
    for e in entries {
        if p == e or p.startswith(e + "/") {
            return True;
        }
    }
    return False;
}

def _str_list(value: object) -> list[str] {
    if not isinstance(value, list) {
        return [];
    }
    return [str(v) for v in value];
}

def kernel_target_from_dict(data: dict[str, object]) -> (KernelTarget | None) {
    fmt = data.get("format");
    if not isinstance(fmt, int) or fmt != KERNEL_TARGET_FORMAT {
        return None;
    }
    root_dir = str(data.get("root", ""));
    root_module = str(data.get("root_module", ""));
    if not root_dir or not root_module {
        return None;
    }
    return KernelTarget(
        format=fmt,
        `root=os.path.abspath(root_dir),
        scope_modules=_str_list(data.get("scope_modules")),
        root_module=root_module,
        kernel_unit_rel=_str_list(data.get("kernel_unit_rel")),
        native_lowered_rel=_str_list(data.get("native_lowered_rel")),
        native_only_rel=_str_list(data.get("native_only_rel")),
        link_mode=str(data.get("link_mode", "") or "")
    );
}

def read_kernel_target(path: str) -> (KernelTarget | None) {
    with open(path, "r", encoding="utf-8") as f {
        data = json.load(f);
    }
    if not isinstance(data, dict) {
        return None;
    }
    return kernel_target_from_dict(data);
}

def with_link_mode(spec: KernelTarget, link_mode: str) -> KernelTarget {
    return KernelTarget(
        format=spec.format,
        `root=spec.root,
        scope_modules=list(spec.scope_modules),
        root_module=spec.root_module,
        kernel_unit_rel=list(spec.kernel_unit_rel),
        native_lowered_rel=list(spec.native_lowered_rel),
        native_only_rel=list(spec.native_only_rel),
        link_mode=link_mode
    );
}

def write_kernel_target(spec: KernelTarget, path: str) {
    with open(path, "w", encoding="utf-8") as f {
        f.write(spec.to_json());
    }
}

def set_kernel_target(spec: (KernelTarget | None)) -> (KernelTarget | None) {
    prev = _TARGET[0] if _TARGET else None;
    _TARGET.clear();
    if spec is not None {
        _TARGET.append(spec);
    }
    _ENV_READ.clear();
    _ENV_READ.append(True);
    _GENERATION[0] = _GENERATION[0] + 1;
    return prev;
}

def active_kernel_target -> (KernelTarget | None) {
    if not _ENV_READ {
        _ENV_READ.append(True);
        spec_path = os.environ.get(KERNEL_TARGET_ENV, "").strip();
        if spec_path {
            spec = read_kernel_target(spec_path);
            if spec is None {
                raise ValueError(
                    f"{KERNEL_TARGET_ENV}={spec_path} is not a format "
                    f"{KERNEL_TARGET_FORMAT} kernel target"
                );
            }
            _TARGET.clear();
            _TARGET.append(spec);
            _GENERATION[0] = _GENERATION[0] + 1;
        }
    }
    return _TARGET[0] if _TARGET else None;
}

def kernel_target_active -> bool {
    return active_kernel_target() is not None;
}

def kernel_target_generation -> int {
    active_kernel_target();
    return _GENERATION[0];
}

def target_pkg_root -> str {
    spec = active_kernel_target();
    if spec is not None {
        return spec.root;
    }
    import from jaclang.compiler.frontend.host { package_root }
    return package_root();
}

def _target_root_real -> str {
    gen = kernel_target_generation();
    if _ROOT_REAL and _ROOT_REAL[0][0] == gen {
        return _ROOT_REAL[0][1];
    }
    pkg = target_pkg_root();
    if not pkg {
        return "\x00";
    }
    real = os.path.realpath(pkg) + os.sep;
    _ROOT_REAL.clear();
    _ROOT_REAL.append((gen, real));
    return real;
}

def is_target_package_path(path: str) -> bool {
    if not path {
        return False;
    }
    try {
        return os.path.realpath(path).startswith(_target_root_real());
    } except (OSError, ValueError) {
        return False;
    }
}

def target_package_rel(path: str) -> (str | None) {
    pkg = _target_root_real();
    try {
        rp = os.path.realpath(path);
    } except (OSError, ValueError) {
        return None;
    }
    if not rp.startswith(pkg) {
        return None;
    }
    return rp[len(pkg):].replace(os.sep, "/");
}
