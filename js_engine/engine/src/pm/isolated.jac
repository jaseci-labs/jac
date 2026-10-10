"""Isolated linker — bun 1.3.13's src/install/isolated_install.zig and
isolated_install/{Store,Installer,Symlinker}.zig. `linker = "auto"` picks it
whenever the project has workspaces (bun 1.3).

Layout (bun's store; every path below is relative to the project root):

  node_modules/.bun/<name>@<version>[+<peer hash>]/node_modules/<name>/…
      the package's files (hard links into the cache), one "store entry" per
      package — or per (package, transitive-peer set) when peers differ
  node_modules/.bun/<store>/node_modules/<dep>   → ../../<dep store>/node_modules/<dep>
      each entry's own dependencies (a dependency with the entry's own name
      goes one level deeper: <store>/node_modules/<name>/node_modules/<dep>)
  node_modules/.bun/node_modules/<name>          → ../<store>/node_modules/<name>
      the hidden hoisted view: the first entry created per dependency name
  node_modules/<dep>                             → .bun/<store>/node_modules/<dep>
      the root's dependencies (workspaces are not linked there)
  <workspace>/node_modules/<dep>                 → ../../../node_modules/.bun/<store>/node_modules/<dep>
  <workspace>/node_modules/<other workspace>     → relative path to that workspace directory

How the store is derived from the lockfile (isolated_install.zig):

  1. Nodes: a depth-first walk from the root (bun pops a LIFO queue and
     reverses each batch, so children come out in dependency order: bun's
     DepSorter — behavior, then name). Filtered like Tree.isFilteredDependency-
     OrWorkspace: unresolved, os/cpu-disabled and bundled dependencies are
     skipped, devDependencies only for local packages (root/workspace/folder),
     optional and peer dependencies per the install flags. A package already
     among the node's ancestors under the same alias is a cycle (the ancestor
     is reused); otherwise the first node created for a package is reused for
     every later occurrence under the same alias ("early dedupe"). Peer
     dependencies resolve to the nearest ancestor providing the name, else to
     the lockfile's resolution (auto-installed), and are recorded on every
     ancestor they were looked up through.
  2. Entries: a breadth-first walk over the nodes. A node whose package
     already has an entry with the same transitive-peer set reuses it (an edge
     is added to the parent; the root's implicit workspace dependencies add no
     edge). A workspace referenced by another workspace gets its own, empty
     entry (only used for the symlink). `hoisted` marks the first entry per
     dependency name.
  3. Install: root and (first) workspace entries link their dependencies and
     bins; npm entries are hard-linked from the cache into the store unless
     the store directory already holds a package.json (force / new .bun
     reinstalls), then get their dependency symlinks, their dependencies' bins
     in <store>/node_modules/.bin, their own bins, and the hidden hoisted link.
  4. Counting follows bun's Installer.onTaskComplete: the root, workspace
     entries and already-present entries are "skipped"; an installed entry
     adds 1, plus 1 more the first time its package is installed (bun counts a
     fresh package twice, which is why "16 packages installed" for 8 packages).

Not ported yet (documented, not silently different): the peer-context hash
that keys bun's early dedupe is always 0 here, and the `+<hash>` store suffix
for entries with transitive peers uses a placeholder hash instead of bun's
Wyhash11 — projects whose workspaces pull in peer dependencies get the same
topology as bun but different suffixes. Only npm and workspace resolutions are
installed (git/github/tarball/folder are reported, like the hoisted linker).
The umask is left alone: bun's isolated installer never calls umask(0), so the
hard-linked files keep the cache's modes (0644-ish), unlike hoisted installs.
"""

import from engine.src.pm.config { PmConfig }
import from engine.src.pm.lockfile {
    Lockfile,
    LockPkg,
    LockWorkspace,
    LockDep,
    lockfile_pkg_enabled,
    lockfile_resolve_from,
    lockfile_root
}
import from engine.src.pm.hoisted {
    InstallSummary,
    pm_link_tree_ex,
    pm_workspace_of,
    pm_native_binlink_replacement
}
import from engine.src.pm.sources {
    SourceResult,
    pm_source_dir,
    pm_github_version_parts,
    pm_git_version_parts,
    pm_after_last_dash
}
import from engine.src.pm.fsx {
    fsx_exists,
    fsx_mkdir,
    fsx_mkdir_p,
    fsx_rename,
    fsx_symlink,
    fsx_readlink,
    fsx_unlink,
    fsx_rm_rf,
    FSX_EEXIST,
    FSX_ENOENT
}
import from engine.src.pm.bins {
    BinSpec,
    BinLinkStats,
    pm_link_bins,
    PM_NATIVE_BINLINK_PACKAGES
}
import from engine.src.pm.paths { pm_path_relative, pm_path_dirname, pm_path_basename }
import from engine.src.pm.json { JVal, jv_is_missing }
import from engine.src.pm.depspec {
    BEH_PROD,
    BEH_OPTIONAL,
    BEH_WORKSPACE,
    behavior_for_group,
    dep_less_than,
    behavior_is_peer,
    behavior_is_dev,
    behavior_is_optional,
    behavior_is_workspace
}
import from engine.src.pm.platform { pm_current_os, pm_current_cpu }
import from engine.src.ffi.libuv { uv_hrtime }

