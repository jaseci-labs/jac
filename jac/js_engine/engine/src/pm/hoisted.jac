"""Hoisted-linker install from a parsed bun.lock (bun's installHoistedPackages).

The lockfile's package keys *are* the hoisted layout ("a/b" → node_modules/a/
node_modules/b), so an install from an up-to-date lockfile needs no resolver:

  1. create ./node_modules (0755, umask applies) if missing;
  2. umask(0) — bun's Bin.Linker.ensureUmask, never restored, which is why files
     extracted from here on keep `perm | 0o666` verbatim (recorded trait);
  3. per node_modules folder, in (depth, path) order: for each dependency
     (alphabetical) skip os/cpu mismatches, skip an already-correct install
     (package.json name+version match) unless the folder is new or --force,
     otherwise remove the old copy, make sure the package is in the cache and
     hard-link it in (copy on EXDEV); workspace packages become relative
     symlinks;
  4. then link that folder's bins (pm/bins.jac).
"""

import from engine.src.pm.config { PmConfig }
import from engine.src.pm.lockfile {
    Lockfile,
    LockPkg,
    LockWorkspace,
    LockDep,
    lockfile_key_segments,
    lockfile_key_to_path,
    lockfile_pkg_enabled,
    lockfile_resolve_from,
    lockfile_root
}
import from engine.src.pm.registry { pm_ensure_cached, FetchResult }
import from engine.src.pm.sources { SourceResult, pm_source_dir }
import from engine.src.pm.fsx {
    fsx_is_dir,
    fsx_is_file,
    fsx_mkdir,
    fsx_mkdir_p,
    fsx_umask_set,
    fsx_scandir,
    FsxDir,
    fsx_link,
    fsx_unlink,
    fsx_copy_file,
    fsx_perm,
    fsx_rm_rf,
    fsx_rename,
    fsx_symlink,
    fsx_realpath,
    fsx_read_bytes,
    fsx_exists,
    fsx_rmdir,
    FSX_EEXIST,
    FSX_EXDEV,
    FSX_ENOENT
}
import from engine.src.pm.bins {
    BinSpec,
    BinLinkStats,
    pm_link_bins,
    PM_NATIVE_BINLINK_PACKAGES
}
import from engine.src.pm.paths { pm_path_relative, pm_path_dirname }
import from engine.src.pm.json { JsonDoc, json_parse_bytes, jv_get_str, jv_is_missing }
import from engine.src.pm.bytes { ByteBuf, bytebuf_free }
import from engine.src.pm.platform { pm_current_os, pm_current_cpu }
import from engine.src.ffi.libuv { uv_hrtime }

obj:pub InstallSummary {
    has success: int = 0,
        skipped: int = 0,
        fail: int = 0,
        errors: list[str] = [],
        installed_keys: list[str] = [],
        bins_linked: int = 0,
        installed_dirs: dict[str, str] = {};  # packages (re)installed
}

# already correct

# key -> directory when it is not the hoisted path (isolated store)
obj TreeGroup {
    has parent_key: str = "",
        depth: int = 0,
        pkgs: list[LockPkg] = [];
}

def _tree_sort_key(depth: int, parent_key: str) -> str {
    return str(depth).zfill(6) + chr(1) + parent_key;
}

"""Group lockfile packages by the node_modules folder they land in, ordered
like bun's tree iterator (depth, then path), dependencies alphabetical."""
def _trees(lf: Lockfile) -> list[TreeGroup] {
    by_key: dict[str, TreeGroup] = {};
    sort_keys: list[str] = [];
    for p in lf.packages {
        sk: str = _tree_sort_key(p.depth, p.parent_key);
        if not (sk in by_key) {
            by_key[sk] = TreeGroup(parent_key=p.parent_key, depth=p.depth);
            sort_keys.append(sk);
        }
        by_key[sk].pkgs.append(p);
    }
    sort_keys.sort();
    out: list[TreeGroup] = [];
    for sk in sort_keys {
        g: TreeGroup = by_key[sk];
        names: list[str] = [];
        for p in g.pkgs {
            names.append(p.dep_name);
        }
        names.sort();
        ordered: list[LockPkg] = [];
        for nm in names {
            for p in g.pkgs {
                if p.dep_name == nm {
                    ordered.append(p);
                    break;
                }
            }
        }
        g.pkgs = ordered;
        out.append(g);
    }
    return out;
}

