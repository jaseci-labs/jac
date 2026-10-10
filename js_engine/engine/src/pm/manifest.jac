"""npm packuments (abbreviated metadata) — fetch, cache, parse, pick versions.

Parsing follows bun's `Npm.PackageManifest.parse`: versions are split into
releases and prereleases, each sorted ascending; per version we keep the
dependency groups bun keeps for registry packages (dependencies,
optionalDependencies, peerDependencies + peerDependenciesMeta; devDependencies
are dropped), bin/binDir, os/cpu, dist.tarball, integrity (sha512 preferred,
else "sha1-" from shasum), hasInstallScript and bundled dependencies.

Selection follows `findBestVersion`: exact → that version only; otherwise the
`latest` dist-tag when it satisfies the range; otherwise the highest release
that does; prereleases are considered only when the range mentions one.
"""

import from engine.src.pm.config { PmConfig, PmRegistry }
import from engine.src.pm.json {
    JVal,
    JsonDoc,
    json_parse_bytes,
    jv_get,
    jv_get_str,
    jv_is_obj,
    jv_is_arr,
    jv_is_str,
    jv_str,
    jv_get_bool,
    jv_is_missing,
    jv_str_list,
    JV_BOOL
}
import from engine.src.pm.semver {
    SemVer,
    SemGroup,
    semver_parse_exact,
    semver_order,
    semver_satisfies,
    semver_group_is_exact,
    semver_group_exact_version,
    semver_eql,
    semver_format
}
import from engine.src.pm.depspec {
    BEH_PROD,
    BEH_OPTIONAL,
    BEH_PEER,
    BEH_BUNDLED,
    dep_less_than
}
import from engine.src.pm.registry { pm_http_get }
import from engine.src.pm.http { HttpResponse }
import from engine.src.pm.bytes { ByteBuf, bytebuf_free }
import from engine.src.pm.fsx {
    fsx_read_bytes,
    fsx_write_bytes,
    fsx_mkdir_p,
    fsx_is_file
}
import from engine.src.runtime.mem { io_free }

glob:pub NPM_ACCEPT: str = "Accept: application/vnd.npm.install-v1+json; q=1.0, application/json; q=0.8, */*";

"""One dependency of a manifest version."""
obj:pub MDep {
    has name: str,
        spec: str,
        behavior: int = 2;
}

obj:pub MVersion {
    has version_str: str = "",
        ver: SemVer = SemVer(),
        deps: list[MDep] = [],
        bin: JVal = JVal(),
        bin_dir: str = "",
        os: JVal = JVal(),
        cpu: JVal = JVal(),
        tarball: str = "",
        integrity: str = "",
        has_install_script: bool = False,
        deprecated: str = "";
}

# sorted like bun (behavior, name)
obj:pub Manifest {
    has ok: bool = False,
        error: str = "",
        name: str = "",
        dist_tags: dict[str, str] = {},
        releases: list[MVersion] = [],
        prereleases: list[MVersion] = [],
        by_version: dict[str, MVersion] = {};
}

# ascending
# ascending
def _hex_to_b64(hex: str) -> str {
    digits: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    vals: list[int] = [];
    i: int = 0;
    while i + 1 < len(hex) {
        try {
            vals.append(int(hex[i:i + 2], 16));
        } except Exception {
            return "";
        }
        i = i + 2;
    }
    out: list[str] = [];
    j: int = 0;
    n: int = len(vals);
    while j + 2 < n {
        b0: int = vals[j];
        b1: int = vals[j + 1];
        b2: int = vals[j + 2];
        out.append(digits[b0 >> 2]);
        out.append(digits[((b0 & 3) << 4) | (b1 >> 4)]);
        out.append(digits[((b1 & 15) << 2) | (b2 >> 6)]);
        out.append(digits[b2 & 63]);
        j = j + 3;
    }
    rem: int = n - j;
    if rem == 1 {
        b0: int = vals[j];
        out.append(digits[b0 >> 2]);
        out.append(digits[(b0 & 3) << 4]);
        out.append("=");
        out.append("=");
    } elif rem == 2 {
        b0: int = vals[j];
        b1: int = vals[j + 1];
        out.append(digits[b0 >> 2]);
        out.append(digits[((b0 & 3) << 4) | (b1 >> 4)]);
        out.append(digits[(b1 & 15) << 2]);
        out.append("=");
    }
    return "".join(out);
}

