glob _e_src: list = [],
     _e_tgt: list = [],
     _e_undir: list = [],
     _e_tag: list = [],
     _e_handle: list = [];

def osp_conn(src: int, tgt: int, eobj: int, undirected: int, edge_tag: int) -> int {
    _e_src.append(src);
    _e_tgt.append(tgt);
    _e_undir.append(undirected);
    _e_tag.append(edge_tag);
    _e_handle.append(eobj);
    return tgt;
}

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

def osp_wrap1(x: int) -> list {
    out: list = [];
    out.append(x);
    return out;
}

def osp_disconnect(edge_handle: int) -> int {
    i = 0;
    n = len(_e_handle);
    while i < n {
        if _e_handle[i] == edge_handle {
            _e_src.pop(i);
            _e_tgt.pop(i);
            _e_undir.pop(i);
            _e_tag.pop(i);
            _e_handle.pop(i);
            return 1;
        }
        i = i + 1;
    }
    return 0;
}
