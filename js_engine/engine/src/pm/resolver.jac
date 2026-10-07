"""Dependency resolution: package.json (+ workspaces, + an existing bun.lock)
→ package graph → hoisted layout → Lockfile model.

Mirrors bun's install flow for the parts that decide the result:
  - the root's dependencies are ordered like bun (workspaces, dev, optional,
    prod, peer; then name) and resolved breadth-first in that order;
  - an npm dependency first reuses an already-known package of that name that
    satisfies its range (bun's getPackageID), otherwise the manifest picks the
    version (manifest_find_best) and a new package is appended;
  - dist-tags resolve through the manifest and reuse only an identical version;
  - optional peers are left unresolved (the hoister adopts a same-name entry);
  - packages of an existing lockfile are seeded first so their versions win;
  - unreachable packages are dropped, then the hoister lays everything out and
    the lockfile is written from the tree placements.
"""

import from engine.src.pm.config { PmConfig, PM_DEFAULT_REGISTRY }
import from engine.src.pm.json {
    JVal,
    jv_get,
    jv_get_str,
    jv_is_obj,
    jv_is_str,
    jv_str,
    jv_get_bool,
    jv_has,
    jv_str_list,
    jv_is_missing
}
import from engine.src.pm.sources {
    SourcePkg,
    pm_source_package,
    pm_folder_value,
    pm_tarball_value,
    pm_github_package,
    pm_git_package,
    pm_after_last_dash
}
import from engine.src.pm.lifecycle { lifecycle_install_script_count }
import from engine.src.pm.semver {
    SemVer,
    semver_parse_exact,
    semver_satisfies,
    semver_group_is_any,
    semver_order,
    semver_format
}
import from engine.src.pm.depspec {
    DepSpec,
    depspec_parse,
    SPEC_NPM,
    SPEC_DIST_TAG,
    SPEC_WORKSPACE,
    SPEC_FOLDER,
    SPEC_TARBALL,
    SPEC_SYMLINK,
    SPEC_GITHUB,
    SPEC_GIT,
    BEH_PROD,
    BEH_DEV,
    BEH_OPTIONAL,
    BEH_PEER,
    BEH_WORKSPACE,
    BEH_BUNDLED,
    behavior_is_optional_peer,
    behavior_is_workspace,
    behavior_group,
    behavior_for_group,
    behavior_is_bundled,
    behavior_is_peer,
    behavior_is_optional
}
import from engine.src.pm.graph {
    Graph,
    RPkg,
    RDep,
    graph_new,
    graph_add,
    graph_sort_deps,
    graph_find_satisfying,
    graph_find_exact,
    graph_find_workspace,
    graph_reachable
}
import from engine.src.pm.hoist {
    HoistOptions,
    HoistResult,
    HTree,
    hoist_build,
    hoist_tree_path,
    hoist_dep
}
import from engine.src.pm.manifest {
    Manifest,
    MVersion,
    MDep,
    manifest_fetch,
    manifest_find_best,
    manifest_find_dist_tag,
    manifest_find_exact
}
import from engine.src.pm.lockfile {
    Lockfile,
    LockPkg,
    LockWorkspace,
    LockDep,
    lockfile_resolve_from,
    LOCK_GROUPS
}
import from engine.src.pm.project { PkgJson, pm_read_package_json, pm_workspace_dirs }
import from engine.src.pm.platform { pm_current_os, pm_current_cpu }

obj:pub ResolveResult {
    has ok: bool = False,
        error: str = "",
        pkg_graph: Graph = Graph(),
        lockfile: Lockfile = Lockfile(),
        new_pkgs: list[int] = [],
        manifests_fetched: int = 0,
        latest: dict[str, str] = {};
}

# package ids resolved from the registry this run

# name -> `latest` dist-tag (for "(vX available)")
obj _Ctx {
    has cfg: PmConfig,
        g: Graph,
        res: ResolveResult,
        root_dir: str = "",
        resolved_specs: dict[str, int] = {},
        manifests: dict[str, Manifest] = {},
        q_pkg: list[int] = [],
        q_idx: list[int] = [];
}

