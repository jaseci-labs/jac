"""node_modules layout computation — a port of bun's `Lockfile.hoist` /
`Tree.processSubtree` / `Tree.hoistDependency` (src/install/lockfile/Tree.zig).

Trees are node_modules folders: tree 0 is ./node_modules, a nested tree is the
node_modules of the dependency that created it. Starting from the root, each
package's dependencies (in bun's order: behavior, then name) try to climb to
the highest folder without a same-name entry:
  - same-name entry resolving to the same package → deduplicated;
  - different package → the dependency stays in its dependent's own folder;
  - peers may hoist onto a satisfying version, root deps onto anything.
Unresolved optional peers adopt a same-name entry when one appears.

`filter` mode (the layout actually installed) additionally skips disabled
(os/cpu), bundled and omitted dependencies; `resolvable` mode (what bun.lock
records) keeps everything.
"""

import from engine.src.pm.graph { Graph, RPkg, RDep }
import from engine.src.pm.depspec {
    dep_less_than,
    behavior_is_optional_peer,
    behavior_is_peer,
    behavior_is_dev,
    behavior_is_bundled,
    behavior_is_workspace,
    behavior_is_optional,
    SPEC_NPM
}
import from engine.src.pm.semver { semver_satisfies }
import from engine.src.pm.platform { pm_os_matches, pm_cpu_matches }

glob:pub HOIST_ROOT_DEP: int = -1,
     HOIST_INVALID_TREE: int = -1;

obj:pub HTree {
    has id: int = 0,
        parent: int = -1,
        dependency_id: int = -1,
        deps: list[int] = [];
}

# flat dep id that created this folder (-1 for the root)
# flat dep ids placed here
obj:pub HoistOptions {
    has filter: bool = False,
        os_name: str = "linux",
        cpu_name: str = "x64",
        omit_dev: bool = False,
        omit_optional: bool = False,
        omit_peer: bool = False;
}

obj:pub HoistResult {
    has ok: bool = False,
        error: str = "",
        trees: list[HTree] = [],
        dep_pkg: list[int] = [],
        dep_idx: list[int] = [],
        pkg_dep_start: list[int] = [],
        pkg_dep_count: list[int] = [];
}

# flat dependency table
# owning package of flat dep id
# index within that package's deps
obj _Res {
    has kind: str = "placement",
        id: int = -1,
        dep_id: int = -1,
        bundled: bool = False;  # hoisted | dependency_loop | resolve | resolve_replace | resolve_later | placement
}

# tree id (placement / resolve_replace) or package id (resolve)
# resolve_replace: the flat dep being replaced
obj _QueueItem {
    has tree_id: int = 0,
        dependency_id: int = -1,
        hoist_root_id: int = -1;
}

obj _Builder {
    has g: Graph,
        opts: HoistOptions,
        res: HoistResult,
        queue: list[_QueueItem] = [],
        pending_optional_peers: dict[str, list[int]] = {},
        error: str = "";
}

def _dep(b: _Builder, d: int) -> RDep {
    return b.g.pkgs[b.res.dep_pkg[d]].deps[b.res.dep_idx[d]];
}

def _resolution(b: _Builder, d: int) -> int {
    return _dep(b, d).resolution;
}

def _set_resolution(b: _Builder, d: int, pkg_id: int) {
    _dep(b, d).resolution = pkg_id;
}

def _is_root_dependency(b: _Builder, d: int) -> bool {
    return b.res.dep_pkg[d] == 0;
}

"""bun's isFilteredDependencyOrWorkspace (install-time filtering)."""
def _is_filtered(b: _Builder, d: int, parent_pkg: int) -> bool {
    dep: RDep = _dep(b, d);
    pkg_id: int = dep.resolution;
    if pkg_id < 0 {
        return not behavior_is_optional_peer(dep.behavior);
    }
    p: RPkg = b.g.pkgs[pkg_id];
    if not pm_os_matches(p.os, b.opts.os_name)
        or not pm_cpu_matches(p.cpu, b.opts.cpu_name) {
        return True;
    }
    if behavior_is_bundled(dep.behavior) {
        return True;
    }
    parent: RPkg = b.g.pkgs[parent_pkg];
    local: bool = parent.kind == "root"
        or parent.kind == "workspace"
        or parent.kind == "folder";
    enabled: bool = (dep.behavior & 2) != 0;
    if behavior_is_optional(dep.behavior) and not b.opts.omit_optional {
        enabled = True;
    }
    if behavior_is_dev(dep.behavior) and local and not b.opts.omit_dev {
        enabled = True;
    }
    if behavior_is_peer(dep.behavior) and not b.opts.omit_peer {
        enabled = True;
    }
    if behavior_is_workspace(dep.behavior) {
        enabled = True;
    }
    return not enabled;
}

