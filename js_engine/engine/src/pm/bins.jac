"""node_modules/.bin linking, after bun's Bin.Linker (src/install/bin.zig).

For one node_modules folder ("tree"): its dependencies that declare a `bin`
are linked in alphabetical order of their dependency name (bun's priority
queue), the first claim on a `.bin/<name>` wins (`seen`), a target that does
not exist is skipped, the link is relative (`../<pkg>/<file>`), `.bin` is
created on demand (mode 0755), an existing entry is replaced, and the target
is chmod 0777 after a successful link.

Native binlink optimisation (bun's PostinstallOptimizer): at the root tree the
bins of `esbuild` / `@anthropic-ai/claude-code` point at the platform package
among their dependencies (e.g. `@esbuild/linux-x64`) when one matches, so the
postinstall that would otherwise copy the binary never has to run.
"""

import from engine.src.pm.fsx {
    fsx_exists,
    fsx_symlink,
    fsx_mkdir_p,
    fsx_rm_rf,
    fsx_chmod,
    fsx_scandir,
    FsxDir,
    fsx_is_dir,
    FSX_ENOENT,
    FSX_EEXIST
}
import from engine.src.pm.json { JVal, jv_is_str, jv_is_obj, jv_str, jv_is_missing }
import from engine.src.pm.paths {
    pm_path_join,
    pm_path_relative,
    pm_unscoped_name,
    pm_normalized_bin_name
}

glob:pub PM_NATIVE_BINLINK_PACKAGES: list[str] = [
         "esbuild",
         "@anthropic-ai/claude-code"
     ];

"""What one package contributes: the alias it is installed under, the directory
holding its files (usually <node_modules>/<alias>) and its bin field."""
obj:pub BinSpec {
    has alias: str = "",
        package_dir: str = "",
        bin: JVal = JVal(),
        bin_dir: str = "";
}

obj:pub BinLinkStats {
    has linked: int = 0,
        skipped_missing: int = 0,
        errors: list[str] = [];
}

"""Link the bins of `spec` into `<node_modules>/.bin`. `seen` is shared across
the whole tree. Returns True when at least one bin was skipped because its
target does not exist (bun retries the native-binlink case then)."""
def:pub pm_link_bins(
    node_modules: str, spec: BinSpec, seen: dict[str, bool], stats: BinLinkStats
) -> bool {
    missing: bool = False;
    if spec.bin_dir != "" {
        dir_abs: str = pm_path_join(spec.package_dir, spec.bin_dir);
        if not fsx_is_dir(dir_abs) {
            return False;
        }
        d: FsxDir = fsx_scandir(dir_abs);
        i: int = 0;
        while i < len(d.names) {
            if d.kinds[i] == 1 or d.kinds[i] == 3 {
                if _link_one(
                    node_modules, dir_abs + "/" + d.names[i], d.names[i], seen, stats
                ) {
                    missing = True;
                }
            }
            i = i + 1;
        }
        return missing;
    }
    if jv_is_str(spec.bin) {
        if spec.bin.s == "" {
            return False;
        }
        target: str = pm_path_join(spec.package_dir, spec.bin.s);
        if _link_one(node_modules, target, pm_unscoped_name(spec.alias), seen, stats) {
            missing = True;
        }
        return missing;
    }
    if jv_is_obj(spec.bin) {
        for k in spec.bin.keys {
            name: str = pm_normalized_bin_name(k);
            rel: str = jv_str(spec.bin.vals[k]);
            if name == "" or rel == "" {
                continue;
            }
            target: str = pm_path_join(spec.package_dir, rel);
            if _link_one(node_modules, target, name, seen, stats) {
                missing = True;
            }
        }
    }
    return missing;
}

"""Create <node_modules>/.bin/<name> → relative(target). Returns True when the
target was missing (nothing linked)."""
def _link_one(
    node_modules: str,
    abs_target: str,
    name: str,
    seen: dict[str, bool],
    stats: BinLinkStats
) -> bool {
    dest_dir: str = node_modules + "/.bin";
    dest: str = dest_dir + "/" + name;
    if dest in seen {
        return False;
    }
    seen[dest] = True;
    if not fsx_exists(abs_target) {
        stats.skipped_missing = stats.skipped_missing + 1;
        return True;
    }
    rel: str = pm_path_relative(dest_dir, abs_target);
    rc: int = fsx_symlink(rel, dest);
    if rc == FSX_ENOENT {
        fsx_mkdir_p(dest_dir, 493);
        rc = fsx_symlink(rel, dest);
    } elif rc == FSX_EEXIST {
        fsx_rm_rf(dest);
        rc = fsx_symlink(rel, dest);
    }
    if rc < 0 {
        stats.errors.append("Failed to link " + name + ": errno " + str(-rc));
        return False;
    }
    fsx_chmod(abs_target, 511);
    stats.linked = stats.linked + 1;
    return False;
}