# `file:` folders and local tarballs resolve against it
# git/github literal -> package (one fetch per spelling)
# ── package.json → dependencies ───────────────────────────────────────────────

"""Dependencies of a package.json as RDeps (root / workspace semantics: all
four groups, peerDependenciesMeta flags optional peers), sorted like bun."""
def:pub pm_manifest_deps(pj: JVal, include_dev: bool) -> list[RDep] {
    deps: list[RDep] = [];
    meta: JVal = jv_get(pj, "peerDependenciesMeta");
    for group in LOCK_GROUPS {
        if group == "devDependencies" and not include_dev {
            continue;
        }
        gobj: JVal = jv_get(pj, group);
        if not jv_is_obj(gobj) {
            continue;
        }
        beh: int = behavior_for_group(group);
        for name in gobj.keys {
            spec_s: str = jv_str(gobj.vals[name]);
            b: int = beh;
            if group == "peerDependencies"
                and jv_get_bool(jv_get(meta, name), "optional", False) {
                b = b | BEH_OPTIONAL;
            }
            deps.append(RDep(name=name, spec=depspec_parse(name, spec_s), behavior=b));
        }
    }
    graph_sort_deps(deps);
    return deps;
}

def _lockdeps_to_rdeps(ldeps: list[LockDep]) -> list[RDep] {
    out: list[RDep] = [];
    for d in ldeps {
        b: int = behavior_for_group(d.group);
        if d.optional_peer {
            b = b | BEH_OPTIONAL;
        }
        out.append(RDep(name=d.name, spec=depspec_parse(d.name, d.spec), behavior=b));
    }
    graph_sort_deps(out);
    return out;
}

def _root_and_workspaces(ctx: _Ctx, root_dir: str, pj: JVal) -> str {
    rootp: RPkg = RPkg(kind="root", name=jv_get_str(pj, "name", ""));
    graph_add(ctx.g, rootp);
    ws_dirs: list[str] = pm_workspace_dirs(root_dir, pj);
    ws_deps: list[RDep] = [];
    for d in ws_dirs {
        m: PkgJson = pm_read_package_json(root_dir + "/" + d + "/package.json");
        if not m.ok {
            return "failed to parse '" + d + "/package.json': " + m.error;
        }
        wp: RPkg = RPkg(
            kind="workspace", name=jv_get_str(m.json, "name", ""), version=d
        );
        if wp.name == "" {
            return "workspace '" + d + "' has no \"name\" in its package.json";
        }
        if jv_has(m.json, "version") {
            wp.ws_version = jv_get_str(m.json, "version", "");
            wp.has_ws_version = True;
        }
        wp.deps = pm_manifest_deps(m.json, True);
        wp.bin = jv_get(m.json, "bin");
        dirs: JVal = jv_get(m.json, "directories");
        if jv_is_missing(wp.bin) and jv_is_obj(dirs) {
            wp.bin_dir = jv_get_str(dirs, "bin", "");
        }
        id: int = graph_add(ctx.g, wp);
        wd: RDep = RDep(
            name=wp.name,
            spec=depspec_parse(wp.name, "workspace:" + d),
            behavior=BEH_WORKSPACE
        );
        wd.resolution = id;
        ws_deps.append(wd);
    }
    # bun parses the root with Features.main: devDependencies are always resolved
    # and recorded in the lockfile; --production / --omit only filter the install
    # tree (pm_install_lockfile).
    rootp.deps = pm_manifest_deps(pj, True);
    for wd2 in ws_deps {
        rootp.deps.append(wd2);
    }
    graph_sort_deps(rootp.deps);
    return "";
}

