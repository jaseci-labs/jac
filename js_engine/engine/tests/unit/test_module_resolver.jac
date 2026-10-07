"""
Unit tests for src/builtins/module_resolver.na.jac

Tests cover the four Group A fixes applied in the vite_fixes review:

  A-C1  Path traversal — _validate_export_target must reject targets that
        escape the package root even when they start with "./".

  A-C3  Condition declaration order — _resolve_conditions must iterate the
        condition object's keys in JSON insertion order (js_object_keys), so
        that a "default" key placed before "require" wins for CJS callers.

  A-C4  ESM error code — require() not-found emits code "MODULE_NOT_FOUND",
        import() not-found emits code "ERR_MODULE_NOT_FOUND".

  A.2   Sanity — resolve_specifier still works end-to-end (dead code removal
        did not break the live paths).

Fixtures live under tests/unit/fixtures/node_modules/<pkg>/ so the resolver
finds them when parent_file is tests/unit/fixtures/entry.js.

Run with (from js_engine/):
  jac run tests/unit/test_module_resolver.na.jac
"""

import from engine.src.builtins.module_resolver { ResolveResult, resolve_specifier }
import from engine.src.builtins.path_utils { path_dirname }
import from engine.src.runtime.jsvalue { JSValue, jsv_is_string_cell, jsv_to_table_id }
import from engine.src.runtime.jsobject { js_object_get, obj_set_realm }
import from engine.src.runtime.jsstring {
    str_intern,
    str_from_id,
    str_set_realm,
    str_intern_seed_well_known
}
import from engine.src.runtime.realm { Realm, realm_new }

# ── Fixtures root ─────────────────────────────────────────────────────────────
# Tests must be run from js_engine/ (make test_unit does this).
# The fake parent file sits inside the fixtures dir so node_modules lookups
# resolve against tests/unit/fixtures/node_modules/<pkg>/.

glob PARENT: str = "tests/unit/fixtures/entry.js";