# ── model ─────────────────────────────────────────────────────────────────────

"""One dependency edge as seen from a node: alias, behavior bits, resolved package."""
obj:pub IsoDepRef {
    has name: str = "",
        behavior: int = 0,
        pkg: LockPkg = LockPkg();
}

"""A transitive peer recorded on a node (bun's Store.Node.TransitivePeer)."""
obj:pub IsoPeer {
    has name: str = "",
        pkg: LockPkg = LockPkg(),
        auto_installed: bool = False;
}

"""bun's Store.Node: a package in the full (non-hoisted) dependency tree."""
obj:pub IsoNode {
    has pkg: LockPkg = LockPkg(),
        dep_name: str = "",
        behavior: int = 0,
        parent: int = -1,
        children: list[int] = [],
        deps: list[IsoDepRef] = [],
        peers: list[IsoPeer] = [];  # kind "root" for the project itself
}

# alias it was reached under; "" for the root

# node ids in dependency order (may point at ancestors / shared nodes)
# non-peer dependencies + resolved peers, for lookups by name
obj IsoQueued {
    has parent: int = -1,
        dep_name: str = "",
        behavior: int = 0,
        pkg: LockPkg = LockPkg();
}

obj:pub IsoEntryDep {
    has entry_id: int = -1,
        name: str = "";
}

"""bun's Store.Entry: what actually gets a directory (or a symlink) on disk."""
obj:pub IsoEntry {
    has node_id: int = 0,
        deps: list[IsoEntryDep] = [],
        parents: list[int] = [],
        hoisted: bool = False,
        peer_hash: str = "";
}

# unordered; `iso_sorted_entry_deps` gives bun's order

# "" or "+<hex>"
obj:pub IsoStore {
    has nodes: list[IsoNode] = [],
        entries: list[IsoEntry] = [],
        error: str = "";
}

# ── small helpers ─────────────────────────────────────────────────────────────

"""Package identity (bun's PackageID): "" for the root, else resolution + URL."""
def _pid(p: LockPkg) -> str {
    if p.kind == "root" {
        return "";
    }
    return p.resolution + "\n" + p.url;
}

def _is_root(nd: IsoNode) -> bool {
    return nd.dep_name == "";
}

def _behavior_of(d: LockDep) -> int {
    b: int = behavior_for_group(d.group);
    if d.optional_peer {
        b = b | BEH_OPTIONAL;
    }
    return b;
}

"""bun's Behavior.isEnabled with the default feature sets: local packages
(root / workspace / folder) install devDependencies, remote ones do not."""
def _dep_enabled(cfg: PmConfig, b: int, local: bool) -> bool {
    if (b & BEH_PROD) != 0 {
        return True;
    }
    if behavior_is_dev(b) {
        return local and cfg.install_dev and not cfg.production;
    }
    if behavior_is_peer(b) {
        return cfg.install_peer;
    }
    if behavior_is_optional(b) {
        return cfg.install_optional;
    }
    if behavior_is_workspace(b) {
        return local;
    }
    return False;
}

def _name_less(a: str, b: str) -> bool {
    return dep_less_than(0, a, 0, b);
}

"""Selection sort by (behavior, name) — bun's DepSorter."""
def _sort_refs(items: list[IsoDepRef]) -> list[IsoDepRef] {
    out: list[IsoDepRef] = [];
    used: dict[int, bool] = {};
    k: int = 0;
    while k < len(items) {
        best: int = -1;
        j: int = 0;
        while j < len(items) {
            if not (j in used) {
                if best < 0
                    or dep_less_than(
                        items[j].behavior,
                        items[j].name,
                        items[best].behavior,
                        items[best].name
                    ) {
                    best = j;
                }
            }
            j = j + 1;
        }
        used[best] = True;
        out.append(items[best]);
        k = k + 1;
    }
    return out;
}

