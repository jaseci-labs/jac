"""Package sources other than the npm registry: remote tarballs
(`https://…/x.tgz`), local tarballs (`file:./x.tgz`, `./x.tgz`) and `file:`
folders — bun's `.remote_tarball`, `.local_tarball` and `.folder` resolutions.

Tarballs are fetched (or read) once, verified against the lockfile's integrity
when there is one (else the sha512 SRI is computed and recorded), extracted into
the cache under `@T@<sha256 of the url/path>` and hard-linked from there like
registry packages. Folders are hard-linked straight from the project (their own
`node_modules` skipped), which is what bun's Hardlinker does.

`pm_source_dir` is the one entry point the linkers use to find the files of any
package kind (npm through pm/registry.jac).
"""

import from engine.src.ffi.libc { getenv }
import from engine.src.pm.config { PmConfig }
import from engine.src.pm.proc { ProcResult, proc_run, proc_env_inherit }
import from engine.src.pm.registry { pm_http_get, pm_ensure_cached, FetchResult }
import from engine.src.pm.http { HttpResponse }
import from engine.src.pm.bytes {
    ByteBuf,
    bytebuf_new,
    bytebuf_append_str,
    bytebuf_free,
    bytes_to_str,
    sri_sha512,
    sri_matches,
    digest_raw,
    bytes_hex
}
import from engine.src.pm.gunzip { gunzip_is_gzip, gunzip_bytes }
import from engine.src.pm.tar { tar_extract_npm, tar_list, TarEntry, TarResult }
import from engine.src.pm.fsx {
    fsx_is_file,
    fsx_is_dir,
    fsx_read_bytes,
    fsx_write_str,
    fsx_mkdir_p,
    fsx_mkdtemp,
    fsx_rename,
    fsx_rm_rf
}
import from engine.src.pm.paths { pm_path_dirname, pm_path_normalize }
import from engine.src.pm.json { JVal, jv_get, jv_is_obj, jv_get_str }
import from engine.src.pm.project { PkgJson, pm_read_package_json }
import from engine.src.pm.lockfile { LockPkg }

"""Where a package's files are, plus the integrity of a fetched tarball."""
obj:pub SourceResult {
    has ok: bool = False,
        error: str = "",
        dir: str = "",
        integrity: str = "",
        resolved: str = "",
        skip_node_modules: bool = False;
}

# github: tarball top folder; git: commit sha
# folder sources: their own node_modules is not part of the package
"""A package.json read from a source (for the resolver)."""
obj:pub SourcePkg {
    has ok: bool = False,
        error: str = "",
        dir: str = "",
        pj: JVal = JVal(),
        integrity: str = "",
        resolved: str = "";
}

def:pub pm_is_remote_url(s: str) -> bool {
    return s.startswith("http://") or s.startswith("https://");
}

"""The tarball's resolution value: `file:` stripped, the path otherwise as written
(bun keeps `./vendor/x.tgz`), URLs untouched."""
def:pub pm_tarball_value(spec_literal: str) -> str {
    if spec_literal.startswith("file:") {
        return spec_literal[5:];
    }
    return spec_literal;
}

"""The folder's resolution value: `file:` stripped and normalized (bun writes
`file:packages/lib` for `file:./packages/lib`)."""
def:pub pm_folder_value(spec_literal: str) -> str {
    p: str = spec_literal;
    if p.startswith("file:") {
        p = p[5:];
    }
    return pm_path_normalize(p);
}

def _sha256_hex(s: str) -> str {
    buf: ByteBuf = bytebuf_new(len(s) + 1);
    bytebuf_append_str(buf, s);
    d: tuple[int, int] = digest_raw("sha256", buf.ptr, buf.len);
    hex: str = bytes_hex(d[0], d[1]);
    bytebuf_free(buf);
    return hex;
}

"""Cache directory for a tarball (`@T@<sha256 of the url/path>`, our own layout —
bun uses a Wyhash of the url with a cache-version suffix)."""
def:pub pm_tarball_cache_dir(cfg: PmConfig, value: str) -> str {
    return cfg.cache_dir + "/@T@" + _sha256_hex(value);
}

