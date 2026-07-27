glob _r_src: list[int] = [],
     _r_tgt: list[int] = [],
     _r_undir: list[int] = [],
     _r_tag: list[int] = [],
     _r_handle: list[int] = [],
     _r_nsrc: list[int] = [],
     _r_ntgt: list[int] = [],
     _row_free: list[int] = [];

glob _nt_cap: int = 0,
     _nt_cnt: int = 0,
     _nt_key: list[int] = [],
     _nt_ho: list[int] = [],
     _nt_to: list[int] = [],
     _nt_hi: list[int] = [],
     _nt_ti: list[int] = [];

glob _rt_cap: int = 0,
     _rt_cnt: int = 0,
     _rt_key: list[int] = [],
     _rt_head: list[int] = [];

glob _rk_addr: list[int] = [],
     _rk_next: list[int] = [],
     _rk_free: list[int] = [];

def _nt_grow {
    ok = _nt_key;
    oho = _nt_ho;
    oto = _nt_to;
    ohi = _nt_hi;
    oti = _nt_ti;
    ocap = _nt_cap;
    ncap = ocap * 2;
    if ncap == 0 {
        ncap = 1024;
    }
    nk: list[int] = [];
    nho: list[int] = [];
    nto: list[int] = [];
    nhi: list[int] = [];
    nti: list[int] = [];
    i = 0;
    while i < ncap {
        nk.append(0);
        nho.append(-1);
        nto.append(-1);
        nhi.append(-1);
        nti.append(-1);
        i += 1;
    }
    _nt_key = nk;
    _nt_ho = nho;
    _nt_to = nto;
    _nt_hi = nhi;
    _nt_ti = nti;
    _nt_cap = ncap;
    _nt_cnt = 0;
    m = ncap - 1;
    i = 0;
    while i < ocap {
        k = ok[i];
        if k != 0 {
            h = ((k >> 4) ^ (k >> 16)) & m;
            while _nt_key[h] != 0 {
                h = (h + 1) & m;
            }
            _nt_key[h] = k;
            _nt_ho[h] = oho[i];
            _nt_to[h] = oto[i];
            _nt_hi[h] = ohi[i];
            _nt_ti[h] = oti[i];
            _nt_cnt += 1;
        }
        i += 1;
    }
}

