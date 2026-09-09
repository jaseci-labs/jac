import os;

glob OSP_CORE_PARTS: list[str] = [
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac"
     ],
     FMT_KERNEL_PARTS: list[str] = ["compiler/backends/common/fmt_kernel.jac"],
     REGION_KERNEL_PARTS: list[str] = ["runtime/region_native.jac"],
     REGION_KERNEL_ABI: dict[str, tuple[bool, int]] = {
         "__jac_region_new": (True, 0),
         "__jac_region_alloc": (True, 2),
         "__jac_region_log_dtor": (False, 3),
         "__jac_region_drop": (False, 1),
         "__jac_region_partition": (True, 1),
         "__jac_region_enter": (False, 1),
         "__jac_region_leave": (False, 0),
         "__jac_region_unwind": (False, 1),
         "__jac_region_current": (True, 0),
         "__jac_region_depth": (True, 0),
         "__jac_region_of": (True, 1),
         "__jac_region_owns": (True, 1)
     };

def _jaclang_dir -> str {
    import jaclang;
    return os.path.dirname(str(jaclang.__file__));
}

def kernel_unit_owner(path: str, module_name: str = "") -> str {
    """Canonical native unit supplying a directly imported runtime source.""";
    import from jaclang.compiler.frontend.codeinfo { resolve_native_module }
    resolved = os.path.realpath(path);
    for part in OSP_CORE_PARTS {
        if module_name == "jaclang." + part[:-4].replace("/", ".") {
            return "osp_kernel";
        }
        if resolved == os.path.realpath(os.path.join(_jaclang_dir(), part)) {
            return "osp_kernel";
        }
        if os.path.basename(resolved) == os.path.basename(part) {
            (_, source) = resolve_native_module(
                "jaclang." + part[:-4].replace("/", "."), os.path.dirname(resolved)
            );
            if source is not None and resolved == os.path.realpath(source) {
                return "osp_kernel";
            }
        }
    }
    return "";
}

def _units_dir -> str {
    import from jaclang.jac0core.cache_paths { get_jir_cache_dir }
    d = os.path.join(str(get_jir_cache_dir()), "kernel_units");
    os.makedirs(d, exist_ok=True);
    return d;
}

def unit_source(parts: list[str]) -> str {
    texts: list[str] = [];
    base = _jaclang_dir();
    for part in parts {
        with open(os.path.join(base, part.replace("/", os.sep)), "r") as f {
            texts.append(f.read());
        }
    }
    return "\n\n".join(texts);
}

def _region_layout_facts -> dict[str, int] {
    import from jaclang.compiler.frontend.codeinfo {
        HDR_ALLOC_ID_OFF,
        HDR_DTOR_OFF,
        HDR_MAGIC,
        HDR_MAGIC_SHIFT_BASE,
        HDR_RC_OFF,
        HDR_TAG_OFF,
        HDR_TOTAL,
        RC_SENTINEL
    }
    return {
        "HDR_ALLOC_ID_OFF": HDR_ALLOC_ID_OFF,
        "HDR_TAG_OFF": HDR_TAG_OFF,
        "HDR_RC_OFF": HDR_RC_OFF,
        "HDR_DTOR_OFF": HDR_DTOR_OFF,
        "HDR_TOTAL": HDR_TOTAL,
        "HDR_MAGIC": HDR_MAGIC,
        "HDR_MAGIC_SHIFT_BASE": HDR_MAGIC_SHIFT_BASE,
        "ARENA_MAGIC_SHIFT_BASE": (HDR_MAGIC + 1) * 4294967296,
        "RC_SENTINEL": RC_SENTINEL
    };
}

def verify_region_layout(source: str) {
    import re;
    facts = _region_layout_facts();
    for (name, want) in facts.items() {
        m = re.search(rf"\b{name}: int = (-?\d+)", source);
        if m is None {
            raise RuntimeError(
                f"region kernel unit does not declare {name}; the header layout "
                f"is defined once in compiler/frontend/codeinfo.jac and restated "
                f"in runtime/region_native.jac"
            );
        }
        if int(m.group(1)) != want {
            raise RuntimeError(
                f"region kernel unit declares {name} = {m.group(1)} but "
                f"compiler/frontend/codeinfo.jac says {want}; update "
                f"runtime/region_native.jac to match"
            );
        }
    }
}

