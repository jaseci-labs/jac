"""Unit tests for the install-side helpers: paths, bin linking, manifest vs
lockfile comparison, workspace globbing, timing format.

Run from the repo root:  jac run engine/tests/unit/test_pm_install.jac
"""

import from engine.src.ffi.libc { fflush, _exit, getenv }
import from engine.src.pm.paths {
    pm_path_normalize,
    pm_path_join,
    pm_path_relative,
    pm_path_dirname,
    pm_path_basename,
    pm_unscoped_name,
    pm_normalized_bin_name
}
import from engine.src.pm.fsx {
    fsx_mkdtemp,
    fsx_mkdir_p,
    fsx_write_str,
    fsx_readlink,
    fsx_is_symlink,
    fsx_perm,
    fsx_rm_rf,
    fsx_exists,
    fsx_umask_set,
    fsx_read_text
}
import from engine.src.pm.json { json_parse_str, JsonDoc, JVal, jv_get }
import from engine.src.pm.bins { BinSpec, BinLinkStats, pm_link_bins }
import from engine.src.pm.lockfile { Lockfile, lockfile_load, LockDep, lockfile_root }
import from engine.src.pm.install { pm_lockfile_matches, pm_fmt_elapsed }
import from engine.src.pm.project { pm_workspace_dirs }
import from engine.src.pm.bytes { str_to_cbuf }

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

with entry {
    # ── paths ────────────────────────────────────────────────────────────────
    check_eq(pm_path_normalize("/a/b/../c/./d//e"), "/a/c/d/e", "normalize abs");
    check_eq(pm_path_normalize("a/../../b"), "../b", "normalize rel climbs");
    check_eq(pm_path_normalize("/../x"), "/x", "normalize abs clamps");
    check_eq(pm_path_normalize(""), ".", "normalize empty");
    check_eq(
        pm_path_join("/p/node_modules/vite", "./bin/vite.js"),
        "/p/node_modules/vite/bin/vite.js",
        "join ./"
    );
    check_eq(pm_path_join("/p", "/abs"), "/abs", "join abs wins");
    check_eq(
        pm_path_relative("/p/node_modules/.bin", "/p/node_modules/vite/bin/vite.js"),
        "../vite/bin/vite.js",
        "relative bin"
    );
    check_eq(
        pm_path_relative("/p/packages/b/node_modules/@ws", "/p/packages/a"),
        "../../../a",
        "relative workspace"
    );
    check_eq(
        pm_path_relative("/p/node_modules", "/p/packages/a"),
        "../packages/a",
        "relative hoisted workspace"
    );
    check_eq(pm_path_relative("/p", "/p"), ".", "relative same");
    check_eq(pm_path_dirname("/a/b/c"), "/a/b", "dirname");
    check_eq(pm_path_dirname("c"), ".", "dirname bare");
    check_eq(pm_path_basename("/a/b/c.js"), "c.js", "basename");
    check_eq(pm_unscoped_name("@babel/parser"), "parser", "unscoped");
    check_eq(pm_unscoped_name("vite"), "vite", "unscoped plain");
    check_eq(pm_normalized_bin_name("./bin/x"), "x", "bin name strips dirs");
    check_eq(pm_normalized_bin_name("a:b"), "b", "bin name strips colon");
    check_eq(pm_normalized_bin_name("tsc"), "tsc", "bin name plain");

    # ── bins ─────────────────────────────────────────────────────────────────
    tmp_root: str = getenv("TMPDIR");
    if tmp_root == None or tmp_root == "" {
        tmp_root = "/tmp";
    }
    tmp: str = fsx_mkdtemp(tmp_root + "/jbpmbinXXXXXX");
    old_umask: int = fsx_umask_set(18);
    nm: str = tmp + "/node_modules";
    fsx_mkdir_p(nm + "/vite/bin", 493);
    fsx_write_str(nm + "/vite/bin/vite.js", "#!/usr/bin/env node\n", 420);
    fsx_mkdir_p(nm + "/@babel/parser/bin", 493);
    fsx_write_str(nm + "/@babel/parser/bin/babel-parser.js", "x", 420);
    fsx_mkdir_p(nm + "/typescript/bin", 493);
    fsx_write_str(nm + "/typescript/bin/tsc", "x", 420);
    fsx_write_str(nm + "/typescript/bin/tsserver", "x", 420);
    fsx_mkdir_p(nm + "/tool/scripts", 493);
    fsx_write_str(nm + "/tool/scripts/one", "x", 420);
    fsx_write_str(nm + "/tool/scripts/two", "x", 420);
}

