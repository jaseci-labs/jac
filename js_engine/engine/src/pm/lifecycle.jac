"""Lifecycle scripts, bun's way (src/install/lockfile/Package/Scripts.zig,
lifecycle_script_runner.zig, PackageManagerLifecycle.zig).

Which scripts run:
  - a registry package: preinstall, install, postinstall — only when trusted
    (package.json `trustedDependencies`, or bun's default list when the project
    does not define its own; npm resolutions only);
  - the root project: those three plus preprepare, prepare, postprepare;
  - a workspace: those three plus prepare;
  - packages replaced by the native-binlink optimisation run nothing.
Untrusted packages with install scripts are counted and reported afterwards
("Blocked N postinstall(s). Run `bun pm untrusted` for details.").

How: `<shell> -c <script>` (bash, sh, zsh from PATH, then well-known paths),
cwd = the package directory, PATH prefixed with every ancestor
`node_modules/.bin`, `node` = the real node when on PATH, otherwise a
temp-dir shim pointing at this binary. Root scripts run in the foreground and
echo `$ <script>` on stderr; dependency scripts are captured and shown only
when they fail.
"""

import from engine.src.pm.resources_gen { pm_default_trusted_resource }
import from engine.src.ffi.libc { write, getenv, getpid }
import from engine.src.pm.json {
    JVal,
    jv_get,
    jv_is_obj,
    jv_str,
    jv_get_str,
    jv_is_str
}
import from engine.src.pm.proc {
    ProcResult,
    proc_run,
    proc_env_inherit,
    proc_env_get,
    proc_env_set,
    proc_which
}
import from engine.src.pm.fsx {
    fsx_exists,
    fsx_is_file,
    fsx_mkdir_p,
    fsx_symlink,
    fsx_readlink,
    fsx_realpath
}
import from engine.src.pm.paths { pm_path_dirname }
import from engine.src.pm.project { PkgJson, pm_read_package_json }
import from engine.src.version { JS_ENGINE_VERSION }

def _err(s: str) {
    write(2, s, len(s));
}

glob:pub LIFECYCLE_NAMES: list[str] = [
         "preinstall",
         "install",
         "postinstall",
         "preprepare",
         "prepare",
         "postprepare"
     ];

obj:pub ScriptList {
    has cwd: str = "",
        package_name: str = "",
        names: list[str] = [],
        scripts: list[str] = [];
}

"""Collect the scripts bun would run for a package of `kind`
(root | workspace | npm | git). `add_node_gyp`: no install/preinstall but a
binding.gyp → an automatic "node-gyp rebuild" install step."""
def:pub lifecycle_collect(
    pj: JVal, cwd: str, package_name: str, kind: str
) -> ScriptList {
    sl: ScriptList = ScriptList(cwd=cwd, package_name=package_name);
    scripts: JVal = jv_get(pj, "scripts");
    if not jv_is_obj(scripts) {
        scripts = JVal();
    }
    def_get: str = "";
    has_install: bool = jv_get_str(scripts, "install", "") != "";
    has_pre: bool = jv_get_str(scripts, "preinstall", "") != "";
    if not has_install and not has_pre and fsx_is_file(cwd + "/binding.gyp") {
        sl.names.append("install");
        sl.scripts.append("node-gyp rebuild");
        post: str = jv_get_str(scripts, "postinstall", "");
        if post != "" {
            sl.names.append("postinstall");
            sl.scripts.append(post);
        }
    } else {
        for n in ["preinstall", "install", "postinstall"] {
            s: str = jv_get_str(scripts, n, "");
            if s != "" {
                sl.names.append(n);
                sl.scripts.append(s);
            }
        }
    }
    if kind == "root" or kind == "git" or kind == "github" {
        for n2 in ["preprepare", "prepare", "postprepare"] {
            s2: str = jv_get_str(scripts, n2, "");
            if s2 != "" {
                sl.names.append(n2);
                sl.scripts.append(s2);
            }
        }
    } elif kind == "workspace" {
        s3: str = jv_get_str(scripts, "prepare", "");
        if s3 != "" {
            sl.names.append("prepare");
            sl.scripts.append(s3);
        }
    }
    return sl;
}

"""Number of install-phase scripts (preinstall/install/postinstall) a
package.json declares — what bun counts as blocked."""
def:pub lifecycle_install_script_count(pj: JVal) -> int {
    scripts: JVal = jv_get(pj, "scripts");
    if not jv_is_obj(scripts) {
        return 0;
    }
    n: int = 0;
    for name in ["preinstall", "install", "postinstall"] {
        if jv_get_str(scripts, name, "") != "" {
            n = n + 1;
        }
    }
    return n;
}

"""bun's default trusted list (data/default-trusted.txt, compiled in:
resources_gen.jac)."""
def:pub lifecycle_default_trusted -> list[str] {
    out: list[str] = [];
    text: str = pm_default_trusted_resource();
    for line in text.split("\n") {
        t: str = line.strip();
        if t != "" and not t.startswith("#") {
            out.append(t);
        }
    }
    return out;
}

"""bun's hasTrustedDependency: a project-defined list replaces the default one."""
def:pub lifecycle_is_trusted(
    name: str,
    kind: str,
    project_trusted: list[str],
    has_project_list: bool,
    default_trusted: list[str]
) -> bool {
    if has_project_list {
        return name in project_trusted;
    }
    return kind == "npm" and (name in default_trusted);
}