def _atomic_write(path: str, text: str) {
    tmp = f"{path}.{os.getpid()}.tmp";
    with open(tmp, "w") as f {
        f.write(text);
    }
    os.replace(tmp, path);
}

glob _RETIRED_UNITS: set[str] = set();

def _retire_superseded_artifacts(name: str, keep: str) {
    import glob as _g;
    import time;
    import from jaclang.compiler.driver.jir { generation_ttl_seconds }
    if name in _RETIRED_UNITS {
        return;
    }
    _RETIRED_UNITS.add(name);
    ttl = generation_ttl_seconds();
    if ttl <= 0.0 {
        return;
    }
    cutoff = time.time() - ttl;
    live = f"{name}.{keep}.";
    for path in _g.`glob(os.path.join(_units_dir(), f"{name}.*")) {
        base = os.path.basename(path);
        if base.endswith(".jac") or base.startswith(live) {
            continue;
        }
        try {
            if os.path.getmtime(path) < cutoff {
                os.remove(path);
            }
        } except OSError {}
    }
}

def kernel_unit_path(name: str, parts: list[str]) -> str {
    import hashlib;
    source = unit_source(parts);
    digest = hashlib.sha256(source.encode()).hexdigest()[:16];
    path = os.path.join(_units_dir(), f"{name}.{digest}.jac");
    if not os.path.exists(path) {
        _atomic_write(path, source);
    }
    _retire_superseded_artifacts(name, digest);
    return path;
}

def osp_core_unit_path(variant: str) -> str {
    return kernel_unit_path(f"osp_core_{variant}", OSP_CORE_PARTS);
}

def fmt_kernel_unit_path(variant: str) -> str {
    return kernel_unit_path(f"fmt_kernel_{variant}", FMT_KERNEL_PARTS);
}

def region_kernel_unit_path(variant: str) -> str {
    verify_region_layout(unit_source(REGION_KERNEL_PARTS));
    return kernel_unit_path(f"region_kernel_{variant}", REGION_KERNEL_PARTS);
}

def _artifact_key(unit_path: str, fingerprint: str) -> str {
    import hashlib;
    import from importlib.metadata { version as pkg_version }
    import from jaclang.compiler.driver.jir { running_compiler_digest }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
    h = hashlib.sha256();
    h.update(jac_ver.encode());
    h.update(running_compiler_digest().encode());
    with open(unit_path, "rb") as f {
        h.update(f.read());
    }
    h.update(fingerprint.encode());
    return h.hexdigest()[:16];
}

def unit_artifact_path(unit_path: str, kind: str, fingerprint: str) -> str {
    stem = os.path.splitext(os.path.basename(unit_path))[0];
    key = _artifact_key(unit_path, fingerprint);
    return os.path.join(_units_dir(), f"{stem}.{key}.{kind}");
}

def load_unit_artifact(unit_path: str, kind: str, fingerprint: str) -> (str | None) {
    try {
        with open(unit_artifact_path(unit_path, kind, fingerprint), "r") as f {
            return f.read();
        }
    } except Exception {
        return None;
    }
}

def store_unit_artifact(unit_path: str, kind: str, fingerprint: str, text: str) {
    import glob as _g;
    path = unit_artifact_path(unit_path, kind, fingerprint);
    stem = os.path.splitext(os.path.basename(unit_path))[0];
    for stale in _g.`glob(os.path.join(_units_dir(), f"{stem}.*.{kind}")) {
        if stale != path {
            try {
                os.remove(stale);
            } except Exception {}
        }
    }
    try {
        with open(path, "r") as f {
            if f.read() == text {
                return;
            }
        }
    } except Exception {}
    _atomic_write(path, text);
}

def es_pass_fingerprint -> str {
    import glob as _g;
    import hashlib;
    es_dir = os.path.join(_jaclang_dir(), *"compiler/backends/es".split("/"));
    h = hashlib.sha256();
    for pat in ["*.jac", os.path.join("impl", "*.jac")] {
        for p in sorted(_g.`glob(os.path.join(es_dir, pat))) {
            try {
                with open(p, "rb") as f {
                    h.update(f.read());
                }
            } except Exception {}
        }
    }
    return h.hexdigest()[:8];
}
