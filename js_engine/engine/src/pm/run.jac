"""`js_engine run <script> [args…]` and `js_engine x <bin> [args…]`.

run (bun's RunCommand): finds the enclosing package.json, runs `pre<script>`,
the script with the extra arguments appended, then `post<script>`, each
through the shell with PATH prefixed by every ancestor `node_modules/.bin`
(plus a `node` shim when no node is installed). Every command is echoed as
`$ <command>` on stderr unless --silent; a failing script prints
`error: script "<name>" exited with code <n>` and exits with that code.

x (bunx): runs `node_modules/.bin/<name>` from the enclosing project when it
exists; auto-installing a missing package is not implemented yet.
"""

import from engine.src.ffi.libc { write }
import from engine.src.pm.json { JVal, jv_get, jv_is_obj, jv_str, jv_get_str }
import from engine.src.pm.project { PkgJson, pm_read_package_json }
import from engine.src.pm.proc { ProcResult, proc_run, proc_env_inherit, proc_env_get }
import from engine.src.pm.lifecycle { lifecycle_shell, lifecycle_env }
import from engine.src.pm.fsx { fsx_is_file, fsx_cwd }
import from engine.src.pm.paths { pm_path_dirname, pm_unscoped_name }

def _out(s: str) {
    write(1, s, len(s));
}
def _err(s: str) {
    write(2, s, len(s));
}

"""Directory of the nearest package.json at or above `start` ("" if none)."""
def:pub pm_find_project_dir(start: str) -> str {
    dir: str = start;
    while True {
        if fsx_is_file(dir + "/package.json") {
            return dir;
        }
        parent: str = pm_path_dirname(dir);
        if parent == dir or parent == "" or parent == "." {
            return "";
        }
        if parent == "/" {
            if fsx_is_file("/package.json") {
                return "/";
            }
            return "";
        }
        dir = parent;
    }
}

def _run_one(
    root_dir: str, pj: JVal, name: str, script: str, extra: list[str], silent: bool
) -> int {
    cmd: str = script;
    if len(extra) > 0 {
        cmd = cmd + " " + " ".join(extra);
    }
    if not silent {
        _err("$ " + cmd + "\n");
    }
    env: list[str] = lifecycle_env(
        root_dir,
        root_dir,
        jv_get_str(pj, "name", ""),
        jv_get_str(pj, "version", ""),
        name,
        cmd
    );
    shell: str = lifecycle_shell(proc_env_get(env, "PATH"));
    r: ProcResult = proc_run([shell, "-c", cmd], root_dir, env, False);
    if not r.ok {
        _err("error: failed to run script \"" + name + "\": " + r.error + "\n");
        return 1;
    }
    if r.exit_code != 0 {
        _err(
            "error: script \"" + name + "\" exited with code " + str(r.exit_code) + "\n"
        );
    }
    return r.exit_code;
}

"""Run package.json script `name`. Returns the exit code, or -1 when there is
no such script (the caller decides what to do next)."""
def:pub pm_run_script(root_dir: str, name: str, extra: list[str], silent: bool) -> int {
    m: PkgJson = pm_read_package_json(root_dir + "/package.json");
    if not m.ok {
        return -1;
    }
    scripts: JVal = jv_get(m.json, "scripts");
    if not jv_is_obj(scripts) or not (name in scripts.vals) {
        return -1;
    }
    pre: str = jv_get_str(scripts, "pre" + name, "");
    if pre != "" {
        rc0: int = _run_one(root_dir, m.json, "pre" + name, pre, [], silent);
        if rc0 != 0 {
            return rc0;
        }
    }
    rc: int = _run_one(
        root_dir, m.json, name, jv_str(scripts.vals[name]), extra, silent
    );
    if rc != 0 {
        return rc;
    }
    post: str = jv_get_str(scripts, "post" + name, "");
    if post != "" {
        rc2: int = _run_one(root_dir, m.json, "post" + name, post, [], silent);
        if rc2 != 0 {
            return rc2;
        }
    }
    return 0;
}

"""bun's script listing (`bun run` with no arguments), appended to the help."""
def:pub pm_scripts_listing(root_dir: str, prog: str) -> str {
    m: PkgJson = pm_read_package_json(root_dir + "/package.json");
    if not m.ok {
        return "";
    }
    scripts: JVal = jv_get(m.json, "scripts");
    if not jv_is_obj(scripts) or len(scripts.keys) == 0 {
        return "";
    }
    out: list[str] = [
        "\npackage.json scripts (" + str(len(scripts.keys)) + " found):\n"
    ];
    for k in scripts.keys {
        out.append(
            "  $ " + prog + " run " + k + "\n    " + jv_str(scripts.vals[k]) + "\n\n"
        );
    }
    return "".join(out);
}

"""`x`: run a binary from the project's node_modules/.bin. Returns the exit
code, or -1 when the binary is not installed locally."""
def:pub pm_x_local(root_dir: str, pkg: str, extra: list[str]) -> int {
    name: str = pkg;
    start: int = 0;
    if name.startswith("@") {
        start = 1;
    }
    at: int = name.find("@", start);
    if at > 0 {
        name = name[0:at];
    }
    bin_name: str = pm_unscoped_name(name);
    dir: str = root_dir;
    bin_path: str = "";
    while True {
        cand: str = dir + "/node_modules/.bin/" + bin_name;
        if fsx_is_file(cand) {
            bin_path = cand;
            break;
        }
        parent: str = pm_path_dirname(dir);
        if parent == dir or parent == "" or parent == "." or parent == "/" {
            break;
        }
        dir = parent;
    }
    if bin_path == "" {
        return -1;
    }
    env: list[str] = lifecycle_env(root_dir, root_dir, "", "", "", "");
    argv: list[str] = [bin_path];
    for a in extra {
        argv.append(a);
    }
    r: ProcResult = proc_run(argv, root_dir, env, False);
    if not r.ok {
        _err("error: failed to run " + bin_path + ": " + r.error + "\n");
        return 1;
    }
    return r.exit_code;
}
