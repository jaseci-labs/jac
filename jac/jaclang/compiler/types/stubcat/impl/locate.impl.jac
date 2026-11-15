impl catalog_origin -> (CatalogOrigin | None) {
    return _ORIGIN[0] if _ORIGIN else None;
}

impl _opened(path: str, offset: int, length: int) {
    _OPENED_FROM.clear();
    _OPENED_FROM.append(CatalogOrigin(path=path, offset=offset, length=length));
}

impl jaclang_pkg_dir -> str {
    import jaclang;
    return os.path.dirname(os.path.realpath(str(jaclang.__file__)));
}

impl typeshed_stdlib_dir(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "vendor", "typeshed", "stdlib");
}

impl jac_internal_stub_dir(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "compiler", "types");
}

impl _digest_files(pkg_dir: str) -> list[str] {
    rels: list[str] = [];
    for root_entry in TYPE_SYSTEM_ROOTS {
        target = os.path.join(pkg_dir, *root_entry.split("/"));
        if os.path.isfile(target) {
            rels.append(root_entry);
            continue;
        }
        if not os.path.isdir(target) {
            continue;
        }
        for (walk_dir, dirs, files) in os.walk(target) {
            dirs[:] = sorted(
                d
                for d in dirs
                if not d.startswith(".")
                    and d not in ("__pycache__", "tests", "fixtures")
            );
            for name in sorted(files) {
                if not name.endswith(DIGEST_SUFFIXES) or ".test." in name {
                    continue;
                }
                rel = os.path.relpath(os.path.join(walk_dir, name), pkg_dir);
                rels.append(rel.replace(os.sep, "/"));
            }
        }
    }
    return sorted(rels);
}

impl type_system_digest(pkg_dir: (str | None) = None) -> str {
    if _DIGEST_CACHE {
        return _DIGEST_CACHE[0];
    }
    pkg = pkg_dir or jaclang_pkg_dir();
    h = hashlib.sha256();
    for rel in _digest_files(pkg) {
        h.update(rel.encode());
        try {
            with open(os.path.join(pkg, *rel.split("/")), "rb") as f {
                h.update(hashlib.sha256(f.read()).digest());
            }
        } except OSError {
            h.update(b"?");
        }
    }
    digest = h.hexdigest();
    _DIGEST_CACHE.append(digest);
    return digest;
}

impl catalog_key(pkg_dir: (str | None) = None) -> str {
    h = hashlib.sha256();
    h.update(f"stubcat-format={FORMAT_VERSION}".encode());
    h.update(f"|python={sys.version_info.major}.{sys.version_info.minor}".encode());
    h.update(f"|platform={sys.platform}".encode());
    h.update(("|types=" + type_system_digest(pkg_dir)).encode());
    return h.hexdigest()[:32];
}

impl bundled_catalog_path(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "_precompiled", "stubcat.bin");
}

impl dev_catalog_path(pkg_dir: str) -> str {
    return str(bucket("jir-stubcat").path() / (catalog_key(pkg_dir) + ".bin"));
}

impl _open_file(path: str, pkg_dir: str) -> StubCatalog | None {
    try {
        found = open_catalog_file(path, pkg_dir);
        if found is not None {
            _opened(path, 0, len(found.buf));
        }
        return found;
    } except Exception as e {
        sys.stderr.write(f"jac: ignoring unreadable stub catalog {path}: {e}\n");
        return None;
    }
}

impl _open_region(
    exe: str, offset: int, length: int, pkg_dir: str
) -> StubCatalog | None {
    try {
        found = open_catalog_region(exe, offset, length, pkg_dir);
        if found is not None {
            _opened(exe, offset, length);
        }
        return found;
    } except Exception as e {
        sys.stderr.write(f"jac: ignoring unreadable embedded stub catalog: {e}\n");
        return None;
    }
}

impl _region_probe(exe: str, source: Source, pkg: str, check_key: bool) -> Probe {
    region = stubcat_region(exe);
    if region is None {
        return Probe.missing();
    }
    cat = _open_region(exe, region.off, region.length, pkg);
    if cat is None {
        return Probe.stale(["the embedded catalog is unreadable"]);
    }
    if check_key and cat.key() != catalog_key(pkg) {
        return Probe.stale(["the type system changed since this catalog was built"]);
    }
    return Probe.hit(
        source, exe, {"catalog": cat, "offset": region.off, "length": region.length}
    );
}