"""bun's Store.Entry.Dependencies order: by dependency name."""
def:pub iso_sorted_entry_deps(items: list[IsoEntryDep]) -> list[IsoEntryDep] {
    out: list[IsoEntryDep] = [];
    used: dict[int, bool] = {};
    k: int = 0;
    while k < len(items) {
        best: int = -1;
        j: int = 0;
        while j < len(items) {
            if not (j in used) {
                if best < 0 or _name_less(items[j].name, items[best].name) {
                    best = j;
                }
            }
            j = j + 1;
        }
        used[best] = True;
        out.append(items[best]);
        k = k + 1;
    }
    return out;
}

def _sort_peers(items: list[IsoPeer]) -> list[IsoPeer] {
    out: list[IsoPeer] = [];
    used: dict[int, bool] = {};
    k: int = 0;
    while k < len(items) {
        best: int = -1;
        j: int = 0;
        while j < len(items) {
            if not (j in used) {
                if best < 0 or _name_less(items[j].name, items[best].name) {
                    best = j;
                }
            }
            j = j + 1;
        }
        used[best] = True;
        out.append(items[best]);
        k = k + 1;
    }
    return out;
}

"""Ordered-set insert for entry dependencies: a second dependency with the same
name is dropped (bun's DependenciesOrderedArraySetCtx.order returns .eq)."""
def _entry_deps_insert(items: list[IsoEntryDep], d: IsoEntryDep) -> None {
    for e in items {
        if e.name == d.name {
            return;
        }
    }
    items.append(d);
}

"""Ordered-set insert for transitive peers (one resolution per peer name)."""
def _peers_insert(items: list[IsoPeer], p: IsoPeer) -> None {
    for e in items {
        if e.name == p.name {
            return;
        }
    }
    items.append(p);
}

def _peers_eq(a: list[IsoPeer], b: list[IsoPeer]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    sa: list[IsoPeer] = _sort_peers(a);
    sb: list[IsoPeer] = _sort_peers(b);
    i: int = 0;
    while i < len(sa) {
        if sa[i].name != sb[i].name {
            return False;
        }
        if _pid(sa[i].pkg) != _pid(sb[i].pkg) {
            return False;
        }
        i = i + 1;
    }
    return True;
}

"""Store-path suffix for an entry with transitive peers. bun: "+" + Wyhash11
over (name, formatted resolution) of each peer. Placeholder hash until Wyhash11
is ported (see the header)."""
def _peer_hash(peers: list[IsoPeer]) -> str {
    if len(peers) == 0 {
        return "";
    }
    h: int = 0;
    for p in _sort_peers(peers) {
        s: str = p.pkg.name + "@" + p.pkg.version;
        i: int = 0;
        while i < len(s) {
            h = (h * 31 + ord(s[i])) & 72057594037927935;  # 2^56 - 1: keeps h*31 inside 64 bits
            i = i + 1;
        }
    }
    return "+" + hex(h)[2:];
}

def _has_dep_named(nd: IsoNode, name: str) -> bool {
    for d in nd.deps {
        if d.name == name {
            return True;
        }
    }
    return False;
}

def _ref(lf: Lockfile, from_key: str, d: LockDep) -> IsoDepRef {
    return IsoDepRef(
        name=d.name,
        behavior=_behavior_of(d),
        pkg=lockfile_resolve_from(lf, from_key, d.name)
    );
}

"""The dependencies bun walks for a node, filtered and sorted."""
def _node_deps(
    cfg: PmConfig, lf: Lockfile, nd: IsoNode, os_name: str, cpu_name: str
) -> list[IsoDepRef] {
    raw: list[IsoDepRef] = [];
    local: bool = True;
    if _is_root(nd) {
        for d in lockfile_root(lf).deps {
            raw.append(_ref(lf, "", d));
        }
        for ws in lf.workspaces {
            if ws.path == "" {
                continue;
            }
            raw.append(
                IsoDepRef(
                    name=ws.name,
                    behavior=BEH_WORKSPACE,
                    pkg=lockfile_resolve_from(lf, "", ws.name)
                )
            );
        }
    } elif nd.pkg.kind == "workspace" {
        ws2: LockWorkspace = pm_workspace_of(lf, nd.pkg);
        for d in ws2.deps {
            raw.append(_ref(lf, nd.pkg.key, d));
        }
    } else {
        local = nd.pkg.kind == "folder";
        for d in nd.pkg.deps {
            raw.append(_ref(lf, nd.pkg.key, d));
        }
    }
    kept: list[IsoDepRef] = [];
    for r in raw {
        if r.pkg.key == "" {
            continue;
        }  # unresolved (e.g. optional peer)
        if not lockfile_pkg_enabled(r.pkg, os_name, cpu_name) {
            continue;
        }
        if r.pkg.bundled {
            continue;
        }
        if not _dep_enabled(cfg, r.behavior, local) {
            continue;
        }
        kept.append(r);
    }
    return _sort_refs(kept);
}

