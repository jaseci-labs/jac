"""`js_engine remove <pkg>…` — bun-compatible `remove`.

bun (updatePackageJSONAndInstall, subcommand .remove): every requested name is
deleted from all four dependency groups of package.json; a group that still has
entries is re-alphabetized, an emptied group is deleted and the top-level keys
are then re-sorted in bun's canonical order (name, version, author, repository,
config, main, module, dependencies, devDependencies, optionalDependencies,
peerDependencies, exports, then everything else alphabetically). package.json is
written back even when nothing matched, and the normal install follows with a
forced resolution (bun always saves the lockfile here, so it ends up 0644).
Afterwards the top-level node_modules/<name> folders of requested packages that
are no longer in the lockfile are deleted (bun's quick cleanup). The install
summary adds "Removed: N" after "N packages installed", or prints "- <name>" per
request and "N packages removed" when nothing had to be installed; N is the
number of root dependencies of the previous lockfile that are gone.
"""

import from engine.src.ffi.libc { write }
import from engine.src.ffi.libuv { uv_hrtime }
import from engine.src.pm.config { PmArgs, PmConfig }
import from engine.src.pm.json { JVal, jv_get, jv_is_obj }
import from engine.src.pm.project { PkgJson, pm_read_package_json }
import from engine.src.pm.add {
    pm_print_package_json,
    pm_guess_indent,
    pm_jv_delete,
    pm_jv_sort_keys,
    PM_DEP_GROUPS
}
import from engine.src.pm.fsx { fsx_is_file, fsx_write_str, fsx_perm, fsx_rm_rf }
import from engine.src.pm.install { pm_install_project, TrustCtx }
import from engine.src.pm.lockfile { Lockfile, lockfile_load, lockfile_root }

def _out(s: str) {
    write(1, s, len(s));
}
def _err(s: str) {
    write(2, s, len(s));
}

"""Remove `names` from every dependency group of the package.json object.
Returns how many of the names were found in at least one group."""
def:pub pm_package_json_remove(pj: JVal, names: list[str]) -> int {
    matched: int = 0;
    root_changed: bool = False;
    for name in names {
        hit: bool = False;
        for g in PM_DEP_GROUPS {
            o: JVal = jv_get(pj, g);
            if not jv_is_obj(o) {
                continue;
            }
            if pm_jv_delete(o, name) {
                hit = True;
                if len(o.keys) == 0 {
                    pm_jv_delete(pj, g);
                    root_changed = True;
                } else {
                    pm_jv_sort_keys(o, False);
                }
            }
        }
        if hit {
            matched = matched + 1;
        }
    }
    if root_changed {
        pm_jv_sort_keys(pj, True);
    }
    return matched;
}

def:pub pm_cmd_remove(args: PmArgs, cfg: PmConfig, banner: str) -> int {
    start: int = uv_hrtime();
    root_dir: str = cfg.cwd;
    pj_path: str = root_dir + "/package.json";
    if not fsx_is_file(pj_path) {
        _err("No package.json, so nothing to remove\n");
        return 1;
    }
    m: PkgJson = pm_read_package_json(pj_path);
    if not m.ok {
        _err("error: failed to parse '" + pj_path + "': " + m.error + "\n");
        return 1;
    }
    _out(banner + "\n");
    if not jv_is_obj(m.json) {
        _err(
            "error: package.json is not an Object {}, so there's nothing to remove!\n"
        );
        return 1;
    }
    if len(m.json.keys) == 0 {
        _err("error: package.json is empty {}, so there's nothing to remove!\n");
        return 1;
    }
    has_group: bool = False;
    for g in PM_DEP_GROUPS {
        if g in m.json.vals {
            has_group = True;
        }
    }
    if not has_group {
        _err("package.json doesn't have dependencies, there's nothing to remove!\n");
        return 0;
    }

    # N for the summary: root dependencies of the previous lockfile that go away
    removed_count: int = 0;
    lf_old: Lockfile = lockfile_load(root_dir + "/bun.lock");
    if lf_old.ok {
        old_root: list[str] = [];
        for d in lockfile_root(lf_old).deps {
            old_root.append(d.name);
        }
        for name in args.positionals {
            if name in old_root {
                removed_count = removed_count + 1;
            }
        }
    }

    pm_package_json_remove(m.json, args.positionals);
    text: str = pm_print_package_json(m.json, pm_guess_indent(m.text));
    mode: int = fsx_perm(pj_path);
    if mode < 0 {
        mode = 420;
    }
    if fsx_write_str(pj_path, text, mode) != 0 {
        _err("error: failed to write package.json\n");
        return 1;
    }
    rc: int = pm_install_project(
        cfg,
        root_dir,
        m.json,
        True,
        start,
        [],
        args.positionals,
        removed_count,
        TrustCtx()
    );

    # bun's quick cleanup: top-level folders of removed packages that left the lockfile
    lf_new: Lockfile = lockfile_load(root_dir + "/bun.lock");
    for name2 in args.positionals {
        still: bool = False;
        if lf_new.ok {
            for p in lf_new.packages {
                if p.name == name2 or p.dep_name == name2 {
                    still = True;
                    break;
                }
            }
        }
        if not still {
            fsx_rm_rf(root_dir + "/node_modules/" + name2);
        }
    }
    return rc;
}
