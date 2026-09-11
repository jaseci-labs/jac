import logging;
import from pathlib { Path }

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


def _assets_dir(project_root: Path) -> Path {
    default_dir = project_root / "assets";
    try {
        import from jaclang.client.config_loader { JacClientConfig }
        client_config = JacClientConfig(project_root);
        configured = str(client_config.get_assets_config().get('dir') or '');
        if configured {
            configured_dir = project_root / configured;
            if configured_dir.is_dir() {
                return configured_dir;
            }
        }
    } except Exception as e {
        _logger.warning(
            f"invalid [client.assets] 'dir' config, falling back to project_root/assets: {e}"
        );
    }
    return default_dir;
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
    assets = str(_assets_dir(project_root));
    public = str(project_root / "public");
    assets_resolved = _resolve_root(assets);
    public_resolved = _resolve_root(public);

    table.append(
        AssetRoot(
            url_prefix="static/assets",
            local_dir=assets,
            source="assets",
            resolved_dir=assets_resolved,
        )
    );

    if dist and dist != "." {
        dist_resolved = _resolve_root(dist);
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
                url_prefix="", local_dir=dist, source="dist", resolved_dir=dist_resolved
            )
        );
    }
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

    mount_is_static_overlay = False;
    for r in table {
        if mount_claimed and not (mount_is_static_overlay and r.url_prefix != "") {
            continue;
        }
        rel = _remainder(url_path, r.url_prefix);
        if rel is None or rel == "" {
            continue;
        }
        if r.source == "mount" {
            mount_claimed = True;
            mount_is_static_overlay = r.url_prefix == "static";
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


def mount_claims(table: list[AssetRoot], url_path: str) -> bool {
    """True when url_path falls under a static_mount's exclusive prefix --
    the same claim resolve_asset uses internally to stop falling through
    past a mount miss into the built-in web-root roots. A miss under an
    exclusive claim is a genuine 404, not a "nobody owns this" case a host
    may keep searching for elsewhere (its own asset table, the SPA shell).
    The 'static' prefix is excluded: a mount there is an additive overlay
    on the built-in /static tier (#7020), not an exclusive owner. Checks
    every mount rather than stopping at the first prefix match, so a
    broader 'static' overlay listed before a nested exclusive mount (e.g.
    'static/brand') can't mask that nested mount's own claim.""";
    for r in table {
        if r.source != "mount" {
            continue;
        }
        rel = _remainder(url_path, r.url_prefix);
        if rel is None or rel == "" {
            continue;
        }
        if r.url_prefix != "static" {
            return True;
        }
    }
    return False;
}


def asset_cache_policy(target: Path) -> str {
    cacheable = target.suffix not in (".html", "");
    return "public, max-age=3600, must-revalidate" if cacheable else "no-cache";
}
