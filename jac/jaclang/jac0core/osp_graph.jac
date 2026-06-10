# Native (LLVM) in-memory edge adjacency for Object-Spatial traversal.
#
# The portable `osp_kernel.jac` owns the walk (`spawn`/`visit`/`disengage`/
# `report`/scope); the *adjacency* (which nodes an edge connects) is the one
# backend-specific piece -- cl stores it on JS object fields (`__ospConn`/
# `__ospRefs`), sv on Python node objects. Native keeps it here, in a module
# compiled to native IR and concatenated into the kernel's `.na.jac` copy (so it
# links through the same `osp_kernel` transitive-source path; issue #6146).
#
# Edges are recorded as opaque `int` handles (`ptrtoint` of the node/edge
# pointer). Storing handles -- not pointers -- keeps the edge<->node graph out
# of the reference-counter, so there is no edge/node refcount cycle; teardown is
# a program-lifetime arena (the lists below), matching the immortal descriptor
# singletons. Parallel lists (not a dict) keep the lowered surface to `list`
# append/index, which native exercises heavily already.
#
# `osp_refs` mirrors cl's `__ospRefs` exactly: filter incident edges by optional
# type tag and direction (undirected edges count as ANY), de-duplicate neighbors
# first-seen so visit order is stable.
glob _e_src: list = [],
     _e_tgt: list = [],
     _e_undir: list = [],
     _e_tag: list = [],
     _e_handle: list = [];

"""Record one edge `src -> tgt` (handles are `ptrtoint`'d node pointers).
`undirected` != 0 makes the edge bidirectional; `edge_tag` is the edge
archetype's type tag, or -1 for an untyped `++>` edge. Returns `tgt` so a
connect expression yields its right operand (chaining)."""
def osp_conn(src: int, tgt: int, eobj: int, undirected: int, edge_tag: int) -> int {
    _e_src.append(src);
    _e_tgt.append(tgt);
    _e_undir.append(undirected);
    _e_tag.append(edge_tag);
    _e_handle.append(eobj);
    return tgt;
}

"""Neighbors (or edges, when `edges_only`) reachable from `origin` along edges
matching `dir` (IN=1, OUT=2, ANY=3) and `edge_tag` (>=0 filters by edge type,
<0 matches any). Returns a fresh `list` of `int` handles -- the same `list`
type the kernel's `osp_visit` consumes, so it feeds straight into `visit`."""
def osp_refs(origin: int, dir: int, edge_tag: int, edges_only: int) -> list {
    out: list = [];
    i = 0;
    n = len(_e_src);
    while i < n {
        s = _e_src[i];
        t = _e_tgt[i];
        et = _e_tag[i];
        und = _e_undir[i];
        eh = _e_handle[i];
        i = i + 1;
        if s != origin and t != origin {
            continue;
        }
        if edge_tag >= 0 and et != edge_tag {
            continue;
        }
        eff = dir;
        if und != 0 {
            eff = 3;
        }
        if (eff == 2 or eff == 3) and s == origin {
            o = eh if edges_only != 0 else t;
            if o not in out {
                out.append(o);
            }
        }
        if (eff == 1 or eff == 3) and t == origin {
            o = eh if edges_only != 0 else s;
            if o not in out {
                out.append(o);
            }
        }
    }
    return out;
}

"""Wrap a single location handle into a `list` of the kernel's `list` type, so
`visit <node>` (a bare target, not an edge ref) can be handed to `osp_visit`
without the backend having to materialize the kernel's list layout itself."""
def osp_wrap1(x: int) -> list {
    out: list = [];
    out.append(x);
    return out;
}
