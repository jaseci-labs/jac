"""Unit tests for the bun.lock reader/writer and platform matching.

Round-trips every recorded golden lockfile byte-for-byte, then checks the
model on a synthetic lockfile covering the other entry kinds.

Run from the repo root:  jac run engine/tests/unit/test_pm_lockfile.jac
"""

import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.pm.fsx { fsx_read_text, fsx_exists }
import from engine.src.pm.json { json_parse_str, JsonDoc, jv_get, JVal }
import from engine.src.pm.lockfile {
    Lockfile,
    LockPkg,
    LockWorkspace,
    LockDep,
    lockfile_load,
    lockfile_parse_bytes,
    lockfile_serialize,
    lockfile_key_segments,
    lockfile_key_to_path,
    lockfile_split_resolution,
    lockfile_root,
    lockfile_get,
    lockfile_resolve_from,
    lockfile_pkg_enabled,
    lockfile_entry,
    lockfile_info_object
}
import from engine.src.pm.bytes { str_to_cbuf }
import from engine.src.pm.platform {
    pm_os_matches,
    pm_cpu_matches,
    pm_platform_to_json,
    pm_platform_field_is_all
}

glob _ok: int = 0,
     _fail: int = 0;

def check(cond: bool, name: str) {
    if cond {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name);
    }
}

def check_eq(got: str, want: str, name: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name + " — got '" + got + "' want '" + want + "'");
    }
}

def first_diff(a: str, b: str) -> str {
    n: int = len(a);
    if len(b) < n {
        n = len(b);
    }
    i: int = 0;
    while i < n and a[i] == b[i] {
        i = i + 1;
    }
    lo: int = i - 60;
    if lo < 0 {
        lo = 0;
    }
    return "at byte "
        + str(i)
        + ": got …"
        + a[lo:i + 60]
        + "… want …"
        + b[lo:i + 60]
        + "…";
}

def parse_str(text: str) -> Lockfile {
    p: int = str_to_cbuf(text);
    return lockfile_parse_bytes(p, len(text));
}

with entry {
    # ── keys / resolutions ───────────────────────────────────────────────────
    check_eq(
        ",".join(lockfile_key_segments("is-even/is-odd/is-number")),
        "is-even,is-odd,is-number",
        "key segments"
    );
    check_eq(
        ",".join(lockfile_key_segments("@babel/core/semver")),
        "@babel/core,semver",
        "key segments scoped parent"
    );
    check_eq(
        ",".join(lockfile_key_segments("vite/@rollup/rollup-linux-x64-gnu")),
        "vite,@rollup/rollup-linux-x64-gnu",
        "key segments scoped child"
    );
    check_eq(
        lockfile_key_to_path("is-even/is-odd"),
        "node_modules/is-even/node_modules/is-odd",
        "key to path"
    );
    check_eq(lockfile_key_to_path("@ws/a"), "node_modules/@ws/a", "key to path scoped");
    r1: tuple[str, str] = lockfile_split_resolution("@ws/a@workspace:packages/a");
    check_eq(
        r1[0] + "|" + r1[1], "@ws/a|workspace:packages/a", "split scoped resolution"
    );
    r2: tuple[str, str] = lockfile_split_resolution("is-odd@3.0.1");
    check_eq(r2[0] + "|" + r2[1], "is-odd|3.0.1", "split resolution");
    r3: tuple[str, str] = lockfile_split_resolution(
        "x@git+ssh://git@github.com/a/b.git#abc"
    );
    check_eq(
        r3[0] + "|" + r3[1],
        "x|git+ssh://git@github.com/a/b.git#abc",
        "split git resolution"
    );
}

glob
     # ── golden round-trips ───────────────────────────────────────────────────
     fixtures: list[str] = [
         "simple",
         "react_app",
         "jac_client",
         "workspace",
         "platform_optional",
         "lifecycle"
     ];
