"""`js_engine add <pkg>[@<spec>]…` — bun-compatible `add`.

Edits package.json like bun's PackageJSONEditor (the dependency goes into the
group chosen by -d / --optional / --peer, groups keep their key order, the
new entry is inserted alphabetically, a missing group is appended at the end
of the file, and the document is re-printed with its own indentation), then
runs the normal install with a forced resolution and prints
`installed <name>@<version>` for each added package.

Version written: the literal the user gave (`is-odd@3.0.1` → "3.0.1",
`x@^1` → "^1"); a bare name or a dist-tag resolves first and is written as
`^<version>` (or exactly with --exact).
"""

import from engine.src.ffi.libc { write }
import from engine.src.ffi.libuv { uv_hrtime }
import from engine.src.pm.config { PmArgs, PmConfig }
import from engine.src.pm.json {
    JVal,
    jv_get,
    jv_is_obj,
    jv_is_arr,
    jv_str,
    jv_object,
    jv_array,
    jv_set,
    jv_push,
    jv_string,
    jv_str_list,
    jv_has,
    json_quote,
    JV_STR,
    JV_NUM,
    JV_BOOL,
    JV_NULL,
    JV_ARR,
    JV_OBJ
}
import from engine.src.pm.project { PkgJson, pm_read_package_json }
import from engine.src.pm.depspec { DepSpec, depspec_parse, SPEC_NPM, SPEC_DIST_TAG }
import from engine.src.pm.manifest {
    Manifest,
    MVersion,
    manifest_fetch,
    manifest_find_best,
    manifest_find_dist_tag
}
import from engine.src.pm.semver {
    semver_group_is_exact,
    semver_group_exact_version,
    semver_format
}
import from engine.src.pm.fsx { fsx_is_file, fsx_write_str, fsx_perm }
import from engine.src.pm.install { pm_install_project, TrustCtx }

def _out(s: str) {
    write(1, s, len(s));
}
def _err(s: str) {
    write(2, s, len(s));
}

"""Split "name@spec" (scoped names keep their leading @)."""
def:pub pm_split_add_arg(arg: str) -> tuple[str, str] {
    start: int = 0;
    if arg.startswith("@") {
        start = 1;
    }
    at: int = arg.find("@", start);
    if at < 0 {
        return (arg, "");
    }
    return (arg[0:at], arg[at + 1:]);
}

"""Indentation unit of a JSON text (bun: guess_indentation): the whitespace
before the first nested key; two spaces when it cannot be told."""
def:pub pm_guess_indent(text: str) -> str {
    return _guess_indent(text);
}

def _guess_indent(text: str) -> str {
    lines: list[str] = text.split("\n");
    for line in lines {
        n: int = 0;
        while n < len(line) and (line[n] == " " or line[n] == "\t") {
            n = n + 1;
        }
        if n > 0 and n < len(line) and line[n] == "\"" {
            return line[0:n];
        }
    }
    return "  ";
}

def _print_json(v: JVal, indent: str, depth: int) -> str {
    if v.kind == JV_STR {
        return json_quote(v.s);
    }
    if v.kind == JV_NUM {
        if v.is_int {
            return str(v.i);
        }
        return str(v.num);
    }
    if v.kind == JV_BOOL {
        return "true" if v.b else "false";
    }
    if v.kind == JV_NULL {
        return "null";
    }
    pad: str = indent * (depth + 1);
    end_pad: str = indent * depth;
    if v.kind == JV_ARR {
        if len(v.items) == 0 {
            return "[]";
        }
        parts: list[str] = [];
        if v.single_line {
            # bun keeps arrays that were written on one line on one line
            for it in v.items {
                parts.append(_print_json(it, indent, depth + 1));
            }
            return "[" + ", ".join(parts) + "]";
        }
        for it in v.items {
            parts.append(pad + _print_json(it, indent, depth + 1));
        }
        return "[\n" + ",\n".join(parts) + "\n" + end_pad + "]";
    }
    if v.kind == JV_OBJ {
        if len(v.keys) == 0 {
            return "{}";
        }
        parts2: list[str] = [];
        if v.single_line {
            for k in v.keys {
                parts2.append(
                    json_quote(k) + ": " + _print_json(v.vals[k], indent, depth + 1)
                );
            }
            return "{ " + ", ".join(parts2) + " }";
        }
        for k in v.keys {
            parts2.append(
                pad + json_quote(k) + ": " + _print_json(v.vals[k], indent, depth + 1)
            );
        }
        return "{\n" + ",\n".join(parts2) + "\n" + end_pad + "}";
    }
    return "null";
}