"""Build the dependency list of a version the way `Package.fromNPM` does:
dependencies, then optionalDependencies (an optional entry replaces a same-name
dependency), then peerDependencies (a same-name earlier entry wins; optional
peers flagged from peerDependenciesMeta), bundled flags, sorted."""
def _version_deps(v: JVal) -> list[MDep] {
    deps: list[MDep] = [];
    bundle_all: bool = False;
    bundled: list[str] = [];
    bd: JVal = jv_get(v, "bundleDependencies");
    if jv_is_missing(bd) {
        bd = jv_get(v, "bundledDependencies");
    }
    if bd.kind == JV_BOOL {
        bundle_all = bd.b;
    } elif jv_is_arr(bd) {
        bundled = jv_str_list(bd);
    }

    prod: JVal = jv_get(v, "dependencies");
    if jv_is_obj(prod) {
        for k in prod.keys {
            deps.append(MDep(name=k, spec=jv_str(prod.vals[k]), behavior=BEH_PROD));
        }
    }
    opt: JVal = jv_get(v, "optionalDependencies");
    if jv_is_obj(opt) {
        for k in opt.keys {
            d: MDep = MDep(name=k, spec=jv_str(opt.vals[k]), behavior=BEH_OPTIONAL);
            dup: int = -1;
            i: int = 0;
            while i < len(deps) {
                if deps[i].name == k {
                    dup = i;
                    break;
                }
                i = i + 1;
            }
            if dup >= 0 {
                del deps[dup];
            }
            deps.append(d);
        }
    }
    peer: JVal = jv_get(v, "peerDependencies");
    if jv_is_obj(peer) {
        meta: JVal = jv_get(v, "peerDependenciesMeta");
        for k in peer.keys {
            exists: bool = False;
            for d2 in deps {
                if d2.name == k {
                    exists = True;
                    break;
                }
            }
            if exists {
                continue;
            }
            b: int = BEH_PEER;
            if jv_get_bool(jv_get(meta, k), "optional", False) {
                b = b | BEH_OPTIONAL;
            }
            deps.append(MDep(name=k, spec=jv_str(peer.vals[k]), behavior=b));
        }
    }
    for d3 in deps {
        if bundle_all or (d3.name in bundled) {
            d3.behavior = d3.behavior | BEH_BUNDLED;
        }
    }
    # sort: behavior then name (insertion sort, lists are small)
    i2: int = 1;
    while i2 < len(deps) {
        j: int = i2;
        while j > 0
            and dep_less_than(
                deps[j].behavior, deps[j].name, deps[j - 1].behavior, deps[j - 1].name
            ) {
            tmp: MDep = deps[j - 1];
            deps[j - 1] = deps[j];
            deps[j] = tmp;
            j = j - 1;
        }
        i2 = i2 + 1;
    }
    return deps;
}

def _parse_version(vs: str, v: JVal) -> MVersion {
    mv: MVersion = MVersion(version_str=vs);
    pe: tuple[bool, SemVer] = semver_parse_exact(vs);
    mv.ver = pe[1];
    mv.deps = _version_deps(v);
    bin: JVal = jv_get(v, "bin");
    if jv_is_str(bin) or jv_is_obj(bin) {
        mv.bin = bin;
    } else {
        dirs: JVal = jv_get(v, "directories");
        if jv_is_obj(dirs) {
            mv.bin_dir = jv_get_str(dirs, "bin", "");
        }
    }
    mv.os = jv_get(v, "os");
    mv.cpu = jv_get(v, "cpu");
    mv.has_install_script = jv_get_bool(v, "hasInstallScript", False);
    mv.deprecated = jv_get_str(v, "deprecated", "");
    dist: JVal = jv_get(v, "dist");
    if jv_is_obj(dist) {
        mv.tarball = jv_get_str(dist, "tarball", "");
        integ: str = jv_get_str(dist, "integrity", "");
        algo: str = "";
        dash: int = integ.find("-");
        if dash > 0 {
            algo = integ[0:dash].lower();
        }
        if algo == "sha512" or algo == "sha384" or algo == "sha256" or algo == "sha1" {
            mv.integrity = integ;
        } else {
            shasum: str = jv_get_str(dist, "shasum", "");
            if shasum != "" {
                b64: str = _hex_to_b64(shasum);
                if b64 != "" {
                    mv.integrity = "sha1-" + b64;
                }
            }
        }
    }
    return mv;
}

def _insert_sorted(lst: list[MVersion], mv: MVersion) {
    lst.append(mv);
    j: int = len(lst) - 1;
    while j > 0 and semver_order(lst[j - 1].ver, lst[j].ver) > 0 {
        tmp: MVersion = lst[j - 1];
        lst[j - 1] = lst[j];
        lst[j] = tmp;
        j = j - 1;
    }
}

def:pub manifest_parse_bytes(ptr: int, n: int, expected_name: str) -> Manifest {
    m: Manifest = Manifest();
    doc: JsonDoc = json_parse_bytes(ptr, n);
    if not doc.ok {
        m.error = "invalid manifest JSON: " + doc.error;
        return m;
    }
    top: JVal = doc.value;
    if not jv_is_obj(top) {
        m.error = "invalid manifest";
        return m;
    }
    m.name = jv_get_str(top, "name", expected_name);
    if m.name == "" {
        m.name = expected_name;
    }
    tags: JVal = jv_get(top, "dist-tags");
    if jv_is_obj(tags) {
        for t in tags.keys {
            m.dist_tags[t] = jv_str(tags.vals[t]);
        }
    }
    versions: JVal = jv_get(top, "versions");
    if jv_is_obj(versions) {
        for vs in versions.keys {
            v: JVal = versions.vals[vs];
            if not jv_is_obj(v) {
                continue;
            }
            pe: tuple[bool, SemVer] = semver_parse_exact(vs);
            if not pe[0] {
                continue;
            }
            mv: MVersion = _parse_version(vs, v);
            m.by_version[vs] = mv;
            if mv.ver.pre != "" {
                _insert_sorted(m.prereleases, mv);
            } else {
                _insert_sorted(m.releases, mv);
            }
        }
    }
    m.ok = True;
    return m;
}