"""True when `<dest>/package.json` names this exact package version."""
def _verify_installed(dest: str, p: LockPkg) -> bool {
    b: ByteBuf = fsx_read_bytes(dest + "/package.json");
    if b.len <= 0 {
        return False;
    }
    doc: JsonDoc = json_parse_bytes(b.ptr, b.len);
    bytebuf_free(b);
    if not doc.ok {
        return False;
    }
    if jv_get_str(doc.value, "name", "") != p.name {
        return False;
    }
    if p.kind != "npm" {
        return True;
    }  # tarball / folder: the version is a path or URL
    return jv_get_str(doc.value, "version", "") == p.version;
}

"""bun's uninstallBeforeInstall: rename away, then delete."""
def _uninstall(dest: str) -> None {
    if not fsx_exists(dest) {
        return;
    }
    tmp: str = pm_path_dirname(dest) + "/.old-" + str(uv_hrtime() % 1000000007);
    if fsx_rename(dest, tmp) == 0 {
        fsx_rm_rf(tmp);
    } else {
        fsx_rm_rf(dest);
    }
}

"""Hard-link every file of `src` under `dst` (directories recreated 0755).
`skip_nm`: leave out `node_modules` folders (bun's Hardlinker skip list for
`file:` folders and the root)."""
def _link_tree(src: str, dst: str, skip_nm: bool) -> str {
    if not fsx_mkdir_p(dst, 493) {
        return "could not create " + dst;
    }
    d: FsxDir = fsx_scandir(src);
    if d.rc < 0 {
        return "could not read " + src;
    }
    i: int = 0;
    while i < len(d.names) {
        name: str = d.names[i];
        kind: int = d.kinds[i];
        i = i + 1;
        s: str = src + "/" + name;
        t: str = dst + "/" + name;
        if kind == 2 {
            if skip_nm and name == "node_modules" {
                continue;
            }
            err: str = _link_tree(s, t, skip_nm);
            if err != "" {
                return err;
            }
        } elif kind == 1 {
            rc: int = fsx_link(s, t);
            if rc == FSX_EEXIST {
                fsx_unlink(t);
                rc = fsx_link(s, t);
            }
            if rc == FSX_EXDEV {
                mode: int = fsx_perm(s);
                if mode < 0 {
                    mode = 420;
                }
                rc = fsx_copy_file(s, t, mode);
            }
            if rc < 0 {
                return "could not link " + t + " (errno " + str(-rc) + ")";
            }
        }
        # symlinks / others inside the cache are ignored, like bun's walker
    }
    return "";
}

def _workspace_of(lf: Lockfile, p: LockPkg) -> LockWorkspace {
    for ws in lf.workspaces {
        if ws.path == p.version {
            return ws;
        }
    }
    return LockWorkspace(path=p.version, name=p.name);
}

"""Symlink `dest` → the workspace directory (relative), bun's installFromLink."""
def _link_workspace(root_dir: str, ws_path: str, dest: str) -> str {
    target_abs: str = fsx_realpath(root_dir + "/" + ws_path);
    if target_abs == "" {
        return "workspace directory not found: " + ws_path;
    }
    parent: str = pm_path_dirname(dest);
    fsx_mkdir_p(parent, 493);
    rel: str = pm_path_relative(parent, target_abs);
    rc: int = fsx_symlink(rel, dest);
    if rc == FSX_EEXIST {
        fsx_rmdir(dest);
        fsx_unlink(dest);
        rc = fsx_symlink(rel, dest);
    }
    if rc < 0 {
        return "could not link workspace " + ws_path + " (errno " + str(-rc) + ")";
    }
    return "";
}

