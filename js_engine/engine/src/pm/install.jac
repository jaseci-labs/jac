"""`js_engine install` — the bun-compatible install command.

Flow (bun's installWithManager, hoisted linker):
  1. read package.json; print the banner;
  2. load bun.lock; if it matches the project exactly, install from it;
     otherwise (no lockfile / stale) resolve (pm/resolver.jac), fetch the newly
     resolved packages into the cache *before* the install phase (so they keep
     the user's umask, as bun's do), and save bun.lock unless disabled;
  3. hoisted install (pm/hoisted.jac): node_modules, umask(0), hard links, bins;
  4. summary on stdout like bun: `+ name@version[ (vX available)]` for direct
     dependencies installed this run, then "<n> packages installed [<time>]" or
     "Checked … (no changes)"; progress lines ("Resolving dependencies",
     "Resolved, downloaded and extracted [N]", "Saved lockfile") on stderr.
"""

import from engine.src.ffi.libc { write }
import from engine.src.ffi.libuv { uv_hrtime }
import from engine.src.pm.config { PmArgs, PmConfig }
import from engine.src.pm.lockfile {
    Lockfile,
    LockWorkspace,
    LockDep,
    LockPkg,
    lockfile_load,
    lockfile_root,
    lockfile_resolve_from,
    LOCK_GROUPS,
    lockfile_serialize,
    lockfile_pkg_enabled,
    lockfile_key_to_path
}
import from engine.src.pm.hoisted {
    pm_hoisted_install,
    InstallSummary,
    pm_native_binlink_target
}
import from engine.src.pm.isolated { pm_isolated_install }
import from engine.src.pm.lifecycle {
    ScriptList,
    lifecycle_collect,
    lifecycle_run,
    lifecycle_default_trusted,
    lifecycle_is_trusted,
    lifecycle_install_script_count
}
import from engine.src.pm.fsx {
    fsx_exists,
    fsx_is_dir,
    fsx_is_file,
    fsx_write_str,
    fsx_unlink,
    fsx_rename
}
import from engine.src.pm.json {
    JVal,
    jv_get,
    jv_is_obj,
    jv_str,
    jv_get_str,
    jv_str_list,
    jv_get_bool,
    jv_has
}
import from engine.src.pm.project { PkgJson, pm_read_package_json, pm_workspace_dirs }
import from engine.src.pm.resolver {
    ResolveResult,
    pm_resolve,
    pm_available_suffix,
    pm_install_lockfile
}
import from engine.src.pm.registry { pm_ensure_cached, FetchResult }
import from engine.src.pm.graph { RPkg }
import from engine.src.pm.depspec { behavior_for_group, dep_less_than, BEH_OPTIONAL }
import from engine.src.pm.platform {
    pm_os_matches,
    pm_cpu_matches,
    pm_current_os,
    pm_current_cpu
}

def _out(s: str) {
    write(1, s, len(s));
}
def _err(s: str) {
    write(2, s, len(s));
}

"""Dependency groups of a package.json as LockDeps; peers flagged optional via
peerDependenciesMeta."""
def _manifest_deps(pj: JVal) -> list[LockDep] {
    out: list[LockDep] = [];
    meta: JVal = jv_get(pj, "peerDependenciesMeta");
    for group in LOCK_GROUPS {
        g: JVal = jv_get(pj, group);
        if not jv_is_obj(g) {
            continue;
        }
        for name in g.keys {
            d: LockDep = LockDep(name=name, spec=jv_str(g.vals[name]), group=group);
            if group == "peerDependencies"
                and jv_get_bool(jv_get(meta, name), "optional", False) {
                d.optional_peer = True;
            }
            out.append(d);
        }
    }
    return out;
}

def _deps_signature(deps: list[LockDep]) -> dict[str, str] {
    sig: dict[str, str] = {};
    for d in deps {
        v: str = d.spec;
        if d.optional_peer {
            v = v + chr(1) + "optional";
        }
        sig[d.group + chr(1) + d.name] = v;
    }
    return sig;
}

def _same_deps(a: list[LockDep], b: list[LockDep]) -> bool {
    sa: dict[str, str] = _deps_signature(a);
    sb: dict[str, str] = _deps_signature(b);
    if len(sa) != len(sb) {
        return False;
    }
    for k in sa {
        if not (k in sb) {
            return False;
        }
        if sa[k] != sb[k] {
            return False;
        }
    }
    return True;
}

