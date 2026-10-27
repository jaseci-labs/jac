impl _database_config -> (DatabaseConfig | None) {
    config = get_config();
    return config.database if config is not None else None;
}

impl _configured_dist -> str {
    config = get_config();
    if config is None or not config.database.postgres_dist {
        return "";
    }
    dist = os.path.expanduser(config.database.postgres_dist);
    if config.project_root is not None {
        dist = os.path.join(str(config.project_root), dist);
    }
    return dist;
}

impl pinned_major -> int {
    database = _database_config();
    wanted = database.postgres_version if database is not None else '';
    if wanted {
        try {
            return int(wanted.split('.')[0]);
        } except ValueError {
            logger.warning(
                f"[database] postgres_version {wanted!r} is not a version; using {PG_MAJOR}"
            );
        }
    }
    return PG_MAJOR;
}

impl dist_cache_dir -> str {
    return str(bucket("pg").path() / 'dist');
}

impl platform_slug -> (str | None) {
    arch = {
        'x86_64': 'amd64',
        'amd64': 'amd64',
        'aarch64': 'arm64v8',
        'arm64': 'arm64v8'
    }.get(
        platform.machine().lower()
    );
    system = {'Linux': 'linux', 'Darwin': 'darwin', 'Windows': 'windows'}.get(
        platform.system()
    );
    return f"{system}-{arch}" if arch and system else None;
}

impl _bin_of(dist: str) -> (str | None) {
    for candidate in [os.path.join(dist, 'bin'), dist] {
        if os.path.isfile(os.path.join(candidate, postgres_exe())) {
            return candidate;
        }
    }
    return None;
}

impl pg_major_of(bin_dir: str) -> (int | None) {
    postgres = os.path.join(bin_dir, postgres_exe());
    if not os.path.isfile(postgres) {
        return None;
    }
    try {
        out = subprocess.run(
            [postgres, '--version'], capture_output=True, text=True, timeout=10
        ).stdout.strip();
    } except (OSError, subprocess.SubprocessError) as e {
        logger.debug(f"pg version probe failed for {postgres}: {e}");
        return None;
    }
    for part in out.split() {
        if part[:1].isdigit() {
            digits = part.split('.')[0];
            return int(digits) if digits.isdigit() else None;
        }
    }
    return None;
}

impl _version_key(version: str) -> tuple[int, ...] {
    return tuple(int(p) if p.isdigit() else 0 for p in version.split('.'));
}

impl _cached(major: int) -> (str | None) {
    slug = platform_slug();
    cache = dist_cache_dir();
    if slug is None or not os.path.isdir(cache) {
        return None;
    }
    versions = [
        name[len(slug) + 1:]
        for name in os.listdir(cache)
        if name.startswith(slug + '-')
            and not name.endswith('.part')
            and os.path.isfile(os.path.join(cache, name, 'bin', postgres_exe()))
    ];
    if not versions {
        return None;
    }
    pinned = [
        v
        for v in versions
        if v.split('.')[0] == str(major)
    ];
    best = max(pinned or versions, key=_version_key);
    return os.path.join(cache, f"{slug}-{best}", 'bin');
}

impl _system(major: int) -> (str | None) {
    candidates: list[str] = [];
    exe = shutil.which(postgres_exe());
    if exe {
        candidates.append(os.path.dirname(os.path.realpath(exe)));
    }
    for base in SYSTEM_ROOTS {
        if os.path.isdir(base) {
            for name in sorted(os.listdir(base), reverse=True) {
                cand = os.path.join(base, name, 'bin');
                if os.path.isfile(os.path.join(cand, postgres_exe())) {
                    candidates.append(cand);
                }
            }
        }
    }
    best: (str | None) = None;
    best_major = 0;
    for cand in candidates {
        found = pg_major_of(cand);
        if found == major {
            return cand;
        }
        if found is not None and found >= MIN_SYSTEM_MAJOR and found > best_major {
            (best, best_major) = (cand, found);
        }
    }
    if best is not None {
        logger.warning(
            f"postgres {major} not found on the system; using the installed "
            f"postgres {best_major} at {best} (set [database] postgres_dist or "
            f"postgres_version to choose)"
        );
    }
    return best;
}

impl _published(slug: str) -> list[str] {
    url = f"{ZONKY_BASE}{slug}/maven-metadata.xml";
    try {
        with urllib.request.urlopen(url, timeout=30) as response {
            body = response.read().decode('utf-8', errors='replace');
        }
    } except OSError as e {
        logger.debug(f"zonky metadata fetch failed: {e}");
        return [];
    }
    return [
        chunk.split('</version>')[0].strip() for chunk in body.split('<version>')[1:]
    ];
}

impl _unpack(slug: str, version: str, dist_dir: str) {
    name = f"embedded-postgres-binaries-{slug}";
    jar_url = f"{ZONKY_BASE}{slug}/{version}/{name}-{version}.jar";
    with urllib.request.urlopen(jar_url + '.sha1', timeout=30) as response {
        want_sha = response.read().decode().strip().split()[0];
    }
    jar_path = fetch(Download("postgres", version, slug, jar_url, want_sha, "sha1"));
    with zipfile.ZipFile(jar_path) as jar {
        payloads = [
            n
            for n in jar.namelist()
            if n.endswith('.txz')
        ];
    }
    if not payloads {
        raise ArtifactUnavailable(f"no .txz payload in {jar_url}");
    }
    staging = dist_dir + '.part';
    shutil.rmtree(staging, ignore_errors=True);
    os.makedirs(staging);
    try {
        extract(jar_path, Path(staging));
        extract(Path(staging) / payloads[0], Path(staging));
        os.remove(os.path.join(staging, payloads[0]));
        os.replace(staging, dist_dir);
    } finally {
        shutil.rmtree(staging, ignore_errors=True);
    }
}