impl _file_probe(path: str, source: Source, pkg: str, check_key: bool) -> Probe {
    if not os.path.isfile(path) {
        return Probe.missing();
    }
    cat = _open_file(path, pkg);
    if cat is None {
        return Probe.stale(["the catalog is unreadable"]);
    }
    if check_key and cat.key() != catalog_key(pkg) {
        return Probe.stale(["the type system changed since this catalog was built"]);
    }
    return Probe.hit(
        source, path, {"catalog": cat, "offset": 0, "length": len(cat.buf)}
    );
}

impl StubcatArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }

    pkg = jaclang_pkg_dir();
    embedded = _region_probe(running_executable(), Source.SEALED, pkg, False);
    if embedded.found is not None {
        return embedded;
    }
    return _file_probe(bundled_catalog_path(pkg), Source.SEALED, pkg, False);
}

impl StubcatArtifact.probe_checkout -> Probe {
    pkg = jaclang_pkg_dir();
    found = _file_probe(dev_catalog_path(pkg), Source.CHECKOUT, pkg, False);
    if found.found is not None {
        import from pathlib { Path }
        import from jaclang.cache.registry { bucket }
        bucket("jir-stubcat").note_hit(Path(found.found.path));
    }
    return found;
}

impl StubcatArtifact.probe_kit -> Probe {
    if kit_image() is None {
        return Probe.missing("this process runs on no kit");
    }

    pkg = jaclang_pkg_dir();
    embedded = _region_probe(running_executable(), Source.KIT, pkg, True);
    if embedded.found is not None or not embedded.absent {
        return embedded;
    }
    return _file_probe(
        kit_path(os.path.join("_precompiled", "stubcat.bin")), Source.KIT, pkg, True
    );
}

impl StubcatArtifact.checkout_path -> str {
    return dev_catalog_path(jaclang_pkg_dir());
}

impl StubcatArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    pkg = jaclang_pkg_dir();
    out = dev_catalog_path(pkg);
    log(f"  building the stub catalog into {out}");
    build_catalog(out, pkg_dir=pkg, quiet=True);
    maybe_sweep("jir-stubcat");
}

impl TypeshedArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }
    return _typeshed_probe(Source.SEALED, False);
}

impl TypeshedArtifact.probe_checkout -> Probe {
    return _typeshed_probe(Source.CHECKOUT, True);
}

impl TypeshedArtifact.checkout_path -> str {
    return typeshed_stdlib_dir(jaclang_pkg_dir());
}

impl TypeshedArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    fetch_typeshed(os.path.dirname(jaclang_pkg_dir()));
}

impl _typeshed_probe(source: Source, check_pin: bool) -> Probe {
    stdlib = typeshed_stdlib_dir(jaclang_pkg_dir());
    if not os.path.isfile(os.path.join(stdlib, "builtins.pyi")) {
        return Probe.missing();
    }
    if check_pin {
        pin = _read_trimmed(os.path.join(os.path.dirname(stdlib), "PIN"));
        stamp = _read_trimmed(os.path.join(stdlib, ".typeshed-sha"));
        if pin and stamp != pin {
            return Probe.stale([f"the typeshed PIN moved to {pin[:12]}"]);
        }
    }
    return Probe.hit(source, stdlib, {});
}

impl _read_trimmed(path: str) -> str {
    try {
        with open(path, encoding="utf-8") as f {
            return f.read().strip();
        }
    } except OSError {
        return "";
    }
}

impl _publish(cat: StubCatalog | None) -> StubCatalog | None {
    if cat is not None and not _CATALOG_CACHE {
        _CATALOG_CACHE.append(cat);
        set_active(cat);
        _ORIGIN.clear();
        _ORIGIN.extend(_OPENED_FROM);
    }
    return cat;
}

impl open_catalog -> StubCatalog | None {
    if _CATALOG_CACHE {
        return _CATALOG_CACHE[0];
    }

    if catalog_disabled() {
        return None;
    }

    found = resolve("stubcat").found;
    if found is None {
        return None;
    }
    _opened(
        found.path,
        int(found.record.get("offset", 0)),
        int(found.record.get("length", 0))
    );
    return _publish(found.record.get("catalog"));
}

impl reset_catalog_cache {
    _CATALOG_CACHE.clear();
    _DIGEST_CACHE.clear();
    _ORIGIN.clear();
    set_active(None);
}
