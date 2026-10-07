"""
Node-compatible module resolution (CJS + ESM import()).

Single canonical resolver used by require(), require.resolve, import(), and
module.createRequire().  Separates resolution (pure path + format) from loading
in vm.na.jac.

Node references:
  https://nodejs.org/api/esm.html#resolution-algorithm
  https://nodejs.org/api/modules.html#all-together
"""

import from engine.src.builtins.path_utils {
    path_split,
    path_normalize,
    path_dirname,
    path_abspath
}
import from engine.src.builtins.fs {
    path_exists,
    path_is_directory,
    _read_file_sync_str
}
import from engine.src.builtins.json { js_json_parse }
import from engine.src.builtins.module_registry { is_builtin_module }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    jsv_is_string_cell,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_null,
    jsv_to_table_id,
    jsv_from_string_id
}
import from engine.src.runtime.jsobject {
    js_object_get,
    js_object_has_own,
    js_object_all_keys,
    js_object_keys
}
import from engine.src.builtins.array { js_is_array, js_array_get, js_array_len }
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.mem { byte_chr }
import from engine.src.runtime.error {
    make_module_not_found,
    make_err_esm_module_not_found,
    make_err_package_path_not_exported,
    make_err_invalid_package_target,
    make_err_require_esm,
    make_err_package_import_not_defined
}

# ── Result type ──────────────────────────────────────────────────────────────

obj ResolveResult {
    has ok: int = 0,
        path: str = "",
        format: str = "",
        err: JSValue = js_undefined();
}

# "cjs-js" | "cjs-json" | "esm-js" | "builtin"
def _ok_result(path: str, format: str) -> ResolveResult {
    return ResolveResult(ok=1, path=path, format=format, err=js_undefined());
}

def _err_result(err: JSValue) -> ResolveResult {
    return ResolveResult(ok=0, path="", format="", err=err);
}

# ── Error helpers ───────────────────────────────────────────────────────────

"""Return the correct module-not-found error depending on CJS vs ESM context."""
def _mnf(msg: str, is_esm_import: int) -> JSValue {
    if is_esm_import != 0 {
        return make_err_esm_module_not_found(msg);
    }
    return make_module_not_found(msg);
}

# ── Path utilities — imported from src.builtins.path_utils ─────────────────

def mr_path_has_ext(path: str) -> bool {
    n: int = len(path);
    if n >= 3 and path[n - 3] == "." and path[n - 2] == "j" and path[n - 1] == "s" {
        return True;
    }
    if n >= 4
        and path[n - 4] == "."
        and path[n - 3] == "m"
        and path[n - 2] == "j"
        and path[n - 1] == "s" {
        return True;
    }
    if n >= 4
        and path[n - 4] == "."
        and path[n - 3] == "c"
        and path[n - 2] == "j"
        and path[n - 1] == "s" {
        return True;
    }
    if n >= 5
        and path[n - 5] == "."
        and path[n - 4] == "j"
        and path[n - 3] == "s"
        and path[n - 2] == "o"
        and path[n - 1] == "n" {
        return True;
    }
    if n >= 5
        and path[n - 5] == "."
        and path[n - 4] == "n"
        and path[n - 3] == "o"
        and path[n - 2] == "d"
        and path[n - 1] == "e" {
        return True;
    }
    if n >= 5
        and path[n - 5] == "."
        and path[n - 4] == "w"
        and path[n - 3] == "a"
        and path[n - 2] == "s"
        and path[n - 1] == "m" {
        return True;
    }
    return False;
}