"""The platform package a native-binlink package should borrow its bins from,
or an empty LockPkg (bun: getNativeBinlinkReplacementPackageID)."""
def _native_binlink_replacement(
    lf: Lockfile, p: LockPkg, os_name: str, cpu_name: str
) -> LockPkg {
    for d in p.deps {
        if d.group == "peerDependencies" or d.group == "devDependencies" {
            continue;
        }
        r: LockPkg = lockfile_resolve_from(lf, p.key, d.name);
        if r.key == "" {
            continue;
        }
        if jv_is_missing(r.os) or jv_is_missing(r.cpu) {
            continue;
        }
        if lockfile_pkg_enabled(r, os_name, cpu_name) {
            return r;
        }
    }
    return LockPkg(key="");
}

"""Shared with the isolated linker (pm/isolated.jac)."""
def:pub pm_link_tree(src: str, dst: str) -> str {
    return _link_tree(src, dst, False);
}

def:pub pm_link_tree_ex(src: str, dst: str, skip_node_modules: bool) -> str {
    return _link_tree(src, dst, skip_node_modules);
}
def:pub pm_workspace_of(lf: Lockfile, p: LockPkg) -> LockWorkspace {
    return _workspace_of(lf, p);
}
def:pub pm_native_binlink_replacement(
    lf: Lockfile, p: LockPkg, os_name: str, cpu_name: str
) -> LockPkg {
    return _native_binlink_replacement(lf, p, os_name, cpu_name);
}

"""Public view of the native-binlink rule for the lifecycle step: the platform
package a root-level `esbuild`-like package borrows its bins from (its install
scripts are skipped then), or an empty LockPkg."""
def:pub pm_native_binlink_target(
    lf: Lockfile, p: LockPkg, os_name: str, cpu_name: str
) -> LockPkg {
    if p.depth != 0 or not (p.name in PM_NATIVE_BINLINK_PACKAGES) {
        return LockPkg(key="");
    }
    return _native_binlink_replacement(lf, p, os_name, cpu_name);
}

"""bun's PackageInstaller counts a package once however many paths it is installed
under (its successfully_installed bitset is per package): "8 packages installed"
for 10 folders when two are duplicates."""
def _count_success(summary: InstallSummary, p: LockPkg, seen: dict[str, bool]) {
    pid: str = p.resolution + "\n" + p.url;
    if not (pid in seen) {
        seen[pid] = True;
        summary.success = summary.success + 1;
    }
    summary.installed_keys.append(p.key);
}

