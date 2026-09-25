import base64;
import json;
import re;
import time;
import from functools { partial }
import from urllib.parse { urlsplit }
import from jaclang.packages.index { DEFAULT_REGISTRY_NAME, registry_urls }
import from jaclang.packages.semver { SemverError, Version }
import from jaclang.project.package_scope { is_package_name }

glob HTML_LINE: re.Pattern = re.compile(r"^[\s>]*<[A-Za-z!/]"),
     IMG_SRC: re.Pattern = re.compile(
         r"<img\b[^>]*?\bsrc\s*=\s*[\"']([^\"']+)[\"']", re.I
     ),
     MD_TARGET: re.Pattern = re.compile(
         r"(!?)\[([^\]]*)\]\(\s*<?([^)\s>]*)>?([^)]*)\)"
     ),
     ANY_TARGET: re.Pattern = re.compile(r"\]\(\s*<?\s*([A-Za-z][A-Za-z0-9+.\-]*):"),
     SAFE_SCHEMES: tuple[str, ...] = ("http", "https", "mailto");

impl open_registry -> Registry {
    return Registry(
        name=DEFAULT_REGISTRY_NAME, url=registry_urls()[DEFAULT_REGISTRY_NAME]
    );
}

impl install_command(name: str, role: str) -> str {
    if role == "template" {
        return f"jac create my-app --use {name}";
    }
    return f"jac install {name}";
}

def _parsed(e: IndexEntry) -> Version | None {
    try {
        return Version.parse(e.version);
    } except SemverError {
        return None;
    }
}

impl latest_entry(entries: list[IndexEntry]) -> IndexEntry | None {
    live: list[tuple[Version, IndexEntry]] = [];
    for e in entries {
        v = _parsed(e);
        if not e.yanked and v is not None {
            live.append((v, e));
        }
    }
    stable = [
        pair
        for pair in live
        if not pair[0].is_prerelease()
    ];
    pool = stable or live;
    if not pool {
        return None;
    }
    return max(
        pool,
        key=lambda (pair: tuple[Version, IndexEntry]) -> Version { return pair[0]; }
    )[1];
}

impl version_of(e: IndexEntry) -> PackageVersion {
    return PackageVersion(
        version=e.version,
        published=e.published,
        yanked=e.yanked,
        jac_version=e.jac_version,
        deps=[f"{k} {v}" for (k, v) in sorted(e.deps.items())],
        pypi=[f"{k} {v}" for (k, v) in sorted(e.pypi.items())],
        npm=[f"{k} {v}" for (k, v) in sorted(e.npm.items())]
    );
}

impl summary_of(
    name: str, entries: list[IndexEntry], surface: dict[str, any] | None
) -> PackageSummary | None {
    latest = latest_entry(entries);
    if latest is None {
        return None;
    }
    (org, short) = name.split("/", 1);
    symbols: set[str] = set();
    for syms in (surface or {}).get("modules", {}).values() {
        symbols.update(syms.keys());
    }
    return PackageSummary(
        name=name,
        org=org,
        short=short,
        role=latest.role,
        description=latest.description,
        latest=latest.version,
        published=latest.published,
        source=latest.source,
        install=install_command(name, latest.role),
        versions=len(entries),
        exports=list(latest.exports),
        symbols=sorted(symbols)
    );
}

impl params_of(desc: dict[str, any]) -> list[ApiParam] {
    return [
        ApiParam(
            name=str(p.get("name", "")),
            kind=str(p.get("kind", "normal")),
            type=str(p.get("type", "any")),
            optional=bool(p.get("default", False)),
            value=str(p.get("value", ""))
        ) for p in desc.get("params", [])
    ];
}

impl api_modules(surface: dict[str, any] | None) -> list[ApiModule] {
    if not surface {
        return [];
    }
    docs: dict[str, str] = surface.get("module_docs", {});
    out: list[ApiModule] = [];
    for (module, syms) in sorted(surface.get("modules", {}).items()) {
        symbols: list[ApiSymbol] = [];
        for (name, d) in sorted(syms.items()) {
            members = [
                ApiMember(
                    name=mname,
                    kind=str(m.get("kind", "")),
                    type=str(m.get("type", "")),
                    doc=str(m.get("doc", "")),
                    value=str(m.get("value", "")),
                    params=params_of(m),
                    returns=str(m.get("returns", ""))
                ) for (mname, m) in sorted(d.get("members", {}).items())
            ];
            symbols.append(
                ApiSymbol(
                    name=name,
                    kind=str(d.get("kind", "")),
                    doc=str(d.get("doc", "")),
                    type=str(d.get("type", "")),
                    returns=str(d.get("returns", "")),
                    params=params_of(d),
                    bases=[str(b) for b in d.get("bases", [])],
                    members=members
                )
            );
        }
        out.append(
            ApiModule(name=module, doc=str(docs.get(module, "")), symbols=symbols)
        );
    }
    return out;
}

def _absolute(target: str, base: str) -> str {
    if target.startswith("#") {
        return target;
    }
    scheme = urlsplit(target).scheme.lower();
    if scheme in SAFE_SCHEMES {
        return target;
    }
    if scheme or target.startswith("//") {
        return "";
    }
    return base + target.removeprefix("./").lstrip("/");
}

def _rewrite_targets(line: str, blob: str, raw: str) -> str {
    def swap(m: re.Match) -> str {
        image = m.group(1) == "!";
        target = _absolute(m.group(3), raw if image else blob);
        if not target {
            return m.group(2) if not image else "";
        }
        return f"{m.group(1)}[{m.group(2)}]({target}{m.group(4)})";
    }
    return ANY_TARGET.sub(
        lambda (m: re.Match) -> str { return m.group(0)
            if m.group(1).lower() in SAFE_SCHEMES
            else "](#"; },
        MD_TARGET.sub(swap, line)
    );
}

