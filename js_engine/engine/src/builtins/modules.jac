"""
Module System — require() implementation + module cache.

Provides the Node.js `require()` function for loading built-in modules and
user JS files.  The module cache ensures each module is loaded at most once.

Architecture:
  - `_MODULE_CACHE` stores resolved module name → exports JSValue
  - `module_resolve()` resolves a specifier to an absolute path or built-in name
  - `module_get_cached()` / `module_cache_set()` manage the cache
  - The actual file-read + parse + compile + eval happens in the VM (vm.na.jac)
    to avoid circular dependencies (modules cannot import vm)

Bun reference: bun/src/bun.js/ModuleLoader.zig
Node.js reference: https://nodejs.org/api/modules.html
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_object_cell,
    jsv_is_undefined
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_get,
    js_object_set,
    js_object_keys,
    js_object_all_keys,
    js_object_has_own,
    js_object_has_own_accessor,
    js_object_get_own_accessor_getter,
    js_object_get_own_accessor_setter,
    js_object_set_accessor_getter,
    js_object_set_accessor_setter
}
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.fn_meta { fn_meta_get_fn_props }
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.builtins.module_registry {
    is_builtin_module,
    create_builtin_module
}
import from engine.src.builtins.module_resolver { resolve_specifier, ResolveResult }

"""Own keys bag for CJS→ESM interop: plain object, or function.fn_props."""
def _cjs_exports_key_bag(cjs_exports: JSValue) -> JSValue {
    if jsv_is_object_cell(cjs_exports) {
        return cjs_exports;
    }
    fp: JSValue = fn_meta_get_fn_props(cjs_exports);
    if not jsv_is_undefined(fp) and jsv_is_object_cell(fp) {
        return fp;
    }
    return js_undefined();
}

"""Copy own keys from CJS exports into ns (supports function module.exports)."""
def _copy_cjs_exports_to_ns(ns: JSValue, cjs_exports: JSValue, all_keys: int) -> None {
    bag: JSValue = _cjs_exports_key_bag(cjs_exports);
    if jsv_is_undefined(bag) {
        return;
    }
    ckeys: list[int] = [];
    if all_keys != 0 {
        ckeys = js_object_all_keys(bag);
    } else {
        ckeys = js_object_keys(bag);
    }
    ci: int = 0;
    while ci < len(ckeys) {
        ck: int = ckeys[ci];
        # ESM-compat CJS modules (esbuild, and any tsc/esbuild `__toCommonJS`
        # bundle) expose their named exports as enumerable GETTERS on
        # module.exports (`{ transform: () => transform }`). A plain
        # js_object_get returns the raw slot (undefined) for an accessor, so
        # copying the value dropped every getter-backed export — `import {
        # transform } from 'esbuild'` bound to undefined. Copy the getter (and
        # any setter) itself to preserve the live binding, matching Node's
        # cjs-module-lexer-synthesized namespace.
        if js_object_has_own_accessor(bag, ck) {
            getter_fn: JSValue = js_object_get_own_accessor_getter(bag, ck);
            _ = js_object_set_accessor_getter(ns, ck, getter_fn);
            setter_fn: JSValue = js_object_get_own_accessor_setter(bag, ck);
            if not jsv_is_undefined(setter_fn) {
                _ = js_object_set_accessor_setter(ns, ck, setter_fn);
            }
        } else {
            # Read from bag: for function exports this is fn_props; for objects, exports itself.
            js_object_set(ns, ck, js_object_get(bag, ck));
        }
        ci = ci + 1;
    }
}

# ── Module cache ─────────────────────────────────────────────────────────────

"""Cache of resolved module name → exports object.  Prevents double execution."""
glob _MODULE_CACHE: dict[str, JSValue] = {};

"""ESM namespace facades for built-in modules (syncBuiltinESMExports)."""
glob _ESM_BUILTIN_NS: dict[str, JSValue] = {};

"""Keys of registered builtin ESM namespace facades (for VM-side accessor sync)."""
def:pub esm_builtin_ns_keys -> list[str] {
    keys: list[str] = [];
    for k in _ESM_BUILTIN_NS {
        keys.append(k);
    }
    return keys;
}

"""Lookup a builtin ESM namespace facade by cache key (`esm:fs`, …)."""
def:pub esm_builtin_ns_get(key: str) -> JSValue {
    if key in _ESM_BUILTIN_NS {
        return _ESM_BUILTIN_NS[key];
    }
    return js_undefined();
}

"""Check if a module is already cached. Returns True if cached."""
def:pub module_is_cached(resolved: str) -> bool {
    return resolved in _MODULE_CACHE;
}

"""Get the cached exports for a module. Returns js_undefined() if not cached."""
def:pub module_get_cached(resolved: str) -> JSValue {
    if resolved in _MODULE_CACHE {
        return _MODULE_CACHE[resolved];
    }
    return js_undefined();
}

"""Store a module's exports in the cache."""
def:pub module_cache_set(resolved: str, exports: JSValue) {
    _MODULE_CACHE[resolved] = exports;
    gc_pin_value(exports);  # Pin against the mark-and-sweep GC
}