"""Extract a (possibly gzipped) tarball into `dir` (one path level stripped)."""
def _extract_into(cfg: PmConfig, body: ByteBuf, dir: str, label: str) -> str {
    tarbuf: ByteBuf = body;
    inflated: bool = False;
    if gunzip_is_gzip(body.ptr, body.len) {
        tarbuf = gunzip_bytes(body.ptr, body.len);
        inflated = True;
        if tarbuf.len < 0 {
            return "failed to decompress tarball for " + label;
        }
    }
    err: str = _extract_tar_into(cfg, tarbuf, dir, label);
    if inflated {
        bytebuf_free(tarbuf);
    }
    return err;
}

"""Extract a plain tar image into `dir` via a temp dir (one path level stripped)."""
def _extract_tar_into(cfg: PmConfig, tarbuf: ByteBuf, dir: str, label: str) -> str {
    tmp_root: str = cfg.cache_dir + "/.tmp";
    if not fsx_mkdir_p(tmp_root, 493) {
        return "could not create cache directory " + tmp_root;
    }
    tmp: str = fsx_mkdtemp(tmp_root + "/extract-XXXXXX");
    if tmp == "" {
        return "could not create a temporary directory under " + tmp_root;
    }
    tr: TarResult = tar_extract_npm(tarbuf.ptr, tarbuf.len, tmp, 1);
    if not tr.ok {
        fsx_rm_rf(tmp);
        return "failed to extract " + label + ": " + tr.error;
    }
    fsx_mkdir_p(pm_path_dirname(dir), 493);
    rc: int = fsx_rename(tmp, dir);
    if rc < 0 {
        fsx_rm_rf(tmp);
        if not fsx_is_file(dir + "/package.json") {
            return "could not move extracted package into the cache (errno "
                + str(-rc)
                + ")";
        }
    }
    return "";
}

"""Fetch/read a tarball into the cache. `value` is the URL or the local path
(relative to `root_dir`); `integrity` from the lockfile is checked when given."""
def:pub pm_ensure_tarball_cached(
    cfg: PmConfig, root_dir: str, value: str, integrity: str
) -> SourceResult {
    res: SourceResult = SourceResult();
    dir: str = pm_tarball_cache_dir(cfg, value);
    res.dir = dir;
    res.integrity = integrity;
    # the integrity note lives next to the cache folder, never inside the package
    # (its files are hard-linked into node_modules)
    if fsx_is_file(dir + "/package.json")
        and (integrity != "" or fsx_is_file(dir + ".integrity")) {
        if integrity == "" {
            res.integrity = _read_small(dir + ".integrity");
        }
        res.ok = True;
        return res;
    }
    body: ByteBuf = ByteBuf();
    if pm_is_remote_url(value) {
        resp: HttpResponse = pm_http_get(cfg, value, []);
        if resp.error != "" {
            res.error = "GET " + value + " - " + resp.error;
            return res;
        }
        if resp.status != 200 {
            res.error = "GET " + value + " - " + str(resp.status);
            bytebuf_free(resp.body);
            return res;
        }
        body = resp.body;
    } else {
        path: str = value;
        if not path.startswith("/") {
            path = root_dir + "/" + pm_path_normalize(value);
        }
        if not fsx_is_file(path) {
            res.error = "tarball not found: " + value;
            return res;
        }
        body = fsx_read_bytes(path);
        if body.len < 0 {
            res.error = "could not read tarball: " + value;
            return res;
        }
    }
    if integrity != "" and not sri_matches(integrity, body.ptr, body.len) {
        res.error = "Integrity check failed for tarball: "
            + value
            + "\n  Wanted: "
            + integrity
            + "\n  Got:    "
            + sri_sha512(body.ptr, body.len);
        bytebuf_free(body);
        return res;
    }
    res.integrity = sri_sha512(body.ptr, body.len);
    fsx_rm_rf(dir);
    err: str = _extract_into(cfg, body, dir, value);
    bytebuf_free(body);
    if err != "" {
        res.error = err;
        return res;
    }
    _write_small(dir + ".integrity", res.integrity);
    res.ok = True;
    return res;
}

# ── git / github ──────────────────────────────────────────────────────────────