def mr_ends_with(s: str, suffix: str) -> bool {
    ns: int = len(s);
    nf: int = len(suffix);
    if nf > ns {
        return False;
    }
    i: int = 0;
    while i < nf {
        if s[ns - nf + i] != suffix[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def _resolver_is_relative_or_absolute(spec: str) -> bool {
    if len(spec) == 0 {
        return False;
    }
    if spec[0] == "/" {
        return True;
    }
    # Bare "." / ".." are relative (Node: require('.') → package root / index)
    if spec == "." or spec == ".." {
        return True;
    }
    if len(spec) >= 2 and spec[0] == "." and spec[1] == "/" {
        return True;
    }
    if len(spec) >= 3 and spec[0] == "." and spec[1] == "." and spec[2] == "/" {
        return True;
    }
    return False;
}

# ── JSON / package.json helpers ───────────────────────────────────────────────

glob _PKG_JSON_CACHE: dict[str, JSValue] = {};

def _jv_str(jsobj: JSValue, key: str) -> str {
    if not jsv_is_object_cell(jsobj) {
        return "";
    }
    v: JSValue = js_object_get(jsobj, str_intern(key));
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

def _read_pkg_json(pkg_dir: str) -> JSValue {
    if pkg_dir in _PKG_JSON_CACHE {
        return _PKG_JSON_CACHE[pkg_dir];
    }
    pj_path: str = path_abspath("package.json", pkg_dir);
    raw: JSValue = _read_file_sync_str(pj_path);
    if jsv_is_undefined(raw) {
        return js_undefined();
    }
    txt: str = str_from_id(jsv_to_table_id(raw));
    parsed: JSValue = js_json_parse([jsv_from_string_id(str_intern(txt))]);
    # Pin against mark-and-sweep: a glob dict is invisible to gc_mark_roots,
    # so without this the parsed exports/imports object tree is swept while
    # the cache still points at the recycled slot — later subpath resolution
    # against the SAME package reads garbage and fails with
    # "Cannot find module '<target>' in package" (vite@6 'vite/module-runner'
    # under --gc). Same pattern as _MODULE_CACHE exports in modules.jac.
    gc_pin_value(parsed);
    _PKG_JSON_CACHE[pkg_dir] = parsed;
    return parsed;
}

def _nearest_package_root(from_dir: str) -> str {
    cur: str = from_dir;
    prev: str = "";
    while cur != prev {
        pj: str = path_abspath("package.json", cur);
        if path_exists(pj) {
            return cur;
        }
        prev = cur;
        if cur == "" or cur == "/" {
            break;
        }
        cur = path_dirname(cur);
    }
    return "";
}

"""Nearest package.json `type` for a file path (`module` or `commonjs`)."""
def:pub package_type_for_path(abs_path: str) -> str {
    return _package_type_for_path(abs_path);
}

def _package_type_for_path(abs_path: str) -> str {
    # Walk up from file dir to find nearest package.json.
    # Node.js spec: the NEAREST package.json determines the module type.
    # If it has "type":"module" → ESM; otherwise (no "type" or "type":"commonjs") → CJS.
    # Do NOT walk past a package.json that lacks a "type" field; the search stops there.
    d: str = path_dirname(abs_path);
    cur: str = d;
    prev: str = "";
    while cur != prev {
        pj: JSValue = _read_pkg_json(cur);
        if jsv_is_object_cell(pj) {
            t: str = _jv_str(pj, "type");
            if t == "module" {
                return "module";
            }
            # Found a package.json — stop here regardless of "type" value.
            # Missing "type" defaults to "commonjs" per Node.js spec.
            return "commonjs";
        }
        prev = cur;
        if cur == "" or cur == "/" {
            break;
        }
        cur = path_dirname(cur);
    }
    return "commonjs";
}

def _format_for_file(abs_path: str, is_esm_import: int) -> str {
    if mr_ends_with(abs_path, ".node") {
        return "napi";
    }
    if mr_ends_with(abs_path, ".json") {
        return "cjs-json";
    }
    if mr_ends_with(abs_path, ".wasm") {
        return "wasm";
    }
    if mr_ends_with(abs_path, ".mjs") {
        return "esm-js";
    }
    if mr_ends_with(abs_path, ".cjs") {
        return "cjs-js";
    }
    if mr_ends_with(abs_path, ".js") {
        pt: str = _package_type_for_path(abs_path);
        if pt == "module" {
            return "esm-js";
        }
        return "cjs-js";
    }
    return "cjs-js";
}

# ── File probing (CJS extension algorithm) ───────────────────────────────────

def _probe_file_path(base: str) -> str {
    # Existing file (not a directory) — use as-is.
    if path_exists(base) and not path_is_directory(base) {
        return base;
    }
    # Directory or extension-less path: try Node's CJS extension / index algorithm.
    # (Directories must never be returned as the resolved module path.)
    if path_is_directory(base) or not mr_path_has_ext(base) {
        cands: list[str] = [
            base + ".js",
            base + ".json",
            base + ".node",
            base + "/index.js",
            base + "/index.json",
            base + "/index.node"
        ];
        ci: int = 0;
        while ci < len(cands) {
            if path_exists(cands[ci]) and not path_is_directory(cands[ci]) {
                return cands[ci];
            }
            ci = ci + 1;
        }
    }
    return "";
}

# ── Conditional exports ───────────────────────────────────────────────────────

def _resolve_conditions(val: JSValue, is_esm_import: int) -> str {
    # String target
    if jsv_is_string_cell(val) {
        return str_from_id(jsv_to_table_id(val));
    }
    if not jsv_is_object_cell(val) {
        return "";
    }
    # Array fallback form (Node "package exports" alternatives), e.g. acorn:
    #   ".": [{ "import": "...", "require": "..." }, "./dist/acorn.js"]
    # Try each alternative in order; first one that resolves wins.
    if js_is_array(val) {
        alt_n: int = js_array_len(val);
        alt_i: int = 0;
        while alt_i < alt_n {
            alt: str = _resolve_conditions(js_array_get(val, alt_i), is_esm_import);
            if alt != "" {
                return alt;
            }
            alt_i = alt_i + 1;
        }
        return "";
    }
    # Iterate condition object keys in declaration order (respects package.json order).
    # Unrecognised conditions (e.g. "vite", "development") are skipped — A-C2 future work.
    keys: list[int] = js_object_keys(val);
    ki: int = 0;
    while ki < len(keys) {
        k_id: int = keys[ki];
        k: str = str_from_id(k_id);
        matched: bool = False;
        if k == "default" {
            matched = True;
        } elif k == "import" and is_esm_import != 0 {
            matched = True;
        } elif k == "require" and is_esm_import == 0 {
            matched = True;
        } elif k == "node" {
            matched = True;
        }
        if matched {
            v: JSValue = js_object_get(val, k_id);
            nested: str = _resolve_conditions(v, is_esm_import);
            if nested != "" {
                return nested;
            }
        }
        ki = ki + 1;
    }
    return "";
}

def _validate_export_target(target: str, pkg_root: str) -> bool {
    if len(target) < 2 {
        return False;
    }
    if target[0] != "." or target[1] != "/" {
        return False;
    }
    if mr_ends_with(target, "/") {
        return False;
    }
    # Reject targets that escape package root via ../
    joined: str = path_abspath(target[2:], pkg_root);
    root_norm: str = path_normalize(pkg_root);
    if not (mr_starts_with(joined, root_norm + "/") or joined == root_norm) {
        return False;
    }
    return True;
}

def mr_starts_with(hay: str, needle: str) -> bool {
    if len(needle) > len(hay) {
        return False;
    }
    i: int = 0;
    while i < len(needle) {
        if hay[i] != needle[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def _match_export_key(request: str, key: str) -> bool {
    if key == request {
        return True;
    }
    if "*" in key {
        star: int = -1;
        ki: int = 0;
        while ki < len(key) {
            if key[ki] == "*" {
                star = ki;
            }
            ki = ki + 1;
        }
        if star >= 0 {
            prefix: str = key[0:star];
            suffix: str = key[star + 1:];
            if mr_starts_with(request, prefix) and mr_ends_with(request, suffix) {
                return True;
            }
        }
    }
    return False;
}

def _substitute_export_pattern(request: str, pattern: str, target_pat: str) -> str {
    if not _match_export_key(request, pattern) {
        return "";
    }
    star_p: int = -1;
    pi: int = 0;
    while pi < len(pattern) {
        if pattern[pi] == "*" {
            star_p = pi;
        }
        pi = pi + 1;
    }
    if star_p < 0 {
        return target_pat;
    }
    pfx: str = pattern[0:star_p];
    sfx: str = pattern[star_p + 1:];
    mid: str = request[len(pfx):len(request) - len(sfx)];
    star_t: int = -1;
    ti: int = 0;
    while ti < len(target_pat) {
        if target_pat[ti] == "*" {
            star_t = ti;
        }
        ti = ti + 1;
    }
    if star_t < 0 {
        return target_pat;
    }
    out: str = target_pat[0:star_t] + mid + target_pat[star_t + 1:];
    if out[0] != "." {
        out = "./" + out;
    }
    return out;
}

def _lookup_exports(exports_val: JSValue, subpath: str, is_esm_import: int) -> str {
    if jsv_is_string_cell(exports_val) {
        if subpath == "." or subpath == "" {
            return str_from_id(jsv_to_table_id(exports_val));
        }
        return "";
    }
    if not jsv_is_object_cell(exports_val) {
        return "";
    }
    req: str = subpath;
    if req == "" {
        req = ".";
    }
    if req[0] != "." {
        req = "./" + req;
    }
    # Top-level array form: `"exports": [alt1, alt2]` — alternatives for ".".
    if js_is_array(exports_val) {
        if req == "." {
            return _resolve_conditions(exports_val, is_esm_import);
        }
        return "";
    }
    keys: list[str] = _object_keys(exports_val);
    # Bare-conditions shorthand (Node): when NO key starts with ".", the whole
    # object is the conditions map for the "." subpath, e.g.
    # @rollup/plugin-json: {"types": ..., "import": ..., "default": ...}.
    if not js_is_array(exports_val) {
        has_subpath_key: bool = False;
        hk: int = 0;
        while hk < len(keys) {
            hkk: str = keys[hk];
            if len(hkk) > 0 and hkk[0] == "." {
                has_subpath_key = True;
                break;
            }
            hk = hk + 1;
        }
        if not has_subpath_key {
            if req == "." {
                return _resolve_conditions(exports_val, is_esm_import);
            }
            return "";
        }
    }
    # Exact match first, then patterns
    best: str = "";
    ki: int = 0;
    while ki < len(keys) {
        k: str = keys[ki];
        if k == req and not _is_pattern_key(k) {
            t: str = _resolve_conditions(
                js_object_get(exports_val, str_intern(k)), is_esm_import
            );
            if t != "" {
                return t;
            }
        }
        ki = ki + 1;
    }
    ki = 0;
    while ki < len(keys) {
        k: str = keys[ki];
        if _is_pattern_key(k) and _match_export_key(req, k) {
            raw_t: str = _resolve_conditions(
                js_object_get(exports_val, str_intern(k)), is_esm_import
            );
            if raw_t != "" {
                subbed: str = _substitute_export_pattern(req, k, raw_t);
                if subbed != "" {
                    return subbed;
                }
                return raw_t;
            }
        }
        ki = ki + 1;
    }
    return "";
}

def _is_pattern_key(k: str) -> bool {
    pi: int = 0;
    while pi < len(k) {
        if k[pi] == "*" {
            return True;
        }
        pi = pi + 1;
    }
    return False;
}

def _object_keys(jsobj: JSValue) -> list[str] {
    keys: list[str] = [];
    if not jsv_is_object_cell(jsobj) {
        return keys;
    }
    ids: list[int] = js_object_all_keys(jsobj);
    ki: int = 0;
    while ki < len(ids) {
        keys.append(str_from_id(ids[ki]));
        ki = ki + 1;
    }
    return keys;
}

# ── Package name parsing ──────────────────────────────────────────────────────

obj BareSpecifier {
    has name: str = "",
        subpath: str = "";
}

def _parse_bare_specifier(spec: str) -> BareSpecifier {
    # Returns (package_name, subpath) where subpath is like "./feature" or ""
    if len(spec) > 0 and spec[0] == "@" {
        # @scope/pkg or @scope/pkg/sub
        slash1: int = -1;
        i: int = 0;
        while i < len(spec) {
            if spec[i] == "/" {
                slash1 = i;
                break;
            }
            i = i + 1;
        }
        if slash1 < 0 {
            return BareSpecifier(name=spec, subpath="");
        }
        slash2: int = -1;
        j: int = slash1 + 1;
        while j < len(spec) {
            if spec[j] == "/" {
                slash2 = j;
                break;
            }
            j = j + 1;
        }
        if slash2 < 0 {
            return BareSpecifier(name=spec, subpath="");
        }
        pkg: str = spec[0:slash2];
        sub: str = "." + spec[slash2:];
        return BareSpecifier(name=pkg, subpath=sub);
    }
    slash: int = -1;
    k: int = 0;
    while k < len(spec) {
        if spec[k] == "/" {
            slash = k;
            break;
        }
        k = k + 1;
    }
    if slash < 0 {
        return BareSpecifier(name=spec, subpath="");
    }
    return BareSpecifier(name=spec[0:slash], subpath="." + spec[slash:]);
}

def _node_modules_paths(from_dir: str) -> list[str] {
    paths: list[str] = [];
    cur: str = from_dir;
    prev: str = "";
    while cur != prev and cur != "" {
        paths.append(path_abspath("node_modules", cur));
        prev = cur;
        cur = path_dirname(cur);
    }
    return paths;
}

def _find_package_root(pkg_name: str, from_dir: str) -> str {
    nm_paths: list[str] = _node_modules_paths(from_dir);
    pi: int = 0;
    while pi < len(nm_paths) {
        nm: str = nm_paths[pi];
        cand: str = path_abspath(pkg_name, nm);
        pj: str = path_abspath("package.json", cand);
        if path_exists(pj) {
            return cand;
        }
        pi = pi + 1;
    }
    return "";
}

def _resolve_target_in_package(
    pkg_root: str, target: str, is_esm_import: int
) -> ResolveResult {
    if not _validate_export_target(target, pkg_root) {
        msg: str = "Invalid package target \"" + target + "\"";
        return _err_result(make_err_invalid_package_target(msg));
    }
    rel: str = target[2:];
    abs_base: str = path_abspath(rel, pkg_root);
    probed: str = _probe_file_path(abs_base);
    if probed == "" {
        msg2: str = "Cannot find module '" + target + "' in package";
        return _err_result(_mnf(msg2, is_esm_import));
    }
    fmt: str = _format_for_file(probed, is_esm_import);
    # Node 22+: require(esm) is allowed; TLA rejection happens at evaluation time
    # (ERR_REQUIRE_ASYNC_MODULE) rather than at resolve time (ERR_REQUIRE_ESM).
    return _ok_result(probed, fmt);
}

def _resolve_package_exports(
    pkg_root: str, pkg_json: JSValue, subpath: str, is_esm_import: int
) -> ResolveResult {
    exports_v: JSValue = js_object_get(pkg_json, str_intern("exports"));
    if jsv_is_undefined(exports_v) or jsv_is_null(exports_v) {
        if subpath != "" and subpath != "." {
            tgt_nf: str = subpath;
            if tgt_nf[0] != "." {
                tgt_nf = "./" + tgt_nf;
            }
            return _resolve_target_in_package(pkg_root, tgt_nf, is_esm_import);
        }
        main: str = _jv_str(pkg_json, "main");
        if main == "" {
            main = "./index.js";
        }
        if main[0] != "." {
            main = "./" + main;
        }
        return _resolve_target_in_package(pkg_root, main, is_esm_import);
    }
    if jsv_is_string_cell(exports_v) {
        t: str = str_from_id(jsv_to_table_id(exports_v));
        if not _validate_export_target(t, pkg_root) {
            return _err_result(
                make_err_invalid_package_target("Invalid package target \"" + t + "\"")
            );
        }
        return _resolve_target_in_package(pkg_root, t, is_esm_import);
    }
    sp: str = subpath;
    if sp == "" {
        sp = ".";
    }
    target: str = _lookup_exports(exports_v, sp, is_esm_import);
    if target == "" {
        # Name the package — without it, a transitive dependency's failure is
        # indistinguishable from the requested package's (cost a debugging
        # session: acorn-import-assertions "failing" was really acorn).
        return _err_result(
            make_err_package_path_not_exported(
                "Package subpath '"
                    + sp
                    + "' is not defined by \"exports\" in "
                    + pkg_root
                    + "/package.json"
            )
        );
    }
    if not _validate_export_target(target, pkg_root) {
        return _err_result(
            make_err_invalid_package_target("Invalid package target \"" + target + "\"")
        );
    }
    return _resolve_target_in_package(pkg_root, target, is_esm_import);
}

def _resolve_imports_hash(
    spec: str, owning_pkg_root: str, pkg_json: JSValue, is_esm_import: int
) -> ResolveResult {
    imports_v: JSValue = js_object_get(pkg_json, str_intern("imports"));
    if not jsv_is_object_cell(imports_v) {
        return _err_result(
            make_err_package_import_not_defined(
                "Package import specifier \"" + spec + "\" is not defined"
            )
        );
    }
    # Exact #key or pattern #lib/*
    keys: list[str] = _object_keys(imports_v);
    matched_target: str = "";
    ki: int = 0;
    while ki < len(keys) {
        k: str = keys[ki];
        if k == spec {
            imp_exact_v: JSValue = js_object_get(imports_v, str_intern(k));
            if not jsv_is_string_cell(imp_exact_v)
                and not jsv_is_object_cell(imp_exact_v) {
                return _err_result(
                    make_err_invalid_package_target("Invalid imports target")
                );
            }
            matched_target = _resolve_conditions(imp_exact_v, is_esm_import);
            if matched_target == "" and jsv_is_object_cell(imp_exact_v) {
                return _err_result(
                    make_err_invalid_package_target("Invalid imports target")
                );
            }
        } elif "*" in k and _match_import_pattern(spec, k) {
            imp_pat_v: JSValue = js_object_get(imports_v, str_intern(k));
            imp_pat_tgt: str = _resolve_conditions(imp_pat_v, is_esm_import);
            if imp_pat_tgt == "" and jsv_is_object_cell(imp_pat_v) {
                return _err_result(
                    make_err_invalid_package_target("Invalid imports target")
                );
            }
            matched_target = _resolve_import_pattern(spec, k, imp_pat_tgt);
        }
        if matched_target != "" {
            ki = len(keys);
        }
        ki = ki + 1;
    }
    if matched_target == "" {
        return _err_result(
            make_err_package_import_not_defined(
                "Package import specifier \"" + spec + "\" is not defined"
            )
        );
    }
    if is_builtin_module(matched_target) {
        return _ok_result(matched_target, "builtin");
    }
    if not _validate_export_target(matched_target, owning_pkg_root) {
        return _err_result(make_err_invalid_package_target("Invalid imports target"));
    }
    return _resolve_target_in_package(owning_pkg_root, matched_target, is_esm_import);
}

def _match_import_pattern(spec: str, pattern: str) -> bool {
    if pattern[len(pattern) - 1] == "*" {
        prefix: str = pattern[0:len(pattern) - 1];
        return mr_starts_with(spec, prefix);
    }
    return False;
}

def _resolve_import_pattern(spec: str, pattern: str, target_pat: str) -> str {
    if not _match_import_pattern(spec, pattern) {
        return "";
    }
    prefix: str = pattern[0:len(pattern) - 1];
    suffix: str = spec[len(prefix):];
    star: int = -1;
    ti: int = 0;
    while ti < len(target_pat) {
        if target_pat[ti] == "*" {
            star = ti;
        }
        ti = ti + 1;
    }
    if star < 0 {
        return target_pat;
    }
    tpre: str = target_pat[0:star];
    tsuf: str = target_pat[star + 1:];
    out: str = tpre + suffix + tsuf;
    if out[0] != "." {
        out = "./" + out;
    }
    return out;
}

def _resolve_bare(
    spec: str, from_dir: str, parent_file: str, is_esm_import: int
) -> ResolveResult {
    parts: BareSpecifier = _parse_bare_specifier(spec);
    pkg_name: str = parts.name;
    subpath: str = parts.subpath;

    # Self-reference: specifier equals own package name
    own_root: str = _nearest_package_root(path_dirname(parent_file));
    if own_root != "" {
        own_pj: JSValue = _read_pkg_json(own_root);
        own_name: str = _jv_str(own_pj, "name");
        if own_name == pkg_name and subpath != "" {
            return _resolve_package_exports(own_root, own_pj, subpath, is_esm_import);
        }
        if own_name == pkg_name and subpath == "" {
            return _resolve_package_exports(own_root, own_pj, ".", is_esm_import);
        }
    }

    # Walk node_modules dirs per Node's LOAD_NODE_MODULES: in EACH directory try
    # the package.json form first, then LOAD_AS_FILE / LOAD_AS_DIRECTORY(index)
    # on the raw specifier — a bare file like node_modules/external.js (rollup's
    # test tree) or a package-json-less directory resolves this way.
    nm_paths: list[str] = _node_modules_paths(from_dir);
    nmi: int = 0;
    while nmi < len(nm_paths) {
        nm_dir: str = nm_paths[nmi];
        pkg_cand: str = path_abspath(pkg_name, nm_dir);
        if path_exists(path_abspath("package.json", pkg_cand)) {
            pj: JSValue = _read_pkg_json(pkg_cand);
            return _resolve_package_exports(pkg_cand, pj, subpath, is_esm_import);
        }
        probed_nm: str = _probe_file_path(path_abspath(spec, nm_dir));
        if probed_nm != "" {
            return _ok_result(probed_nm, _format_for_file(probed_nm, is_esm_import));
        }
        nmi = nmi + 1;
    }
    return _err_result(_mnf("Cannot find module '" + spec + "'", is_esm_import));
}

def _resolve_relative(spec: str, from_dir: str, is_esm_import: int) -> ResolveResult {
    base: str = spec;
    if len(spec) >= 1 and spec[0] == "." {
        base = path_abspath(spec, from_dir);
    }
    base = path_normalize(base);
    probed: str = _probe_file_path(base);
    if probed == "" {
        return _err_result(_mnf("Cannot find module '" + spec + "'", is_esm_import));
    }
    fmt: str = _format_for_file(probed, is_esm_import);
    # Node 22+: require(esm) is allowed; TLA rejection happens at evaluation time.
    return _ok_result(probed, fmt);
}

"""
Canonical module resolution entry point.

  specifier     — raw module specifier from require/import
  parent_file   — absolute path of the requesting module (or entry script)
  is_esm_import — True for import() / static import; False for require()

Returns ResolveResult with absolute path and format, or err JSValue to throw.
"""
def _strip_file_url(p: str) -> str {
    if len(p) > 7
        and p[0] == "f"
        and p[1] == "i"
        and p[2] == "l"
        and p[3] == "e"
        and p[4] == ":"
        and p[5] == "/"
        and p[6] == "/" {
        fu: str = p[7:];
        # URL semantics: `?query` / `#fragment` are never part of the filesystem
        # path (a literal ? or # in a path must be percent-encoded). Node strips
        # them; we resolved the literal string, so
        # `import(pathToFileURL(f) + "?t=" + Date.now())` — vite's cache-busted
        # config temp-file import (loadConfigFromBundledFile) — probed a file
        # literally named `...mjs?t=<ts>` → not found → empty namespace →
        # "config must export or return an object". Divergence note: Node keys
        # the module cache on the FULL URL (each ?t= evaluates fresh); we key on
        # the path — acceptable for vite, which writes a NEW temp file per load.
        fq: int = 0;
        fn2: int = len(fu);
        while fq < fn2 {
            if fu[fq] == "?" or fu[fq] == "#" {
                return fu[0:fq];
            }
            fq = fq + 1;
        }
        return fu;
    }
    return p;
}

"""Hex digit value, or -1 if not a hex digit."""
def _hex_nibble(c: str) -> int {
    if c >= "0" and c <= "9" {
        return ord(c) - ord("0");
    }
    if c >= "a" and c <= "f" {
        return ord(c) - ord("a") + 10;
    }
    if c >= "A" and c <= "F" {
        return ord(c) - ord("A") + 10;
    }
    return -1;
}

"""
Percent-decode a path/specifier once (Node file URL / ESM import semantics).

Decodes valid `%HH` sequences; leaves malformed `%` sequences intact.
Double-encoded forms like `%2520` become `%20` (one decode pass) — matching
Node, which does not recursively decode.
"""
def _percent_decode_path(s: str) -> str {
    if len(s) == 0 {
        return s;
    }
    has_pct: int = 0;
    si: int = 0;
    while si < len(s) {
        if s[si] == "%" {
            has_pct = 1;
            si = len(s);
        }
        si = si + 1;
    }
    if has_pct == 0 {
        return s;
    }
    out: str = "";
    i: int = 0;
    n: int = len(s);
    while i < n {
        if s[i] == "%" and i + 2 < n {
            h1: int = _hex_nibble(s[i + 1]);
            h2: int = _hex_nibble(s[i + 2]);
            if h1 >= 0 and h2 >= 0 {
                b: int = h1 * 16 + h2;
                # Avoid embedding raw NUL (chr(0) collides with "" in Jac).
                if b == 0 {
                    out = out + "%00";
                } else {
                    out = out + byte_chr(b);
                }
                i = i + 3;
            } else {
                out = out + s[i];
                i = i + 1;
            }
        } else {
            out = out + s[i];
            i = i + 1;
        }
    }
    return out;
}

def:pub resolve_specifier(
    specifier: str, parent_file: str, is_esm_import: int
) -> ResolveResult {
    parent_file = _strip_file_url(parent_file);
    # ESM / file: URL imports percent-decode the specifier once before FS lookup
    # (Node: `%2520` → `%20`, not space).
    if is_esm_import != 0 {
        specifier = _percent_decode_path(specifier);
    }
    if len(specifier) > 7
        and specifier[0] == "f"
        and specifier[1] == "i"
        and specifier[2] == "l"
        and specifier[3] == "e"
        and specifier[4] == ":"
        and specifier[5] == "/"
        and specifier[6] == "/" {
        abs_u: str = _strip_file_url(specifier);
        # CJS require(fileURL) still needs a single decode pass.
        if is_esm_import == 0 {
            abs_u = _percent_decode_path(abs_u);
        }
        fmt_u: str = _format_for_file(abs_u, is_esm_import);
        return _ok_result(abs_u, fmt_u);
    }
    bare: str = specifier;
    if len(specifier) > 5
        and specifier[0] == "n"
        and specifier[1] == "o"
        and specifier[2] == "d"
        and specifier[3] == "e"
        and specifier[4] == ":" {
        bare = specifier[5:];
    }

    if is_builtin_module(bare) {
        return _ok_result(bare, "builtin");
    }

    from_dir: str = path_dirname(parent_file);
    if from_dir == "" and len(parent_file) > 0 {
        from_dir = path_dirname(path_normalize(parent_file));
    }

    # package#import (consumer require.resolve) — not exposed outside owning package
    hash_pos: int = -1;
    hp: int = 1;
    while hp < len(specifier) {
        if specifier[hp] == "#" {
            hash_pos = hp;
            hp = len(specifier);
        }
        hp = hp + 1;
    }
    if hash_pos > 0 {
        pkg_part: str = specifier[0:hash_pos];
        imp_part: str = specifier[hash_pos:];
        pkg_root_h: str = _find_package_root(pkg_part, from_dir);
        if pkg_root_h == "" {
            return _err_result(
                _mnf("Cannot find module '" + specifier + "'", is_esm_import)
            );
        }
        own_root_h: str = _nearest_package_root(from_dir);
        if own_root_h != pkg_root_h {
            return _err_result(
                _mnf("Cannot find module '" + specifier + "'", is_esm_import)
            );
        }
        pj_h: JSValue = _read_pkg_json(own_root_h);
        return _resolve_imports_hash(imp_part, own_root_h, pj_h, is_esm_import);
    }

    # Package imports (#hash) — only from within owning package
    if len(specifier) > 0 and specifier[0] == "#" {
        own_root: str = _nearest_package_root(from_dir);
        if own_root == "" {
            return _err_result(
                _mnf("Cannot find module '" + specifier + "'", is_esm_import)
            );
        }
        pj: JSValue = _read_pkg_json(own_root);
        return _resolve_imports_hash(specifier, own_root, pj, is_esm_import);
    }

    if _resolver_is_relative_or_absolute(specifier) {
        return _resolve_relative(specifier, from_dir, is_esm_import);
    }

    return _resolve_bare(specifier, from_dir, parent_file, is_esm_import);
}