# ── store construction ────────────────────────────────────────────────────────

def _build_nodes(
    cfg: PmConfig, lf: Lockfile, os_name: str, cpu_name: str
) -> list[IsoNode] {
    nodes: list[IsoNode] = [];
    root_ws: dict[str, bool] = {};  # workspaces declared by the root (bun's root_declares_workspace)
    for ws in lf.workspaces {
        if ws.path == "" {
            continue;
        }
        wp: LockPkg = lockfile_resolve_from(lf, "", ws.name);
        if wp.key != "" {
            root_ws[_pid(wp)] = True;
        }
    }
    early: dict[str, int] = {};  # package identity -> first node (peer context hash 0)
    queue: list[IsoQueued] = [IsoQueued(pkg=LockPkg(kind="root"))];
    while len(queue) > 0 {
        q: IsoQueued = queue[len(queue) - 1];
        del queue[len(queue) - 1];
        qid: str = _pid(q.pkg);

        # cycle: the same package among the ancestors
        cur: int = q.parent;
        linked: bool = False;
        stop: bool = False;
        while cur != -1 and not stop {
            cn: IsoNode = nodes[cur];
            if _pid(cn.pkg) == qid {
                if _is_root(cn) and q.dep_name == "" {
                    nodes[q.parent].children.append(cur);
                    linked = True;
                    stop = True;
                } elif _is_root(cn) or q.dep_name == "" {
                    stop = True;
                } elif cn.dep_name == q.dep_name
                    and behavior_is_workspace(cn.behavior)
                        == behavior_is_workspace(q.behavior) {
                    nodes[q.parent].children.append(cur);
                    linked = True;
                    stop = True;
                }
            }
            if not stop {
                cur = cn.parent;
            }
        }
        if linked {
            continue;
        }

        skip_deps: bool = q.pkg.kind == "root" and q.dep_name != "";
        if q.dep_name != "" {
            if q.pkg.kind == "workspace"
                and not behavior_is_workspace(q.behavior)
                and (qid in root_ws) {
                skip_deps = True;
            }
            if qid in early {
                dn: IsoNode = nodes[early[qid]];
                dedupe: bool = (not _is_root(dn)) and dn.dep_name == q.dep_name;
                if dedupe
                    and dn.pkg.kind == "workspace"
                    and behavior_is_workspace(dn.behavior)
                        != behavior_is_workspace(q.behavior) {
                    dedupe = False;
                }
                if dedupe {
                    # the shared node's transitive peers become the new parents' too
                    for peer in dn.peers {
                        cur2: int = q.parent;
                        while cur2 != -1 {
                            if _has_dep_named(nodes[cur2], peer.name) {
                                break;
                            }
                            _peers_insert(nodes[cur2].peers, peer);
                            cur2 = nodes[cur2].parent;
                        }
                    }
                    nodes[q.parent].children.append(early[qid]);
                    continue;
                }
            } else {
                early[qid] = len(nodes);
            }
        }

        nid: int = len(nodes);
        nodes.append(
            IsoNode(
                pkg=q.pkg, dep_name=q.dep_name, behavior=q.behavior, parent=q.parent
            )
        );
        if q.parent != -1 {
            nodes[q.parent].children.append(nid);
        }
        if skip_deps {
            continue;
        }

        mark: int = len(queue);
        peers_todo: list[IsoDepRef] = [];
        for r in _node_deps(cfg, lf, nodes[nid], os_name, cpu_name) {
            if behavior_is_peer(r.behavior) {
                peers_todo.append(r);
                continue;
            }
            nodes[nid].deps.append(r);
            queue.append(
                IsoQueued(parent=nid, dep_name=r.name, behavior=r.behavior, pkg=r.pkg)
            );
        }
        for pr in peers_todo {
            res: LockPkg = LockPkg();
            auto: bool = True;
            visited: list[int] = [];
            found: bool = False;
            cur3: int = nid;
            while cur3 != -1 and not found {
                for dr in nodes[cur3].deps {
                    if dr.name == pr.name {
                        res = dr.pkg;
                        auto = False;
                        found = True;
                        break;
                    }
                }
                if found {
                    break;
                }
                for tp in nodes[cur3].peers {
                    if tp.name != pr.name {
                        continue;
                    }
                    if not tp.auto_installed {
                        res = tp.pkg;
                        auto = False;
                        found = True;
                        break;
                    }
                    if pr.pkg.key == "" {
                        res = LockPkg();
                        auto = True;
                        found = True;
                        break;
                    }
                    if _pid(pr.pkg) == _pid(tp.pkg) {
                        res = tp.pkg;
                        auto = True;
                        found = True;
                        break;
                    }
                    # a better version than the recorded auto-installed peer: every remaining ancestor learns it
                    while cur3 != -1 {
                        visited.append(cur3);
                        cur3 = nodes[cur3].parent;
                    }
                    res = pr.pkg;
                    auto = True;
                    found = True;
                    break;
                }
                if found {
                    break;
                }
                visited.append(cur3);
                cur3 = nodes[cur3].parent;
            }
            if not found {
                res = pr.pkg;
                auto = True;
            }
            if res.key == "" {
                continue;
            }
            for v in visited {
                _peers_insert(
                    nodes[v].peers, IsoPeer(name=pr.name, pkg=res, auto_installed=auto)
                );
            }
            if len(visited) > 0 {
                nodes[nid].deps.append(
                    IsoDepRef(name=pr.name, behavior=pr.behavior, pkg=res)
                );
                queue.append(
                    IsoQueued(
                        parent=nid, dep_name=pr.name, behavior=pr.behavior, pkg=res
                    )
                );
            }
        }
        # bun pops from the end: reverse this batch so children come out in dependency order
        batch: list[IsoQueued] = [];
        while len(queue) > mark {
            batch.append(queue[len(queue) - 1]);
            del queue[len(queue) - 1];
        }
        for b in batch {
            queue.append(b);
        }
    }
    return nodes;
}

