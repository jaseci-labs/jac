"""bun.lock (text lockfile, lockfileVersion 1) reader and writer.

Format (bun/src/install/lockfile/bun.lock.zig, `Stringifier`): JSONC with
trailing commas. `workspaces` maps workspace dir ("" = root) → name/version/
dependency groups; `packages` maps the hoisted install path of a package
(e.g. "is-even/is-odd/is-number" → node_modules/is-even/node_modules/is-odd/
node_modules/is-number) to an entry:

  npm         ["name@version", "<tarball url or '' for the default registry>", INFO, "sha512-…"]
  workspace   ["name@workspace:path"]
  folder      ["name@file:path", INFO]
  symlink     ["name@link:path", INFO]
  tarball     ["name@<url or path>", INFO, "integrity"?]
  root        ["name@root:", { bin }]
  git/github  ["name@git+url" | "name@github:user/repo", INFO, "<resolved>", "integrity"?]

INFO = { dependencies / devDependencies / optionalDependencies /
peerDependencies (each name → spec), optionalPeers [names], bundled, os, cpu,
bin | binDir }.

`lockfile_serialize` reproduces bun's bytes exactly for a parsed lockfile
(round-trip tested against the recorded goldens) so a fresh resolution only has
to fill the same model.
"""

import from engine.src.pm.json {
    JVal,
    JsonDoc,
    json_parse_bytes,
    jv_get,
    jv_get_str,
    jv_get_int,
    jv_has,
    jv_is_obj,
    jv_is_arr,
    jv_is_str,
    jv_is_missing,
    jv_str,
    jv_len,
    jv_at,
    jv_str_list,
    json_quote,
    jv_object,
    jv_set,
    jv_string,
    jv_array,
    jv_push,
    JV_STR,
    JV_OBJ,
    JV_ARR,
    JV_MISSING,
    JV_BOOL
}
import from engine.src.pm.bytes { ByteBuf }
import from engine.src.pm.fsx { fsx_read_bytes }
import from engine.src.pm.platform {
    pm_os_matches,
    pm_cpu_matches,
    pm_platform_to_json
}

glob:pub LOCK_GROUPS: list[str] = [
         "dependencies",
         "devDependencies",
         "optionalDependencies",
         "peerDependencies"
     ];

obj:pub LockDep {
    has name: str,
        spec: str,
        group: str = "dependencies",
        optional_peer: bool = False;
}

obj:pub LockWorkspace {
    has path: str = "",
        name: str = "",
        version: str = "",
        has_version: bool = False,
        deps: list[LockDep] = [],
        bin: JVal = JVal(),
        bin_dir: str = "";  # "" = root
}

# "bin" value (string or object)
# "binDir" value
obj:pub LockPkg {
    has key: str = "",
        dep_name: str = "",
        parent_key: str = "",
        depth: int = 0,
        name: str = "",
        version: str = "",
        kind: str = "npm",
        resolution: str = "",
        url: str = "",
        integrity: str = "",
        has_integrity: bool = False,
        info: JVal = JVal(),
        deps: list[LockDep] = [],
        bin: JVal = JVal(),
        bin_dir: str = "",
        os: JVal = JVal(),
        cpu: JVal = JVal(),
        bundled: bool = False;  # install-path key
}

# alias: last key segment

# real package name
# npm version, or the payload after the tag
# npm | workspace | folder | symlink | tarball | root | git | github
# the full "name@…" string
# npm: tarball URL ("" = default registry); git: resolved
obj:pub Lockfile {
    has ok: bool = False,
        error: str = "",
        path: str = "",
        lockfile_version: int = 1,
        config_version: int = 1,
        has_config_version: bool = True,
        workspaces: list[LockWorkspace] = [],
        packages: list[LockPkg] = [],
        by_key: dict[str, int] = {},
        trusted: list[str] = [],
        patched: JVal = JVal(),
        overrides: JVal = JVal(),
        catalog: JVal = JVal(),
        catalogs: JVal = JVal();
}

# ── keys ──────────────────────────────────────────────────────────────────────

