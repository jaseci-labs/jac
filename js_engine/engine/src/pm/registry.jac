"""Registry access and the package cache.

Tarballs are downloaded once, verified against their SRI integrity and
extracted into the cache (`cfg.cache_dir`, default ~/.js_engine/install/cache,
overridable with BUN_INSTALL_CACHE_DIR like bun). Installs then hard-link the
cached files into node_modules — bun's layout and mechanism, which is also what
makes the file modes come out the same: a cached file keeps the mode it was
extracted with, and the install phase runs with umask 0 (see pm/install.jac).

Cache folder names follow bun (`<name>@<version>` plus `@@<host>` for a
non-default registry) so a scoped package nests under its scope directory.
"""

import from engine.src.pm.config { PmConfig, PmRegistry, PM_DEFAULT_REGISTRY }
import from engine.src.pm.http {
    HttpResponse,
    http_get,
    http_origin,
    http_parse_url,
    HttpUrl,
    http_body_str
}
import from engine.src.pm.bytes {
    ByteBuf,
    bytebuf_free,
    sri_matches,
    sri_sha512,
    b64_encode,
    str_to_cbuf,
    b64_decode,
    bytebuf_to_str
}
import from engine.src.pm.fsx {
    fsx_is_file,
    fsx_is_dir,
    fsx_mkdir_p,
    fsx_mkdtemp,
    fsx_rename,
    fsx_rm_rf,
    fsx_exists,
    FSX_EEXIST,
    FSX_ENOTEMPTY
}
import from engine.src.pm.gunzip { gunzip_bytes, gunzip_is_gzip }
import from engine.src.pm.tar { tar_extract_npm, TarResult }
import from engine.src.pm.paths { pm_path_dirname }
import from engine.src.runtime.mem { io_free }

obj:pub FetchResult {
    has ok: bool = False,
        error: str = "",
        cache_dir: str = "",
        from_cache: bool = False,
        bytes: int = 0;
}

def _strip_slash(u: str) -> str {
    if u.endswith("/") {
        return u[0:len(u) - 1];
    }
    return u;
}

"""The registry configured for `url` (scope registries first), or the default."""
def _registry_for_url(cfg: PmConfig, url: str) -> PmRegistry {
    for scope in cfg.scopes {
        r: PmRegistry = cfg.scopes[scope];
        if r.url != "" and url.startswith(_strip_slash(r.url)) {
            return r;
        }
    }
    return cfg.registry;
}

"""Authorization header(s) for a request to `url`: the credentials of the
registry the URL belongs to, sent only to that registry's origin (scheme, host
and port — a tarball URL on plain http or another port of the same host gets
none) and only under the path they are keyed to (.npmrc //host/path/)."""
def:pub pm_auth_headers(cfg: PmConfig, url: str) -> list[str] {
    out: list[str] = [];
    r: PmRegistry = _registry_for_url(cfg, url);
    ru: HttpUrl = http_parse_url(r.url);
    uu: HttpUrl = http_parse_url(url);
    if not ru.ok or not uu.ok {
        return out;
    }
    if http_origin(uu).lower() != http_origin(ru).lower() {
        return out;
    }
    if not uu.path.startswith(r.auth_path) {
        return out;
    }
    if r.token != "" {
        out.append("Authorization: Bearer " + r.token);
        return out;
    }
    if r.auth_basic != "" {
        out.append("Authorization: Basic " + r.auth_basic);
        return out;
    }
    if r.username != "" {
        pw: str = r.password;
        dec: ByteBuf = b64_decode(pw);
        if dec.len > 0 {
            pw = bytebuf_to_str(dec);
        }
        bytebuf_free(dec);
        cred: str = r.username + ":" + pw;
        cp: int = str_to_cbuf(cred);
        out.append("Authorization: Basic " + b64_encode(cp, len(cred)));
        io_free(cp);
    }
    return out;
}

"""GET with the configured auth / TLS settings."""
def:pub pm_http_get(cfg: PmConfig, url: str, extra: list[str]) -> HttpResponse {
    headers: list[str] = [];
    for h in pm_auth_headers(cfg, url) {
        headers.append(h);
    }
    for h in extra {
        headers.append(h);
    }
    verify: bool = cfg.strict_ssl and not cfg.no_verify;
    return http_get(url, headers, verify, cfg.cafile);
}