def _build_entries(nodes: list[IsoNode]) -> list[IsoEntry] {
    entries: list[IsoEntry] = [];
    q_nodes: list[int] = [0];
    q_parents: list[int] = [-1];
    qi: int = 0;
    dedupe: dict[str, list[int]] = {};  # package identity -> its entries
    hidden_hoisted: dict[str, bool] = {};
    while qi < len(q_nodes) {
        nid: int = q_nodes[qi];
        pe: int = q_parents[qi];
        qi = qi + 1;
        nd: IsoNode = nodes[nid];
        pid: str = _pid(nd.pkg);
        if pid in dedupe {
            reused: bool = False;
            for eid in dedupe[pid] {
                en: IsoNode = nodes[entries[eid].node_id];
                if _is_root(en) != _is_root(nd) {
                    continue;
                }
                if nd.pkg.kind == "workspace"
                    and not _is_root(nd)
                    and behavior_is_workspace(en.behavior)
                        != behavior_is_workspace(nd.behavior) {
                    continue;
                }
                if not _peers_eq(en.peers, nd.peers) {
                    continue;
                }
                entries[eid].parents.append(pe);
                if pe != -1 and not behavior_is_workspace(nd.behavior) {
                    _entry_deps_insert(
                        entries[pe].deps, IsoEntryDep(entry_id=eid, name=nd.dep_name)
                    );
                }
                reused = True;
                break;
            }
            if reused {
                continue;
            }
        }
        hoisted: bool = False;
        if not _is_root(nd) and not (nd.dep_name in hidden_hoisted) {
            hidden_hoisted[nd.dep_name] = True;
            hoisted = True;
        }
        eid2: int = len(entries);
        entries.append(
            IsoEntry(
                node_id=nid,
                parents=[pe],
                hoisted=hoisted,
                peer_hash=_peer_hash(nd.peers)
            )
        );
        if pe != -1 and not behavior_is_workspace(nd.behavior) {
            _entry_deps_insert(
                entries[pe].deps, IsoEntryDep(entry_id=eid2, name=nd.dep_name)
            );
        }
        if not (pid in dedupe) {
            dedupe[pid] = [];
        }
        dedupe[pid].append(eid2);
        for cid in nd.children {
            q_nodes.append(cid);
            q_parents.append(eid2);
        }
    }
    return entries;
}

"""Build bun's store (nodes + entries) for a lockfile."""
def:pub pm_isolated_store(
    cfg: PmConfig, lf: Lockfile, os_name: str, cpu_name: str
) -> IsoStore {
    st: IsoStore = IsoStore();
    st.nodes = _build_nodes(cfg, lf, os_name, cpu_name);
    st.entries = _build_entries(st.nodes);
    return st;
}

# ── paths ─────────────────────────────────────────────────────────────────────

"""bun's fmtStorePath for strings: `/`, `\\`, `:` and `#` become `+`."""
def _store_escape(s: str) -> str {
    return s.replace("/", "+").replace("\\", "+").replace(":", "+").replace("#", "+");
}