"""Seed the graph with the packages of an existing lockfile (their versions
are preferred, exactly like bun keeps what the lockfile already resolved)."""
def _seed_from_lockfile(ctx: _Ctx, lf: Lockfile) {
    ids_by_key: dict[str, int] = {};
    for p in lf.packages {
        if p.kind == "workspace" or p.kind == "root" {
            continue;
        }
        id: int = graph_find_exact(ctx.g, p.name, p.kind, p.version);
        if id < 0 {
            rp: RPkg = RPkg(
                kind=p.kind,
                name=p.name,
                version=p.version,
                url=p.url,
                integrity=p.integrity,
                bin=p.bin,
                bin_dir=p.bin_dir,
                os=p.os,
                cpu=p.cpu,
                from_lockfile=True
            );
            if p.kind == "npm" {
                pe: tuple[bool, SemVer] = semver_parse_exact(p.version);
                rp.semver = pe[1];
            }
            rp.deps = _lockdeps_to_rdeps(p.deps);
            id = graph_add(ctx.g, rp);
        }
        ids_by_key[p.key] = id;
    }
    # resolve their dependencies through the lockfile's own layout
    for p in lf.packages {
        if not (p.key in ids_by_key) {
            continue;
        }
        rp: RPkg = ctx.g.pkgs[ids_by_key[p.key]];
        for d in rp.deps {
            if d.resolution >= 0 {
                continue;
            }
            target: LockPkg = lockfile_resolve_from(lf, p.key, d.name);
            if target.key == "" {
                continue;
            }
            if target.kind == "workspace" {
                d.resolution = graph_find_workspace(ctx.g, target.name);
            } elif target.key in ids_by_key {
                d.resolution = ids_by_key[target.key];
            } else {
                d.resolution = graph_find_exact(
                    ctx.g, target.name, target.kind, target.version
                );
            }
        }
    }
}

# ── resolution ────────────────────────────────────────────────────────────────

def _enqueue_deps(ctx: _Ctx, pkg_id: int) {
    p: RPkg = ctx.g.pkgs[pkg_id];
    i: int = 0;
    while i < len(p.deps) {
        if p.deps[i].resolution < 0 {
            ctx.q_pkg.append(pkg_id);
            ctx.q_idx.append(i);
        }
        i = i + 1;
    }
}

def _get_manifest(ctx: _Ctx, name: str) -> Manifest {
    if name in ctx.manifests {
        return ctx.manifests[name];
    }
    m: Manifest = manifest_fetch(ctx.cfg, name, False);
    ctx.res.manifests_fetched = ctx.res.manifests_fetched + 1;
    ctx.manifests[name] = m;
    if m.ok and ("latest" in m.dist_tags) {
        ctx.res.latest[name] = m.dist_tags["latest"];
    }
    return m;
}

def _mdeps_to_rdeps(mdeps: list[MDep]) -> list[RDep] {
    out: list[RDep] = [];
    for d in mdeps {
        out.append(
            RDep(name=d.name, spec=depspec_parse(d.name, d.spec), behavior=d.behavior)
        );
    }
    return out;  # already in bun's order
}

def _add_from_manifest(ctx: _Ctx, name: str, mv: MVersion) -> int {
    rp: RPkg = RPkg(
        kind="npm",
        name=name,
        version=mv.version_str,
        semver=mv.ver,
        url=mv.tarball,
        integrity=mv.integrity,
        bin=mv.bin,
        bin_dir=mv.bin_dir,
        os=mv.os,
        cpu=mv.cpu,
        has_install_script=mv.has_install_script
    );
    rp.deps = _mdeps_to_rdeps(mv.deps);
    id: int = graph_add(ctx.g, rp);
    ctx.res.new_pkgs.append(id);
    _enqueue_deps(ctx, id);
    return id;
}