def _nt_slot(addr: int) -> int {
    if _nt_cap == 0 or _nt_cnt * 4 >= _nt_cap * 3 {
        _nt_grow();
    }
    m = _nt_cap - 1;
    h = ((addr >> 4) ^ (addr >> 16)) & m;
    while True {
        k = _nt_key[h];
        if k == addr {
            return h;
        }
        if k == 0 {
            _nt_key[h] = addr;
            _nt_cnt += 1;
            return h;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def _nt_find(addr: int) -> int {
    if _nt_cap == 0 {
        return -1;
    }
    m = _nt_cap - 1;
    h = ((addr >> 4) ^ (addr >> 16)) & m;
    while True {
        k = _nt_key[h];
        if k == addr {
            return h;
        }
        if k == 0 {
            return -1;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def _nt_del(s: int) {
    m = _nt_cap - 1;
    i = s;
    j = s;
    while True {
        j = (j + 1) & m;
        k = _nt_key[j];
        if k == 0 {
            break;
        }
        h = ((k >> 4) ^ (k >> 16)) & m;
        move = False;
        if i <= j {
            if h <= i or h > j {
                move = True;
            }
        } else {
            if h <= i and h > j {
                move = True;
            }
        }
        if move {
            _nt_key[i] = k;
            _nt_ho[i] = _nt_ho[j];
            _nt_to[i] = _nt_to[j];
            _nt_hi[i] = _nt_hi[j];
            _nt_ti[i] = _nt_ti[j];
            i = j;
        }
    }
    _nt_key[i] = 0;
    _nt_ho[i] = -1;
    _nt_to[i] = -1;
    _nt_hi[i] = -1;
    _nt_ti[i] = -1;
    _nt_cnt -= 1;
}

def _rt_grow {
    ok = _rt_key;
    oh = _rt_head;
    ocap = _rt_cap;
    ncap = ocap * 2;
    if ncap == 0 {
        ncap = 256;
    }
    nk: list[int] = [];
    nh: list[int] = [];
    i = 0;
    while i < ncap {
        nk.append(0);
        nh.append(-1);
        i += 1;
    }
    _rt_key = nk;
    _rt_head = nh;
    _rt_cap = ncap;
    _rt_cnt = 0;
    m = ncap - 1;
    i = 0;
    while i < ocap {
        k = ok[i];
        if k != 0 {
            h = ((k >> 4) ^ (k >> 16)) & m;
            while _rt_key[h] != 0 {
                h = (h + 1) & m;
            }
            _rt_key[h] = k;
            _rt_head[h] = oh[i];
            _rt_cnt += 1;
        }
        i += 1;
    }
}

def _rt_slot(rgn: int) -> int {
    if _rt_cap == 0 or _rt_cnt * 4 >= _rt_cap * 3 {
        _rt_grow();
    }
    m = _rt_cap - 1;
    h = ((rgn >> 4) ^ (rgn >> 16)) & m;
    while True {
        k = _rt_key[h];
        if k == rgn {
            return h;
        }
        if k == 0 {
            _rt_key[h] = rgn;
            _rt_cnt += 1;
            return h;
        }
        h = (h + 1) & m;
    }
    return -1;
}

def _rt_del(s: int) {
    m = _rt_cap - 1;
    i = s;
    j = s;
    while True {
        j = (j + 1) & m;
        k = _rt_key[j];
        if k == 0 {
            break;
        }
        h = ((k >> 4) ^ (k >> 16)) & m;
        move = False;
        if i <= j {
            if h <= i or h > j {
                move = True;
            }
        } else {
            if h <= i and h > j {
                move = True;
            }
        }
        if move {
            _rt_key[i] = k;
            _rt_head[i] = _rt_head[j];
            i = j;
        }
    }
    _rt_key[i] = 0;
    _rt_head[i] = -1;
    _rt_cnt -= 1;
}

def osp_conn(
    src: int,
    tgt: int,
    eobj: int,
    undirected: int,
    edge_tag: int,
    rgn_src: int,
    rgn_tgt: int
) -> int {
    ss = _nt_slot(src);
    ts = _nt_slot(tgt);
    if rgn_src != 0 and _nt_ho[ss] < 0 and _nt_hi[ss] < 0 {
        _rk_reg(src, rgn_src);
    }
    if rgn_tgt != 0 and ts != ss and _nt_ho[ts] < 0 and _nt_hi[ts] < 0 {
        _rk_reg(tgt, rgn_tgt);
    }
    r = -1;
    if _row_free {
        r = _row_free.pop();
        _r_src[r] = src;
        _r_tgt[r] = tgt;
        _r_undir[r] = undirected;
        _r_tag[r] = edge_tag;
        _r_handle[r] = eobj;
        _r_nsrc[r] = -1;
        _r_ntgt[r] = -1;
    } else {
        r = len(_r_src);
        _r_src.append(src);
        _r_tgt.append(tgt);
        _r_undir.append(undirected);
        _r_tag.append(edge_tag);
        _r_handle.append(eobj);
        _r_nsrc.append(-1);
        _r_ntgt.append(-1);
    }
    t = _nt_to[ss];
    if t >= 0 {
        _r_nsrc[t] = r;
    } else {
        _nt_ho[ss] = r;
    }
    _nt_to[ss] = r;
    t = _nt_ti[ts];
    if t >= 0 {
        _r_ntgt[t] = r;
    } else {
        _nt_hi[ts] = r;
    }
    _nt_ti[ts] = r;
    return tgt;
}

def _rk_reg(addr: int, rgn: int) {
    s = _rt_slot(rgn);
    e = -1;
    if _rk_free {
        e = _rk_free.pop();
        _rk_addr[e] = addr;
        _rk_next[e] = _rt_head[s];
    } else {
        e = len(_rk_addr);
        _rk_addr.append(addr);
        _rk_next.append(_rt_head[s]);
    }
    _rt_head[s] = e;
}

def osp_refs(origin: int, dir: int, edge_tag: int, edges_only: int) -> list {
    out: list = [];
    s = _nt_find(origin);
    if s < 0 {
        return out;
    }
    r = _nt_ho[s];
    while r >= 0 {
        eff = dir;
        if _r_undir[r] != 0 {
            eff = 3;
        }
        if (eff == 2 or eff == 3) and (edge_tag < 0 or _r_tag[r] == edge_tag) {
            o = _r_handle[r] if edges_only != 0 else _r_tgt[r];
            if o not in out {
                out.append(o);
            }
        }
        r = _r_nsrc[r];
    }
    r = _nt_hi[s];
    while r >= 0 {
        eff = dir;
        if _r_undir[r] != 0 {
            eff = 3;
        }
        if (eff == 1 or eff == 3) and (edge_tag < 0 or _r_tag[r] == edge_tag) {
            o = _r_handle[r] if edges_only != 0 else _r_src[r];
            if o not in out {
                out.append(o);
            }
        }
        r = _r_ntgt[r];
    }
    return out;
}

def osp_refs_many(origins: list, dir: int, edge_tag: int, edges_only: int) -> list {
    out: list = [];
    i = 0;
    n = len(origins);
    while i < n {
        hop = osp_refs(origins[i], dir, edge_tag, edges_only);
        i = i + 1;
        j = 0;
        m = len(hop);
        while j < m {
            o = hop[j];
            j = j + 1;
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

def _unlink_out(src: int, row: int) {
    s = _nt_find(src);
    if s < 0 {
        return;
    }
    prev = -1;
    r = _nt_ho[s];
    while r >= 0 {
        if r == row {
            if prev < 0 {
                _nt_ho[s] = _r_nsrc[r];
            } else {
                _r_nsrc[prev] = _r_nsrc[r];
            }
            if _nt_to[s] == r {
                _nt_to[s] = prev;
            }
            return;
        }
        prev = r;
        r = _r_nsrc[r];
    }
}

def _unlink_in(tgt: int, row: int) {
    s = _nt_find(tgt);
    if s < 0 {
        return;
    }
    prev = -1;
    r = _nt_hi[s];
    while r >= 0 {
        if r == row {
            if prev < 0 {
                _nt_hi[s] = _r_ntgt[r];
            } else {
                _r_ntgt[prev] = _r_ntgt[r];
            }
            if _nt_ti[s] == r {
                _nt_ti[s] = prev;
            }
            return;
        }
        prev = r;
        r = _r_ntgt[r];
    }
}

def osp_disconnect(edge_handle: int) -> int {
    i = 0;
    n = len(_r_handle);
    while i < n {
        if _r_handle[i] == edge_handle and _r_src[i] != -1 {
            _unlink_out(_r_src[i], i);
            _unlink_in(_r_tgt[i], i);
            _r_src[i] = -1;
            _r_handle[i] = 0;
            _row_free.append(i);
            return 1;
        }
        i = i + 1;
    }
    return 0;
}

def osp_region_died(rgn: int) -> int {
    n = 0;
    if _rt_cap == 0 {
        return 0;
    }
    m = _rt_cap - 1;
    h = ((rgn >> 4) ^ (rgn >> 16)) & m;
    s = -1;
    while True {
        k = _rt_key[h];
        if k == rgn {
            s = h;
            break;
        }
        if k == 0 {
            return 0;
        }
        h = (h + 1) & m;
    }
    stash_ho: list[int] = [];
    stash_hi: list[int] = [];
    e = _rt_head[s];
    while e >= 0 {
        addr = _rk_addr[e];
        ns = _nt_find(addr);
        if ns >= 0 {
            stash_ho.append(_nt_ho[ns]);
            stash_hi.append(_nt_hi[ns]);
            _nt_del(ns);
        }
        nx2 = _rk_next[e];
        _rk_free.append(e);
        e = nx2;
    }
    _rt_del(s);
    i = 0;
    while i < len(stash_ho) {
        r = stash_ho[i];
        while r >= 0 {
            nx = _r_nsrc[r];
            if _r_src[r] != -1 {
                if _nt_find(_r_tgt[r]) >= 0 {
                    _unlink_in(_r_tgt[r], r);
                }
                _r_src[r] = -1;
                _r_handle[r] = 0;
                _row_free.append(r);
                n += 1;
            }
            r = nx;
        }
        r = stash_hi[i];
        while r >= 0 {
            nx = _r_ntgt[r];
            if _r_src[r] != -1 {
                if _nt_find(_r_src[r]) >= 0 {
                    _unlink_out(_r_src[r], r);
                }
                _r_src[r] = -1;
                _r_handle[r] = 0;
                _row_free.append(r);
                n += 1;
            }
            r = nx;
        }
        i += 1;
    }
    return n;
}