"""`<name>@<version>` with `/` → `+` (bun's fmtStorePath): npm `name@1.2.3`,
tarball `name@https+++host+x.tgz`, folder `name@file+packages+lib`; "" when unsupported."""
def:pub iso_store_name(p: LockPkg) -> str {
    if p.kind == "npm" {
        return p.name.replace("/", "+") + "@" + p.version;
    }
    if p.kind == "tarball" {
        return _store_escape(p.name) + "@" + _store_escape(p.version);
    }
    if p.kind == "folder" {
        return _store_escape(p.name) + "@file+" + _store_escape(p.version);
    }
    if p.kind == "github" {
        gh: tuple[str, str, str] = pm_github_version_parts(p.version);
        return _store_escape(p.name)
            + "@github+"
            + _store_escape(gh[0])
            + "+"
            + _store_escape(gh[1])
            + "+"
            + _store_escape(pm_after_last_dash(p.url));
    }
    if p.kind == "git" {
        gv: tuple[str, str] = pm_git_version_parts(p.version);
        return _store_escape(p.name)
            + "@git+"
            + _store_escape(gv[0])
            + "+"
            + _store_escape(pm_after_last_dash(p.url));
    }
    return "";
}

"""bun's Installer.appendStorePath: where the entry's files live (absolute)."""
def:pub iso_entry_store_dir(root_dir: str, st: IsoStore, eid: int) -> str {
    e: IsoEntry = st.entries[eid];
    nd: IsoNode = st.nodes[e.node_id];
    if _is_root(nd) {
        return "";
    }
    if nd.pkg.kind == "workspace" {
        return root_dir + "/" + nd.pkg.version;
    }
    return root_dir
        + "/node_modules/.bun/"
        + iso_store_name(nd.pkg)
        + e.peer_hash
        + "/node_modules/"
        + nd.pkg.name;
}

"""bun's Installer.appendStoreNodeModulesPath: the node_modules an entry's
dependencies are linked into (absolute)."""
def:pub iso_entry_node_modules(root_dir: str, st: IsoStore, eid: int) -> str {
    e: IsoEntry = st.entries[eid];
    nd: IsoNode = st.nodes[e.node_id];
    if _is_root(nd) {
        return root_dir + "/node_modules";
    }
    if nd.pkg.kind == "workspace" {
        return root_dir + "/" + nd.pkg.version + "/node_modules";
    }
    return root_dir
        + "/node_modules/.bun/"
        + iso_store_name(nd.pkg)
        + e.peer_hash
        + "/node_modules";
}

# ── filesystem steps ──────────────────────────────────────────────────────────

def _symlink_mkparent(dest: str, target: str) -> int {
    rc: int = fsx_symlink(target, dest);
    if rc == FSX_ENOENT {
        fsx_mkdir_p(pm_path_dirname(dest), 493);
        rc = fsx_symlink(target, dest);
    }
    return rc;
}

"""bun's Symlinker.ensureSymlink. expect_missing: create, replacing whatever is
there; expect_existing: keep a link that already points at `target`."""
def _ensure_symlink(dest: str, target: str, expect_existing: bool) -> int {
    if expect_existing {
        cur: str = fsx_readlink(dest);
        if cur == "" {
            if fsx_exists(dest) {
                fsx_rm_rf(dest);
            }  # not a symlink
            return _symlink_mkparent(dest, target);
        }
        if len(cur) > 1 and cur[len(cur) - 1] == "/" {
            cur = cur[0:len(cur) - 1];
        }
        if cur == target {
            return 0;
        }
        fsx_unlink(dest);
        return fsx_symlink(target, dest);
    }
    rc: int = fsx_symlink(target, dest);
    if rc == FSX_ENOENT {
        fsx_mkdir_p(pm_path_dirname(dest), 493);
        return fsx_symlink(target, dest);
    }
    if rc == FSX_EEXIST {
        fsx_rm_rf(dest);
        return fsx_symlink(target, dest);
    }
    return rc;
}

"""node_modules/.bun/node_modules/<name> → the entry (bun's linkToHiddenNodeModules)."""
def _link_hidden(root_dir: str, st: IsoStore, eid: int, is_new: bool) -> int {
    nd: IsoNode = st.nodes[st.entries[eid].node_id];
    dest: str = root_dir + "/node_modules/.bun/node_modules/" + nd.pkg.name;
    target: str = pm_path_relative(
        pm_path_dirname(dest), iso_entry_store_dir(root_dir, st, eid)
    );
    return _ensure_symlink(dest, target, not is_new);
}

def _rand_hex -> str {
    h: str = hex(uv_hrtime() & 72057594037927935)[2:];
    return h.zfill(16);
}