"""A package known only by its package.json (a `file:` folder or a tarball):
bun parses folders with Features.folder (devDependencies included) and tarballs
like registry packages (dev excluded)."""
def _add_from_package_json(
    ctx: _Ctx, kind: str, version: str, pj: JVal, integrity: str, include_dev: bool
) -> int {
    rp: RPkg = RPkg(
        kind=kind, name=jv_get_str(pj, "name", ""), version=version, integrity=integrity
    );
    rp.deps = pm_manifest_deps(pj, include_dev);
    bin: JVal = jv_get(pj, "bin");
    if jv_is_str(bin) or jv_is_obj(bin) {
        rp.bin = bin;
    } else {
        dirs: JVal = jv_get(pj, "directories");
        if jv_is_obj(dirs) {
            rp.bin_dir = jv_get_str(dirs, "bin", "");
        }
    }
    rp.os = jv_get(pj, "os");
    rp.cpu = jv_get(pj, "cpu");
    rp.has_install_script = lifecycle_install_script_count(pj) > 0;
    id: int = graph_add(ctx.g, rp);
    _enqueue_deps(ctx, id);
    return id;
}

"""Resolve one dependency; returns "" or an error message."""
def _resolve_dep(ctx: _Ctx, pkg_id: int, idx: int) -> str {
    dep: RDep = ctx.g.pkgs[pkg_id].deps[idx];
    if dep.resolution >= 0 {
        return "";
    }
    if behavior_is_optional_peer(dep.behavior) {
        return "";
    }
    spec: DepSpec = dep.spec;
    if spec.tag == SPEC_WORKSPACE {
        id: int = graph_find_workspace(ctx.g, dep.name);
        if id < 0 {
            # workspace:<path>
            for p in ctx.g.pkgs {
                if p.kind == "workspace" and p.version == spec.path {
                    id = p.id;
                    break;
                }
            }
        }
        if id < 0 {
            return "Workspace dependency \"" + dep.name + "\" not found";
        }
        dep.resolution = id;
        return "";
    }
    if spec.tag == SPEC_NPM {
        # a workspace package of that name satisfies the range → link it
        ws: int = graph_find_workspace(ctx.g, spec.name);
        if ws >= 0 {
            wp: RPkg = ctx.g.pkgs[ws];
            if semver_group_is_any(spec.range) {
                dep.resolution = ws;
                return "";
            }
            if wp.has_ws_version {
                pe: tuple[bool, SemVer] = semver_parse_exact(wp.ws_version);
                if pe[0] and semver_satisfies(spec.range, pe[1]) {
                    dep.resolution = ws;
                    return "";
                }
            }
        }
        existing: int = graph_find_satisfying(ctx.g, spec.name, spec.range);
        if existing >= 0 {
            dep.resolution = existing;
            return "";
        }
        m: Manifest = _get_manifest(ctx, spec.name);
        if not m.ok {
            return m.error;
        }
        mv: MVersion = manifest_find_best(m, spec.range);
        if mv.version_str == "" {
            return "No version matching \""
                + spec.literal
                + "\" found for specifier \""
                + spec.name
                + "\" (but package exists)";
        }
        same: int = graph_find_exact(ctx.g, spec.name, "npm", mv.version_str);
        if same >= 0 {
            dep.resolution = same;
            return "";
        }
        dep.resolution = _add_from_manifest(ctx, spec.name, mv);
        return "";
    }
    if spec.tag == SPEC_DIST_TAG {
        m2: Manifest = _get_manifest(ctx, spec.name);
        if not m2.ok {
            return m2.error;
        }
        mv2: MVersion = manifest_find_dist_tag(m2, spec.dist_tag);
        if mv2.version_str == "" {
            ws2: int = graph_find_workspace(ctx.g, spec.name);
            if ws2 >= 0 {
                dep.resolution = ws2;
                return "";
            }
            return "package \""
                + spec.name
                + "\" with tag \""
                + spec.dist_tag
                + "\" not found";
        }
        same2: int = graph_find_exact(ctx.g, spec.name, "npm", mv2.version_str);
        if same2 >= 0 {
            dep.resolution = same2;
            return "";
        }
        dep.resolution = _add_from_manifest(ctx, spec.name, mv2);
        return "";
    }
    if spec.tag == SPEC_FOLDER {
        fv: str = pm_folder_value(spec.literal);
        for fp in ctx.g.pkgs {
            if fp.kind == "folder" and fp.version == fv {
                dep.resolution = fp.id;
                return "";
            }
        }
        sp: SourcePkg = pm_source_package(ctx.cfg, ctx.root_dir, "folder", fv, "");
        if not sp.ok {
            return sp.error;
        }
        dep.resolution = _add_from_package_json(ctx, "folder", fv, sp.pj, "", True);
        return "";
    }
    if spec.tag == SPEC_TARBALL {
        tv: str = pm_tarball_value(spec.literal);
        for tp in ctx.g.pkgs {
            if tp.kind == "tarball" and tp.version == tv {
                dep.resolution = tp.id;
                return "";
            }
        }
        sp2: SourcePkg = pm_source_package(ctx.cfg, ctx.root_dir, "tarball", tv, "");
        if not sp2.ok {
            return sp2.error;
        }
        dep.resolution = _add_from_package_json(
            ctx, "tarball", tv, sp2.pj, sp2.integrity, False
        );
        return "";
    }
    if spec.tag == SPEC_GITHUB or spec.tag == SPEC_GIT {
        key: str = spec.literal;
        if key in ctx.resolved_specs {
            dep.resolution = ctx.resolved_specs[key];
            return "";
        }
        kind: str = "github";
        ver: str = "";
        sp3: SourcePkg = SourcePkg();
        if spec.tag == SPEC_GITHUB {
            sp3 = pm_github_package(ctx.cfg, spec.owner, spec.repo, spec.committish);
            if not sp3.ok {
                return sp3.error;
            }
            # bun prints the tarball folder's last '-' part (the short commit) after '#'
            ver = "github:"
                + spec.owner
                + "/"
                + spec.repo
                + "#"
                + pm_after_last_dash(sp3.resolved);
        } else {
            kind = "git";
            sp3 = pm_git_package(ctx.cfg, spec.repo, spec.committish);
            if not sp3.ok {
                return sp3.error;
            }
            ver = "git+" + spec.repo + "#" + sp3.resolved;
        }
        for gp in ctx.g.pkgs {
            if gp.kind == kind and gp.version == ver {
                dep.resolution = gp.id;
                ctx.resolved_specs[key] = gp.id;
                return "";
            }
        }
        gid: int = _add_from_package_json(ctx, kind, ver, sp3.pj, sp3.integrity, False);
        ctx.g.pkgs[gid].url = sp3.resolved;  # the lockfile's third element
        ctx.resolved_specs[key] = gid;
        dep.resolution = gid;
        return "";
    }
    if spec.tag == SPEC_SYMLINK {
        # bun: `link:` names a package registered with `bun link`, not a path
        return "Package \""
            + dep.name
            + "\" is not linked\n\nTo install a linked package:\n   js_engine link my-pkg-name-from-package-json\n\nTip: the package name is from package.json, which can differ from the folder name.\n\nerror: "
            + dep.name
            + "@"
            + spec.literal
            + " failed to resolve";
    }
    return "unsupported dependency specifier \""
        + spec.literal
        + "\" for \""
        + dep.name
        + "\" (not implemented yet)";
}