with entry {
    for fx in fixtures {
        path: str = "tools/pm_diff/golden/" + fx + "/install-fresh/bun.lock";
        if not fsx_exists(path) {
            print("skip (no golden): " + path);
            continue;
        }
        text: str = fsx_read_text(path);
        lf: Lockfile = lockfile_load(path);
        check(lf.ok, "golden parses: " + fx + " " + lf.error);
        out: str = lockfile_serialize(lf);
        if out == text {
            _ok = _ok + 1;
        } else {
            _fail = _fail + 1;
            print("FAIL: golden round-trip " + fx + " " + first_diff(out, text));
        }
    }

    # workspace golden: model checks
    wsl: Lockfile = lockfile_load(
        "tools/pm_diff/golden/workspace/install-fresh/bun.lock"
    );
    if wsl.ok {
        check_eq(str(len(wsl.workspaces)), "3", "workspace count");
        check_eq(lockfile_root(wsl).name, "ws-root", "root workspace name");
        check_eq(
            lockfile_root(wsl).deps[0].group
                + ":"
                + lockfile_root(wsl).deps[0].name
                + "@"
                + lockfile_root(wsl).deps[0].spec,
            "devDependencies:is-odd@3.0.1",
            "root dep"
        );
        check_eq(str(len(wsl.packages)), "10", "workspace package count");
        wa: LockPkg = lockfile_get(wsl, "@ws/a");
        check_eq(
            wa.kind + "|" + wa.name + "|" + wa.version,
            "workspace|@ws/a|packages/a",
            "workspace entry"
        );
        nested: LockPkg = lockfile_get(wsl, "is-even/is-odd/is-number");
        check_eq(
            nested.name
                + "@"
                + nested.version
                + " depth="
                + str(nested.depth)
                + " parent="
                + nested.parent_key
                + " alias="
                + nested.dep_name,
            "is-number@3.0.0 depth=2 parent=is-even/is-odd alias=is-number",
            "nested entry"
        );
        check_eq(
            nested.deps[0].name + "@" + nested.deps[0].spec,
            "kind-of@^3.0.2",
            "nested deps"
        );
        check(
            nested.has_integrity and nested.integrity.startswith("sha512-"),
            "integrity read"
        );
        check_eq(
            lockfile_resolve_from(wsl, "is-even/is-odd", "is-number").version,
            "3.0.0",
            "resolve nested"
        );
        check_eq(
            lockfile_resolve_from(wsl, "is-even", "is-number").version,
            "7.0.0",
            "resolve hoisted from mid path"
        );
        check_eq(
            lockfile_resolve_from(wsl, "", "kind-of").version,
            "3.2.2",
            "resolve from root"
        );
        check_eq(
            lockfile_resolve_from(wsl, "is-odd", "nope").key, "", "resolve missing"
        );
    }

    # platform golden: os/cpu
    pl: Lockfile = lockfile_load(
        "tools/pm_diff/golden/platform_optional/install-fresh/bun.lock"
    );
    if pl.ok {
        lx: LockPkg = lockfile_get(pl, "@esbuild/linux-x64");
        check(
            lockfile_pkg_enabled(lx, "linux", "x64"), "linux-x64 enabled on linux/x64"
        );
        check(
            not lockfile_pkg_enabled(lx, "darwin", "x64"),
            "linux-x64 disabled on darwin"
        );
        check(
            not lockfile_pkg_enabled(lockfile_get(pl, "fsevents"), "linux", "x64"),
            "fsevents disabled on linux"
        );
        check(
            lockfile_pkg_enabled(lockfile_get(pl, "esbuild"), "linux", "x64"),
            "esbuild enabled everywhere"
        );
        check_eq(
            lockfile_get(pl, "esbuild").bin.vals["esbuild"].s,
            "bin/esbuild",
            "bin map read"
        );
    }
}

glob
     # ── synthetic: other entry kinds + formatting details ────────────────────
     syn: str = "{\n  \"lockfileVersion\": 1,\n  \"configVersion\": 1,\n  \"workspaces\": {\n    \"\": {\n      \"name\": \"syn\",\n      \"dependencies\": {\n        \"a\": \"^1.0.0\",\n      },\n      \"peerDependencies\": {\n        \"p\": \"*\",\n      },\n      \"optionalPeers\": [\n        \"p\",\n      ],\n    },\n    \"pk/b\": {\n      \"name\": \"b\",\n      \"version\": \"2.0.0\",\n      \"bin\": {\n        \"b\": \"cli.js\",\n      },\n    },\n  },\n  \"trustedDependencies\": [\n    \"a\",\n  ],\n  \"packages\": {\n    \"a\": [\"a@1.2.3\", \"\", { \"dependencies\": { \"c\": \"~2\" }, \"peerDependencies\": { \"p\": \"*\" }, \"optionalPeers\": [\"p\"], \"os\": [ \"darwin\", \"linux\", ], \"cpu\": \"!arm\", \"bin\": \"./cli.js\" }, \"sha512-AAAA\"],\n\n    \"b\": [\"b@workspace:pk/b\"],\n\n    \"c\": [\"c@2.0.0\", \"\", { \"bundled\": true, \"binDir\": \"bins\" }, \"sha512-BBBB\"],\n\n    \"d\": [\"d@file:../d\", { \"dependencies\": { \"a\": \"1\" } }],\n\n    \"e\": [\"e@link:../e\", {}],\n\n    \"f\": [\"f@github:user/repo\", {}, \"abc123\", \"sha512-CCCC\"],\n\n    \"g\": [\"g@https://example.com/g.tgz\", {}, \"sha512-DDDD\"],\n\n    \"h\": [\"h@git+https://github.com/u/h.git#deadbeef\", {}, \"deadbeef\"],\n\n    \"a/c\": [\"c@2.1.0\", \"\", {}, \"sha512-EEEE\"],\n  }\n}\n";
