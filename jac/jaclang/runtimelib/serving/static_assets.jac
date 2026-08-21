import logging;
import from pathlib { Path }
import from jaclang.runtimelib.serving.datatypes { Response, FileResponse }

glob _logger = logging.getLogger(__name__);


obj AssetRoot {
    has url_prefix: str,
        local_dir: str,
        source: str,
        resolved_dir: Path;
}


def _resolve_root(local_dir: str) -> Path {
    p = Path(local_dir);
    try {
        return p.resolve();
    } except (OSError, ValueError) {
        _logger.warning(
            f"could not resolve asset root {local_dir!r}, using unresolved path"
        );
        return p;
    }
}


def asset_root_table(
    project_root: Path, client_dist: Path, mounts: list[dict]
) -> list[AssetRoot] {
    table: list[AssetRoot] = [];

    for m in mounts {
        prefix = str(m.get("url_prefix", "")).strip("/");
        local = str(m.get("local_path", ""));
        if prefix and local {
            table.append(
                AssetRoot(
                    url_prefix=prefix,
                    local_dir=local,
                    source="mount",
                    resolved_dir=_resolve_root(local),
                )
            );
        } else {
            _logger.debug(f"static mount missing url_prefix/local_path, dropped: {m}");
        }
    }

    dist = str(client_dist);
    assets = str(project_root / "assets");
    public = str(project_root / "public");
    dist_resolved = _resolve_root(dist);
    assets_resolved = _resolve_root(assets);
    public_resolved = _resolve_root(public);

    table.append(
        AssetRoot(
            url_prefix="static",
            local_dir=dist,
            source="dist",
            resolved_dir=dist_resolved
        )
    );
    table.append(
        AssetRoot(
            url_prefix="static/assets",
            local_dir=assets,
            source="assets",
            resolved_dir=assets_resolved,
        )
    );
    table.append(
        AssetRoot(
            url_prefix="", local_dir=dist, source="dist", resolved_dir=dist_resolved
        )
    );
    table.append(
        AssetRoot(
            url_prefix="",
            local_dir=public,
            source="public",
            resolved_dir=public_resolved
        )
    );
    table.append(
        AssetRoot(
            url_prefix="",
            local_dir=assets,
            source="assets",
            resolved_dir=assets_resolved
        )
    );

    return table;
}


def _remainder(url_path: str, prefix: str) -> (str | None) {
    p = prefix.strip("/");
    if p == "" {
        rel = url_path.lstrip("/");
        if rel.startswith("static/") {
            return None;
        }
        return rel;
    }
    marker = "/" + p;
    if url_path == marker {
        return "";
    }
    if url_path.startswith(marker + "/") {
        return url_path[len(marker) + 1:];
    }
    return None;
}


def resolve_asset(
    table: list[AssetRoot], url_path: str
) -> (tuple[Path, AssetRoot] | None) {
    mount_claimed = False;
    for r in table {
        if mount_claimed and r.url_prefix == "" {
            continue;
        }
        rel = _remainder(url_path, r.url_prefix);
        if rel is None or rel == "" {
            continue;
        }
        if r.source == "mount" {
            mount_claimed = True;
        }
        base = r.resolved_dir;
        target = base / rel;
        try {
            resolved = target.resolve();
            if not resolved.is_relative_to(base) {
                continue;
            }
        } except (OSError, ValueError) {
            continue;
        }
        if resolved.is_file() {
            return (resolved, r);
        }
    }
    return None;
}


def asset_response(target: Path) -> Response {
    cacheable = target.suffix not in (".html", "");
    policy = "public, max-age=3600, must-revalidate" if cacheable else "no-cache";
    headers = {"Cache-Control": policy};
    if cacheable {
        import from email.utils { formatdate }
        st = target.stat();
        headers["Last-Modified"] = formatdate(st.st_mtime, usegmt=True);
        headers["ETag"] = f'"{st.st_mtime_ns:x}-{st.st_size:x}"';
    }
    return FileResponse(path=str(target), headers=headers);
}