# ── lockfile model ────────────────────────────────────────────────────────────

def _rdeps_to_lockdeps(deps: list[RDep]) -> list[LockDep] {
    out: list[LockDep] = [];
    for d in deps {
        if behavior_is_workspace(d.behavior) {
            continue;
        }
        group: str = behavior_group(d.behavior);
        if group == "" {
            continue;
        }
        ld: LockDep = LockDep(name=d.name, spec=d.spec.literal, group=group);
        if behavior_is_optional_peer(d.behavior) {
            ld.optional_peer = True;
        }
        out.append(ld);
    }
    # the lockfile writer expects each group in name order
    i: int = 1;
    while i < len(out) {
        j: int = i;
        while j > 0
            and out[j].name < out[j - 1].name
            and out[j].group == out[j - 1].group {
            tmp: LockDep = out[j - 1];
            out[j - 1] = out[j];
            out[j] = tmp;
            j = j - 1;
        }
        i = i + 1;
    }
    return out;
}

def _lock_url(url: str) -> str {
    d: str = PM_DEFAULT_REGISTRY;
    if d.endswith("/") {
        d = d[0:len(d) - 1];
    }
    if url.startswith(d) {
        return "";
    }
    return url;
}

def _build_lockfile(ctx: _Ctx, pj: JVal, hr: HoistResult) -> Lockfile {
    lf: Lockfile = Lockfile();
    lf.ok = True;
    lf.lockfile_version = 1;
    lf.config_version = 1;
    rootp: RPkg = ctx.g.pkgs[0];
    rws: LockWorkspace = LockWorkspace(path="", name=rootp.name);
    rws.deps = _rdeps_to_lockdeps(rootp.deps);
    lf.workspaces.append(rws);
    for p in ctx.g.pkgs {
        if p.kind != "workspace" {
            continue;
        }
        ws: LockWorkspace = LockWorkspace(path=p.version, name=p.name);
        ws.has_version = p.has_ws_version;
        ws.version = p.ws_version;
        ws.bin = p.bin;
        ws.bin_dir = p.bin_dir;
        ws.deps = _rdeps_to_lockdeps(p.deps);
        lf.workspaces.append(ws);
    }
    t: int = 0;
    while t < len(hr.trees) {
        tree: HTree = hr.trees[t];
        pd: tuple[str, int] = hoist_tree_path(hr, ctx.g, t);
        path: str = pd[0];
        depth: int = pd[1];
        for d in tree.deps {
            dep: RDep = hoist_dep(hr, ctx.g, d);
            if dep.resolution < 0 {
                continue;
            }
            p: RPkg = ctx.g.pkgs[dep.resolution];
            key: str = dep.name;
            if depth > 0 {
                key = path + "/" + dep.name;
            }
            lp: LockPkg = LockPkg(
                key=key,
                dep_name=dep.name,
                parent_key=path,
                depth=depth,
                name=p.name,
                kind=p.kind
            );
            if p.kind == "workspace" {
                lp.version = p.version;
                lp.resolution = p.name + "@workspace:" + p.version;
            } else {
                lp.version = p.version;
                lp.resolution = p.name + "@" + p.version;
                if p.kind == "folder" {
                    lp.resolution = p.name + "@file:" + p.version;
                }
                lp.url = _lock_url(p.url);
                lp.integrity = p.integrity;
                lp.has_integrity = p.integrity != "";
                lp.deps = _rdeps_to_lockdeps(p.deps);
                lp.bin = p.bin;
                lp.bin_dir = p.bin_dir;
                lp.os = p.os;
                lp.cpu = p.cpu;
                lp.bundled = behavior_is_bundled(dep.behavior);
            }
            lf.by_key[key] = len(lf.packages);
            lf.packages.append(lp);
        }
        t = t + 1;
    }
    lf.trusted = jv_str_list(jv_get(pj, "trustedDependencies"));
    return lf;
}

