"""`js_engine pm untrusted | trust | default-trusted` — bun's
src/cli/pm_trusted_command.zig.

untrusted: every dependency of the lockfile that is not trusted (the project's
`trustedDependencies` list when present, else bun's default list) and whose
installed package.json has install scripts is listed as
    ./node_modules/<path> @<version>
     » [postinstall]: <script>
followed by the hint to run `js_engine pm trust`; with none: "Found 0 untrusted
dependencies with scripts." The banner goes to stderr.

trust <names…> | --all: the selected packages' scripts run (deepest folders
first, output shown only on failure), each package is printed with ✓ (skipped
untrusted ones with »), the names are appended to package.json
"trustedDependencies" (an existing array is kept; bun fills the new slots from
the end, so several new names land in reverse order) and to the lockfile's
"trustedDependencies", and the summary reads
    " N script(s) ran across M package(s) [time]"  (+ " K package(s) with blocked scripts")
Nothing to run → exit 1 with bun's "0 scripts ran" error; no names and no
--all → "error: expected package names(s) or --all".

default-trusted: bun's default list (engine/src/pm/data/default-trusted.txt).
"""

import from engine.src.ffi.libc { write }
import from engine.src.ffi.libuv { uv_hrtime }
import from engine.src.pm.config { PmArgs, PmConfig }
import from engine.src.pm.json {
    JVal,
    jv_get,
    jv_is_arr,
    jv_str_list,
    jv_has,
    jv_set,
    jv_array,
    jv_push,
    jv_string
}
import from engine.src.pm.project { PkgJson, pm_read_package_json }
import from engine.src.pm.add { pm_print_package_json, pm_guess_indent }
import from engine.src.pm.fsx {
    fsx_is_file,
    fsx_write_str,
    fsx_perm,
    fsx_rename,
    fsx_unlink
}
import from engine.src.pm.lockfile {
    Lockfile,
    LockPkg,
    lockfile_load,
    lockfile_key_to_path,
    lockfile_serialize
}
import from engine.src.pm.lifecycle {
    ScriptList,
    lifecycle_collect,
    lifecycle_default_trusted,
    lifecycle_is_trusted,
    lifecycle_run
}
import from engine.src.pm.install { pm_fmt_elapsed }

def _out(s: str) {
    write(1, s, len(s));
}
def _err(s: str) {
    write(2, s, len(s));
}

"""An installed, untrusted dependency with install scripts."""
obj:pub Untrusted {
    has key: str = "",
        alias: str = "",
        version: str = "",
        depth: int = 0,
        sl: ScriptList = ScriptList(),
        selected: bool = False;
}

def:pub pm_cmd_default_trusted(eroot: str) -> int {
    defaults: list[str] = lifecycle_default_trusted(eroot);
    _out("Default trusted dependencies (" + str(len(defaults)) + "):\n");
    for n in defaults {
        _out(" - " + n + "\n");
    }
    return 0;
}

"""The lockfile's untrusted dependencies that have install scripts, in the
lockfile's (depth, path) order — bun walks the node_modules tree the same way."""
def:pub pm_collect_untrusted(
    eroot: str, root_dir: str, pj: JVal, lf: Lockfile
) -> list[Untrusted] {
    project_trusted: list[str] = jv_str_list(jv_get(pj, "trustedDependencies"));
    has_list: bool = jv_has(pj, "trustedDependencies");
    defaults: list[str] = lifecycle_default_trusted(eroot);
    out: list[Untrusted] = [];
    for p in lf.packages {
        if p.kind == "workspace" or p.kind == "root" {
            continue;
        }
        if lifecycle_is_trusted(
            p.dep_name, p.kind, project_trusted, has_list, defaults
        ) {
            continue;
        }
        dir: str = root_dir + "/" + lockfile_key_to_path(p.key);
        dpj: PkgJson = pm_read_package_json(dir + "/package.json");
        if not dpj.ok {
            continue;
        }  # not installed (ENOENT): bun skips it too
        sl: ScriptList = lifecycle_collect(dpj.json, dir, p.name, p.kind);
        if len(sl.names) == 0 {
            continue;
        }
        out.append(
            Untrusted(
                key=p.key, alias=p.dep_name, version=p.version, depth=p.depth, sl=sl
            )
        );
    }
    return out;
}

"""bun's Package.Scripts.List.printScripts: the folder and one line per script."""
def _print_scripts(u: Untrusted, mark: str) {
    _out("./" + lockfile_key_to_path(u.key) + " @" + u.version + "\n");
    i: int = 0;
    while i < len(u.sl.names) {
        _out(" " + mark + " [" + u.sl.names[i] + "]: " + u.sl.scripts[i] + "\n");
        i = i + 1;
    }
}

def _load(root_dir: str) -> tuple[bool, Lockfile, JVal] {
    lf: Lockfile = lockfile_load(root_dir + "/bun.lock");
    if not lf.ok {
        _err("error: Lockfile not found\n");
        return (False, lf, JVal());
    }
    pj: JVal = JVal();
    m: PkgJson = pm_read_package_json(root_dir + "/package.json");
    if m.ok {
        pj = m.json;
    }
    return (True, lf, pj);
}

def:pub pm_cmd_untrusted(eroot: str, cfg: PmConfig, banner: str) -> int {
    _err(banner + "\n");
    loaded: tuple[bool, Lockfile, JVal] = _load(cfg.cwd);
    if not loaded[0] {
        return 1;
    }
    us: list[Untrusted] = pm_collect_untrusted(eroot, cfg.cwd, loaded[2], loaded[1]);
    if len(us) == 0 {
        _out(
            "Found 0 untrusted dependencies with scripts.\n\nThis means all packages with scripts are in \"trustedDependencies\" or none of your dependencies have scripts.\n\nFor more information, visit https://bun.com/docs/install/lifecycle#trusteddependencies\n"
        );
        return 0;
    }
    for u in us {
        _print_scripts(u, "»");
        _out("\n");
    }
    _out(
        "These dependencies had their lifecycle scripts blocked during install.\n\nIf you trust them and wish to run their scripts, use `js_engine pm trust`.\n"
    );
    return 0;
}

