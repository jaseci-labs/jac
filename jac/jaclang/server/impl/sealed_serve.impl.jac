impl _image_module_keys(img_root: str) -> set {
    mf = os.path.join(img_root, "_precompiled", MANIFEST_NAME);
    try {
        mtime = os.path.getmtime(mf);
    } except OSError {
        return set();
    }
    cached = _MODULE_KEYS_CACHE.get(img_root);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    keys = set();
    try {
        data: dict[str, any] = json.loads(Path(mf).read_text(encoding="utf-8"));
        if isinstance(data, dict) {
            modules = data.get("modules");
            if isinstance(modules, dict) {
                keys = set(modules.keys());
            }
            `entry = data.get("entry");
            if isinstance(`entry, dict) and isinstance(`entry.get("path"), str) {
                keys.add(`entry["path"]);
            }
        }
    } except Exception {
        keys = set();
    }
    _MODULE_KEYS_CACHE[img_root] = (mtime, keys);
    return keys;
}

impl _image_key(abs_path: str, img_root: str) -> str {
    rel = os.path.relpath(abs_path, img_root).replace(os.sep, "/");
    return rel[:-3] + ".jac" if rel.endswith(".py") else rel;
}

impl _image_roots(abs_path: str) -> Iterator[tuple[str, bool]] {
    nested = False;
    d = os.path.dirname(abs_path);
    while True {
        if os.path.isfile(os.path.join(d, "_precompiled", MANIFEST_NAME)) {
            yield (d, nested);
        }
        if os.path.isfile(os.path.join(d, "jac.toml")) {
            nested = True;
        }
        parent = os.path.dirname(d);
        if parent == d {
            break;
        }
        d = parent;
    }
}

impl sealed_root_for(path: str) -> (str | None) {
    abs_path = os.path.normpath(os.path.abspath(path));
    for (img_root, _) in _image_roots(abs_path) {
        if _image_key(abs_path, img_root) in _image_module_keys(img_root) {
            return img_root;
        }
    }
    return None;
}

impl unlisted_image_root(path: str) -> (str | None) {
    abs_path = os.path.normpath(os.path.abspath(path));
    nearest = next(_image_roots(abs_path), None);
    if nearest is None {
        return None;
    }
    (img_root, nested) = nearest;
    if nested or _image_key(abs_path, img_root) in _image_module_keys(img_root) {
        return None;
    }
    return img_root;
}

impl serve_manifest_stamp -> dict[str, (int | str)] {
    try {
        jac_version = resolve_cli_version();
    } except Exception {
        jac_version = "0.0.0";
    }
    return {'format': SERVE_MANIFEST_FORMAT, 'jaclang_version': jac_version};
}

impl read_serve_manifest(img_root: str) -> dict[str, any] {
    mf = Path(img_root) / SERVE_MANIFEST_REL;
    if not mf.is_file() {
        raise RuntimeError(
            f'Sealed application has no serving manifest: {mf}; '
            'rebuild the bundle so the seal step writes it'
        );
    }
    data = json.loads(mf.read_text(encoding="utf-8"));
    meta = data if isinstance(data, dict) else {};
    if meta.get('format') != SERVE_MANIFEST_FORMAT {
        built_by = meta.get('jaclang_version');
        origin = f'jac {built_by}' if built_by else 'an older jac';
        runtime = serve_manifest_stamp()['jaclang_version'];
        raise RuntimeError(
            f'Sealed application at {img_root} was built by {origin} '
            f'(serve manifest format {meta.get("format", "unstamped")}); '
            f'this runtime (jac {runtime}) reads format {SERVE_MANIFEST_FORMAT}. '
            'Rebuild the bundle with the jac that will run it.'
        );
    }
    return data;
}

impl serve_manifest_for(path: str) -> (dict[str, any] | None) {
    prepared = prepared_manifest(path);
    if prepared is not None {
        return prepared;
    }
    img_root = sealed_root_for(path);
    if img_root is None
        or not os.path.isfile(os.path.join(img_root, SERVE_MANIFEST_REL)) {
        return None;
    }
    relative = os.path.relpath(path, img_root).replace(os.sep, '/');
    return read_serve_manifest(img_root)['module_manifests'].get(relative);
}

impl native_lib_suffix -> str {
    import sys;
    if sys.platform.startswith("win") {
        return ".dll";
    }
    if sys.platform == "darwin" {
        return ".dylib";
    }
    return ".so";
}

impl native_lib_name(stem: str) -> str {
    return stem + native_lib_suffix();
}

impl interop_record_path(lib_output: str) -> Path {
    return Path(str(lib_output) + ".interop.json");
}

impl client_dist_for(path: str) -> (Path | None) {
    prepared = application_for(path);
    if prepared is not None and prepared.client_dist and not prepared.dev {
        return Path(prepared.client_dist);
    }
    img_root = sealed_root_for(path);
    if img_root is None {
        return None;
    }
    dist = Path(img_root) / CLIENT_DIST_REL;
    if dist.is_dir() and any(dist.`glob("client.*.js")) {
        return dist;
    }
    return None;
}