"""Version named by a dist-tag, or an empty MVersion (version_str "")."""
def:pub manifest_find_dist_tag(m: Manifest, tag: str) -> MVersion {
    if tag in m.dist_tags {
        vs: str = m.dist_tags[tag];
        if vs in m.by_version {
            return m.by_version[vs];
        }
    }
    return MVersion();
}

def:pub manifest_find_exact(m: Manifest, v: SemVer) -> MVersion {
    key: str = semver_format(v);
    if key in m.by_version {
        return m.by_version[key];
    }
    # tolerate build-metadata-less lookups
    for mv in m.releases {
        if semver_eql(mv.ver, v) {
            return mv;
        }
    }
    for mv2 in m.prereleases {
        if semver_eql(mv2.ver, v) {
            return mv2;
        }
    }
    return MVersion();
}

"""bun's findBestVersion."""
def:pub manifest_find_best(m: Manifest, g: SemGroup) -> MVersion {
    if semver_group_is_exact(g) {
        return manifest_find_exact(m, semver_group_exact_version(g));
    }
    latest: MVersion = manifest_find_dist_tag(m, "latest");
    if latest.version_str != "" and semver_satisfies(g, latest.ver) {
        if g.flag_pre {
            left: SemVer = g.lists[0].ranges[0].left.ver;
            if semver_order(left, latest.ver) == 0 {
                return latest;
            }
        } else {
            return latest;
        }
    }
    i: int = len(m.releases);
    while i > 0 {
        i = i - 1;
        if semver_satisfies(g, m.releases[i].ver) {
            return m.releases[i];
        }
    }
    if g.flag_pre {
        j: int = len(m.prereleases);
        while j > 0 {
            j = j - 1;
            if semver_satisfies(g, m.prereleases[j].ver) {
                return m.prereleases[j];
            }
        }
    }
    return MVersion();
}

# ── fetching / caching ────────────────────────────────────────────────────────

def _strip_slash(u: str) -> str {
    if u.endswith("/") {
        return u[0:len(u) - 1];
    }
    return u;
}

"""Registry URL for a package name (scope registries first)."""
def:pub pm_registry_url_for(cfg: PmConfig, name: str) -> str {
    if name.startswith("@") {
        slash: int = name.find("/");
        if slash > 0 {
            scope: str = name[0:slash];
            if scope in cfg.scopes and cfg.scopes[scope].url != "" {
                return cfg.scopes[scope].url;
            }
        }
    }
    return cfg.registry.url;
}

def _manifest_url(cfg: PmConfig, name: str) -> str {
    return _strip_slash(pm_registry_url_for(cfg, name))
        + "/"
        + name.replace("/", "%2F");
}

def _manifest_cache_path(cfg: PmConfig, name: str) -> str {
    return cfg.cache_dir + "/manifests/" + name.replace("/", "%2F") + ".json";
}

"""Manifest for `name`: disk cache first (unless `refresh`), else HTTP.
`error` describes a 404 / network failure; `ok` false then."""
def:pub manifest_fetch(cfg: PmConfig, name: str, refresh: bool) -> Manifest {
    cache_path: str = _manifest_cache_path(cfg, name);
    if not refresh and not cfg.cache_disable_manifest and fsx_is_file(cache_path) {
        b: ByteBuf = fsx_read_bytes(cache_path);
        if b.len > 0 {
            m: Manifest = manifest_parse_bytes(b.ptr, b.len, name);
            bytebuf_free(b);
            if m.ok {
                return m;
            }
        }
    }
    url: str = _manifest_url(cfg, name);
    resp: HttpResponse = pm_http_get(cfg, url, [NPM_ACCEPT]);
    bad: Manifest = Manifest(name=name);
    if resp.error != "" {
        bad.error = "GET " + url + " - " + resp.error;
        return bad;
    }
    if resp.status == 404 {
        bad.error = "package \"" + name + "\" not found " + url + " 404";
        bytebuf_free(resp.body);
        return bad;
    }
    if resp.status != 200 {
        bad.error = "GET " + url + " - " + str(resp.status);
        bytebuf_free(resp.body);
        return bad;
    }
    m2: Manifest = manifest_parse_bytes(resp.body.ptr, resp.body.len, name);
    if m2.ok and not cfg.cache_disable_manifest and cfg.cache_dir != "" {
        fsx_mkdir_p(cfg.cache_dir + "/manifests", 493);
        fsx_write_bytes(cache_path, resp.body.ptr, resp.body.len, 420);
    }
    bytebuf_free(resp.body);
    return m2;
}