"""Split an install-path key into dependency names ("@scope/name" stays one)."""
def:pub lockfile_key_segments(key: str) -> list[str] {
    out: list[str] = [];
    parts: list[str] = key.split("/");
    i: int = 0;
    while i < len(parts) {
        seg: str = parts[i];
        if seg.startswith("@") and i + 1 < len(parts) {
            out.append(seg + "/" + parts[i + 1]);
            i = i + 2;
        } else {
            out.append(seg);
            i = i + 1;
        }
    }
    return out;
}

"""node_modules path for a key, relative to the project root."""
def:pub lockfile_key_to_path(key: str) -> str {
    return "node_modules/" + "/node_modules/".join(lockfile_key_segments(key));
}

"""Split "name@rest" at the '@' that ends the (possibly scoped) name."""
def:pub lockfile_split_resolution(res: str) -> tuple[str, str] {
    start: int = 0;
    if res.startswith("@") {
        start = 1;
    }
    at: int = res.find("@", start);
    if at < 0 {
        return (res, "");
    }
    return (res[0:at], res[at + 1:]);
}

def _kind_of(version: str) -> str {
    if version.startswith("workspace:") {
        return "workspace";
    }
    if version.startswith("file:") {
        return "folder";
    }
    if version.startswith("link:") {
        return "symlink";
    }
    if version.startswith("root:") {
        return "root";
    }
    if version.startswith("git+") {
        return "git";
    }
    if version.startswith("github:") {
        return "github";
    }
    if version.startswith("http://") or version.startswith("https://") {
        return "tarball";
    }
    if version.endswith(".tgz")
        or version.endswith(".tar.gz")
        or version.endswith(".tar") {
        return "tarball";
    }
    return "npm";
}

# ── reading ───────────────────────────────────────────────────────────────────

def _read_deps(info: JVal, out: list[LockDep]) {
    optional_peers: list[str] = jv_str_list(jv_get(info, "optionalPeers"));
    for group in LOCK_GROUPS {
        g: JVal = jv_get(info, group);
        if not jv_is_obj(g) {
            continue;
        }
        for name in g.keys {
            spec: JVal = g.vals[name];
            d: LockDep = LockDep(name=name, spec=jv_str(spec), group=group);
            if group == "peerDependencies" and (name in optional_peers) {
                d.optional_peer = True;
            }
            out.append(d);
        }
    }
}

def _read_workspace(path: str, v: JVal) -> LockWorkspace {
    ws: LockWorkspace = LockWorkspace(path=path);
    ws.name = jv_get_str(v, "name", "");
    if jv_has(v, "version") {
        ws.version = jv_get_str(v, "version", "");
        ws.has_version = True;
    }
    if jv_has(v, "bin") {
        ws.bin = jv_get(v, "bin");
    }
    if jv_has(v, "binDir") {
        ws.bin_dir = jv_get_str(v, "binDir", "");
    }
    _read_deps(v, ws.deps);
    return ws;
}