# Cache of ESM namespace objects for userland CJS modules (keyed by resolved path).
glob _ESM_CJS_NS: dict[str, JSValue] = {};

"""
Wrap a CJS module.exports value as an ESM namespace for `import … from`.
Node interop: `import x from './cjs.js'` binds x to module.exports via
namespace.default; named imports also see enumerable own keys.
"""
def:pub esm_cjs_namespace_for(resolved: str, cjs_exports: JSValue) -> JSValue {
    esm_key: str = "cjsns:" + resolved;
    ns: JSValue = js_undefined();
    if esm_key in _ESM_CJS_NS {
        ns = _ESM_CJS_NS[esm_key];
    } else {
        ns = js_object_create_null();
        _ESM_CJS_NS[esm_key] = ns;
        gc_pin_value(ns);
    }
    _copy_cjs_exports_to_ns(ns, cjs_exports, 1);
    # Always set default to the CJS exports value (object, function, or primitive).
    js_object_set(ns, str_intern("default"), cjs_exports);
    return ns;
}

"""Copy/sync CJS builtin exports into an ESM namespace object (import() / static import)."""
def:pub esm_builtin_namespace_for(bare_name: str, cjs_exports: JSValue) -> JSValue {
    esm_key: str = "esm:" + bare_name;
    ns: JSValue = js_undefined();
    had_ns: int = 0;
    if esm_key in _ESM_BUILTIN_NS {
        ns = _ESM_BUILTIN_NS[esm_key];
        had_ns = 1;
    } else {
        ns = js_object_create_null();
        _ESM_BUILTIN_NS[esm_key] = ns;
        gc_pin_value(ns);
    }
    bag: JSValue = _cjs_exports_key_bag(cjs_exports);
    if not jsv_is_undefined(bag) {
        if had_ns == 0 {
            _copy_cjs_exports_to_ns(ns, cjs_exports, 1);
        } else {
            nkeys_sync: list[int] = js_object_keys(ns);
            ni_s: int = 0;
            while ni_s < len(nkeys_sync) {
                nk_s: int = nkeys_sync[ni_s];
                if js_object_has_own(bag, nk_s) {
                    js_object_set(ns, nk_s, js_object_get(bag, nk_s));
                }
                ni_s = ni_s + 1;
            }
        }
    }
    # Always expose default — critical for `import assert from 'node:assert'`
    # where module.exports is a function (not an object cell).
    js_object_set(ns, str_intern("default"), cjs_exports);
    return ns;
}