"""Install everything in `lf` under `root_dir/node_modules`."""
def:pub pm_hoisted_install(
    cfg: PmConfig, lf: Lockfile, root_dir: str, summary: InstallSummary
) -> None {
    os_name: str = cfg.target_os;
    if os_name == "" {
        os_name = pm_current_os();
    }
    cpu_name: str = cfg.target_cpu;
    if cpu_name == "" {
        cpu_name = pm_current_cpu();
    }

    nm_root: str = root_dir + "/node_modules";
    new_nm: bool = False;
    if not fsx_is_dir(nm_root) {
        rc: int = fsx_mkdir(nm_root, 493);
        if rc < 0 and rc != FSX_EEXIST {
            summary.errors.append(
                "could not create the \"node_modules\" directory (errno "
                    + str(-rc)
                    + ")"
            );
            summary.fail = summary.fail + 1;
            return;
        }
        new_nm = True;
    }
    fsx_umask_set(0);
    skip_verify: bool = new_nm or cfg.force;
    skip_delete: bool = new_nm and not cfg.force;

    seen_pkgs: dict[str, bool] = {};  # bun's successfully_installed bitset: one count per distinct package
    disabled: dict[str, bool] = {};
    for p in lf.packages {
        if not lockfile_pkg_enabled(p, os_name, cpu_name) {
            disabled[p.key] = True;
        }
    }

    for tree in _trees(lf) {
        # a folder under a disabled package does not exist
        if tree.parent_key != "" {
            segs: list[str] = lockfile_key_segments(tree.parent_key);
            anc_disabled: bool = False;
            j: int = 1;
            while j <= len(segs) {
                if ("/".join(segs[0:j])) in disabled {
                    anc_disabled = True;
                    break;
                }
                j = j + 1;
            }
            if anc_disabled {
                continue;
            }
        }
        tree_nm: str = nm_root;
        if tree.parent_key != "" {
            tree_nm = root_dir
                + "/"
                + lockfile_key_to_path(tree.parent_key)
                + "/node_modules";
        }

        bin_specs: list[BinSpec] = [];
        bin_pkgs: list[LockPkg] = [];
        for p in tree.pkgs {
            if p.key in disabled {
                continue;
            }
            dest: str = tree_nm + "/" + p.dep_name;
            ok: bool = False;
            if p.kind == "workspace" {
                if not skip_delete {
                    _uninstall(dest);
                }
                err: str = _link_workspace(root_dir, p.version, dest);
                if err != "" {
                    summary.fail = summary.fail + 1;
                    summary.errors.append(err);
                    continue;
                }
                _count_success(summary, p, seen_pkgs);
                ws: LockWorkspace = _workspace_of(lf, p);
                if ws.bin_dir != "" or not jv_is_missing(ws.bin) {
                    bin_specs.append(
                        BinSpec(
                            alias=p.dep_name,
                            package_dir=root_dir + "/" + ws.path,
                            bin=ws.bin,
                            bin_dir=ws.bin_dir
                        )
                    );
                    bin_pkgs.append(p);
                }
                continue;
            }
            if p.kind != "npm"
                and p.kind != "tarball"
                and p.kind != "folder"
                and p.kind != "github"
                and p.kind != "git" {
                summary.fail = summary.fail + 1;
                summary.errors.append(
                    "unsupported resolution for "
                        + p.key
                        + ": "
                        + p.resolution
                        + " (not implemented yet)"
                );
                continue;
            }
            if not skip_verify and _verify_installed(dest, p) {
                summary.skipped = summary.skipped + 1;
                ok = True;
            } else {
                if not skip_delete {
                    _uninstall(dest);
                }
                src: SourceResult = pm_source_dir(cfg, root_dir, p);
                if not src.ok {
                    summary.fail = summary.fail + 1;
                    summary.errors.append(src.error);
                    continue;
                }
                err2: str = _link_tree(src.dir, dest, src.skip_node_modules);
                if err2 != "" {
                    summary.fail = summary.fail + 1;
                    summary.errors.append(err2);
                    continue;
                }
                _count_success(summary, p, seen_pkgs);
                ok = True;
            }
            if ok and (p.bin_dir != "" or not jv_is_missing(p.bin)) {
                bin_specs.append(
                    BinSpec(
                        alias=p.dep_name, package_dir=dest, bin=p.bin, bin_dir=p.bin_dir
                    )
                );
                bin_pkgs.append(p);
            }
        }

        # bins of this folder, alphabetical by alias, first claim wins
        seen: dict[str, bool] = {};
        stats: BinLinkStats = BinLinkStats();
        i: int = 0;
        while i < len(bin_specs) {
            spec: BinSpec = bin_specs[i];
            p: LockPkg = bin_pkgs[i];
            i = i + 1;
            if tree.depth == 0 and (p.name in PM_NATIVE_BINLINK_PACKAGES) {
                repl: LockPkg = _native_binlink_replacement(lf, p, os_name, cpu_name);
                if repl.key != "" {
                    alt: BinSpec = BinSpec(
                        alias=spec.alias,
                        package_dir=root_dir + "/" + lockfile_key_to_path(repl.key),
                        bin=spec.bin,
                        bin_dir=spec.bin_dir
                    );
                    missing: bool = pm_link_bins(tree_nm, alt, seen, stats);
                    if not missing {
                        continue;
                    }
                    # bun retries with the package itself (the seen-set makes this a no-op)
                }
            }
            pm_link_bins(tree_nm, spec, seen, stats);
        }
        summary.bins_linked = summary.bins_linked + stats.linked;
        for e in stats.errors {
            summary.errors.append(e);
        }
    }
}