"""Serialise package.json the way bun re-prints it after an edit."""
def:pub pm_print_package_json(v: JVal, indent: str) -> str {
    return _print_json(v, indent, 0) + "\n";
}

glob:pub PM_DEP_GROUPS: list[str] = [
         "dependencies",
         "devDependencies",
         "optionalDependencies",
         "peerDependencies"
     ];

"""Delete `key` from a JSON object; False when absent."""
def:pub pm_jv_delete(o: JVal, key: str) -> bool {
    if not jv_is_obj(o) or not (key in o.vals) {
        return False;
    }
    del o.vals[key];
    idx: int = o.keys.index(key);
    del o.keys[idx];
    return True;
}

"""bun's PackageJSONSort rank for top-level package.json keys; unknown keys sort
after the known ones."""
def _pj_rank(key: str) -> int {
    order: list[str] = [
        "name",
        "version",
        "author",
        "repository",
        "config",
        "main",
        "module",
        "dependencies",
        "devDependencies",
        "optionalDependencies",
        "peerDependencies",
        "exports"
    ];
    i: int = 0;
    while i < len(order) {
        if order[i] == key {
            return i;
        }
        i = i + 1;
    }
    return len(order);
}

def _pj_less(a: str, b: str) -> bool {
    ra: int = _pj_rank(a);
    rb: int = _pj_rank(b);
    if ra != rb {
        return ra < rb;
    }
    return a < b;
}

"""Re-order an object's keys: alphabetically (bun's alphabetizeProperties) or in
package.json's canonical top-level order (bun's packageJSONSort)."""
def:pub pm_jv_sort_keys(o: JVal, canonical: bool) {
    out: list[str] = [];
    used: dict[int, bool] = {};
    n: int = len(o.keys);
    k: int = 0;
    while k < n {
        best: int = -1;
        j: int = 0;
        while j < n {
            if not (j in used) {
                if best < 0 {
                    best = j;
                } elif canonical {
                    if _pj_less(o.keys[j], o.keys[best]) {
                        best = j;
                    }
                } elif o.keys[j] < o.keys[best] {
                    best = j;
                }
            }
            j = j + 1;
        }
        used[best] = True;
        out.append(o.keys[best]);
        k = k + 1;
    }
    o.keys = out;
}

"""Insert `name: spec` into `group` of the package.json object: existing group
→ replace or insert, then the whole group is re-alphabetized (bun's
PackageJSONEditor); missing group → appended at the end. The same name is
removed from the other dependency groups (bun moves it)."""
def:pub pm_package_json_add(pj: JVal, group: str, name: str, spec: str) {
    for og in PM_DEP_GROUPS {
        if og == group {
            continue;
        }
        pm_jv_delete(jv_get(pj, og), name);
    }
    g: JVal = jv_get(pj, group);
    if not jv_is_obj(g) {
        g = jv_object();
        jv_set(pj, group, g);
    }
    jv_set(g, name, jv_string(spec));
    pm_jv_sort_keys(g, False);
}