def _read_package(key: str, arr: JVal) -> LockPkg {
    p: LockPkg = LockPkg(key=key);
    segs: list[str] = lockfile_key_segments(key);
    p.depth = len(segs) - 1;
    if len(segs) > 0 {
        p.dep_name = segs[len(segs) - 1];
    }
    if len(segs) > 1 {
        p.parent_key = "/".join(segs[0:len(segs) - 1]);
    }
    p.resolution = jv_str(jv_at(arr, 0));
    nv: tuple[str, str] = lockfile_split_resolution(p.resolution);
    p.name = nv[0];
    p.kind = _kind_of(nv[1]);
    p.version = nv[1];
    if p.kind == "workspace" {
        p.version = nv[1][10:];
    } elif p.kind == "folder" {
        p.version = nv[1][5:];
    } elif p.kind == "symlink" {
        p.version = nv[1][5:];
    } elif p.kind == "root" {
        p.version = "";
    }
    n: int = jv_len(arr);
    info_idx: int = 1;
    if p.kind == "npm" {
        p.url = jv_str(jv_at(arr, 1));
        info_idx = 2;
        if n > 3 {
            p.integrity = jv_str(jv_at(arr, 3));
            p.has_integrity = True;
        }
    } elif p.kind == "git" or p.kind == "github" {
        if n > 2 {
            p.url = jv_str(jv_at(arr, 2));
        }
        if n > 3 {
            p.integrity = jv_str(jv_at(arr, 3));
            p.has_integrity = True;
        }
    } elif p.kind == "tarball" {
        if n > 2 {
            p.integrity = jv_str(jv_at(arr, 2));
            p.has_integrity = True;
        }
    }
    if n > info_idx and jv_is_obj(jv_at(arr, info_idx)) {
        p.info = jv_at(arr, info_idx);
        _read_deps(p.info, p.deps);
        if jv_has(p.info, "bin") {
            p.bin = jv_get(p.info, "bin");
        }
        if jv_has(p.info, "binDir") {
            p.bin_dir = jv_get_str(p.info, "binDir", "");
        }
        p.os = jv_get(p.info, "os");
        p.cpu = jv_get(p.info, "cpu");
        b: JVal = jv_get(p.info, "bundled");
        if b.kind == JV_BOOL {
            p.bundled = b.b;
        }
    } else {
        p.info = jv_object();
    }
    return p;
}

def:pub lockfile_parse_bytes(ptr: int, n: int) -> Lockfile {
    lf: Lockfile = Lockfile();
    doc: JsonDoc = json_parse_bytes(ptr, n);
    if not doc.ok {
        lf.error = "failed to parse bun.lock: "
            + doc.error
            + " (line "
            + str(doc.line)
            + ")";
        return lf;
    }
    top: JVal = doc.value;
    if not jv_is_obj(top) {
        lf.error = "bun.lock: expected an object";
        return lf;
    }
    lf.lockfile_version = jv_get_int(top, "lockfileVersion", 0);
    if lf.lockfile_version != 0 and lf.lockfile_version != 1 {
        lf.error = "bun.lock: unsupported lockfileVersion " + str(lf.lockfile_version);
        return lf;
    }
    lf.has_config_version = jv_has(top, "configVersion");
    lf.config_version = jv_get_int(top, "configVersion", 0);
    ws: JVal = jv_get(top, "workspaces");
    if jv_is_obj(ws) {
        for path in ws.keys {
            lf.workspaces.append(_read_workspace(path, ws.vals[path]));
        }
    }
    if len(lf.workspaces) == 0 {
        lf.workspaces.append(LockWorkspace(path=""));
    }
    lf.trusted = jv_str_list(jv_get(top, "trustedDependencies"));
    lf.patched = jv_get(top, "patchedDependencies");
    lf.overrides = jv_get(top, "overrides");
    lf.catalog = jv_get(top, "catalog");
    lf.catalogs = jv_get(top, "catalogs");
    pk: JVal = jv_get(top, "packages");
    if jv_is_obj(pk) {
        for key in pk.keys {
            ent: JVal = pk.vals[key];
            if not jv_is_arr(ent) or jv_len(ent) == 0 {
                continue;
            }
            lf.by_key[key] = len(lf.packages);
            lf.packages.append(_read_package(key, ent));
        }
    }
    lf.ok = True;
    return lf;
}

"""Load and parse `path`; `ok` false with `error` "" when the file is absent."""
def:pub lockfile_load(path: str) -> Lockfile {
    b: ByteBuf = fsx_read_bytes(path);
    if b.len < 0 {
        lf: Lockfile = Lockfile();
        lf.path = path;
        return lf;
    }
    lf2: Lockfile = lockfile_parse_bytes(b.ptr, b.len);
    lf2.path = path;
    return lf2;
}

def:pub lockfile_root(lf: Lockfile) -> LockWorkspace {
    for ws in lf.workspaces {
        if ws.path == "" {
            return ws;
        }
    }
    return LockWorkspace(path="");
}

def:pub lockfile_get(lf: Lockfile, key: str) -> LockPkg {
    if key in lf.by_key {
        return lf.packages[lf.by_key[key]];
    }
    return LockPkg(key="");
}