"""Cache folder for a package version (bun: name@version[@@host]@@@1)."""
def:pub pm_cache_pkg_dir(
    cfg: PmConfig, name: str, version: str, tarball_url: str
) -> str {
    suffix: str = "";
    if tarball_url != "" {
        u: HttpUrl = http_parse_url(tarball_url);
        d: HttpUrl = http_parse_url(PM_DEFAULT_REGISTRY);
        if u.ok and d.ok and u.host != d.host {
            suffix = "@@" + u.host;
        }
    }
    return cfg.cache_dir + "/" + name + "@" + version + suffix;
}

"""Default tarball URL for a package on `registry_url`:
<registry>/<name>/-/<unscoped>-<version>.tgz"""
def:pub pm_default_tarball_url(registry_url: str, name: str, version: str) -> str {
    unscoped: str = name;
    slash: int = name.find("/");
    if name.startswith("@") and slash >= 0 {
        unscoped = name[slash + 1:];
    }
    return _strip_slash(registry_url)
        + "/"
        + name
        + "/-/"
        + unscoped
        + "-"
        + version
        + ".tgz";
}

"""Make sure `<cache>/<name>@<version>` holds the extracted package; download,
verify (`integrity`, "" = unchecked) and extract when it does not."""
def:pub pm_ensure_cached(
    cfg: PmConfig, name: str, version: str, tarball_url: str, integrity: str
) -> FetchResult {
    res: FetchResult = FetchResult();
    url: str = tarball_url;
    if url == "" {
        url = pm_default_tarball_url(cfg.registry.url, name, version);
    }
    dir: str = pm_cache_pkg_dir(cfg, name, version, url);
    res.cache_dir = dir;
    if fsx_is_file(dir + "/package.json") {
        res.ok = True;
        res.from_cache = True;
        return res;
    }
    resp: HttpResponse = pm_http_get(cfg, url, []);
    if resp.error != "" {
        res.error = "GET " + url + " - " + resp.error;
        return res;
    }
    if resp.status != 200 {
        res.error = "GET " + url + " - " + str(resp.status);
        bytebuf_free(resp.body);
        return res;
    }
    res.bytes = resp.body.len;
    if integrity != "" and not sri_matches(integrity, resp.body.ptr, resp.body.len) {
        res.error = "Integrity check failed for tarball: "
            + name
            + "@"
            + version
            + "\n  Wanted: "
            + integrity
            + "\n  Got:    "
            + sri_sha512(resp.body.ptr, resp.body.len);
        bytebuf_free(resp.body);
        return res;
    }
    tarbuf: ByteBuf = resp.body;
    inflated: bool = False;
    if gunzip_is_gzip(resp.body.ptr, resp.body.len) {
        tarbuf = gunzip_bytes(resp.body.ptr, resp.body.len);
        inflated = True;
        if tarbuf.len < 0 {
            res.error = "failed to decompress tarball for " + name + "@" + version;
            bytebuf_free(resp.body);
            return res;
        }
    }
    tmp_root: str = cfg.cache_dir + "/.tmp";
    if not fsx_mkdir_p(tmp_root, 493) {
        res.error = "could not create cache directory " + tmp_root;
        return res;
    }
    tmp: str = fsx_mkdtemp(tmp_root + "/extract-XXXXXX");
    if tmp == "" {
        res.error = "could not create a temporary directory under " + tmp_root;
        return res;
    }
    tr: TarResult = tar_extract_npm(tarbuf.ptr, tarbuf.len, tmp, 1);
    if inflated {
        bytebuf_free(tarbuf);
    }
    bytebuf_free(resp.body);
    if not tr.ok {
        fsx_rm_rf(tmp);
        res.error = "failed to extract " + name + "@" + version + ": " + tr.error;
        return res;
    }
    fsx_mkdir_p(pm_path_dirname(dir), 493);
    rc: int = fsx_rename(tmp, dir);
    if rc < 0 {
        # Someone else populated it meanwhile, or the rename was refused: keep
        # whatever is there if it looks complete.
        fsx_rm_rf(tmp);
        if not fsx_is_file(dir + "/package.json") {
            res.error = "could not move extracted package into the cache (errno "
                + str(-rc)
                + ")";
            return res;
        }
    }
    res.ok = True;
    return res;
}