glob seen: dict[str, bool] = {};
with entry {
    stats: BinLinkStats = BinLinkStats();
    vite_bin: JVal = json_parse_str("{\"vite\": \"bin/vite.js\"}").value;
    missing: bool = pm_link_bins(
        nm,
        BinSpec(alias="vite", package_dir=nm + "/vite", bin=vite_bin, bin_dir=""),
        seen,
        stats
    );
    check(not missing, "vite bin linked");
    check_eq(
        fsx_readlink(nm + "/.bin/vite"), "../vite/bin/vite.js", "vite link target"
    );
    check_eq(str(fsx_perm(nm + "/vite/bin/vite.js")), "511", "bin target chmod 0777");
    check_eq(str(fsx_perm(nm + "/.bin")), "493", ".bin dir 0755");
    parser_bin: JVal = json_parse_str("\"./bin/babel-parser.js\"").value;
    pm_link_bins(
        nm,
        BinSpec(
            alias="@babel/parser",
            package_dir=nm + "/@babel/parser",
            bin=parser_bin,
            bin_dir=""
        ),
        seen,
        stats
    );
    check_eq(
        fsx_readlink(nm + "/.bin/parser"),
        "../@babel/parser/bin/babel-parser.js",
        "string bin uses unscoped name"
    );
    ts_bin: JVal = json_parse_str(
        "{\"tsc\": \"bin/tsc\", \"tsserver\": \"bin/tsserver\"}"
    ).value;
    pm_link_bins(
        nm,
        BinSpec(
            alias="typescript", package_dir=nm + "/typescript", bin=ts_bin, bin_dir=""
        ),
        seen,
        stats
    );
    check(
        fsx_is_symlink(nm + "/.bin/tsc") and fsx_is_symlink(nm + "/.bin/tsserver"),
        "bin map links both"
    );
    pm_link_bins(
        nm,
        BinSpec(alias="tool", package_dir=nm + "/tool", bin=JVal(), bin_dir="scripts"),
        seen,
        stats
    );
    check_eq(
        fsx_readlink(nm + "/.bin/one") + " " + fsx_readlink(nm + "/.bin/two"),
        "../tool/scripts/one ../tool/scripts/two",
        "binDir links each file"
    );
    # conflict: second claim on "vite" is ignored (first wins)
    other_bin: JVal = json_parse_str("{\"vite\": \"bin/tsc\"}").value;
    pm_link_bins(
        nm,
        BinSpec(
            alias="typescript",
            package_dir=nm + "/typescript",
            bin=other_bin,
            bin_dir=""
        ),
        seen,
        stats
    );
    check_eq(
        fsx_readlink(nm + "/.bin/vite"), "../vite/bin/vite.js", "first bin claim wins"
    );
    # missing target is skipped and reported
    gone_bin: JVal = json_parse_str("{\"gone\": \"bin/gone.js\"}").value;
    miss2: bool = pm_link_bins(
        nm,
        BinSpec(alias="vite", package_dir=nm + "/vite", bin=gone_bin, bin_dir=""),
        seen,
        stats
    );
    check(miss2 and not fsx_exists(nm + "/.bin/gone"), "missing bin target skipped");
    check_eq(str(stats.linked), "6", "bins linked count");
    # existing wrong entry gets replaced (fresh seen set = new tree pass)
    fsx_write_str(nm + "/.bin/stale", "junk", 420);
}

glob seen2: dict[str, bool] = {};
with entry {
    stale_bin: JVal = json_parse_str("{\"stale\": \"bin/vite.js\"}").value;
    pm_link_bins(
        nm,
        BinSpec(alias="vite", package_dir=nm + "/vite", bin=stale_bin, bin_dir=""),
        seen2,
        stats
    );
    check(fsx_is_symlink(nm + "/.bin/stale"), "existing .bin entry replaced");
    fsx_umask_set(old_umask);
    fsx_rm_rf(tmp);
}

