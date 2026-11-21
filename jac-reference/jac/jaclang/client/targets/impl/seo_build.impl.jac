impl normalized_site_url(site_url: str) -> str {
    import from urllib.parse { urlparse }
    value = site_url.strip();
    parsed = urlparse(value);
    if parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or parsed.query
        or parsed.fragment
        or value.endswith(("?", "#")) {
        raise RuntimeError(
            "[client.seo] site_url must be an absolute http(s) URL with no query "
            f"or fragment, such as 'https://example.org', got '{site_url}'."
        );
    }
    return value.rstrip("/");
}

impl _is_enumerable(path: str) -> bool {
    return not any(
        segment.startswith(":") or segment == "*" for segment in path.split("/")
    );
}

impl _as_path(item: str) -> str {
    import from urllib.parse { quote }
    value = str(item).strip();
    return quote(value if value.startswith("/") else f"/{value}", safe=URL_SAFE);
}

impl _crawl_prefix(path: str) -> str {
    kept: list[str] = [];
    for segment in path.split("/") {
        if segment.startswith(":") or segment == "*" {
            return "/".join(kept) + "/";
        }
        kept.append(segment);
    }
    return path;
}

impl sitemap_paths(
    routes: list[RouteEntry], exclude: list[str], extra: list[str]
) -> list[str] {
    candidates: list[str] = [
        _as_path(route.path)
        for route in routes
        if not route.auth_required
            and not route.is_layout
            and not route.is_catch_all
            and _is_enumerable(route.path)
    ];
    if not routes {
        candidates = ["/"];
    }
    excluded = {_as_path(e) for e in exclude};
    out: list[str] = [];
    for path in candidates + [_as_path(e) for e in extra] {
        if path not in excluded and path not in out {
            out.append(path);
        }
    }
    return out;
}

impl robots_disallows(routes: list[RouteEntry], disallow: list[str]) -> list[str] {
    out: list[str] = [];
    for route in routes {
        if not route.auth_required or route.is_layout {
            continue;
        }
        path = _as_path(route.path);
        if not _is_enumerable(route.path) or route.is_catch_all {
            rules = [_as_path(_crawl_prefix(route.path))];
        } elif path == "/" {
            rules = ["/$"];
        } else {
            rules = [f"{path}$", f"{path}/"];
        }
        for rule in rules {
            if rule not in out {
                out.append(rule);
            }
        }
    }
    for item in disallow {
        path = _as_path(item);
        if path not in out {
            out.append(path);
        }
    }
    return out;
}

impl robots_blocks(rule: str, path: str) -> bool {
    import re;
    anchored = rule.endswith("$");
    body = rule[:-1] if anchored else rule;
    pattern = ".*".join(re.escape(part) for part in body.split("*"));
    return re.match(pattern + ("$" if anchored else ""), path) is not None;
}

impl crawl_rules(
    routes: list[RouteEntry], exclude: list[str], extra: list[str], disallow: list[str]
) -> tuple[list[str], list[str], list[str]] {
    own_rules = [_as_path(item) for item in disallow];
    paths = [
        path
        for path in sitemap_paths(routes, exclude, extra)
        if not any(robots_blocks(rule, path) for rule in own_rules)
    ];
    disallows = robots_disallows(routes, disallow);
    allows = [
        f"{path}$"
        for path in paths
        if any(robots_blocks(rule, path) for rule in disallows)
    ];
    return (paths, allows, disallows);
}

impl render_sitemap(site_url: str, paths: list[str]) -> str {
    import html;
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<urlset xmlns="{SITEMAP_NS}">'
    ];
    for path in paths {
        lines.append(f"  <url><loc>{html.escape(site_url + path)}</loc></url>");
    }
    lines.append("</urlset>");
    return "\n".join(lines) + "\n";
}

impl render_robots(site_url: str, disallows: list[str], asset_paths: list[str]) -> str {
    lines = ["User-agent: *"];
    if disallows {
        lines.extend([f"Allow: {asset}" for asset in asset_paths]);
        lines.extend([f"Disallow: {path}" for path in disallows]);
    } else {
        lines.append("Allow: /");
    }
    lines.append("");
    lines.append(f"Sitemap: {site_url}/{SITEMAP_PATH}");
    return "\n".join(lines) + "\n";
}

impl scan_routes(app_root: Path) -> list[RouteEntry] {
    scanner = RouteScanner(app_root, route_exports_of=resolve_route_exports);
    return scanner.scan();
}

impl clear_seo_files(dist_dir: Path) -> None {
    for name in (ROBOTS_PATH, SITEMAP_PATH) {
        (dist_dir / name).unlink(missing_ok=True);
    }
}

impl apply_seo(
    dist_dir: Path,
    seo_config: dict[str, any],
    routes: list[RouteEntry],
    public_dirs: list[Path],
    asset_paths: list[str]
) -> list[str] {
    site_url = normalized_site_url(str(seo_config.get("site_url", "")));
    sitemap_cfg = seo_config.get("sitemap", {}) or {};
    (paths, allows, disallows) = crawl_rules(
        routes,
        list(sitemap_cfg.get("exclude", [])),
        list(sitemap_cfg.get("extra", [])),
        list((seo_config.get("robots", {}) or {}).get("disallow", []))
    );
    rendered: dict[str, str] = {
        SITEMAP_PATH: render_sitemap(site_url, paths),
        ROBOTS_PATH: render_robots(site_url, disallows, asset_paths + allows)
    };
    written: list[str] = [];
    for (name, text) in rendered.items() {
        hand_written = next(
            (
                d / name
                for d in public_dirs
                if (d / name).is_file() and d.resolve() in (d / name).resolve().parents
            ),
            None
        );
        if hand_written is not None {
            console.print(
                f"  ✔ Using {hand_written} instead of a generated {name}", style="muted"
            );
            continue;
        }
        (dist_dir / name).write_text(text, encoding="utf-8");
        written.append(name);
    }
    if written {
        console.print(
            f"  ✔ Generated {', '.join(written)} for {site_url}", style="success"
        );
    }
    return written;
}