"""Resolve dependency `name` as seen from install path `from_key` ("" = root):
walk up the key chain, the way Node's resolver would."""
def:pub lockfile_resolve_from(lf: Lockfile, from_key: str, name: str) -> LockPkg {
    segs: list[str] = [];
    if from_key != "" {
        segs = lockfile_key_segments(from_key);
    }
    while True {
        cand: str = name;
        if len(segs) > 0 {
            cand = "/".join(segs) + "/" + name;
        }
        if cand in lf.by_key {
            return lf.packages[lf.by_key[cand]];
        }
        if len(segs) == 0 {
            break;
        }
        del segs[len(segs) - 1];
    }
    return LockPkg(key="");
}

"""Whether the package installs on this platform (bun skips os/cpu mismatches)."""
def:pub lockfile_pkg_enabled(p: LockPkg, os_name: str, cpu_name: str) -> bool {
    return pm_os_matches(p.os, os_name) and pm_cpu_matches(p.cpu, cpu_name);
}

# ── writing ───────────────────────────────────────────────────────────────────

def _ind(n: int) -> str {
    return "  " * n;
}

"""Single-line bin: string, or `{ "a": "b", "c": "d" }`."""
def _bin_single_line(bin: JVal) -> str {
    if bin.kind == JV_STR {
        return json_quote(bin.s);
    }
    if bin.kind != JV_OBJ {
        return "\"\"";
    }
    parts: list[str] = [];
    for k in bin.keys {
        parts.append(" " + json_quote(k) + ": " + json_quote(jv_str(bin.vals[k])));
    }
    return "{" + ",".join(parts) + " }";
}

"""Multi-line bin (workspaces section), `indent` is the key's indentation."""
def _bin_multi_line(bin: JVal, indent: int) -> str {
    if bin.kind == JV_STR {
        return json_quote(bin.s);
    }
    if bin.kind != JV_OBJ {
        return "\"\"";
    }
    out: list[str] = ["{\n"];
    for k in bin.keys {
        out.append(
            _ind(indent + 1)
                + json_quote(k)
                + ": "
                + json_quote(jv_str(bin.vals[k]))
                + ",\n"
        );
    }
    out.append(_ind(indent) + "}");
    return "".join(out);
}

"""os/cpu value as bun prints it (canonical form, see pm_platform_to_json)."""
def _platform_field(v: JVal, is_os: bool) -> str {
    return pm_platform_to_json(v, is_os);
}

def _deps_in_group(deps: list[LockDep], group: str) -> list[LockDep] {
    out: list[LockDep] = [];
    for d in deps {
        if d.group == group {
            out.append(d);
        }
    }
    return out;
}

def _optional_peers(deps: list[LockDep]) -> list[str] {
    out: list[str] = [];
    for d in deps {
        if d.group == "peerDependencies" and d.optional_peer {
            out.append(d.name);
        }
    }
    return out;
}

"""INFO object on one line: `{ "dependencies": { "a": "^1" }, "os": "linux" }`
or `{}` when empty."""
def:pub lockfile_info_object(p: LockPkg) -> str {
    parts: list[str] = [];
    for group in LOCK_GROUPS {
        gd: list[LockDep] = _deps_in_group(p.deps, group);
        if len(gd) == 0 {
            continue;
        }
        items: list[str] = [];
        for d in gd {
            items.append(json_quote(d.name) + ": " + json_quote(d.spec));
        }
        parts.append(" " + json_quote(group) + ": { " + ", ".join(items) + " }");
    }
    op: list[str] = _optional_peers(p.deps);
    if len(op) > 0 {
        q: list[str] = [];
        for name in op {
            q.append(json_quote(name));
        }
        parts.append(" \"optionalPeers\": [" + ", ".join(q) + "]");
    }
    if p.bundled {
        parts.append(" \"bundled\": true");
    }
    if not jv_is_missing(p.os) {
        parts.append(" \"os\": " + _platform_field(p.os, True));
    }
    if not jv_is_missing(p.cpu) {
        parts.append(" \"cpu\": " + _platform_field(p.cpu, False));
    }
    if p.bin_dir != "" {
        parts.append(" \"binDir\": " + json_quote(p.bin_dir));
    } elif not jv_is_missing(p.bin) {
        parts.append(" \"bin\": " + _bin_single_line(p.bin));
    }
    if len(parts) == 0 {
        return "{}";
    }
    return "{" + ",".join(parts) + " }";
}