"""
Sync existing ESM namespace keys from current CJS builtin exports.
Updates values for keys already in the namespace. When a CJS export has been
deleted, the corresponding namespace key is set to undefined so live bindings
(named imports) observe the deletion (Node syncBuiltinESMExports).
"""
def:pub sync_builtin_esm_exports(globals_ref: dict[str, JSValue]) {
    for esm_key in _ESM_BUILTIN_NS {
        ns: JSValue = _ESM_BUILTIN_NS[esm_key];
        bare_name: str = esm_key;
        if len(esm_key) > 4
            and esm_key[0] == "e"
            and esm_key[1] == "s"
            and esm_key[2] == "m"
            and esm_key[3] == ":" {
            bare_name = esm_key[4:];
        }
        # Prefer namespace.default — that is the live CJS exports object the
        # named imports were bound against (globals["fs"] may be a different
        # interim globalThis.fs stub).
        cjs: JSValue = js_object_get(ns, str_intern("default"));
        if not jsv_is_object_cell(cjs) {
            if bare_name in globals_ref {
                cjs = globals_ref[bare_name];
            }
        }
        if not jsv_is_object_cell(cjs) and module_is_cached(bare_name) {
            cjs = module_get_cached(bare_name);
        }
        if not jsv_is_object_cell(cjs) {
            continue;
        }
        # Refresh string keys on ns (skip symbol keys like @@toStringTag).
        nkeys: list[int] = js_object_all_keys(ns);
        ni: int = 0;
        while ni < len(nkeys) {
            nk: int = nkeys[ni];
            if nk >= SYMBOL_KEY_BASE {
                ni = ni + 1;
                continue;
            }
            # Preserve namespace.default → CJS exports object itself.
            if nk == str_intern("default") {
                js_object_set(ns, nk, cjs);
            } elif js_object_has_own(cjs, nk) {
                js_object_set(ns, nk, js_object_get(cjs, nk));
            } else {
                # Deleted / missing on CJS side — clear live binding.
                js_object_set(ns, nk, js_undefined());
            }
            ni = ni + 1;
        }
    }
}

"""Remove a module from the cache (require.cache delete parity)."""
def:pub module_cache_delete(resolved: str) {
    if resolved in _MODULE_CACHE {
        del _MODULE_CACHE[resolved];
    }
    esm_export_meta_delete(resolved);
}

# ── ESM export metadata for Instantiation / ResolveExport ─────────────────────
# Entry encoding (absolute dependency paths already resolved by the VM):
#   "L:<name>"                         — local export
#   "I:<exportName>:<importName>:<abs>" — indirect export { import as export } from
#   "S:<abs>"                          — star export * from
glob _ESM_EXPORT_ENTRIES: dict[str, list[str]] = {};

def:pub esm_export_meta_has(resolved: str) -> bool {
    return resolved in _ESM_EXPORT_ENTRIES;
}

def:pub esm_export_meta_get(resolved: str) -> list[str] {
    if resolved in _ESM_EXPORT_ENTRIES {
        return _ESM_EXPORT_ENTRIES[resolved];
    }
    out: list[str] = [];
    return out;
}

def:pub esm_export_meta_set(resolved: str, entries: list[str]) {
    _ESM_EXPORT_ENTRIES[resolved] = entries;
}

def:pub esm_export_meta_delete(resolved: str) {
    if resolved in _ESM_EXPORT_ENTRIES {
        del _ESM_EXPORT_ENTRIES[resolved];
    }
}