def _hoist_dependency(
    b: _Builder,
    tree_id: int,
    as_defined: bool,
    hoist_root_id: int,
    package_id: int,
    d: int
) -> _Res {
    tree: HTree = b.res.trees[tree_id];
    dep: RDep = _dep(b, d);
    for existing in tree.deps {
        ex: RDep = _dep(b, existing);
        if ex.name != dep.name {
            continue;
        }
        res_id: int = ex.resolution;
        if res_id < 0 and package_id < 0 {
            return _Res(kind="resolve_later");
        }
        if res_id < 0 {
            return _Res(kind="resolve_replace", id=tree_id, dep_id=existing);
        }
        if package_id < 0 {
            return _Res(kind="resolve", id=res_id);
        }
        if res_id == package_id {
            return _Res(kind="hoisted");
        }
        if as_defined
            and behavior_is_dev(ex.behavior) != behavior_is_dev(dep.behavior) {
            return _Res(kind="hoisted");
        }
        if behavior_is_peer(dep.behavior) {
            if dep.spec.tag == SPEC_NPM {
                rp: RPkg = b.g.pkgs[res_id];
                if rp.kind == "npm" and semver_satisfies(dep.spec.range, rp.semver) {
                    return _Res(kind="hoisted");
                }
            }
            if _is_root_dependency(b, existing) {
                return _Res(kind="hoisted");
            }
        }
        if as_defined and not behavior_is_peer(ex.behavior) {
            pk: RPkg = b.g.pkgs[package_id];
            rk: RPkg = b.g.pkgs[res_id];
            b.error = "Package \""
                + pk.name
                + "@"
                + pk.version
                + "\" has a dependency loop\n  Resolution: \""
                + rk.name
                + "@"
                + rk.version
                + "\"\n  Dependency: \""
                + dep.name
                + "@"
                + dep.spec.literal
                + "\"";
            return _Res(kind="dependency_loop");
        }
        return _Res(kind="dependency_loop");
    }
    if tree.parent != HOIST_INVALID_TREE and tree.id != hoist_root_id {
        r: _Res = _hoist_dependency(
            b, tree.parent, False, hoist_root_id, package_id, d
        );
        if not as_defined or r.kind != "dependency_loop" {
            return r;
        }
    }
    return _Res(kind="placement", id=tree.id);
}