"""Does `lf` describe this project exactly (bun: no lockfile changes)?"""
def:pub pm_lockfile_matches(lf: Lockfile, root_dir: str, pj: JVal) -> bool {
    rootws: LockWorkspace = lockfile_root(lf);
    if rootws.name != jv_get_str(pj, "name", "") {
        return False;
    }
    if not _same_deps(rootws.deps, _manifest_deps(pj)) {
        return False;
    }
    dirs: list[str] = pm_workspace_dirs(root_dir, pj);
    lock_dirs: list[str] = [];
    for ws in lf.workspaces {
        if ws.path != "" {
            lock_dirs.append(ws.path);
        }
    }
    lock_dirs.sort();
    if len(dirs) != len(lock_dirs) {
        return False;
    }
    i: int = 0;
    while i < len(dirs) {
        if dirs[i] != lock_dirs[i] {
            return False;
        }
        i = i + 1;
    }
    for d in dirs {
        m: PkgJson = pm_read_package_json(root_dir + "/" + d + "/package.json");
        if not m.ok {
            return False;
        }
        found: bool = False;
        for ws in lf.workspaces {
            if ws.path != d {
                continue;
            }
            found = True;
            if ws.name != jv_get_str(m.json, "name", "") {
                return False;
            }
            if ws.has_version != jv_has(m.json, "version") {
                return False;
            }
            if ws.has_version and ws.version != jv_get_str(m.json, "version", "") {
                return False;
            }
            if not _same_deps(ws.deps, _manifest_deps(m.json)) {
                return False;
            }
        }
        if not found {
            return False;
        }
    }
    trusted: list[str] = jv_str_list(jv_get(pj, "trustedDependencies"));
    if len(trusted) != len(lf.trusted) {
        return False;
    }
    for t in trusted {
        if not (t in lf.trusted) {
            return False;
        }
    }
    return True;
}

