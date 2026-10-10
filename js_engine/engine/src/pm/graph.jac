"""The package graph the resolver builds and the hoister consumes — bun's
`Lockfile.packages` + `buffers.dependencies` + `buffers.resolutions`.

Package 0 is the root project. Each package owns an ordered list of RDeps
(sorted like bun: behavior, then name); `RDep.resolution` is the index of the
package it resolved to, or -1. `Graph.by_name` keeps append order per name,
which is what bun's `getPackageID` walks when it reuses an existing package.
"""

import from engine.src.pm.depspec { DepSpec, dep_less_than }
import from engine.src.pm.semver { SemVer, SemGroup, semver_satisfies }
import from engine.src.pm.json { JVal }

obj:pub RDep {
    has name: str,
        spec: DepSpec,
        behavior: int = 2,
        resolution: int = -1;  # alias: the key in the dependent's package.json
}

obj:pub RPkg {
    has id: int = 0,
        name: str = "",
        kind: str = "npm",
        version: str = "",
        semver: SemVer = SemVer(),
        url: str = "",
        integrity: str = "",
        deps: list[RDep] = [],
        bin: JVal = JVal(),
        bin_dir: str = "",
        os: JVal = JVal(),
        cpu: JVal = JVal(),
        has_install_script: bool = False,
        ws_version: str = "",
        has_ws_version: bool = False,
        from_lockfile: bool = False;
}

# root | npm | workspace | folder | symlink | tarball | git | github
# npm version; workspace: relative dir

# npm tarball URL as the registry gave it

# loaded from an existing bun.lock (not resolved this run)
obj:pub Graph {
    has pkgs: list[RPkg] = [],
        by_name: dict[str, list[int]] = {};
}

def:pub graph_new -> Graph {
    return Graph();
}

def:pub graph_add(g: Graph, p: RPkg) -> int {
    p.id = len(g.pkgs);
    g.pkgs.append(p);
    if not (p.name in g.by_name) {
        g.by_name[p.name] = [];
    }
    g.by_name[p.name].append(p.id);
    return p.id;
}

"""Sort a dependency list in place like bun (behavior, then name)."""
def:pub graph_sort_deps(deps: list[RDep]) {
    i: int = 1;
    while i < len(deps) {
        j: int = i;
        while j > 0
            and dep_less_than(
                deps[j].behavior, deps[j].name, deps[j - 1].behavior, deps[j - 1].name
            ) {
            tmp: RDep = deps[j - 1];
            deps[j - 1] = deps[j];
            deps[j] = tmp;
            j = j - 1;
        }
        i = i + 1;
    }
}

"""bun's `getPackageID` for an npm dependency: the first package of that
name (append order) whose npm version satisfies `range`. -1 when none."""
def:pub graph_find_satisfying(g: Graph, name: str, range: SemGroup) -> int {
    if not (name in g.by_name) {
        return -1;
    }
    for id in g.by_name[name] {
        p: RPkg = g.pkgs[id];
        if p.kind != "npm" {
            continue;
        }
        if semver_satisfies(range, p.semver) {
            return id;
        }
    }
    return -1;
}

"""The package of `name` with exactly this `kind` + `version` (-1 if none)."""
def:pub graph_find_exact(g: Graph, name: str, kind: str, version: str) -> int {
    if not (name in g.by_name) {
        return -1;
    }
    for id in g.by_name[name] {
        p: RPkg = g.pkgs[id];
        if p.kind == kind and p.version == version {
            return id;
        }
    }
    return -1;
}

"""Workspace package by name (-1 if none)."""
def:pub graph_find_workspace(g: Graph, name: str) -> int {
    if not (name in g.by_name) {
        return -1;
    }
    for id in g.by_name[name] {
        if g.pkgs[id].kind == "workspace" {
            return id;
        }
    }
    return -1;
}

"""Packages reachable from the root through resolutions (bun's clean step
drops the rest). Returns a keep-flag per package id."""
def:pub graph_reachable(g: Graph) -> list[bool] {
    keep: list[bool] = [];
    for p in g.pkgs {
        keep.append(False);
    }
    if len(g.pkgs) == 0 {
        return keep;
    }
    stack: list[int] = [0];
    keep[0] = True;
    while len(stack) > 0 {
        id: int = stack.pop();
        for d in g.pkgs[id].deps {
            r: int = d.resolution;
            if r >= 0 and r < len(keep) and not keep[r] {
                keep[r] = True;
                stack.append(r);
            }
        }
    }
    return keep;
}