def:pub pm_cmd_add(eroot: str, args: PmArgs, cfg: PmConfig, banner: str) -> int {
    start: int = uv_hrtime();
    root_dir: str = cfg.cwd;
    pj_path: str = root_dir + "/package.json";
    if not fsx_is_file(pj_path) {
        _err("error: js_engine could not find a package.json file to install from\n");
        _err("note: Run \"js_engine init\" to initialize a project\n");
        return 1;
    }
    m: PkgJson = pm_read_package_json(pj_path);
    if not m.ok {
        _err("error: failed to parse '" + pj_path + "': " + m.error + "\n");
        return 1;
    }
    _out(banner + "\n");
    group: str = "dependencies";
    if cfg.add_kind == "dev" {
        group = "devDependencies";
    } elif cfg.add_kind == "optional" {
        group = "optionalDependencies";
    } elif cfg.add_kind == "peer" {
        group = "peerDependencies";
    }

    added: list[str] = [];
    for arg in args.positionals {
        ns: tuple[str, str] = pm_split_add_arg(arg);
        name: str = ns[0];
        spec_s: str = ns[1];
        if name == "" {
            _err("error: invalid package name \"" + arg + "\"\n");
            return 1;
        }
        spec: DepSpec = depspec_parse(name, spec_s);
        write_spec: str = spec_s;
        needs_resolve: bool = spec.tag == SPEC_DIST_TAG
            or (spec.tag == SPEC_NPM and spec_s == "");
        if needs_resolve {
            mf: Manifest = manifest_fetch(cfg, spec.name, False);
            if not mf.ok {
                _err("error: " + mf.error + "\n");
                return 1;
            }
            mv: MVersion = MVersion();
            if spec.tag == SPEC_DIST_TAG {
                mv = manifest_find_dist_tag(mf, spec.dist_tag);
            } else {
                mv = manifest_find_best(mf, spec.range);
            }
            if mv.version_str == "" {
                _err(
                    "error: package \""
                        + spec.name
                        + "\" with tag \""
                        + spec.dist_tag
                        + "\" not found\n"
                );
                return 1;
            }
            if cfg.exact {
                write_spec = mv.version_str;
            } else {
                write_spec = "^" + mv.version_str;
            }
            if spec.is_alias {
                write_spec = "npm:" + spec.name + "@" + write_spec;
            }
        }
        pm_package_json_add(m.json, group, name, write_spec);
        added.append(name);
    }
    # --trust: remember the trusted list as it was (the scripts decision uses it), then
    # add the requested names to "trustedDependencies" (bun does so on a fresh install too)
    trust: TrustCtx = TrustCtx(
        active=cfg.trust,
        requested=added,
        project_list=jv_str_list(jv_get(m.json, "trustedDependencies")),
        has_project_list=jv_has(m.json, "trustedDependencies")
    );
    if cfg.trust {
        pm_package_json_add_trusted(m.json, added);
    }
    if cfg.save {
        text: str = pm_print_package_json(m.json, _guess_indent(m.text));
        mode: int = fsx_perm(pj_path);
        if mode < 0 {
            mode = 420;
        }
        if fsx_write_str(pj_path, text, mode) != 0 {
            _err("error: failed to write package.json\n");
            return 1;
        }
    }
    rc: int = pm_install_project(
        eroot, cfg, root_dir, m.json, True, start, added, [], 0, trust
    );
    # dependencies whose scripts ran through the request trust join the list afterwards (bun's second edit)
    if cfg.save and len(trust.ran_via) > 0 {
        m2: PkgJson = pm_read_package_json(pj_path);
        if m2.ok and pm_package_json_add_trusted(m2.json, trust.ran_via) {
            mode2: int = fsx_perm(pj_path);
            if mode2 < 0 {
                mode2 = 420;
            }
            fsx_write_str(
                pj_path, pm_print_package_json(m2.json, _guess_indent(m2.text)), mode2
            );
        }
    }
    return rc;
}

"""Append `names` to package.json "trustedDependencies" (created when missing,
existing names skipped). bun fills the new slots from the end of the array, so
several new names land in reverse order. Returns whether anything was added."""
def:pub pm_package_json_add_trusted(pj: JVal, names: list[str]) -> bool {
    arr: JVal = jv_get(pj, "trustedDependencies");
    if not jv_is_arr(arr) {
        arr = jv_array();
        jv_set(pj, "trustedDependencies", arr);
    }
    existing: list[str] = jv_str_list(arr);
    fresh: list[str] = [];
    for n in names {
        if not (n in existing) and not (n in fresh) {
            fresh.append(n);
        }
    }
    k: int = len(fresh) - 1;
    while k >= 0 {
        jv_push(arr, jv_string(fresh[k]));
        k = k - 1;
    }
    return len(fresh) > 0;
}