"""One package entry (the value part), bun's per-kind layout."""
def:pub lockfile_entry(p: LockPkg) -> str {
    info: str = lockfile_info_object(p);
    if p.kind == "workspace" {
        return "[" + json_quote(p.name + "@workspace:" + p.version) + "]";
    }
    if p.kind == "root" {
        inner: str = "";
        if p.bin_dir != "" {
            inner = " \"binDir\": " + json_quote(p.bin_dir) + " ";
        } elif not jv_is_missing(p.bin) {
            inner = " \"bin\": " + _bin_single_line(p.bin) + " ";
        }
        return "[" + json_quote(p.name + "@root:") + ", {" + inner + "}]";
    }
    if p.kind == "npm" {
        return "["
            + json_quote(p.name + "@" + p.version)
            + ", "
            + json_quote(p.url)
            + ", "
            + info
            + ", "
            + json_quote(p.integrity)
            + "]";
    }
    if p.kind == "git" or p.kind == "github" {
        tail: str = ", " + json_quote(p.url);
        if p.has_integrity {
            tail = tail + ", " + json_quote(p.integrity);
        }
        return "[" + json_quote(p.name + "@" + p.version) + ", " + info + tail + "]";
    }
    if p.kind == "tarball" {
        tail2: str = "";
        if p.has_integrity {
            tail2 = ", " + json_quote(p.integrity);
        }
        return "[" + json_quote(p.name + "@" + p.version) + ", " + info + tail2 + "]";
    }
    # folder / symlink
    return "[" + json_quote(p.resolution) + ", " + info + "]";
}

def _workspace_block(ws: LockWorkspace, indent: int) -> str {
    # `indent` is the indentation of the key line; members are indent+1
    out: list[str] = [];
    any: bool = False;
    if ws.path == "" {
        out.append("\"\": {");
        if ws.name != "" {
            out.append("\n" + _ind(indent + 1) + "\"name\": " + json_quote(ws.name));
            any = True;
        }
    } else {
        out.append(json_quote(ws.path) + ": {");
        out.append("\n" + _ind(indent + 1) + "\"name\": " + json_quote(ws.name));
        if ws.has_version {
            out.append(
                ",\n" + _ind(indent + 1) + "\"version\": " + json_quote(ws.version)
            );
        }
        if ws.bin_dir != "" {
            out.append(
                ",\n" + _ind(indent + 1) + "\"binDir\": " + json_quote(ws.bin_dir)
            );
        } elif not jv_is_missing(ws.bin) {
            out.append(
                ",\n"
                    + _ind(indent + 1)
                    + "\"bin\": "
                    + _bin_multi_line(ws.bin, indent + 1)
            );
        }
        any = True;
    }
    for group in LOCK_GROUPS {
        gd: list[LockDep] = _deps_in_group(ws.deps, group);
        if len(gd) == 0 {
            continue;
        }
        if any {
            out.append(",");
        }
        out.append("\n" + _ind(indent + 1) + json_quote(group) + ": {\n");
        lines: list[str] = [];
        for d in gd {
            lines.append(
                _ind(indent + 2) + json_quote(d.name) + ": " + json_quote(d.spec)
            );
        }
        out.append(",\n".join(lines));
        out.append(",\n" + _ind(indent + 1) + "}");
        any = True;
    }
    op: list[str] = _optional_peers(ws.deps);
    if len(op) > 0 {
        out.append(",\n" + _ind(indent + 1) + "\"optionalPeers\": [\n");
        for name in op {
            out.append(_ind(indent + 2) + json_quote(name) + ",\n");
        }
        out.append(_ind(indent + 1) + "]");
    }
    if any {
        out.append(",\n" + _ind(indent));
    }
    out.append("},");
    return "".join(out);
}