"""
ResolveExport(module, exportName) for Instantiation validation.
Returns:
  "ok"         — resolved to a concrete binding
  "null"       — unresolved / circular
  "ambiguous"  — conflicting star-export resolutions
"""
def:pub esm_resolve_export(
    resolved: str, export_name: str, resolve_set: dict[str, bool]
) -> str {
    rs_key: str = resolved + "\x1f" + export_name;
    if rs_key in resolve_set {
        return "null";
    }
    resolve_set[rs_key] = True;
    entries: list[str] = esm_export_meta_get(resolved);
    # A "C:" marker means the module is CommonJS (registered by
    # _esm_ensure_export_meta when the source has no ESM import/export syntax).
    # A CJS module's namespace is synthesized dynamically from module.exports
    # (cjs-module-lexer), so — like Node — it provides every named binding:
    # ResolveExport succeeds for any non-`default` name. This is the re-export
    # analogue of a direct `import { x } from './cjs'` (already works); without
    # it, `export { x as y } from './cjs'` (e.g. vite's
    # `export { version as esbuildVersion } from 'esbuild'`) wrongly reported
    # "does not provide an export named 'y'", because the CJS source has no
    # I:/L:/T: entries to walk — it registers an empty ESM entry list, so a
    # "has no meta" check would NOT distinguish it. `default` keeps the standard
    # treatment (CJS default is bound via the namespace's own default synthesis,
    # not indirect ResolveExport).
    ci_cjs: int = 0;
    while ci_cjs < len(entries) {
        ec: str = entries[ci_cjs];
        if len(ec) >= 2 and ec[0] == "C" and ec[1] == ":" {
            if export_name != "default" {
                return "ok";
            }
            return "null";
        }
        ci_cjs = ci_cjs + 1;
    }
    ei: int = 0;
    while ei < len(entries) {
        e: str = entries[ei];
        # L:name — local export initialized at Instantiation (var/function)
        # T:name — local export TDZ until evaluation (let/const/class/default)
        # Both are concrete local bindings for ResolveExport.
        if len(e) >= 2 and (e[0] == "L" or e[0] == "T") and e[1] == ":" {
            if e[2:] == export_name {
                return "ok";
            }
        } elif len(e) >= 2 and e[0] == "I" and e[1] == ":" {
            # I:exportName:importName:absPath  (first two ':' delimit names; rest is path)
            rest: str = e[2:];
            c1: int = -1;
            c2: int = -1;
            ci: int = 0;
            while ci < len(rest) {
                if rest[ci] == ":" {
                    if c1 < 0 {
                        c1 = ci;
                    } elif c2 < 0 {
                        c2 = ci;
                    }
                }
                ci = ci + 1;
            }
            if c1 >= 0 and c2 > c1 {
                exp_n: str = rest[0:c1];
                imp_n: str = rest[c1 + 1:c2];
                dep: str = rest[c2 + 1:];
                if exp_n == export_name {
                    return esm_resolve_export(dep, imp_n, resolve_set);
                }
            }
        }
        ei = ei + 1;
    }
    # Star exports do not provide "default".
    if export_name == "default" {
        return "null";
    }
    star_res: str = "";
    ei = 0;
    while ei < len(entries) {
        e2: str = entries[ei];
        if len(e2) >= 2 and e2[0] == "S" and e2[1] == ":" {
            dep2: str = e2[2:];
            # Fresh resolveSet copy is NOT used — spec shares resolveSet.
            r2: str = esm_resolve_export(dep2, export_name, resolve_set);
            if r2 == "ambiguous" {
                return "ambiguous";
            }
            if r2 == "ok" {
                if star_res == "" {
                    star_res = dep2 + "\x1f" + export_name;
                } elif star_res != dep2 + "\x1f" + export_name {
                    return "ambiguous";
                }
            }
        }
        ei = ei + 1;
    }
    if star_res != "" {
        return "ok";
    }
    return "null";
}

"""
Validate module.[[IndirectExportEntries]] (ES ModuleDeclarationInstantiation).
Returns "" on success, or a SyntaxError message on failure.
"""
def:pub esm_validate_indirect_exports(resolved: str) -> str {
    entries: list[str] = esm_export_meta_get(resolved);
    ei: int = 0;
    while ei < len(entries) {
        e: str = entries[ei];
        if len(e) >= 2 and e[0] == "I" and e[1] == ":" {
            rest: str = e[2:];
            c1: int = -1;
            ci: int = 0;
            while ci < len(rest) {
                if rest[ci] == ":" {
                    if c1 < 0 {
                        c1 = ci;
                    }
                }
                ci = ci + 1;
            }
            if c1 >= 0 {
                exp_n: str = rest[0:c1];
                rs: dict[str, bool] = {};
                r: str = esm_resolve_export(resolved, exp_n, rs);
                if r == "null" or r == "ambiguous" {
                    return "The requested module does not provide an export named '"
                        + exp_n
                        + "'";
                }
            }
        }
        ei = ei + 1;
    }
    return "";
}