# ═════════════════════════════════════════════════════════════════════════════
with entry {
    # ── Realm bootstrap ──────────────────────────────────────────────────
    # Tests 9+ call make_module_not_found → js_object_create_null → _obj_alloc
    # which requires _OBJ_REALM to be set.  Tests 9+ also call str_intern.
    # Both need a live Realm; wire it here before any test runs.
    _r: Realm = realm_new();
    str_set_realm(_r);
    obj_set_realm(_r);
    str_intern_seed_well_known();

    ok: int = 0;
    fail: int = 0;

    # ── 1-4: path_dirname — pure function, no FS ──────────────────────

    d1: str = path_dirname("/foo/bar/baz.js");
    if d1 == "/foo/bar" {
        ok += 1;
        print("OK  1  dirname /foo/bar/baz.js → /foo/bar");
    } else {
        fail += 1;
        print("FAIL 1  dirname  got:", d1);
    }

    d2: str = path_dirname("/foo");
    if d2 == "/" {
        ok += 1;
        print("OK  2  dirname /foo → /");
    } else {
        fail += 1;
        print("FAIL 2  dirname /foo  got:", d2);
    }

    d3: str = path_dirname("");
    if d3 == "" {
        ok += 1;
        print("OK  3  dirname '' → ''");
    } else {
        fail += 1;
        print("FAIL 3  dirname ''  got:", d3);
    }

    d4: str = path_dirname("/foo/bar/");
    if d4 == "/foo" {
        ok += 1;
        print("OK  4  dirname /foo/bar/ → /foo  (strips trailing slash)");
    } else {
        fail += 1;
        print("FAIL 4  dirname trailing slash  got:", d4);
    }

    # ── 5-8: Builtin modules — no FS, no fixtures needed ─────────────────

    rr5: ResolveResult = resolve_specifier("fs", "/any/parent.js", 0);
    if rr5.ok == 1 and rr5.path == "fs" and rr5.format == "builtin" {
        ok += 1;
        print("OK  5  builtin 'fs'");
    } else {
        fail += 1;
        print("FAIL 5  builtin fs  ok=", rr5.ok, "path=", rr5.path);
    }

    rr6: ResolveResult = resolve_specifier("node:path", "/any/parent.js", 0);
    if rr6.ok == 1 and rr6.path == "path" and rr6.format == "builtin" {
        ok += 1;
        print("OK  6  builtin 'node:path' strips node: prefix");
    } else {
        fail += 1;
        print("FAIL 6  node:path  ok=", rr6.ok, "path=", rr6.path);
    }

    rr7: ResolveResult = resolve_specifier("path", "/any/parent.js", 1);
    if rr7.ok == 1 and rr7.path == "path" and rr7.format == "builtin" {
        ok += 1;
        print("OK  7  builtin 'path' (ESM import)");
    } else {
        fail += 1;
        print("FAIL 7  builtin path ESM  ok=", rr7.ok);
    }

    rr8: ResolveResult = resolve_specifier("node:fs", "/any/parent.js", 1);
    if rr8.ok == 1 and rr8.path == "fs" and rr8.format == "builtin" {
        ok += 1;
        print("OK  8  builtin 'node:fs' (ESM)");
    } else {
        fail += 1;
        print("FAIL 8  node:fs ESM  ok=", rr8.ok, "path=", rr8.path);
    }

    # ── 9-10: Error codes — A-C4 fix ─────────────────────────────────────
    # CJS require() → "MODULE_NOT_FOUND"
    # ESM import()  → "ERR_MODULE_NOT_FOUND"
    # Inline all JSValue field access to avoid cross-module struct param pattern.

    rr9: ResolveResult = resolve_specifier("_mr_nonexistent_pkg_", "/any/parent.js", 0);
    cv9: JSValue = js_object_get(rr9.err, str_intern("code"));
    code9: str = "";
    if jsv_is_string_cell(cv9) {
        code9 = str_from_id(jsv_to_table_id(cv9));
    }
    if rr9.ok == 0 and code9 == "MODULE_NOT_FOUND" {
        ok += 1;
        print("OK  9  CJS not-found → MODULE_NOT_FOUND");
    } else {
        fail += 1;
        print("FAIL 9  CJS code  ok=", rr9.ok, "code=", code9);
    }

    rr10: ResolveResult = resolve_specifier(
        "_mr_nonexistent_pkg_", "/any/parent.js", 1
    );
    cv10: JSValue = js_object_get(rr10.err, str_intern("code"));
    code10: str = "";
    if jsv_is_string_cell(cv10) {
        code10 = str_from_id(jsv_to_table_id(cv10));
    }
    if rr10.ok == 0 and code10 == "ERR_MODULE_NOT_FOUND" {
        ok += 1;
        print("OK  10 ESM not-found → ERR_MODULE_NOT_FOUND");
    } else {
        fail += 1;
        print("FAIL 10 ESM code  ok=", rr10.ok, "code=", code10);
    }

    # ── 11-12: Relative file resolution ──────────────────────────────────

    rr11: ResolveResult = resolve_specifier("./rel_module.js", PARENT, 0);
    p11_n: int = len(rr11.path);
}

glob sfx11: str = "rel_module.js";
with entry {
    sfx11_n: int = len(sfx11);
    p11_ok: int = 0;
    if sfx11_n <= p11_n and rr11.path[p11_n - sfx11_n:] == sfx11 {
        p11_ok = 1;
    }
    if rr11.ok == 1 and p11_ok == 1 {
        ok += 1;
        print("OK  11 relative ./rel_module.js resolved");
    } else {
        fail += 1;
        print("FAIL 11 relative ok=", rr11.ok, "path=", rr11.path);
    }

    rr12: ResolveResult = resolve_specifier("./nonexistent_mr_xyz.js", PARENT, 0);
    cv12: JSValue = js_object_get(rr12.err, str_intern("code"));
    code12: str = "";
    if jsv_is_string_cell(cv12) {
        code12 = str_from_id(jsv_to_table_id(cv12));
    }
    if rr12.ok == 0 and code12 == "MODULE_NOT_FOUND" {
        ok += 1;
        print("OK  12 relative miss → MODULE_NOT_FOUND");
    } else {
        fail += 1;
        print("FAIL 12 relative miss  ok=", rr12.ok, "code=", code12);
    }

    # ── 13: Package with 'main' field, no exports (A.2 sanity) ───────────

    rr13: ResolveResult = resolve_specifier("mr-simple", PARENT, 0);
    p13_n: int = len(rr13.path);
}