def _zero_ran(trust_all: bool, names: list[str]) -> int {
    _out("\n");
    if trust_all {
        _err(
            "error: 0 scripts ran. This means all dependencies are already trusted or none have scripts.\n"
        );
    } else {
        _err(
            "error: 0 scripts ran. The following packages are already trusted, don't have scripts to run, or don't exist:\n\n"
        );
        for n in names {
            _err(" - " + n + "\n");
        }
    }
    return 1;
}

"""Deepest node_modules folders first (bun iterates the depth groups in reverse)."""
def _by_depth_desc(us: list[Untrusted]) -> list[Untrusted] {
    out: list[Untrusted] = [];
    max_depth: int = 0;
    for u in us {
        if u.depth > max_depth {
            max_depth = u.depth;
        }
    }
    d: int = max_depth;
    while d >= 0 {
        for u in us {
            if u.depth == d {
                out.append(u);
            }
        }
        d = d - 1;
    }
    return out;
}

def _plural(n: int, word: str) -> str {
    if n > 1 {
        return word + "s";
    }
    return word;
}

def:pub pm_cmd_trust(eroot: str, args: PmArgs, cfg: PmConfig, banner: str) -> int {
    start: int = uv_hrtime();
    _err(banner);
    names: list[str] = [];
    i: int = 1;  # positionals[0] is "trust"
    while i < len(args.positionals) {
        names.append(args.positionals[i]);
        i = i + 1;
    }
    trust_all: bool = ("all" in args.flags) or ("analyze" in args.flags);  # -a is bun's short form
    if not trust_all and len(names) == 0 {
        _err("error: expected package names(s) or --all\n");
        return 1;
    }
    root_dir: str = cfg.cwd;
    loaded: tuple[bool, Lockfile, JVal] = _load(root_dir);
    if not loaded[0] {
        return 1;
    }
    lf: Lockfile = loaded[1];
    pj: JVal = loaded[2];
    us: list[Untrusted] = pm_collect_untrusted(eroot, root_dir, pj, lf);
    if len(us) == 0 {
        return _zero_ran(trust_all, names);
    }
    to_add: list[str] = [];
    for u in us {
        if trust_all or (u.alias in names) {
            u.selected = True;
            if not (u.alias in to_add) {
                to_add.append(u.alias);
            }
        }
    }
    if len(to_add) == 0 {
        return _zero_ran(trust_all, names);
    }

    ordered: list[Untrusted] = _by_depth_desc(us);
    rc: int = 0;
    for u in ordered {
        if not u.selected {
            continue;
        }
        r: int = lifecycle_run(u.sl, root_dir, u.version, False);
        if r != 0 and rc == 0 {
            rc = r;
        }
    }

    total_scripts: int = 0;
    ran_pkgs: int = 0;
    skipped: int = 0;
    _out("\n");
    for u2 in ordered {
        if u2.selected {
            ran_pkgs = ran_pkgs + 1;
            total_scripts = total_scripts + len(u2.sl.names);
            _print_scripts(u2, "✓");
        } else {
            skipped = skipped + 1;
            _print_scripts(u2, "»");
        }
        _out("\n");
    }

    # package.json: append the new names to "trustedDependencies" (bun fills the new
    # slots from the end, so several names land in reverse order)
    pj_path: str = root_dir + "/package.json";
    m: PkgJson = pm_read_package_json(pj_path);
    if m.ok {
        arr: JVal = jv_get(m.json, "trustedDependencies");
        if not jv_is_arr(arr) {
            arr = jv_array();
            jv_set(m.json, "trustedDependencies", arr);
        }
        existing: list[str] = jv_str_list(arr);
        fresh: list[str] = [];
        for n in to_add {
            if not (n in existing) {
                fresh.append(n);
            }
        }
        k: int = len(fresh) - 1;
        while k >= 0 {
            jv_push(arr, jv_string(fresh[k]));
            k = k - 1;
        }
        text: str = pm_print_package_json(m.json, pm_guess_indent(m.text));
        mode: int = fsx_perm(pj_path);
        if mode < 0 {
            mode = 420;
        }
        if fsx_write_str(pj_path, text, mode) != 0 {
            _err("error: failed to write package.json\n");
            return 1;
        }
        # the lockfile records the same list (bun: saveToDisk after updating trusted_dependencies)
        lf.trusted = jv_str_list(jv_get(m.json, "trustedDependencies"));
        lock_path: str = root_dir + "/bun.lock";
        tmp_lock: str = lock_path + ".tmp";
        fsx_unlink(tmp_lock);
        if fsx_write_str(tmp_lock, lockfile_serialize(lf), 420) != 0
            or fsx_rename(tmp_lock, lock_path) != 0 {
            fsx_unlink(tmp_lock);
            _err("error: failed to write bun.lock\n");
            return 1;
        }
    }

    _out(
        " "
            + str(total_scripts)
            + " "
            + _plural(total_scripts, "script")
            + " ran across "
            + str(ran_pkgs)
            + " "
            + _plural(ran_pkgs, "package")
            + " "
            + pm_fmt_elapsed(uv_hrtime() - start)
            + "\n"
    );
    if skipped > 0 {
        _out(
            "\n "
                + str(skipped)
                + " "
                + _plural(skipped, "package")
                + " with blocked scripts\n"
        );
    }
    return rc;
}