"""Sort key bun uses for package entries: depth of the install path first,
then the parent path, then the dependency name (all byte-wise)."""
def _pkg_sort_key(p: LockPkg) -> str {
    return str(p.depth).zfill(6) + chr(1) + p.parent_key + chr(1) + p.dep_name;
}

"""Serialize to bun's exact text format."""
def:pub lockfile_serialize(lf: Lockfile) -> str {
    out: list[str] = ["{\n"];
    out.append("  \"lockfileVersion\": " + str(lf.lockfile_version) + ",\n");
    if lf.has_config_version {
        out.append("  \"configVersion\": " + str(lf.config_version) + ",\n");
    }
    out.append("  \"workspaces\": {\n");
    rootws: LockWorkspace = lockfile_root(lf);
    out.append("    " + _workspace_block(rootws, 2));
    others: list[LockWorkspace] = [];
    for ws in lf.workspaces {
        if ws.path != "" {
            others.append(ws);
        }
    }
    paths: list[str] = [];
    for ws in others {
        paths.append(ws.path);
    }
    paths.sort();
    for pth in paths {
        for ws in others {
            if ws.path == pth {
                out.append("\n    " + _workspace_block(ws, 2));
                break;
            }
        }
    }
    out.append("\n  },\n");
    if len(lf.trusted) > 0 {
        out.append("  \"trustedDependencies\": [\n");
        for t in lf.trusted {
            out.append("    " + json_quote(t) + ",\n");
        }
        out.append("  ],\n");
    }
    if jv_is_obj(lf.patched) and jv_len(lf.patched) > 0 {
        out.append("  \"patchedDependencies\": {\n");
        for k in lf.patched.keys {
            out.append(
                "    "
                    + json_quote(k)
                    + ": "
                    + json_quote(jv_str(lf.patched.vals[k]))
                    + ",\n"
            );
        }
        out.append("  },\n");
    }
    if jv_is_obj(lf.overrides) and jv_len(lf.overrides) > 0 {
        out.append("  \"overrides\": {\n");
        for k in lf.overrides.keys {
            out.append(
                "    "
                    + json_quote(k)
                    + ": "
                    + json_quote(jv_str(lf.overrides.vals[k]))
                    + ",\n"
            );
        }
        out.append("  },\n");
    }
    if jv_is_obj(lf.catalog) and jv_len(lf.catalog) > 0 {
        out.append("  \"catalog\": {\n");
        for k in lf.catalog.keys {
            out.append(
                "    "
                    + json_quote(k)
                    + ": "
                    + json_quote(jv_str(lf.catalog.vals[k]))
                    + ",\n"
            );
        }
        out.append("  },\n");
    }
    if jv_is_obj(lf.catalogs) and jv_len(lf.catalogs) > 0 {
        out.append("  \"catalogs\": {\n");
        for cname in lf.catalogs.keys {
            cat: JVal = lf.catalogs.vals[cname];
            out.append("    " + json_quote(cname) + ": {\n");
            if jv_is_obj(cat) {
                for k in cat.keys {
                    out.append(
                        "      "
                            + json_quote(k)
                            + ": "
                            + json_quote(jv_str(cat.vals[k]))
                            + ",\n"
                    );
                }
            }
            out.append("    },\n");
        }
        out.append("  },\n");
    }
    out.append("  \"packages\": {");
    keys: list[str] = [];
    by_sort: dict[str, LockPkg] = {};
    for p in lf.packages {
        sk: str = _pkg_sort_key(p);
        keys.append(sk);
        by_sort[sk] = p;
    }
    keys.sort();
    first: bool = True;
    for sk in keys {
        p: LockPkg = by_sort[sk];
        if first {
            out.append("\n    ");
            first = False;
        } else {
            out.append(",\n\n    ");
        }
        out.append(json_quote(p.key) + ": " + lockfile_entry(p));
    }
    if not first {
        out.append(",\n  ");
    }
    out.append("}\n}\n");
    return "".join(out);
}