def _process_subtree(
    b: _Builder, this_tree_id: int, dependency_id: int, hoist_root_id: int
) -> None {
    parent_pkg: int = 0;
    if dependency_id != HOIST_ROOT_DEP {
        parent_pkg = _resolution(b, dependency_id);
    }
    if parent_pkg < 0 {
        return;
    }
    count: int = b.res.pkg_dep_count[parent_pkg];
    if count == 0 {
        return;
    }
    start: int = b.res.pkg_dep_start[parent_pkg];
    next: HTree = HTree(
        id=len(b.res.trees), parent=this_tree_id, dependency_id=dependency_id
    );
    b.res.trees.append(next);

    # dependencies sorted by behavior, then name
    order: list[int] = [];
    i: int = 0;
    while i < count {
        order.append(start + i);
        i = i + 1;
    }
    k: int = 1;
    while k < len(order) {
        j: int = k;
        while j > 0 {
            a: RDep = _dep(b, order[j]);
            c: RDep = _dep(b, order[j - 1]);
            if dep_less_than(a.behavior, a.name, c.behavior, c.name) {
                tmp: int = order[j - 1];
                order[j - 1] = order[j];
                order[j] = tmp;
                j = j - 1;
            } else {
                break;
            }
        }
        k = k + 1;
    }

    for d in order {
        dep: RDep = _dep(b, d);
        pkg_id: int = dep.resolution;
        if b.opts.filter {
            if _is_filtered(b, d, parent_pkg) {
                continue;
            }
            if pkg_id < 0 {
                continue;
            }
        }
        r: _Res = _Res(kind="placement", id=next.id);
        if behavior_is_bundled(dep.behavior) {
            r = _Res(kind="placement", id=next.id, bundled=True);
        } elif pkg_id < 0 {
            if not behavior_is_optional_peer(dep.behavior) {
                continue;
            }
            r = _hoist_dependency(b, next.id, True, hoist_root_id, pkg_id, d);
        } elif b.g.pkgs[pkg_id].kind == "folder" {
            r = _Res(kind="placement", id=next.id);
        } else {
            r = _hoist_dependency(b, next.id, True, hoist_root_id, pkg_id, d);
        }
        if b.error != "" {
            return;
        }
        if r.kind == "hoisted" or r.kind == "dependency_loop" {
            continue;
        }
        if r.kind == "resolve" {
            _set_resolution(b, d, r.id);
            if dep.name in b.pending_optional_peers {
                for pd in b.pending_optional_peers[dep.name] {
                    _set_resolution(b, pd, r.id);
                }
                del b.pending_optional_peers[dep.name];
            }
            continue;
        }
        if r.kind == "resolve_replace" {
            _set_resolution(b, r.dep_id, pkg_id);
            if dep.name in b.pending_optional_peers {
                for pd in b.pending_optional_peers[dep.name] {
                    _set_resolution(b, pd, pkg_id);
                }
                del b.pending_optional_peers[dep.name];
            }
            placed: list[int] = b.res.trees[r.id].deps;
            m: int = 0;
            while m < len(placed) {
                if placed[m] == r.dep_id {
                    placed[m] = d;
                }
                m = m + 1;
            }
            if pkg_id >= 0 and b.res.pkg_dep_count[pkg_id] > 0 {
                b.queue.append(
                    _QueueItem(
                        tree_id=r.id, dependency_id=d, hoist_root_id=hoist_root_id
                    )
                );
            }
            continue;
        }
        if r.kind == "resolve_later" {
            if not (dep.name in b.pending_optional_peers) {
                b.pending_optional_peers[dep.name] = [];
            }
            b.pending_optional_peers[dep.name].append(d);
            continue;
        }
        # placement
        b.res.trees[r.id].deps.append(d);
        if pkg_id >= 0 and b.res.pkg_dep_count[pkg_id] > 0 {
            hr: int = hoist_root_id;
            if r.bundled {
                hr = r.id;
            }
            b.queue.append(_QueueItem(tree_id=r.id, dependency_id=d, hoist_root_id=hr));
        }
    }
    if len(next.deps) == 0 {
        # the folder stayed empty: drop it (it is the last one appended)
        if b.res.trees[len(b.res.trees) - 1].id == next.id {
            del b.res.trees[len(b.res.trees) - 1];
        }
    }
}

"""Compute the tree layout for `g`."""
def:pub hoist_build(g: Graph, opts: HoistOptions) -> HoistResult {
    res: HoistResult = HoistResult();
    # flatten dependencies
    for p in g.pkgs {
        res.pkg_dep_start.append(len(res.dep_pkg));
        res.pkg_dep_count.append(len(p.deps));
        i: int = 0;
        while i < len(p.deps) {
            res.dep_pkg.append(p.id);
            res.dep_idx.append(i);
            i = i + 1;
        }
    }
    b: _Builder = _Builder(g=g, opts=opts, res=res);
    _process_subtree(b, HOIST_INVALID_TREE, HOIST_ROOT_DEP, HOIST_INVALID_TREE);
    while b.error == "" and len(b.queue) > 0 {
        item: _QueueItem = b.queue[0];
        del b.queue[0];
        _process_subtree(b, item.tree_id, item.dependency_id, item.hoist_root_id);
    }
    if b.error != "" {
        res.error = b.error;
        return res;
    }
    # clean: drop dependencies that never resolved (optional peers)
    for t in res.trees {
        kept: list[int] = [];
        for d in t.deps {
            if _resolution(b, d) >= 0 {
                kept.append(d);
            }
        }
        t.deps = kept;
    }
    res.ok = True;
    return res;
}

"""Folder name of a tree = the alias of the dependency that created it."""
def:pub hoist_tree_name(res: HoistResult, g: Graph, tree_id: int) -> str {
    t: HTree = res.trees[tree_id];
    if t.dependency_id < 0 {
        return "";
    }
    return g.pkgs[res.dep_pkg[t.dependency_id]].deps[res.dep_idx[t.dependency_id]].name;
}

"""Relative install path of a tree in bun's pkg_path style ("a/b") and its depth."""
def:pub hoist_tree_path(res: HoistResult, g: Graph, tree_id: int) -> tuple[str, int] {
    names: list[str] = [];
    cur: int = tree_id;
    while cur > 0 and cur < len(res.trees) {
        names.insert(0, hoist_tree_name(res, g, cur));
        cur = res.trees[cur].parent;
    }
    return ("/".join(names), len(names));
}

def:pub hoist_dep(res: HoistResult, g: Graph, d: int) -> RDep {
    return g.pkgs[res.dep_pkg[d]].deps[res.dep_idx[d]];
}