def _fmt2(x: float) -> str {
    v: int = int(x * 100.0 + 0.5);
    frac: str = str(v % 100);
    if len(frac) < 2 {
        frac = "0" + frac;
    }
    return str(v // 100) + "." + frac;
}

"""bun's printStartEnd: "[123.45ms]" up to 1500 ms, then "[1.23s]"."""
def:pub pm_fmt_elapsed(ns: int) -> str {
    ms: float = float(ns) / 1000000.0;
    if ms <= 1500.0 {
        return "[" + _fmt2(ms) + "ms]";
    }
    return "[" + _fmt2(ms / 1000.0) + "s]";
}

def _plural(n: int, word: str) -> str {
    if n == 1 {
        return word;
    }
    return word + "s";
}

"""`add --trust` bookkeeping. bun trusts the requested packages and their transitive
dependencies *as recorded in the previous lockfile* for this install's scripts
(findTrustedDependenciesFromUpdateRequests — nothing on a first install), and the
request names go into package.json "trustedDependencies" regardless; dependencies
whose scripts ran through that trust are appended afterwards (`ran_via`)."""
obj:pub TrustCtx {
    has active: bool = False,
        requested: list[str] = [],
        project_list: list[str] = [],
        has_project_list: bool = False,
        ran_via: list[str] = [];
}

# trustedDependencies before add edited package.json

# output: dependency names whose scripts ran through the request trust
"""Dependency names trusted through the requests: the matching root dependencies of
the previous lockfile and everything reachable from them."""
def _trust_via_requests(lf: Lockfile, requested: list[str]) -> list[str] {
    out: list[str] = [];
    seen: dict[str, bool] = {};
    stack: list[str] = [];
    for d in lockfile_root(lf).deps {
        if not (d.name in requested) {
            continue;
        }
        p: LockPkg = lockfile_resolve_from(lf, "", d.name);
        if p.key == "" {
            continue;
        }
        if not (d.name in out) {
            out.append(d.name);
        }
        stack.append(p.key);
    }
    while len(stack) > 0 {
        key: str = stack[len(stack) - 1];
        del stack[len(stack) - 1];
        if key in seen {
            continue;
        }
        seen[key] = True;
        if not (key in lf.by_key) {
            continue;
        }
        p2: LockPkg = lf.packages[lf.by_key[key]];
        for dd in p2.deps {
            t: LockPkg = lockfile_resolve_from(lf, key, dd.name);
            if t.key == "" {
                continue;
            }
            if not (dd.name in out) {
                out.append(dd.name);
            }
            stack.append(t.key);
        }
    }
    return out;
}

"""Run lifecycle scripts after the packages are in place (bun: dependency
scripts, then the root's), and count blocked ones. Only packages resolved this
run are known to have install scripts (the text lockfile does not record it),
which matches bun: installs from a lockfile run no dependency scripts and
report nothing blocked. Returns (blocked packages, blocked scripts, exit code)."""
def _run_lifecycle(
    cfg: PmConfig,
    root_dir: str,
    pj: JVal,
    lf: Lockfile,
    summary: InstallSummary,
    rr: ResolveResult,
    resolved: bool,
    trust: TrustCtx,
    via: list[str]
) -> tuple[int, int, int] {
    if cfg.ignore_scripts {
        return (0, 0, 0);
    }
    blocked_pkgs: int = 0;
    blocked_scripts: int = 0;
    os_name: str = cfg.target_os;
    if os_name == "" {
        os_name = pm_current_os();
    }
    cpu_name: str = cfg.target_cpu;
    if cpu_name == "" {
        cpu_name = pm_current_cpu();
    }
    if resolved {
        has_script: dict[str, bool] = {};
        for p in rr.pkg_graph.pkgs {
            if p.kind != "root" and p.kind != "workspace" and p.has_install_script {
                has_script[p.name + "@" + p.version] = True;
            }
        }
        project_trusted: list[str] = jv_str_list(jv_get(pj, "trustedDependencies"));
        has_project_list: bool = jv_has(pj, "trustedDependencies");
        if trust.active {  # add --trust: the list as it was before add edited package.json
            project_trusted = trust.project_list;
            has_project_list = trust.has_project_list;
        }
        defaults: list[str] = lifecycle_default_trusted();
        for key in summary.installed_keys {
            if not (key in lf.by_key) {
                continue;
            }
            lp: LockPkg = lf.packages[lf.by_key[key]];
            if lp.kind == "workspace" or lp.kind == "root" {
                continue;
            }
            if not ((lp.name + "@" + lp.version) in has_script) {
                continue;
            }
            if pm_native_binlink_target(lf, lp, os_name, cpu_name).key != "" {
                continue;
            }
            dest: str = root_dir + "/" + lockfile_key_to_path(key);
            if key in summary.installed_dirs {
                dest = summary.installed_dirs[key];
            }  # isolated store path
            dpj: PkgJson = pm_read_package_json(dest + "/package.json");
            if not dpj.ok {
                continue;
            }
            via_request: bool = lp.dep_name in via;
            if via_request
                or lifecycle_is_trusted(
                    lp.dep_name, lp.kind, project_trusted, has_project_list, defaults
                ) {
                sl: ScriptList = lifecycle_collect(dpj.json, dest, lp.name, lp.kind);
                if via_request
                    and len(sl.scripts) > 0
                    and not (lp.dep_name in trust.ran_via) {
                    trust.ran_via.append(lp.dep_name);
                }
                rc: int = lifecycle_run(sl, root_dir, lp.version, False);
                if rc != 0 {
                    return (blocked_pkgs, blocked_scripts, rc);
                }
            } else {
                cnt: int = lifecycle_install_script_count(dpj.json);
                if cnt > 0 {
                    blocked_pkgs = blocked_pkgs + 1;
                    blocked_scripts = blocked_scripts + cnt;
                }
            }
        }
    }
    # workspaces, then the root, in the foreground
    for ws in lf.workspaces {
        if ws.path == "" {
            continue;
        }
        wdir: str = root_dir + "/" + ws.path;
        wpj: PkgJson = pm_read_package_json(wdir + "/package.json");
        if not wpj.ok {
            continue;
        }
        wsl: ScriptList = lifecycle_collect(wpj.json, wdir, ws.name, "workspace");
        if len(wsl.scripts) > 0 {
            _err("\n");
            rc2: int = lifecycle_run(wsl, root_dir, ws.version, True);
            if rc2 != 0 {
                return (blocked_pkgs, blocked_scripts, rc2);
            }
        }
    }
    root_name: str = jv_get_str(pj, "name", "");
    rsl: ScriptList = lifecycle_collect(pj, root_dir, root_name, "root");
    if len(rsl.scripts) > 0 {
        _err("\n");
        rc3: int = lifecycle_run(rsl, root_dir, jv_get_str(pj, "version", ""), True);
        if rc3 != 0 {
            return (blocked_pkgs, blocked_scripts, rc3);
        }
    }
    return (blocked_pkgs, blocked_scripts, 0);
}

"""Whether a root dependency group is installed under the current flags
(--production / --omit=dev|optional|peer)."""
def _group_installed(cfg: PmConfig, group: str) -> bool {
    if group == "devDependencies" {
        return cfg.install_dev;
    }
    if group == "optionalDependencies" {
        return cfg.install_optional;
    }
    if group == "peerDependencies" {
        return cfg.install_peer;
    }
    return True;
}

"""The root's dependencies in the order bun prints them (its root dependency
list: Behavior.cmp — dev before prod — then name), not alphabetical."""
def _root_deps_ordered(deps: list[LockDep]) -> list[LockDep] {
    out: list[LockDep] = [];
    used: dict[int, bool] = {};
    n: int = len(deps);
    k: int = 0;
    while k < n {
        best: int = -1;
        j: int = 0;
        while j < n {
            if not (j in used) {
                bj: int = behavior_for_group(deps[j].group);
                if deps[j].optional_peer {
                    bj = bj | BEH_OPTIONAL;
                }
                if best < 0 {
                    best = j;
                } else {
                    bb: int = behavior_for_group(deps[best].group);
                    if deps[best].optional_peer {
                        bb = bb | BEH_OPTIONAL;
                    }
                    if dep_less_than(bj, deps[j].name, bb, deps[best].name) {
                        best = j;
                    }
                }
            }
            j = j + 1;
        }
        used[best] = True;
        out.append(deps[best]);
        k = k + 1;
    }
    return out;
}

"""Shared by `install`, `add` and `remove`: everything after package.json is
known. `force_resolve` makes a stale-lockfile check unnecessary (add and remove
always resolve and save the lockfile). `added` are add's names (printed as
"installed x@y"), `requests` remove's names and `removed_count` how many root
dependencies of the previous lockfile went away (bun's summary.remove)."""
def:pub pm_install_project(
    cfg: PmConfig,
    root_dir: str,
    pj: JVal,
    force_resolve: bool,
    start: int,
    added: list[str],
    requests: list[str],
    removed_count: int,
    trust: TrustCtx
) -> int {
    lock_path: str = root_dir + "/bun.lock";
    lf: Lockfile = Lockfile();
    have_lock: bool = False;
    if cfg.lockfile_load and fsx_exists(lock_path) {
        lf = lockfile_load(lock_path);
        if not lf.ok {
            _err("error: " + lf.error + "\n");
            return 1;
        }
        have_lock = True;
    }
    via: list[str] = [];  # add --trust: trusted through the requests, from the previous lockfile
    if trust.active and have_lock {
        via = _trust_via_requests(lf, trust.requested);
    }
    up_to_date: bool = have_lock
        and not force_resolve
        and pm_lockfile_matches(lf, root_dir, pj);
    rr: ResolveResult = ResolveResult();
    resolved: bool = False;
    prefetch_errors: list[str] = [];
    if not up_to_date {
        if cfg.frozen_lockfile and have_lock {
            _err("error: lockfile had changes, but lockfile is frozen\n");
            _err(
                "note: try re-running without --frozen-lockfile and commit the updated lockfile\n"
            );
            return 1;
        }
        # bun shows the progress lines only when it has network work: always on a
        # fresh install; with a lockfile only when something was fetched (add) —
        # a remove that fetches nothing prints just "Saved lockfile".
        if not have_lock {
            _err("Resolving dependencies\n");
        }
        old: Lockfile = Lockfile();
        if have_lock {
            old = lf;
        }
        rr = pm_resolve(cfg, root_dir, pj, old);
        if not rr.ok {
            _err("error: " + rr.error + "\n");
            return 1;
        }
        lf = rr.lockfile;
        resolved = True;
        # fetch what was newly resolved now, before the install phase clears the umask
        os_name: str = cfg.target_os;
        if os_name == "" {
            os_name = pm_current_os();
        }
        cpu_name: str = cfg.target_cpu;
        if cpu_name == "" {
            cpu_name = pm_current_cpu();
        }
        fetched: int = 0;
        if not cfg.dry_run {
            for id in rr.new_pkgs {
                p: RPkg = rr.pkg_graph.pkgs[id];
                if p.kind != "npm" {
                    continue;
                }
                if not pm_os_matches(p.os, os_name)
                    or not pm_cpu_matches(p.cpu, cpu_name) {
                    continue;
                }
                fr: FetchResult = pm_ensure_cached(
                    cfg, p.name, p.version, p.url, p.integrity
                );
                if not fr.ok {
                    prefetch_errors.append(fr.error);
                } else {
                    fetched = fetched + 1;
                }
            }
        }
        # `add` always re-fetches the manifests of the requested packages in bun, so it
        # always shows the progress lines even when nothing new was needed.
        tasks: int = rr.manifests_fetched + fetched;
        busy: bool = tasks > 0 or len(added) > 0;
        if have_lock and busy {
            _err("Resolving dependencies\n");
        }
        if not have_lock or busy {
            _err("Resolved, downloaded and extracted [" + str(tasks) + "]\n");
        }
        if cfg.lockfile_save and not cfg.dry_run {
            # bun writes a fresh file (0644 under umask) and renames it over the old one
            text: str = lockfile_serialize(lf);
            tmp_lock: str = lock_path + ".tmp";
            fsx_unlink(tmp_lock);
            if fsx_write_str(tmp_lock, text, 420) != 0
                or fsx_rename(tmp_lock, lock_path) != 0 {
                fsx_unlink(tmp_lock);
                _err("error: failed to write bun.lock\n");
                return 1;
            }
            _err("Saved lockfile\n");
        }
    }
    for e in prefetch_errors {
        _err("error: " + e + "\n");
    }

    linker: str = cfg.linker;
    if linker == "" or linker == "auto" {
        linker = "hoisted";
        if len(lf.workspaces) > 1 {
            linker = "isolated";
        }
    }
    if linker != "hoisted" and linker != "isolated" {
        _err(
            "error: unknown linker \""
                + linker
                + "\" (expected \"hoisted\" or \"isolated\")\n"
        );
        return 1;
    }

    rootws: LockWorkspace = lockfile_root(lf);
    if cfg.dry_run {
        for d in _root_deps_ordered(rootws.deps) {
            if not _group_installed(cfg, d.group) {
                continue;
            }
            r: LockPkg = lockfile_resolve_from(lf, "", d.name);
            if r.key != "" {
                _out("+ " + d.name + "@" + r.version + "\n");
            }
        }
        _out(
            "\n"
                + str(len(lf.packages))
                + " "
                + _plural(len(lf.packages), "package")
                + " would be installed (dry run)\n"
        );
        return 0;
    }

    summary: InstallSummary = InstallSummary();
    # bun installs from a tree built with its filter Tree.Builder (os/cpu, bundled,
    # --production / --omit) and re-hoisted; the saved lockfile keeps the full layout.
    # The isolated linker applies the same filters itself from the full lockfile.
    lf_install: Lockfile = lf;
    if linker != "isolated" {
        ins_os: str = cfg.target_os;
        if ins_os == "" {
            ins_os = pm_current_os();
        }
        ins_cpu: str = cfg.target_cpu;
        if ins_cpu == "" {
            ins_cpu = pm_current_cpu();
        }
        lf_install = pm_install_lockfile(
            cfg, root_dir, pj, lf, rr.pkg_graph, resolved, ins_os, ins_cpu
        );
    }
    if not cfg.skip_install_packages {
        if linker == "isolated" {
            pm_isolated_install(cfg, lf, root_dir, summary);
        } else {
            pm_hoisted_install(cfg, lf_install, root_dir, summary);
        }
    }
    for e in summary.errors {
        _err("error: " + e + "\n");
    }

    lc: tuple[int, int, int] = _run_lifecycle(
        cfg, root_dir, pj, lf_install, summary, rr, resolved, trust, via
    );
    script_rc: int = lc[2];
    blocked_info: str = "\n";
    if lc[0] > 0 {
        plural: str = "";
        if lc[1] > 1 {
            plural = "s";
        }
        blocked_info = "\n\nBlocked "
            + str(lc[1])
            + " postinstall"
            + plural
            + ". Run `js_engine pm untrusted` for details.\n";
    }

    if not cfg.silent and not cfg.no_summary {
        lines: list[str] = [];
        for d in _root_deps_ordered(rootws.deps) {
            nm: str = d.name;
            if nm in added {
                continue;
            }  # bun prints "installed x@y" for these instead
            if not _group_installed(cfg, d.group) {
                continue;
            }  # --production / --omit
            r: LockPkg = lockfile_resolve_from(lf_install, "", nm);
            if r.key != "" and (r.key in summary.installed_keys) {
                suffix: str = "";
                if resolved {
                    suffix = pm_available_suffix(rr, r.name, r.version);
                }
                lines.append("+ " + nm + "@" + r.version + suffix);
            }
        }
        if len(lines) > 0 {
            _out("\n".join(lines) + "\n\n");
        }
        for a in added {
            r2: LockPkg = lockfile_resolve_from(lf, "", a);
            if r2.key != "" {
                _out("installed " + a + "@" + r2.version + "\n");
            }
        }
        if len(added) > 0 {
            _out("\n");
        }
        elapsed: str = pm_fmt_elapsed(uv_hrtime() - start);
        n_requests: int = len(added) + len(requests);  # bun's update_requests
        if summary.success > 0 {
            # bun: "it's confusing when it shows 3 packages and says it installed 1"
            shown: int = summary.success;
            if n_requests > shown {
                shown = n_requests;
            }
            _out(
                str(shown)
                    + " "
                    + _plural(shown, "package")
                    + " installed "
                    + elapsed
                    + blocked_info
            );
            if removed_count > 0 {
                _out("Removed: " + str(removed_count) + "\n");
            }
        } elif removed_count > 0 {
            for rq in requests {
                _out("- " + rq + "\n");
            }
            _out(
                str(removed_count)
                    + " "
                    + _plural(removed_count, "package")
                    + " removed "
                    + elapsed
                    + blocked_info
            );
        } elif summary.skipped > 0 and summary.fail == 0 and n_requests == 0 {
            total: int = len(lf.packages) + 1;  # bun counts the root package too
            if total != summary.skipped {
                _out(
                    "Checked "
                        + str(summary.skipped)
                        + " "
                        + _plural(summary.skipped, "install")
                        + " across "
                        + str(total)
                        + " "
                        + _plural(total, "package")
                        + " (no changes) "
                        + elapsed
                        + blocked_info
                );
            } else {
                _out(
                    "Done! Checked "
                        + str(summary.skipped)
                        + " "
                        + _plural(summary.skipped, "package")
                        + " (no changes) "
                        + elapsed
                        + blocked_info
                );
            }
        } elif summary.fail == 0 {
            _out(elapsed + " done\n");
        }
        if summary.fail > 0 {
            _out(
                "Failed to install "
                    + str(summary.fail)
                    + " "
                    + _plural(summary.fail, "package")
                    + "\n"
            );
        }
    }
    if summary.fail > 0 or len(prefetch_errors) > 0 or script_rc != 0 {
        return 1;
    }
    return 0;
}

def:pub pm_cmd_install(args: PmArgs, cfg: PmConfig, banner: str) -> int {
    start: int = uv_hrtime();
    root_dir: str = cfg.cwd;
    pj_path: str = root_dir + "/package.json";
    if not fsx_is_file(pj_path) {
        _err("error: js_engine could not find a package.json file to install from\n");
        _err("note: Run \"js_engine init\" to initialize a project\n");
        return 1;
    }
    m: PkgJson = pm_read_package_json(pj_path);
    if not m.ok {
        _err("error: failed to parse '" + pj_path + "': " + m.error + "\n");
        return 1;
    }
    _out(banner + "\n");
    return pm_install_project(
        cfg, root_dir, m.json, False, start, [], [], 0, TrustCtx()
    );
}