impl download_dist -> str {
    slug = platform_slug();
    if slug is None {
        raise ArtifactUnavailable(
            f"no embedded postgres is published for {platform.system()} {platform.machine()}"
        );
    }
    published = _published(slug);
    want = pinned_major();
    versions = [
        v
        for v in published
        if v.split('.')[0] == str(want)
    ];
    if not versions and published {
        newest = max(
            {
                int(v.split('.')[0])
                for v in published
                if v[:1].isdigit()
            }
        );
        logger.warning(
            f"postgres {want} is not yet published to the embedded channel; using {newest}"
        );
        versions = [
            v
            for v in published
            if v.split('.')[0] == str(newest)
        ];
    }
    if not versions {
        raise ArtifactUnavailable(
            "the embedded postgres channel (Maven Central) is unreachable"
        );
    }
    version = versions[-1];
    dist_dir = os.path.join(dist_cache_dir(), f"{slug}-{version}");
    bin_dir = os.path.join(dist_dir, 'bin');
    os.makedirs(dist_cache_dir(), exist_ok=True);
    with FileLock(Path(dist_cache_dir()) / f".{slug}-{version}.lock") {
        if not os.path.isfile(os.path.join(bin_dir, postgres_exe())) {
            logger.info(f"fetching embedded postgres {version} ({slug})...");
            _unpack(slug, version, dist_dir);
        }
    }
    return bin_dir;
}

impl PostgresArtifact.probe_checkout -> Probe {
    env = _env_dist();
    if env {
        found = _bin_of(env);
        return Probe.hit(Source.CONFIGURED, found, {})
            if found
            else Probe.missing(f"JAC_PG_DIST {env!r} has no bin/{postgres_exe()}");
    }
    configured = _configured_dist();
    if configured {
        found = _bin_of(configured);
        return Probe.hit(Source.CONFIGURED, found, {})
            if found
            else Probe.missing(
                f"[database] postgres_dist {configured!r} has no bin/{postgres_exe()}"
            );
    }
    major = pinned_major();
    found = _cached(major);
    if found is not None {
        return Probe.hit(Source.CACHE, found, {});
    }
    found = _system(major);
    if found is not None {
        return Probe.hit(Source.SYSTEM, found, {});
    }
    return Probe.missing(f"postgres {major} is not provisioned");
}

impl PostgresArtifact.checkout_path -> str {
    return dist_cache_dir();
}

impl PostgresArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    log(f"  postgres {pinned_major()} -> {download_dist()}");
}

impl _env_dist -> str {
    raw = os.environ.get('JAC_PG_DIST', '').strip();
    return os.path.expanduser(raw) if raw else '';
}

impl postgres_exe -> str {
    return 'postgres.exe' if platform.system() == 'Windows' else 'postgres';
}

impl _dist_root(bin_dir: (str | None)) -> (str | None) {
    if not bin_dir {
        return None;
    }
    parent = os.path.dirname(bin_dir);
    if (
        os.path.isdir(os.path.join(parent, 'lib'))
        and os.path.isdir(os.path.join(parent, 'share'))
    ) {
        return parent;
    }
    return None;
}

impl bundled_dist_dir -> str {
    env = _env_dist();
    if env {
        vendored = _dist_root(_bin_of(env));
        if vendored {
            return vendored;
        }
        raise ArtifactUnavailable(
            f"JAC_PG_DIST {env!r} is not a self-contained postgres distribution "
            "(no sibling lib/ and share/); point it at a jac-fetched dist or unset it"
        );
    }
    configured = _configured_dist();
    if configured {
        vendored = _dist_root(_bin_of(configured));
        if vendored {
            return vendored;
        }
        raise ArtifactUnavailable(
            f"[database] postgres_dist {configured!r} is not self-contained (no "
            "sibling lib/ and share/); a desktop bundle needs a relocatable distribution"
        );
    }
    found = _cached(pinned_major());
    if found is not None {
        vendored = _dist_root(found);
        if vendored {
            return vendored;
        }
    }
    if offline_mode() {
        raise ArtifactUnavailable(
            f"no cached postgres {pinned_major()} distribution to bundle, and "
            "this project is offline ([network] offline)"
        );
    }
    vendored = _dist_root(download_dist());
    if vendored is None {
        raise ArtifactUnavailable(
            "the fetched postgres distribution is not self-contained (no sibling lib/ and share/)"
        );
    }
    return vendored;
}

impl cached_dist_dir -> str {
    for chosen in [_env_dist(), _configured_dist()] {
        if chosen {
            bin_dir = _bin_of(chosen);
            vendored = _dist_root(bin_dir) if bin_dir else None;
            return vendored or '';
        }
    }
    found = _cached(pinned_major());
    return (_dist_root(found) or '') if found is not None else '';
}

impl PostgresArtifact.build_blocker -> str {
    env = _env_dist();
    if env {
        if _bin_of(env) is None {
            return f"JAC_PG_DIST {env!r} has no bin/{postgres_exe()}";
        }
        return "";
    }
    configured = _configured_dist();
    if configured and _bin_of(configured) is None {
        return f"[database] postgres_dist {configured!r} has no bin/{postgres_exe()}";
    }
    return "";
}

impl postgres_bin_dir -> str {
    found = require("postgres").found;
    assert found is not None;
    return found.path;
}
