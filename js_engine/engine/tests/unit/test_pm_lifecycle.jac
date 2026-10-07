"""Unit tests for child processes (pm/proc.jac) and lifecycle scripts
(pm/lifecycle.jac).

Run from the repo root:  jac run engine/tests/unit/test_pm_lifecycle.jac
"""

import from engine.src.ffi.libc { fflush, _exit, getenv }
import from engine.src.pm.proc {
    ProcResult,
    proc_run,
    proc_env_inherit,
    proc_env_get,
    proc_env_set,
    proc_which
}
import from engine.src.pm.lifecycle {
    ScriptList,
    lifecycle_collect,
    lifecycle_run,
    lifecycle_is_trusted,
    lifecycle_install_script_count,
    lifecycle_shell,
    lifecycle_env,
    lifecycle_default_trusted
}
import from engine.src.pm.json { json_parse_str, JVal }
import from engine.src.pm.fsx {
    fsx_mkdtemp,
    fsx_read_text,
    fsx_rm_rf,
    fsx_exists,
    fsx_mkdir_p,
    fsx_write_str
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
    env: list[str] = proc_env_inherit();
    check(len(env) > 0 and proc_env_get(env, "PATH") != "", "env inherited with PATH");
    proc_env_set(env, "JB_TEST_VAR", "hello");
    check_eq(proc_env_get(env, "JB_TEST_VAR"), "hello", "env set/get");
    proc_env_set(env, "JB_TEST_VAR", "again");
    check_eq(proc_env_get(env, "JB_TEST_VAR"), "again", "env replace");

    # ── proc_run ─────────────────────────────────────────────────────────────
    r: ProcResult = proc_run(
        ["sh", "-c", "echo out-$JB_TEST_VAR; echo err 1>&2; exit 3"], "", env, True
    );
    check(r.ok, "spawn ok: " + r.error);
    check_eq(str(r.exit_code), "3", "exit code");
    check_eq(r.stdout, "out-again\n", "captured stdout with env");
    check_eq(r.stderr, "err\n", "captured stderr");
    tmp_root: str = getenv("TMPDIR");
    if tmp_root == None or tmp_root == "" {
        tmp_root = "/tmp";
    }
    tmp: str = fsx_mkdtemp(tmp_root + "/jbpmprocXXXXXX");
    r2: ProcResult = proc_run(["sh", "-c", "pwd"], tmp, env, True);
    check(r2.ok and r2.exit_code == 0, "cwd spawn ok");
    check(
        r2.stdout.strip().endswith(tmp[tmp.rfind("/"):]),
        "cwd honoured: " + r2.stdout.strip()
    );
    r3: ProcResult = proc_run(["definitely-not-a-binary-xyz"], "", env, True);
    check(not r3.ok or r3.exit_code == 127, "missing binary reported");
    # large output must not deadlock (both pipes > pipe buffer)
    r4: ProcResult = proc_run(
        [
            "sh",
            "-c",
            "i=0; while [ $i -lt 3000 ]; do echo 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; echo 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy' 1>&2; i=$((i+1)); done"
        ],
        "",
        env,
        True
    );
    check(
        r4.ok
            and r4.exit_code == 0
            and len(r4.stdout) == 3000 * 81
            and len(r4.stderr) == 3000 * 82,
        "large interleaved output drained"
    );
    check(proc_which("sh", proc_env_get(env, "PATH")) != "", "which sh");
    check_eq(
        proc_which("no-such-tool-abc", proc_env_get(env, "PATH")), "", "which missing"
    );

    # ── lifecycle collection ─────────────────────────────────────────────────
    pj: JVal = json_parse_str(
        "{\"name\": \"p\", \"version\": \"1.2.3\", \"scripts\": {\"preinstall\": \"a\", \"install\": \"b\", \"postinstall\": \"c\", \"prepare\": \"d\", \"preprepare\": \"e\", \"postprepare\": \"f\", \"test\": \"t\"}}"
    ).value;
    sl_root: ScriptList = lifecycle_collect(pj, tmp, "p", "root");
    check_eq(
        ",".join(sl_root.names),
        "preinstall,install,postinstall,preprepare,prepare,postprepare",
        "root script order"
    );
    sl_npm: ScriptList = lifecycle_collect(pj, tmp, "p", "npm");
    check_eq(
        ",".join(sl_npm.names), "preinstall,install,postinstall", "npm package scripts"
    );
    sl_ws: ScriptList = lifecycle_collect(pj, tmp, "p", "workspace");
    check_eq(
        ",".join(sl_ws.names),
        "preinstall,install,postinstall,prepare",
        "workspace scripts"
    );
    check_eq(str(lifecycle_install_script_count(pj)), "3", "install script count");
    pj2: JVal = json_parse_str("{\"scripts\": {\"postinstall\": \"x\"}}").value;
    check_eq(
        str(lifecycle_install_script_count(pj2)), "1", "single postinstall counted"
    );
    check_eq(
        str(lifecycle_install_script_count(json_parse_str("{}").value)),
        "0",
        "no scripts"
    );
    # binding.gyp auto script
    fsx_mkdir_p(tmp + "/gyp", 493);
    fsx_write_str(tmp + "/gyp/binding.gyp", "{}", 420);
    sl_gyp: ScriptList = lifecycle_collect(pj2, tmp + "/gyp", "g", "npm");
    check_eq(
        ",".join(sl_gyp.scripts),
        "node-gyp rebuild,x",
        "node-gyp rebuild inserted before postinstall"
    );

    # ── trust ────────────────────────────────────────────────────────────────
    defaults: list[str] = lifecycle_default_trusted("engine");
    check(
        len(defaults) > 300 and ("esbuild" in defaults) and not ("core-js" in defaults),
        "default trusted list loaded"
    );
    check(
        lifecycle_is_trusted("esbuild", "npm", [], False, defaults),
        "esbuild trusted by default"
    );
    check(
        not lifecycle_is_trusted("core-js", "npm", [], False, defaults),
        "core-js not trusted by default"
    );
    check(
        not lifecycle_is_trusted("esbuild", "git", [], False, defaults),
        "defaults apply to npm only"
    );
    check(
        lifecycle_is_trusted("core-js", "npm", ["core-js"], True, defaults),
        "project list trusts"
    );
    check(
        not lifecycle_is_trusted("esbuild", "npm", ["core-js"], True, defaults),
        "project list replaces defaults"
    );

    # ── running ──────────────────────────────────────────────────────────────
    shell: str = lifecycle_shell(proc_env_get(env, "PATH"));
    check(
        shell.endswith("/bash") or shell.endswith("/sh") or shell.endswith("/zsh"),
        "shell found: " + shell
    );
    penv: list[str] = lifecycle_env(
        tmp, tmp + "/pkg", "p", "1.2.3", "postinstall", "echo hi"
    );
    check(
        proc_env_get(penv, "PATH").startswith(tmp + "/pkg/node_modules/.bin:"),
        "PATH starts with package .bin"
    );
    check(
        proc_env_get(penv, "PATH").find(tmp + "/node_modules/.bin:") > 0,
        "PATH includes ancestor .bin"
    );
    check_eq(
        proc_env_get(penv, "npm_lifecycle_event"), "postinstall", "npm_lifecycle_event"
    );
    check_eq(proc_env_get(penv, "npm_package_version"), "1.2.3", "npm_package_version");
    check_eq(proc_env_get(penv, "INIT_CWD"), tmp, "INIT_CWD");
    run_pj: JVal = json_parse_str(
        "{\"name\": \"m\", \"scripts\": {\"preinstall\": \"echo $npm_lifecycle_event > pre.marker\", \"postinstall\": \"echo done > post.marker\"}}"
    ).value;
    fsx_mkdir_p(tmp + "/m", 493);
    sl_m: ScriptList = lifecycle_collect(run_pj, tmp + "/m", "m", "npm");
    rc: int = lifecycle_run(sl_m, tmp, "0.0.1", False);
    check_eq(str(rc), "0", "scripts run ok");
    check_eq(
        fsx_read_text(tmp + "/m/pre.marker"),
        "preinstall\n",
        "preinstall ran with npm_lifecycle_event"
    );
    check_eq(
        fsx_read_text(tmp + "/m/post.marker"),
        "done\n",
        "postinstall ran in package cwd"
    );
    fail_pj: JVal = json_parse_str(
        "{\"scripts\": {\"install\": \"exit 7\", \"postinstall\": \"echo never > never.marker\"}}"
    ).value;
    sl_f: ScriptList = lifecycle_collect(fail_pj, tmp + "/m", "m", "npm");
    rc2: int = lifecycle_run(sl_f, tmp, "", False);
    check_eq(str(rc2), "7", "failing script exit code propagated");
    check(
        not fsx_exists(tmp + "/m/never.marker"), "later scripts skipped after failure"
    );
    fsx_rm_rf(tmp);

    print("pm_lifecycle: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