with entry {
    sl: Lockfile = parse_str(syn);
    check(sl.ok, "synthetic parses: " + sl.error);
    out2: str = lockfile_serialize(sl);
    if out2 == syn {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: synthetic round-trip " + first_diff(out2, syn));
    }
    a: LockPkg = lockfile_get(sl, "a");
    check_eq(
        a.kind + " " + a.version + " url=[" + a.url + "] " + a.integrity,
        "npm 1.2.3 url=[] sha512-AAAA",
        "npm entry default registry"
    );
    check(
        a.deps[1].optional_peer and a.deps[1].group == "peerDependencies",
        "optional peer flagged"
    );
    check(
        pm_os_matches(a.os, "linux")
            and pm_os_matches(a.os, "darwin")
            and not pm_os_matches(a.os, "win32"),
        "os list"
    );
    check(
        pm_cpu_matches(a.cpu, "x64") and not pm_cpu_matches(a.cpu, "arm"),
        "cpu negation"
    );
    check_eq(a.bin.s, "./cli.js", "bin string");
    check_eq(
        lockfile_get(sl, "c").bin_dir + " " + str(lockfile_get(sl, "c").bundled),
        "bins True",
        "binDir + bundled"
    );
    check_eq(
        lockfile_get(sl, "d").kind + ":" + lockfile_get(sl, "d").version,
        "folder:../d",
        "folder entry"
    );
    check_eq(
        lockfile_get(sl, "e").kind + ":" + lockfile_get(sl, "e").version,
        "symlink:../e",
        "symlink entry"
    );
    check_eq(
        lockfile_get(sl, "f").kind
            + ":"
            + lockfile_get(sl, "f").url
            + ":"
            + lockfile_get(sl, "f").integrity,
        "github:abc123:sha512-CCCC",
        "github entry"
    );
    check_eq(
        lockfile_get(sl, "g").kind + ":" + lockfile_get(sl, "g").integrity,
        "tarball:sha512-DDDD",
        "tarball entry"
    );
    check_eq(
        lockfile_get(sl, "h").kind
            + ":"
            + lockfile_get(sl, "h").url
            + ":"
            + str(lockfile_get(sl, "h").has_integrity),
        "git:deadbeef:False",
        "git entry without integrity"
    );
    check_eq(",".join(sl.trusted), "a", "trusted deps");
    check_eq(
        lockfile_root(sl).deps[1].name
            + ":"
            + str(lockfile_root(sl).deps[1].optional_peer),
        "p:True",
        "root optional peer"
    );
    check_eq(sl.workspaces[1].bin.vals["b"].s, "cli.js", "workspace bin");
    check_eq(
        lockfile_resolve_from(sl, "a", "c").version, "2.1.0", "nested c wins under a"
    );
    check_eq(lockfile_resolve_from(sl, "", "c").version, "2.0.0", "root c");

    # ── platform canonical printing ──────────────────────────────────────────
    check_eq(
        pm_platform_to_json(json_parse_str("\"linux\"").value, True),
        "\"linux\"",
        "platform one included"
    );
    check_eq(
        pm_platform_to_json(json_parse_str("[\"!win32\"]").value, True),
        "\"!win32\"",
        "platform one excluded"
    );
    check_eq(
        pm_platform_to_json(json_parse_str("[\"darwin\", \"linux\"]").value, True),
        "[ \"darwin\", \"linux\", ]",
        "platform list canonical order"
    );
    check_eq(
        pm_platform_to_json(json_parse_str("[\"!win32\", \"!darwin\"]").value, True),
        "[ \"!darwin\", \"!win32\", ]",
        "platform negated list"
    );
    check_eq(
        pm_platform_to_json(json_parse_str("[\"plan9\"]").value, True),
        "\"none\"",
        "platform unrecognized -> none"
    );
    check(
        pm_platform_field_is_all(json_parse_str("[]").value, True),
        "platform empty list is all"
    );
    check(
        pm_platform_field_is_all(json_parse_str("\"any\"").value, True),
        "platform any is all"
    );
    check(
        not pm_platform_field_is_all(json_parse_str("\"linux\"").value, True),
        "platform linux not all"
    );
    check_eq(
        pm_platform_to_json(json_parse_str("[\"x64\", \"arm64\"]").value, False),
        "[ \"arm64\", \"x64\", ]",
        "cpu list canonical"
    );

    # empty lockfile
    el: Lockfile = parse_str(
        "{\n  \"lockfileVersion\": 1,\n  \"configVersion\": 1,\n  \"workspaces\": {\n    \"\": {},\n  },\n  \"packages\": {}\n}\n"
    );
    check(el.ok, "empty lockfile parses");
    check_eq(
        lockfile_serialize(el),
        "{\n  \"lockfileVersion\": 1,\n  \"configVersion\": 1,\n  \"workspaces\": {\n    \"\": {},\n  },\n  \"packages\": {}\n}\n",
        "empty lockfile round-trip"
    );

    print("pm_lockfile: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