glob sfx13: str = "index.js";
with entry {
    sfx13_n: int = len(sfx13);
    p13_ok: int = 0;
    if sfx13_n <= p13_n and rr13.path[p13_n - sfx13_n:] == sfx13 {
        p13_ok = 1;
    }
    if rr13.ok == 1 and p13_ok == 1 {
        ok += 1;
        print("OK  13 package 'main' → index.js");
    } else {
        fail += 1;
        print("FAIL 13 mr-simple  ok=", rr13.ok, "path=", rr13.path);
    }

    # ── 14-15: Conditional exports — require vs import (A-C3) ────────────
    # mr-exports/package.json exports ".": { "require": cjs.js, "import": esm.js, "default": cjs.js }

    rr14: ResolveResult = resolve_specifier("mr-exports", PARENT, 0);
    p14_n: int = len(rr14.path);
}

glob sfx14: str = "cjs.js";
with entry {
    sfx14_n: int = len(sfx14);
    p14_ok: int = 0;
    if sfx14_n <= p14_n and rr14.path[p14_n - sfx14_n:] == sfx14 {
        p14_ok = 1;
    }
    if rr14.ok == 1 and p14_ok == 1 {
        ok += 1;
        print("OK  14 conditional exports: require → cjs.js");
    } else {
        fail += 1;
        print("FAIL 14 mr-exports CJS  ok=", rr14.ok, "path=", rr14.path);
    }

    rr15: ResolveResult = resolve_specifier("mr-exports", PARENT, 1);
    p15_n: int = len(rr15.path);
}

glob sfx15: str = "esm.js";
with entry {
    sfx15_n: int = len(sfx15);
    p15_ok: int = 0;
    if sfx15_n <= p15_n and rr15.path[p15_n - sfx15_n:] == sfx15 {
        p15_ok = 1;
    }
    if rr15.ok == 1 and p15_ok == 1 {
        ok += 1;
        print("OK  15 conditional exports: import → esm.js");
    } else {
        fail += 1;
        print("FAIL 15 mr-exports ESM  ok=", rr15.ok, "path=", rr15.path);
    }

    # ── 16: Declaration order — A-C3 fix ─────────────────────────────────
    # mr-exports-order/package.json: { "default": fallback.js, "require": cjs.js }
    # "default" is listed first in JSON → must win for both CJS and ESM callers.
    # (Old code with fixed check order would have returned cjs.js for CJS.)

    rr16: ResolveResult = resolve_specifier("mr-exports-order", PARENT, 0);
    p16_n: int = len(rr16.path);
}

glob sfx16: str = "fallback.js";
with entry {
    sfx16_n: int = len(sfx16);
    p16_ok: int = 0;
    if sfx16_n <= p16_n and rr16.path[p16_n - sfx16_n:] == sfx16 {
        p16_ok = 1;
    }
    if rr16.ok == 1 and p16_ok == 1 {
        ok += 1;
        print("OK  16 condition order: 'default' before 'require' wins (CJS)");
    } else {
        fail += 1;
        print("FAIL 16 mr-exports-order  ok=", rr16.ok, "path=", rr16.path);
    }

    # ── 17: Path traversal rejected — A-C1 fix ───────────────────────────
    # mr-traversal/package.json exports ".": "./../../evil.js"
    # After normalization this escapes the package root → must be rejected.

    rr17: ResolveResult = resolve_specifier("mr-traversal", PARENT, 0);
    if rr17.ok == 0 {
        ok += 1;
        print("OK  17 path traversal target rejected");
    } else {
        fail += 1;
        print("FAIL 17 traversal NOT rejected  path=", rr17.path);
    }

    # ── Summary ───────────────────────────────────────────────────────────

    print("");
    print("module_resolver:", ok, "passed,", fail, "failed");
    if fail > 0 {
        print("RESULT: FAIL");
    }
}