# ── Module resolution ────────────────────────────────────────────────────────

"""
Resolve a module specifier to a canonical path or built-in name.

Uses the canonical Node-compatible resolver.  `parent_file` should be the
absolute path of the requesting module; when empty, `from_dir` is used to
synthesize a parent path for resolution.
"""
def:pub module_resolve(
    specifier: str, from_dir: str, parent_file: str, is_esm_import: int
) -> str {
    pf: str = parent_file;
    if pf == "" {
        if from_dir != "" {
            pf = from_dir + "/.__jac_parent__.js";
        } else {
            pf = "/.__jac_parent__.js";
        }
    }
    res: ResolveResult = resolve_specifier(specifier, pf, is_esm_import);
    if res.ok != 0 {
        return res.path;
    }
    return "";
}

"""Return resolution error JSValue, or js_undefined() if resolve would succeed."""
def:pub module_resolve_error(
    specifier: str, from_dir: str, parent_file: str, is_esm_import: int
) -> JSValue {
    pf: str = parent_file;
    if pf == "" {
        if from_dir != "" {
            pf = from_dir + "/.__jac_parent__.js";
        } else {
            pf = "/.__jac_parent__.js";
        }
    }
    res: ResolveResult = resolve_specifier(specifier, pf, is_esm_import);
    if res.ok != 0 {
        return js_undefined();
    }
    return res.err;
}

"""Return resolved format string (cjs-js, cjs-json, esm-js, builtin) or ""."""
def:pub module_resolve_format(
    specifier: str, from_dir: str, parent_file: str, is_esm_import: int
) -> str {
    pf: str = parent_file;
    if pf == "" {
        if from_dir != "" {
            pf = from_dir + "/.__jac_parent__.js";
        } else {
            pf = "/.__jac_parent__.js";
        }
    }
    res: ResolveResult = resolve_specifier(specifier, pf, is_esm_import);
    if res.ok != 0 {
        return res.format;
    }
    return "";
}

"""
Resolve a require() call.  This is the main entry point called from the VM.

  1. Resolve the specifier to a canonical name
  2. Check the cache — return cached exports if already loaded
  3. For built-in modules: create via registry factory
  4. For user files: return js_undefined() (caller must handle file loading)

Returns the exports JSValue, or js_undefined() if not a built-in and not cached.
The `is_resolved` flag (returned via the second return in practice) indicates
whether the module was fully resolved here or needs file loading by the VM.
"""
def:pub module_require_builtin(
    specifier: str, from_dir: str, globals_ref: dict[str, JSValue]
) -> JSValue {
    resolved: str = module_resolve(specifier, from_dir, "", 0);

    # Check cache first
    if module_is_cached(resolved) {
        return module_get_cached(resolved);
    }

    # Built-in module — create via registry (JS file builtins load in VM)
    if is_builtin_module(resolved) {
        bare_nm: str = resolved;
        if len(resolved) > 5
            and resolved[0] == "n"
            and resolved[1] == "o"
            and resolved[2] == "d"
            and resolved[3] == "e"
            and resolved[4] == ":" {
            bare_nm = resolved[5:];
        }
        if bare_nm == "path" or bare_nm == "url" or bare_nm == "querystring" {
            return js_undefined();
        }
        exports: JSValue = create_builtin_module(resolved, globals_ref);
        if jsv_is_undefined(exports) {
            return js_undefined();
        }
        module_cache_set(resolved, exports);
        if bare_nm != "" {
            esm_builtin_namespace_for(bare_nm, exports);
        }
        return exports;
    }

    # Not a built-in — return undefined to signal "load from file"
    return js_undefined();
}