glob:priv _SHELL: str = "";

"""bun's findShell: bash, sh, zsh on PATH, then well-known locations."""
def:pub lifecycle_shell(path_env: str) -> str {
    if _SHELL != "" {
        return _SHELL;
    }
    for name in ["bash", "sh", "zsh"] {
        found: str = proc_which(name, path_env);
        if found != "" {
            _SHELL = found;
            return found;
        }
    }
    for cand in [
        "/bin/bash",
        "/usr/bin/bash",
        "/usr/local/bin/bash",
        "/bin/sh",
        "/usr/bin/sh",
        "/usr/bin/zsh",
        "/usr/local/bin/zsh"
    ] {
        if fsx_is_file(cand) {
            _SHELL = cand;
            return cand;
        }
    }
    return "/bin/sh";
}

glob:priv _NODE_SHIM_DIR: str = "",
     _NODE_SHIM_CHECKED: bool = False,
     _NODE_SHIM_FORCE: bool = False;

"""`-b` / `--bun`: scripts always get `node` → this executable, even when a
real node is on PATH (bun's meaning of the flag: use its runtime, not Node.js)."""
def:pub lifecycle_force_node_shim(v: bool) {
    _NODE_SHIM_FORCE = v;
}

"""Directory to prepend to PATH so `node` resolves: "" when a real node is on
PATH (unless forced), otherwise a temp dir holding `node` → this executable
(bun does the same with itself)."""
def:pub lifecycle_node_shim_dir(path_env: str) -> str {
    if _NODE_SHIM_CHECKED {
        return _NODE_SHIM_DIR;
    }
    _NODE_SHIM_CHECKED = True;
    if not _NODE_SHIM_FORCE and proc_which("node", path_env) != "" {
        return "";
    }
    self_exe: str = fsx_readlink("/proc/self/exe");
    if self_exe == "" {
        return "";
    }
    tmp: str = getenv("TMPDIR");
    if tmp == None or tmp == "" {
        tmp = "/tmp";
    }
    dir: str = tmp + "/js_engine-node-" + str(getpid());
    if not fsx_mkdir_p(dir, 493) {
        return "";
    }
    if not fsx_exists(dir + "/node") {
        fsx_symlink(self_exe, dir + "/node");
    }
    _NODE_SHIM_DIR = dir;
    return dir;
}

"""Environment for a script of the package at `cwd` (root project `root_dir`)."""
def:pub lifecycle_env(
    root_dir: str,
    cwd: str,
    package_name: str,
    package_version: str,
    script_name: str,
    script: str
) -> list[str] {
    env: list[str] = proc_env_inherit();
    path_env: str = proc_env_get(env, "PATH");
    parts: list[str] = [];
    dir: str = cwd;
    while True {
        parts.append(dir + "/node_modules/.bin");
        parent: str = pm_path_dirname(dir);
        if parent == dir or parent == "." or parent == "" or parent == "/" {
            break;
        }
        dir = parent;
    }
    shim: str = lifecycle_node_shim_dir(path_env);
    if shim != "" {
        parts.append(shim);
    }
    parts.append(path_env);
    proc_env_set(env, "PATH", ":".join(parts));
    proc_env_set(env, "INIT_CWD", root_dir);
    proc_env_set(env, "npm_lifecycle_event", script_name);
    proc_env_set(env, "npm_lifecycle_script", script);
    proc_env_set(env, "npm_package_name", package_name);
    if package_version != "" {
        proc_env_set(env, "npm_package_version", package_version);
    }
    proc_env_set(
        env,
        "npm_config_user_agent",
        "bun/1.3.13 npm/? node/? linux x64 js_engine/" + JS_ENGINE_VERSION
    );
    return env;
}

"""Run the scripts of `sl` in order. Foreground scripts echo `$ <script>` and
inherit stdio; background ones are captured and printed only on failure.
Returns the first non-zero exit code (0 on success)."""
def:pub lifecycle_run(
    sl: ScriptList, root_dir: str, package_version: str, foreground: bool
) -> int {
    if len(sl.scripts) == 0 {
        return 0;
    }
    base_env: list[str] = proc_env_inherit();
    shell: str = lifecycle_shell(proc_env_get(base_env, "PATH"));
    i: int = 0;
    while i < len(sl.scripts) {
        script: str = sl.scripts[i];
        name: str = sl.names[i];
        i = i + 1;
        if foreground {
            _err("$ " + script + "\n");
        }
        env: list[str] = lifecycle_env(
            root_dir, sl.cwd, sl.package_name, package_version, name, script
        );
        r: ProcResult = proc_run([shell, "-c", script], sl.cwd, env, not foreground);
        if not r.ok {
            _err(
                "error: Failed to run script "
                    + name
                    + " for \""
                    + sl.package_name
                    + "\": "
                    + r.error
                    + "\n"
            );
            return 1;
        }
        if r.exit_code != 0 {
            if not foreground {
                if r.stdout != "" {
                    _err(r.stdout + "\n");
                }
                if r.stderr != "" {
                    _err(r.stderr + "\n");
                }
            }
            _err(
                "error: "
                    + name
                    + " script from \""
                    + sl.package_name
                    + "\" exited with "
                    + str(r.exit_code)
                    + "\n"
            );
            return r.exit_code;
        }
    }
    return 0;
}