def _github_api -> str {
    u: str = getenv("GITHUB_API_URL");
    if u == None or u == "" {
        return "https://api.github.com";
    }
    if u.endswith("/") {
        u = u[0:len(u) - 1];
    }
    return u;
}

"""Last '-'-separated part of a GitHub tarball folder (`owner-repo-<sha>` → sha)."""
def:pub pm_after_last_dash(s: str) -> str {
    i: int = len(s) - 1;
    while i >= 0 {
        if s[i] == "-" {
            return s[i + 1:];
        }
        i = i - 1;
    }
    return s;
}

"""`github:owner/repo#ref` → (owner, repo, ref)."""
def:pub pm_github_version_parts(version: str) -> tuple[str, str, str] {
    s: str = version;
    if s.startswith("github:") {
        s = s[7:];
    }
    committish: str = "";
    h: int = len(s) - 1;
    while h >= 0 {
        if s[h] == "#" {
            committish = s[h + 1:];
            s = s[0:h];
            break;
        }
        h = h - 1;
    }
    slash: int = s.find("/");
    if slash < 0 {
        return ("", s, committish);
    }
    return (s[0:slash], s[slash + 1:], committish);
}

"""`git+<url>#<ref>` → (url, ref)."""
def:pub pm_git_version_parts(version: str) -> tuple[str, str] {
    s: str = version;
    if s.startswith("git+") {
        s = s[4:];
    }
    h: int = len(s) - 1;
    while h >= 0 {
        if s[h] == "#" {
            return (s[0:h], s[h + 1:]);
        }
        h = h - 1;
    }
    return (s, "");
}

"""Top folder of a GitHub tarball (`<owner>-<repo>-<sha>`), skipping the pax header."""
def _tar_top_dir(ptr: int, n: int) -> str {
    for e in tar_list(ptr, n) {
        if e.path == "pax_global_header" {
            continue;
        }
        p: str = e.path;
        slash: int = p.find("/");
        if slash > 0 {
            return p[0:slash];
        }
        if p != "" {
            return p;
        }
    }
    return "";
}

