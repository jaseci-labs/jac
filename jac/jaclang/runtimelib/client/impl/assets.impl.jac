import from email.utils { formatdate, parsedate_to_datetime }
import from urllib.parse { unquote }

impl AssetPolicy.from_config(
    base_path: (Path | None) = None, dev: bool = False
) -> AssetPolicy {
    import from jaclang.cli.console { console }
    import from jaclang.project.config { get_config }
    base = base_path if base_path is not None else resolve_project_root();
    config = get_config(base_path) if base_path is not None else get_config();
    client_cfg = config.get_plugin_config('client') if config else None;
    raw: dict[str, any] = _as_dict(client_cfg.get('assets') if client_cfg else None);
    extensions: set[str] = set(ASSET_MEDIA_TYPES.keys()) | configured_extra_extensions();
    extensions -= _as_ext_set(_as_dict(raw.get('extensions')).get('remove'));
    if raw.get('custom_extensions') {
        console.warning(
            "[client.assets] custom_extensions is deprecated and is now additive; " + "use extensions.add = [...] instead. It no longer replaces the " + "built-in extension table."
        );
    }
    roots: list[AssetRoot] = [];
    for entry in _as_list(raw.get('roots')) {
        spec: dict[str, any] = _as_dict(entry);
        declared = str(spec.get('path', ''));
        if not declared {
            continue;
        }
        candidate = confined_path(base, declared);
        if candidate is None {
            console.warning(
                f"[client.assets] ignoring root outside the project: {declared}"
            );
            continue;
        }
        roots.append(
            AssetRoot(
                path=candidate,
                mode=str(spec.get('mode', AssetRootMode.SOURCE_ASSET.value)),
                flatten=bool(spec.get('flatten', False))
            )
        );
    }
    if not roots {
        roots = default_asset_roots(base);
    }
    reserved: list[str] = list(RESERVED_URL_PREFIXES);
    cl_prefix: str = config.serve.cl_route_prefix if config else 'cl';
    if cl_prefix {
        reserved.append(f"{cl_prefix}/");
    }
    max_age: any = raw.get('immutable_max_age', 31536000);
    return AssetPolicy(
        roots=roots,
        extensions=extensions,
        reserved_prefixes=reserved,
        dev=dev,
        immutable_max_age=int(max_age) if isinstance(max_age, int) else 31536000
    );
}

impl AssetResolution.headers -> dict[str, str] {
    out = {'Cache-Control': self.cache_control};
    if self.etag {
        out['ETag'] = self.etag;
    }
    if self.last_modified {
        out['Last-Modified'] = self.last_modified;
    }
    return out;
}

impl AssetResolver.build(
    dev: bool = False, base_path: (Path | None) = None
) -> AssetResolver {
    return AssetResolver(policy=AssetPolicy.from_config(base_path, dev));
}

impl AssetResolver.resolve(url_path: str, query: str = "") -> AssetResolution {
    rel = unquote(url_path).lstrip('/');
    under_static = rel.startswith('static/');
    if under_static {
        rel = rel[7:];
    } elif is_reserved_url(rel, self.policy.reserved_prefixes) {
        return AssetResolution(outcome=AssetOutcome.NOT_AN_ASSET.value);
    }
    if not rel {
        return AssetResolution(outcome=AssetOutcome.NOT_AN_ASSET.value);
    }
    segments = rel.split('/');
    for segment in segments {
        if not segment
        or segment.startswith('.')
        or ('\\' in segment)
        or ('\x00' in segment) {
            return AssetResolution(
                outcome=AssetOutcome.FORBIDDEN.value, status=403, message='Forbidden'
            );
        }
    }
    suffix = Path(rel).suffix.lower();
    if suffix in SOURCE_ONLY_EXTENSIONS {
        return AssetResolution(
            outcome=AssetOutcome.FORBIDDEN.value, status=403, message='Forbidden'
        );
    }
    found = self._locate(rel);
    if found is not None {
        return self._describe(found, has_cache_bust(query));
    }
    if under_static or (suffix in self.policy.extensions) {
        return AssetResolution(
            outcome=AssetOutcome.NOT_FOUND.value,
            status=404,
            message=f"Asset not found: {rel}"
        );
    }
    return AssetResolution(outcome=AssetOutcome.NOT_AN_ASSET.value);
}

impl AssetResolver._locate(rel: str) -> (Path | None) {
    file_name = Path(rel).name;
    for asset_root in self.policy.roots {
        candidate = confined_path(asset_root.path, rel);
        if candidate is not None and candidate.is_file() {
            return candidate;
        }
        if asset_root.flatten and (file_name != rel) {
            flat = confined_path(asset_root.path, file_name);
            if flat is not None and flat.is_file() {
                return flat;
            }
        }
    }
    return None;
}

impl AssetResolver._describe(file_path: Path, cache_bust: bool) -> AssetResolution {
    try {
        stat = file_path.stat();
    } except OSError {
        return AssetResolution(
            outcome=AssetOutcome.NOT_FOUND.value, status=404, message='Asset not found'
        );
    }
    immutable = cache_bust or is_content_hashed(file_path.name);
    if immutable {
        cache_control = f"public, max-age={self.policy.immutable_max_age}, immutable";
    } elif self.policy.dev {
        cache_control = 'no-store';
    } else {
        cache_control = 'no-cache';
    }
    return AssetResolution(
        outcome=AssetOutcome.SERVED.value,
        status=200,
        path=file_path,
        media_type=asset_media_type(file_path),
        cache_control=cache_control,
        etag=f'"{stat.st_mtime_ns:x}-{stat.st_size:x}"',
        last_modified=formatdate(stat.st_mtime, usegmt=True)
    );
}

impl AssetResolution.read_bytes -> bytes {
    if self.path is None {
        return b'';
    }
    return self.path.read_bytes();
}

impl AssetResolution.is_fresh(
    if_none_match: (str | None) = None, if_modified_since: (str | None) = None
) -> bool {
    if not self.is_served() {
        return False;
    }
    if if_none_match {
        if if_none_match.strip() == '*' {
            return True;
        }
        for raw_tag in if_none_match.split(',') {
            tag = raw_tag.strip();
            if tag.startswith('W/') {
                tag = tag[2:];
            }
            if tag == self.etag {
                return True;
            }
        }
        return False;
    }
    if if_modified_since and self.path is not None {
        try {
            since = parsedate_to_datetime(if_modified_since);
        } except (TypeError, ValueError) {
            return False;
        }
        if since is None {
            return False;
        }
        return int(self.path.stat().st_mtime) <= int(since.timestamp());
    }
    return False;
}