"""Resolve the project at `root_dir`. `old` is the existing lockfile (ok false
when there is none)."""
def:pub pm_resolve(
    cfg: PmConfig, root_dir: str, pj: JVal, old: Lockfile
) -> ResolveResult {
    res: ResolveResult = ResolveResult();
    ctx: _Ctx = _Ctx(cfg=cfg, g=graph_new(), res=res);
    ctx.root_dir = root_dir;
    err: str = _root_and_workspaces(ctx, root_dir, pj);
    if err != "" {
        res.error = err;
        return res;
    }
    if old.ok {
        _seed_from_lockfile(ctx, old);
    }
    # workspaces' own dependencies and the root's
    _enqueue_deps(ctx, 0);
    for p in ctx.g.pkgs {
        if p.kind == "workspace" {
            _enqueue_deps(ctx, p.id);
        }
    }
    for p in ctx.g.pkgs {
        if p.from_lockfile {
            _enqueue_deps(ctx, p.id);
        }
    }
    qi: int = 0;
    while qi < len(ctx.q_pkg) {
        e: str = _resolve_dep(ctx, ctx.q_pkg[qi], ctx.q_idx[qi]);
        if e != "" {
            res.error = e;
            return res;
        }
        qi = qi + 1;
    }
    res.pkg_graph = ctx.g;
    opts: HoistOptions = HoistOptions(filter=False);
    hr: HoistResult = hoist_build(ctx.g, opts);
    if not hr.ok {
        res.error = hr.error;
        return res;
    }
    res.lockfile = _build_lockfile(ctx, pj, hr);
    res.ok = True;
    return res;
}