"""Create node_modules and node_modules/.bun. Returns 1 when the store is new,
0 when it already existed, -1 on a fatal error. A node_modules without .bun
(e.g. a hoisted install) is moved aside into .old_modules-<hex>, its .cache is
kept, and the workspaces' node_modules move in there as well (bun 1.3.13)."""
def _prepare_bun_modules(lf: Lockfile, root_dir: str, summary: InstallSummary) -> int {
    nm: str = root_dir + "/node_modules";
    bunm: str = nm + "/.bun";
    rc: int = fsx_mkdir(nm, 493);
    if rc == 0 {
        rc2: int = fsx_mkdir(bunm, 493);
        if rc2 < 0 and rc2 != FSX_EEXIST {
            summary.errors.append(
                "failed to create './node_modules/.bun' (errno " + str(-rc2) + ")"
            );
            return -1;
        }
        return 1;
    }
    if rc != FSX_EEXIST {
        summary.errors.append(
            "failed to create './node_modules' (errno " + str(-rc) + ")"
        );
        return -1;
    }
    rc3: int = fsx_mkdir(bunm, 493);
    if rc3 == FSX_EEXIST {
        return 0;
    }
    if rc3 < 0 {
        summary.errors.append(
            "failed to create './node_modules/.bun' (errno " + str(-rc3) + ")"
        );
        return -1;
    }
    tmp: str = root_dir + "/.tmp_modules-" + _rand_hex();
    if fsx_rename(nm, tmp) != 0 {
        return 1;
    }
    if fsx_mkdir(nm, 493) < 0 or fsx_mkdir(bunm, 493) < 0 {
        summary.errors.append("failed to create './node_modules/.bun'");
        return -1;
    }
    old: str = nm + "/.old_modules-" + _rand_hex();
    if fsx_rename(tmp, old) != 0 {
        return 1;
    }
    fsx_rename(old + "/.cache", nm + "/.cache");
    for ws in lf.workspaces {
        if ws.path == "" {
            continue;
        }
        fsx_rename(
            root_dir + "/" + ws.path + "/node_modules",
            old + "/.old_" + pm_path_basename(ws.path) + "_modules"
        );
    }
    return 1;
}