glob
     # ── manifest vs lockfile ─────────────────────────────────────────────────
     fx: str = "tools/pm_diff/fixtures";
with entry {
    simple_pj: JVal = json_parse_str(fsx_read_text(fx + "/simple/package.json")).value;
    simple_lf: Lockfile = lockfile_load(
        "tools/pm_diff/golden/simple/install-fresh/bun.lock"
    );
    if simple_lf.ok {
        check(
            pm_lockfile_matches(simple_lf, fx + "/simple", simple_pj),
            "simple lockfile matches its package.json"
        );
        changed: JVal = json_parse_str(
            "{\"name\": \"vite-example-simple\", \"devDependencies\": {\"vite\": \"6.4.2\"}}"
        ).value;
        check(
            not pm_lockfile_matches(simple_lf, fx + "/simple", changed),
            "changed spec detected"
        );
        added: JVal = json_parse_str(
            "{\"name\": \"vite-example-simple\", \"devDependencies\": {\"vite\": \"6.4.3\"}, \"dependencies\": {\"is-odd\": \"3.0.1\"}}"
        ).value;
        check(
            not pm_lockfile_matches(simple_lf, fx + "/simple", added),
            "added dep detected"
        );
        renamed: JVal = json_parse_str(
            "{\"name\": \"other\", \"devDependencies\": {\"vite\": \"6.4.3\"}}"
        ).value;
        check(
            not pm_lockfile_matches(simple_lf, fx + "/simple", renamed),
            "renamed project detected"
        );
        moved: JVal = json_parse_str(
            "{\"name\": \"vite-example-simple\", \"dependencies\": {\"vite\": \"6.4.3\"}}"
        ).value;
        check(
            not pm_lockfile_matches(simple_lf, fx + "/simple", moved),
            "dep moved between groups detected"
        );
    }
    ws_pj: JVal = json_parse_str(fsx_read_text(fx + "/workspace/package.json")).value;
    check_eq(
        ",".join(pm_workspace_dirs(fx + "/workspace", ws_pj)),
        "packages/a,packages/b",
        "workspace globs"
    );
    ws_lf: Lockfile = lockfile_load(
        "tools/pm_diff/golden/workspace/install-fresh/bun.lock"
    );
    if ws_lf.ok {
        check(
            pm_lockfile_matches(ws_lf, fx + "/workspace", ws_pj),
            "workspace lockfile matches"
        );
        check(
            not pm_lockfile_matches(ws_lf, fx + "/simple", ws_pj),
            "workspace dirs missing detected"
        );
    }
    react_pj: JVal = json_parse_str(
        fsx_read_text(fx + "/react_app/package.json")
    ).value;
    react_lf: Lockfile = lockfile_load(
        "tools/pm_diff/golden/react_app/install-fresh/bun.lock"
    );
    if react_lf.ok {
        check(
            pm_lockfile_matches(react_lf, fx + "/react_app", react_pj),
            "react_app lockfile matches"
        );
    }
    plat_pj: JVal = json_parse_str(
        fsx_read_text(fx + "/platform_optional/package.json")
    ).value;
    plat_lf: Lockfile = lockfile_load(
        "tools/pm_diff/golden/platform_optional/install-fresh/bun.lock"
    );
    if plat_lf.ok {
        check(
            pm_lockfile_matches(plat_lf, fx + "/platform_optional", plat_pj),
            "platform_optional lockfile matches (optionalDependencies)"
        );
    }

    # ── timing format ────────────────────────────────────────────────────────
    check_eq(pm_fmt_elapsed(12000000), "[12.00ms]", "elapsed ms");
    check_eq(pm_fmt_elapsed(1101000000), "[1101.00ms]", "elapsed 1101ms stays ms");
    check_eq(pm_fmt_elapsed(3620000000), "[3.62s]", "elapsed seconds");
    check_eq(pm_fmt_elapsed(1234567), "[1.23ms]", "elapsed fraction");

    print("pm_install: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
