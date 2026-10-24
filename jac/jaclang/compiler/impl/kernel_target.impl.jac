impl KernelTarget.to_dict -> dict[str, object] {
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

impl KernelTarget.to_json -> str {
    return json.dumps(self.to_dict(), sort_keys=True);
}

impl KernelTarget.module_path(module: str) -> str {
    rel = module.split(".", 1)[1] if "." in module else module;
    return os.path.join(self.root, rel.replace(".", os.sep) + ".jac");
}

impl KernelTarget.root_module_path -> str {
    return self.module_path(self.root_module);
}

impl KernelTarget.is_native_only(rel: str) -> bool {
    return _rel_under(rel, self.native_only_rel);
}

impl KernelTarget.is_native_lowered(rel: str) -> bool {
    return _rel_under(rel, self.native_lowered_rel);
}

impl _rel_under(rel: str, entries: list[str]) -> bool {
    p = rel.replace(os.sep, "/");
    for e in entries {
        if p == e or p.startswith(e + "/") {
            return True;
        }
    }
    return False;
}

impl _str_list(value: object) -> list[str] {
    if not isinstance(value, list) {
        return [];
    }
    return [str(v) for v in value];
}

impl kernel_target_from_dict(data: dict[str, object]) -> (KernelTarget | None) {
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

impl read_kernel_target(path: str) -> (KernelTarget | None) {
    with open(path, "rb") as f {
        raw = f.read();
    }
    data = json.loads(raw.decode("utf-8"));
    if not isinstance(data, dict) {
        return None;
    }
    return kernel_target_from_dict(data);
}

impl with_link_mode(spec: KernelTarget, link_mode: str) -> KernelTarget {
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

impl write_kernel_target(spec: KernelTarget, path: str) {
    with open(path, "wb") as f {
        f.write(spec.to_json().encode("utf-8"));
    }
}

impl set_kernel_target(spec: (KernelTarget | None)) -> (KernelTarget | None) {
    prev = _TARGET[0] if _TARGET else None;
    _TARGET.clear();
    if spec is not None {
        _TARGET.append(spec);
    }
    _GENERATION[0] = _GENERATION[0] + 1;
    return prev;
}

impl active_kernel_target -> (KernelTarget | None) {
    return _TARGET[0] if _TARGET else None;
}

impl kernel_target_active -> bool {
    return active_kernel_target() is not None;
}

impl kernel_target_generation -> int {
    return _GENERATION[0];
}

impl target_pkg_root -> str {
    spec = active_kernel_target();
    if spec is not None {
        return spec.root;
    }
    import from jaclang.compiler.frontend.host { package_root }
    return package_root();
}

impl _target_root_real -> str {
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

impl is_target_package_path(path: str) -> bool {
    if not path {
        return False;
    }
    try {
        return os.path.realpath(path).startswith(_target_root_real());
    } except (OSError, ValueError) {
        return False;
    }
}

impl target_package_rel(path: str) -> (str | None) {
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