impl safe_readme(text: str, owner: str, repo: str, branch: str) -> list[str] {
    blob = f"https://github.com/{owner}/{repo}/blob/{branch}/";
    raw = f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/";
    out: list[str] = [];
    fence = "";
    for line in text.splitlines() {
        mark = line.strip()[:3];
        if fence {
            out.append(line);
            if mark == fence {
                fence = "";
            }
            continue;
        }
        if mark in ("```", "~~~") {
            fence = mark;
            out.append(line);
            continue;
        }
        if HTML_LINE.match(line) {
            prefix = line[:len(line) - len(line.lstrip(" \t>"))];
            for src in IMG_SRC.findall(line) {
                target = _absolute(src, raw);
                if target.startswith("https://") {
                    out.append(f"{prefix}![]({target})");
                }
            }
            continue;
        }
        out.append(_rewrite_targets(line, blob, raw));
    }
    return out;
}

def _github_json(path: str) -> dict[str, any] | None {
    body = fetch(API_ROOT + path, USER_AGENT, accept_json=True);
    if body is None {
        return None;
    }
    data = json.loads(body);
    return data if isinstance(data, dict) else None;
}

impl repo_readme(source: str) -> RepoReadme {
    parsed = parse_repo_url(source);
    if parsed is None {
        return RepoReadme();
    }
    (owner, repo) = parsed;
    meta = _github_json(f"{owner}/{repo}") or {};
    found = _github_json(f"{owner}/{repo}/readme") or {};
    text = "";
    if found.get("encoding") == "base64" {
        text = base64.b64decode(str(found.get("content", ""))).decode(
            "utf-8", "replace"
        );
    }
    return RepoReadme(
        lines=safe_readme(text, owner, repo, str(meta.get("default_branch", "main"))),
        stars=int(meta.get("stargazers_count", 0) or 0),
        topics=[str(t) for t in meta.get("topics", [])]
    );
}

impl build_catalog -> PackageCatalog {
    registry = open_registry();
    packages: list[PackageSummary] = [];
    for name in registry.list_names() {
        try {
            entries = registry.entries(name);
            latest = latest_entry(entries);
            surface = registry.api(name, latest.version)
                if latest is not None and latest.role == "lib"
                else None;
            summary = summary_of(name, entries, surface);
        } except Exception as e {
            log.warning(f"packages: skipping {name}: {e}");
            continue;
        }
        if summary is not None {
            packages.append(summary);
        }
    }
    return PackageCatalog(
        ready=True,
        fetched_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        packages=packages
    );
}

impl cached(key: str, ttl: float, make: any) -> any {
    with _LOCK {
        hit = _CACHE.get(key);
    }
    if hit is not None and time.monotonic() - hit[0] < ttl {
        return hit[1];
    }
    try {
        value = make();
    } except Exception as e {
        if hit is not None {
            log.warning(f"packages: serving stale {key}: {e}");
            return hit[1];
        }
        raise e;
    }
    with _LOCK {
        _CACHE[key] = (time.monotonic(), value);
    }
    return value;
}

impl package_catalog -> PackageCatalog {
    try {
        return cached("catalog", CATALOG_TTL_S, build_catalog);
    } except Exception as e {
        log.error(f"packages: the index is unavailable: {e}");
        return PackageCatalog(error="The package index is unavailable right now.");
    }
}

def _detail(name: str, version: str) -> PackageDetail {
    registry = open_registry();
    entries = registry.entries(name);
    if not entries {
        return PackageDetail(error=f"{name} is not in the index.");
    }
    latest = latest_entry(entries);
    chosen = registry.find(name, version) if version else latest;
    if chosen is None {
        chosen = entries[-1];
    }
    if version and chosen.version != version {
        return PackageDetail(error=f"{name} has no version {version}.");
    }
    surface = registry.api(name, chosen.version) if chosen.role == "lib" else None;
    summary = summary_of(name, entries, surface) or summary_of(name, [chosen], surface);
    readme = cached(
        f"readme:{chosen.source}", README_TTL_S, partial(repo_readme, chosen.source)
    )
        if chosen.source
        else RepoReadme();
    ranked: list[tuple[Version, IndexEntry]] = [];
    unranked: list[IndexEntry] = [];
    for e in entries {
        v = _parsed(e);
        if v is None {
            unranked.append(e);
        } else {
            ranked.append((v, e));
        }
    }
    ranked.sort(
        key=lambda (pair: tuple[Version, IndexEntry]) -> Version { return pair[0]; },
        reverse=True
    );
    ordered = [pair[1] for pair in ranked] + unranked;
    return PackageDetail(
        found=True,
        summary=summary,
        version=chosen.version,
        versions=[version_of(e) for e in ordered],
        modules=api_modules(surface),
        readme_lines=readme.lines,
        stars=readme.stars,
        topics=readme.topics
    );
}

impl package_detail(name: str, version: str = "") -> PackageDetail {
    if not is_package_name(name) {
        return PackageDetail(error=f"'{name}' is not a package name (org/name).");
    }
    try {
        return cached(
            f"detail:{name}@{version}", CATALOG_TTL_S, partial(_detail, name, version)
        );
    } except Exception as e {
        log.error(f"packages: {name}: {e}");
        return PackageDetail(error="The package index is unavailable right now.");
    }
}