"""GitHub dependency: the API tarball (`/repos/<owner>/<repo>/tarball/<ref>`),
extracted into `@GH@<top folder>`; `resolved` is that folder name (bun prints its
last '-' part as the commit) and `.bun-tag` inside the package records it."""
def:pub pm_ensure_github_cached(
    cfg: PmConfig, owner: str, repo: str, committish: str, resolved: str, integrity: str
) -> SourceResult {
    res: SourceResult = SourceResult();
    res.resolved = resolved;
    res.integrity = integrity;
    if resolved != "" {
        dir0: str = cfg.cache_dir + "/@GH@" + resolved;
        if fsx_is_file(dir0 + "/package.json") {
            res.dir = dir0;
            res.ok = True;
            return res;
        }
    }
    url: str = _github_api()
        + "/repos/"
        + owner
        + "/"
        + repo
        + "/tarball/"
        + committish;
    label: str = "github:" + owner + "/" + repo;
    if committish != "" {
        label = label + "#" + committish;
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
    if integrity != "" and not sri_matches(integrity, resp.body.ptr, resp.body.len) {
        res.error = "Integrity check failed for tarball: "
            + label
            + "\n  Wanted: "
            + integrity
            + "\n  Got:    "
            + sri_sha512(resp.body.ptr, resp.body.len);
        bytebuf_free(resp.body);
        return res;
    }
    res.integrity = sri_sha512(resp.body.ptr, resp.body.len);
    tarbuf: ByteBuf = resp.body;
    inflated: bool = False;
    if gunzip_is_gzip(resp.body.ptr, resp.body.len) {
        tarbuf = gunzip_bytes(resp.body.ptr, resp.body.len);
        inflated = True;
        if tarbuf.len < 0 {
            bytebuf_free(resp.body);
            res.error = "failed to decompress tarball for " + label;
            return res;
        }
    }
    top: str = _tar_top_dir(tarbuf.ptr, tarbuf.len);
    if top == "" {
        if inflated {
            bytebuf_free(tarbuf);
        }
        bytebuf_free(resp.body);
        res.error = "unexpected tarball layout for " + label;
        return res;
    }
    dir: str = cfg.cache_dir + "/@GH@" + top;
    fsx_rm_rf(dir);
    err: str = _extract_tar_into(cfg, tarbuf, dir, label);
    if inflated {
        bytebuf_free(tarbuf);
    }
    bytebuf_free(resp.body);
    if err != "" {
        res.error = err;
        return res;
    }
    fsx_write_str(dir + "/.bun-tag", top, 420);  # bun creates it 0644 regardless of the umask
    res.resolved = top;
    res.dir = dir;
    res.ok = True;
    return res;
}

def _git(argv: list[str], cwd: str) -> ProcResult {
    return proc_run(argv, cwd, proc_env_inherit(), True);
}

"""Git dependency (bun's Repository.download / findCommit / checkout): a bare
clone under `.git-clones/`, the commit found with `git log -1 <ref>`, a
`--no-checkout` clone of it checked out into `@G@<sha>` with `.git` removed and
`.bun-tag` written."""
def:pub pm_ensure_git_cached(
    cfg: PmConfig, url: str, committish: str, resolved: str
) -> SourceResult {
    res: SourceResult = SourceResult();
    res.resolved = resolved;
    if resolved != "" {
        dir0: str = cfg.cache_dir + "/@G@" + resolved;
        if fsx_is_file(dir0 + "/package.json") {
            res.dir = dir0;
            res.ok = True;
            return res;
        }
    }
    clones: str = cfg.cache_dir + "/.git-clones";
    if not fsx_mkdir_p(clones, 493) {
        res.error = "could not create " + clones;
        return res;
    }
    bare: str = clones + "/" + _sha256_hex(url) + ".git";
    if fsx_is_dir(bare) {
        r0: ProcResult = _git(["git", "-C", bare, "fetch", "--quiet"], cfg.cache_dir);
        if not r0.ok or r0.exit_code != 0 {
            res.error = "\"git fetch\" for \"" + url + "\" failed";
            return res;
        }
    } else {
        r1: ProcResult = _git(
            [
                "git",
                "clone",
                "-c",
                "core.longpaths=true",
                "--quiet",
                "--bare",
                url,
                bare
            ],
            cfg.cache_dir
        );
        if not r1.ok or r1.exit_code != 0 {
            fsx_rm_rf(bare);
            res.error = "\"git clone\" for \"" + url + "\" failed";
            if r1.stderr != "" {
                res.error = res.error + "\n" + r1.stderr.strip();
            }
            return res;
        }
    }
    sha: str = resolved;
    if sha == "" {
        argv: list[str] = ["git", "-C", bare, "log", "--format=%H", "-1"];
        if committish != "" {
            argv.append(committish);
        }
        r2: ProcResult = _git(argv, cfg.cache_dir);
        if not r2.ok or r2.exit_code != 0 or r2.stdout.strip() == "" {
            res.error = "no commit matching \""
                + committish
                + "\" found for \""
                + url
                + "\" (but repository exists)";
            return res;
        }
        sha = r2.stdout.strip();
    }
    dir: str = cfg.cache_dir + "/@G@" + sha;
    if not fsx_is_file(dir + "/package.json") {
        fsx_rm_rf(dir);
        r3: ProcResult = _git(
            [
                "git",
                "clone",
                "-c",
                "core.longpaths=true",
                "--quiet",
                "--no-checkout",
                bare,
                dir
            ],
            cfg.cache_dir
        );
        if not r3.ok or r3.exit_code != 0 {
            res.error = "\"git clone\" for \"" + url + "\" failed";
            return res;
        }
        r4: ProcResult = _git(
            ["git", "-C", dir, "checkout", "--quiet", sha], cfg.cache_dir
        );
        if not r4.ok or r4.exit_code != 0 {
            res.error = "\"git checkout\" for \"" + url + "\" failed";
            return res;
        }
        fsx_rm_rf(dir + "/.git");
        fsx_write_str(dir + "/.bun-tag", sha, 420);
    }
    res.resolved = sha;
    res.dir = dir;
    res.ok = True;
    return res;
}

def _pkg_from_dir(dir: str, value: str, out: SourcePkg) -> SourcePkg {
    m: PkgJson = pm_read_package_json(dir + "/package.json");
    if not m.ok {
        out.error = "no package.json in " + value + ": " + m.error;
        return out;
    }
    out.dir = dir;
    out.pj = m.json;
    out.ok = True;
    return out;
}

"""Fetch a github dependency and read its package.json (for the resolver)."""
def:pub pm_github_package(
    cfg: PmConfig, owner: str, repo: str, committish: str
) -> SourcePkg {
    out: SourcePkg = SourcePkg();
    sr: SourceResult = pm_ensure_github_cached(cfg, owner, repo, committish, "", "");
    if not sr.ok {
        out.error = sr.error;
        return out;
    }
    out.resolved = sr.resolved;
    out.integrity = sr.integrity;
    return _pkg_from_dir(sr.dir, "github:" + owner + "/" + repo, out);
}

"""Clone a git dependency and read its package.json (for the resolver)."""
def:pub pm_git_package(cfg: PmConfig, url: str, committish: str) -> SourcePkg {
    out: SourcePkg = SourcePkg();
    sr: SourceResult = pm_ensure_git_cached(cfg, url, committish, "");
    if not sr.ok {
        out.error = sr.error;
        return out;
    }
    out.resolved = sr.resolved;
    return _pkg_from_dir(sr.dir, url, out);
}

def _read_small(path: str) -> str {
    b: ByteBuf = fsx_read_bytes(path);
    if b.len <= 0 {
        return "";
    }
    s: str = bytes_to_str(b.ptr, 0, b.len);
    bytebuf_free(b);
    return s;
}

def _write_small(path: str, s: str) {
    fsx_write_str(path, s, 420);
}

"""The package.json of a tarball (fetched into the cache) or of a `file:` folder."""
def:pub pm_source_package(
    cfg: PmConfig, root_dir: str, kind: str, value: str, integrity: str
) -> SourcePkg {
    out: SourcePkg = SourcePkg();
    dir: str = "";
    if kind == "folder" {
        dir = value;
        if not dir.startswith("/") {
            dir = root_dir + "/" + value;
        }
        if not fsx_is_dir(dir) {
            out.error = "folder not found: " + value;
            return out;
        }
    } else {
        sr: SourceResult = pm_ensure_tarball_cached(cfg, root_dir, value, integrity);
        if not sr.ok {
            out.error = sr.error;
            return out;
        }
        dir = sr.dir;
        out.integrity = sr.integrity;
    }
    m: PkgJson = pm_read_package_json(dir + "/package.json");
    if not m.ok {
        out.error = "no package.json in " + value + ": " + m.error;
        return out;
    }
    out.dir = dir;
    out.pj = m.json;
    out.ok = True;
    return out;
}

"""Where the files of a lockfile package live, fetching into the cache when needed."""
def:pub pm_source_dir(cfg: PmConfig, root_dir: str, p: LockPkg) -> SourceResult {
    res: SourceResult = SourceResult();
    if p.kind == "npm" {
        fr: FetchResult = pm_ensure_cached(cfg, p.name, p.version, p.url, p.integrity);
        if not fr.ok {
            res.error = fr.error;
            return res;
        }
        res.dir = fr.cache_dir;
        res.ok = True;
        return res;
    }
    if p.kind == "tarball" {
        return pm_ensure_tarball_cached(cfg, root_dir, p.version, p.integrity);
    }
    if p.kind == "github" {
        gh: tuple[str, str, str] = pm_github_version_parts(p.version);
        return pm_ensure_github_cached(cfg, gh[0], gh[1], gh[2], p.url, p.integrity);
    }
    if p.kind == "git" {
        gv: tuple[str, str] = pm_git_version_parts(p.version);
        return pm_ensure_git_cached(cfg, gv[0], gv[1], p.url);
    }
    if p.kind == "folder" {
        dir: str = p.version;
        if not dir.startswith("/") {
            dir = root_dir + "/" + p.version;
        }
        if not fsx_is_dir(dir) {
            res.error = "folder not found: " + p.version;
            return res;
        }
        res.dir = dir;
        res.skip_node_modules = True;
        res.ok = True;
        return res;
    }
    res.error = "unsupported resolution for "
        + p.key
        + ": "
        + p.resolution
        + " (not implemented yet)";
    return res;
}