"""The entry whose bins a native-binlink package (esbuild, …) borrows, or -1
(bun's Installer.maybeReplaceNodeModulesPath)."""
def _native_replacement_entry(
    st: IsoStore, lf: Lockfile, p: LockPkg, os_name: str, cpu_name: str
) -> int {
    if not (p.name in PM_NATIVE_BINLINK_PACKAGES) {
        return -1;
    }
    repl: LockPkg = pm_native_binlink_replacement(lf, p, os_name, cpu_name);
    if repl.key == "" {
        return -1;
    }
    rid: str = _pid(repl);
    i: int = 0;
    while i < len(st.entries) {
        if _pid(st.nodes[st.entries[i].node_id].pkg) == rid {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

def _bin_of(lf: Lockfile, p: LockPkg) -> tuple[JVal, str] {
    if p.kind == "workspace" {
        ws: LockWorkspace = pm_workspace_of(lf, p);
        return (ws.bin, ws.bin_dir);
    }
    return (p.bin, p.bin_dir);
}

"""Link one package's bins into `nm/.bin`, trying the native-binlink target first."""
def _link_bins_for(
    root_dir: str,
    st: IsoStore,
    lf: Lockfile,
    nm: str,
    alias: str,
    p: LockPkg,
    os_name: str,
    cpu_name: str,
    seen: dict[str, bool],
    stats: BinLinkStats
) -> None {
    bd: tuple[JVal, str] = _bin_of(lf, p);
    if bd[1] == "" and jv_is_missing(bd[0]) {
        return;
    }
    rid: int = _native_replacement_entry(st, lf, p, os_name, cpu_name);
    if rid >= 0 {
        rp: LockPkg = st.nodes[st.entries[rid].node_id].pkg;
        alt: BinSpec = BinSpec(
            alias=alias,
            package_dir=iso_entry_node_modules(root_dir, st, rid) + "/" + rp.name,
            bin=bd[0],
            bin_dir=bd[1]
        );
        if not pm_link_bins(nm, alt, seen, stats) {
            return;
        }
        # bun retries with the package itself when the native target is missing
    }
    pm_link_bins(
        nm,
        BinSpec(alias=alias, package_dir=nm + "/" + alias, bin=bd[0], bin_dir=bd[1]),
        seen,
        stats
    );
}

"""Install everything in `lf` under `root_dir` in bun's isolated layout."""
def:pub pm_isolated_install(
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

    prep: int = _prepare_bun_modules(lf, root_dir, summary);
    if prep < 0 {
        summary.fail = summary.fail + 1;
        return;
    }
    is_new: bool = prep == 1;

    st: IsoStore = pm_isolated_store(cfg, lf, os_name, cpu_name);
    n: int = len(st.entries);

    # 1. put the packages in place
    active: dict[int, bool] = {};
    installed_pids: dict[str, bool] = {};
    seen_ws: dict[str, bool] = {};
    eid: int = 0;
    while eid < n {
        e: IsoEntry = st.entries[eid];
        nd: IsoNode = st.nodes[e.node_id];
        p: LockPkg = nd.pkg;
        cur_eid: int = eid;
        eid = eid + 1;
        if _is_root(nd) {
            active[cur_eid] = True;
            summary.skipped = summary.skipped + 1;
            continue;
        }
        pid: str = _pid(p);
        if p.kind == "workspace" {
            if not (pid in seen_ws) {
                seen_ws[pid] = True;
                active[cur_eid] = True;
            }
            summary.skipped = summary.skipped + 1;
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
        store_dir: str = iso_entry_store_dir(root_dir, st, cur_eid);
        needs: bool = cfg.force
            or is_new
            or not fsx_exists(store_dir + "/package.json");
        if not needs {
            if e.hoisted and p.kind != "folder" {
                _link_hidden(root_dir, st, cur_eid, False);
            }
            summary.skipped = summary.skipped + 1;
            continue;
        }
        src: SourceResult = pm_source_dir(cfg, root_dir, p);
        if not src.ok {
            summary.fail = summary.fail + 1;
            summary.errors.append(src.error);
            continue;
        }
        err: str = pm_link_tree_ex(src.dir, store_dir, src.skip_node_modules);
        if err != "" {
            summary.fail = summary.fail + 1;
            summary.errors.append(err);
            continue;
        }
        active[cur_eid] = True;
        summary.success = summary.success + 1;
        if not (pid in installed_pids) {
            installed_pids[pid] = True;
            summary.success = summary.success + 1;
        }
        summary.installed_keys.append(p.key);
        summary.installed_dirs[p.key] = store_dir;
    }

    # 2. dependency symlinks
    eid = 0;
    while eid < n {
        cur2: int = eid;
        eid = eid + 1;
        if not (cur2 in active) {
            continue;
        }
        e2: IsoEntry = st.entries[cur2];
        nd2: IsoNode = st.nodes[e2.node_id];
        nm2: str = iso_entry_node_modules(root_dir, st, cur2);
        local: bool = _is_root(nd2) or nd2.pkg.kind == "workspace";
        for d in e2.deps {
            dest: str = nm2 + "/" + d.name;
            if not local and d.name == nd2.pkg.name {
                dest = nm2 + "/" + nd2.pkg.name + "/node_modules/" + d.name;
            }
            target_abs: str = iso_entry_store_dir(root_dir, st, d.entry_id);
            if target_abs == "" {
                continue;
            }
            rel: str = pm_path_relative(pm_path_dirname(dest), target_abs);
            rc: int = _ensure_symlink(dest, rel, local);
            if rc < 0 {
                summary.errors.append(
                    "could not link " + dest + " (errno " + str(-rc) + ")"
                );
            }
        }
    }

    # 3. bins and the hidden hoisted view
    eid = 0;
    while eid < n {
        cur3: int = eid;
        eid = eid + 1;
        if not (cur3 in active) {
            continue;
        }
        e3: IsoEntry = st.entries[cur3];
        nd3: IsoNode = st.nodes[e3.node_id];
        nm3: str = iso_entry_node_modules(root_dir, st, cur3);
        seen: dict[str, bool] = {};
        stats: BinLinkStats = BinLinkStats();
        for d2 in iso_sorted_entry_deps(e3.deps) {
            _link_bins_for(
                root_dir,
                st,
                lf,
                nm3,
                d2.name,
                st.nodes[st.entries[d2.entry_id].node_id].pkg,
                os_name,
                cpu_name,
                seen,
                stats
            );
        }
        if not _is_root(nd3) {
            # bun: npm/git/github/tarball entries get the hidden hoisted link, folders do not
            if nd3.pkg.kind != "folder" and e3.hoisted {
                _link_hidden(root_dir, st, cur3, is_new);
            }
            own_seen: dict[str, bool] = {};
            _link_bins_for(
                root_dir,
                st,
                lf,
                nm3,
                nd3.dep_name,
                nd3.pkg,
                os_name,
                cpu_name,
                own_seen,
                stats
            );
        }
        summary.bins_linked = summary.bins_linked + stats.linked;
        for msg in stats.errors {
            summary.errors.append(msg);
        }
    }
}
