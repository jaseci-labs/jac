"""Unit tests for `run` / `x` (pm/run.jac) and the run/x argument grammar.

Run from the repo root:  jac run engine/tests/unit/test_pm_run.jac
"""

import from engine.src.ffi.libc { fflush, _exit, getenv }
import from engine.src.pm.run {
    pm_find_project_dir,
    pm_run_script,
    pm_scripts_listing,
    pm_x_local
}
import from engine.src.pm.cli { pm_parse_args }
import from engine.src.pm.config { PmArgs }
import from engine.src.pm.fsx {
    fsx_mkdtemp,
    fsx_mkdir_p,
    fsx_write_str,
    fsx_read_text,
    fsx_rm_rf,
    fsx_chmod
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

with entry {
    # ── argument grammar ─────────────────────────────────────────────────────
    a: PmArgs = pm_parse_args(
        "run", ["js_engine", "run", "--silent", "build", "--flag", "-x", "--", "y"], 2
    );
    check_eq(",".join(a.positionals), "build", "run: first positional is the script");
    check_eq(
        ",".join(a.passthrough),
        "--flag,-x,--,y",
        "run: everything after the script passes through"
    );
    check("silent" in a.flags, "run: flags before the script are parsed");
    b: PmArgs = pm_parse_args("x", ["js_engine", "x", "cowsay", "--help"], 2);
    check(
        not b.help and ",".join(b.passthrough) == "--help",
        "x: --help after the binary passes through"
    );
    c: PmArgs = pm_parse_args(
        "install", ["js_engine", "install", "--frozen-lockfile", "a"], 2
    );
    check(
        "frozen-lockfile" in c.flags and ",".join(c.positionals) == "a",
        "install: flags parsed anywhere"
    );

    # ── project discovery + scripts ──────────────────────────────────────────
    tmp_root: str = getenv("TMPDIR");
    if tmp_root == None or tmp_root == "" {
        tmp_root = "/tmp";
    }
    tmp: str = fsx_mkdtemp(tmp_root + "/jbpmrunXXXXXX");
    fsx_mkdir_p(tmp + "/proj/src/deep", 493);
    fsx_write_str(
        tmp + "/proj/package.json",
        "{\"name\": \"p\", \"version\": \"2.0.0\", \"scripts\": {\"prebuild\": \"echo $npm_lifecycle_event >> out.txt\", \"build\": \"echo BUILD >> out.txt\", \"postbuild\": \"echo POST >> out.txt\", \"fail\": \"exit 4\", \"tool\": \"mytool a b\"}}",
        420
    );
    check_eq(
        pm_find_project_dir(tmp + "/proj/src/deep"),
        tmp + "/proj",
        "find project dir walks up"
    );
    check_eq(pm_find_project_dir(tmp), "", "no project above tmp");
    rc: int = pm_run_script(tmp + "/proj", "build", ["--flag", "x"], True);
    check_eq(str(rc), "0", "run build ok");
    check_eq(
        fsx_read_text(tmp + "/proj/out.txt"),
        "prebuild\nBUILD --flag x\nPOST\n",
        "pre/build(args appended like bun)/post order, npm_lifecycle_event"
    );
    check_eq(
        str(pm_run_script(tmp + "/proj", "fail", [], True)),
        "4",
        "failing script exit code"
    );
    check_eq(
        str(pm_run_script(tmp + "/proj", "nope", [], True)),
        "-1",
        "missing script -> -1"
    );
    listing: str = pm_scripts_listing(tmp + "/proj", "js_engine");
}

glob want_listing: str = "\npackage.json scripts (5 found):\n  $ js_engine run prebuild\n    echo $npm_lifecycle_event >> out.txt\n\n";
with entry {
    check_eq(listing[0:len(want_listing)], want_listing, "scripts listing format");
    # node_modules/.bin on PATH for scripts
    fsx_mkdir_p(tmp + "/proj/node_modules/.bin", 493);
    fsx_write_str(
        tmp + "/proj/node_modules/.bin/mytool",
        "#!/bin/sh\necho tool:$1:$2 > \"$INIT_CWD/tool.txt\"\n",
        493
    );
    fsx_chmod(tmp + "/proj/node_modules/.bin/mytool", 493);
    check_eq(
        str(pm_run_script(tmp + "/proj", "tool", [], True)),
        "0",
        "script finds .bin tool"
    );
    check_eq(
        fsx_read_text(tmp + "/proj/tool.txt"),
        "tool:a:b\n",
        ".bin tool ran with INIT_CWD"
    );
    # x: local binary
    check_eq(
        str(pm_x_local(tmp + "/proj/src", "mytool", ["q", "r"])),
        "0",
        "x runs local .bin from a subdirectory"
    );
    check_eq(
        fsx_read_text(tmp + "/proj/src/tool.txt"),
        "tool:q:r\n",
        "x passed arguments (INIT_CWD = start dir)"
    );
    check_eq(
        str(pm_x_local(tmp + "/proj", "not-installed-tool", [])),
        "-1",
        "x missing -> -1"
    );
    check_eq(
        str(pm_x_local(tmp + "/proj", "mytool@1.2.3", ["v"])),
        "0",
        "x strips a version suffix"
    );
    fsx_rm_rf(tmp);

    print("pm_run: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