"""The lockfile to *install* from. bun builds the install tree with its `.filter`
Tree.Builder — os/cpu-disabled packages, bundled dependencies and the groups
omitted by --production / --omit are dropped and the remaining packages are
hoisted again — while the saved lockfile keeps the unfiltered layout (Features.main).
The dependency graph is the resolution's when one just happened (`have_graph`),
otherwise it is rebuilt from the lockfile itself (no network). Falls back to `lf`
when the lockfile cannot be mapped onto a graph."""
def:pub pm_install_lockfile(
    cfg: PmConfig,
    root_dir: str,
    pj: JVal,
    lf: Lockfile,
    g: Graph,
    have_graph: bool,
    os_name: str,
    cpu_name: str
) -> Lockfile {
    ctx: _Ctx = _Ctx(cfg=cfg, g=g, res=ResolveResult());
    ctx.root_dir = root_dir;
    if not have_graph {
        ctx.g = graph_new();
        err: str = _root_and_workspaces(ctx, root_dir, pj);
        if err != "" {
            return lf;
        }
        _seed_from_lockfile(ctx, lf);
        # the root's and the workspaces' dependencies resolve through the lockfile's layout
        for p in ctx.g.pkgs {
            if p.kind != "root" and p.kind != "workspace" {
                continue;
            }
            from_key: str = "";
            if p.kind == "workspace" {
                for lp in lf.packages {
                    if lp.kind == "workspace" and lp.name == p.name {
                        from_key = lp.key;
                        break;
                    }
                }
            }
            for d in p.deps {
                if d.resolution >= 0 {
                    continue;
                }
                target: LockPkg = lockfile_resolve_from(lf, from_key, d.name);
                if target.key == "" {
                    if behavior_is_optional_peer(d.behavior) {
                        continue;
                    }
                    return lf;  # not in the lockfile (stale): install its layout as is
                }
                if target.kind == "workspace" {
                    d.resolution = graph_find_workspace(ctx.g, target.name);
                } else {
                    d.resolution = graph_find_exact(
                        ctx.g, target.name, target.kind, target.version
                    );
                }
                if d.resolution < 0 {
                    return lf;
                }
            }
        }
    }
    opts: HoistOptions = HoistOptions(
        filter=True,
        os_name=os_name,
        cpu_name=cpu_name,
        omit_dev=not cfg.install_dev,
        omit_optional=not cfg.install_optional,
        omit_peer=not cfg.install_peer
    );
    hr: HoistResult = hoist_build(ctx.g, opts);
    if not hr.ok {
        return lf;
    }
    return _build_lockfile(ctx, pj, hr);
}

"""Installed-version summary suffix bun prints: " (vX available)" when the
manifest's latest is newer than what was resolved."""
def:pub pm_available_suffix(res: ResolveResult, name: str, version: str) -> str {
    if not (name in res.latest) {
        return "";
    }
    lv: str = res.latest[name];
    a: tuple[bool, SemVer] = semver_parse_exact(lv);
    b: tuple[bool, SemVer] = semver_parse_exact(version);
    if a[0] and b[0] and semver_order(a[1], b[1]) > 0 {
        return " (v" + lv + " available)";
    }
    return "";
}
