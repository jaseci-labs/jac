glob _isa: dict[int, set[int]] = {};

def osp_register_type(tag: int, bases: list[int]) -> int {
    anc: set[int] = set();
    anc.add(tag);
    for b in bases {
        if b in _isa {
            banc: set[int] = _isa[b];
            for t in banc {
                anc.add(t);
            }
        } else {
            anc.add(b);
        }
    }
    if tag in _isa {
        old: set[int] = _isa[tag];
        same = len(old) == len(anc);
        if same {
            for t in anc {
                if t not in old {
                    same = False;
                }
            }
        }
        return 1 if same else 0;
    }
    _isa[tag] = anc;
    return 1;
}

def osp_is_a(tag: int, base: int) -> bool {
    if tag == base {
        return True;
    }
    if tag in _isa {
        anc: set[int] = _isa[tag];
        return base in anc;
    }
    return False;
}

obj EdgeRow {
    has src: int,
        tgt: int,
        tag: int,
        handle: int,
        undirected: bool = False,
        live: bool = True;
}

obj Adj {
    has rows_out: list[int],
        rows_in: list[int],
        out: dict[int, list[int]],
        inn: dict[int, list[int]];
}

obj OspGraph {
    has adj: dict[int, Adj],
        rows: list[EdgeRow],
        free_rows: list[int],
        row_of: dict[int, int],
        dead: dict[int, int],
        regions: dict[int, list[int]];

    def adj_of(h: int) -> Adj {
        if h in self.adj {
            found: Adj = self.adj[h];
            return found;
        }
        made = Adj(rows_out=[], rows_in=[], out={}, inn={});
        self.adj[h] = made;
        return made;
    }

    def has_light(h: int) -> bool {
        if h not in self.adj {
            return False;
        }
        a: Adj = self.adj[h];
        for k in a.out {
            peers: list[int] = a.out[k];
            if peers {
                return True;
            }
        }
        for k in a.inn {
            srcs: list[int] = a.inn[k];
            if srcs {
                return True;
            }
        }
        return False;
    }

    def connect_light(src: int, tgt: int, tag: int, one_sided: bool) -> int {
        if src in self.dead or tgt in self.dead {
            return -1;
        }
        sa: Adj = self.adj_of(src);
        ta: Adj = self.adj_of(tgt);
        if tag in sa.out {
            outs: list[int] = sa.out[tag];
            outs.append(tgt);
        } else {
            sa.out[tag] = [tgt];
        }
        if not one_sided {
            if tag in ta.inn {
                inns: list[int] = ta.inn[tag];
                inns.append(src);
            } else {
                ta.inn[tag] = [src];
            }
        }
        return tgt;
    }

    def light_remove_one(src: int, tgt: int, tag: int) -> bool {
        if src not in self.adj {
            return False;
        }
        sa: Adj = self.adj[src];
        if tag not in sa.out {
            return False;
        }
        outs: list[int] = sa.out[tag];
        if not self._drop_handle(outs, tgt) {
            return False;
        }
        if tgt in self.adj {
            ta: Adj = self.adj[tgt];
            if tag in ta.inn {
                inns: list[int] = ta.inn[tag];
                self._drop_handle(inns, src);
            }
        }
        return True;
    }

    def light_pairs(h: int, outgoing: bool) -> list[int] {
        out: list[int] = [];
        if h not in self.adj {
            return out;
        }
        a: Adj = self.adj[h];
        d: dict[int, list[int]] = a.out if outgoing else a.inn;
        for k in d {
            peers: list[int] = d[k];
            for p in peers {
                out.append(k);
                out.append(p);
            }
        }
        return out;
    }

    def light_detach(h: int) -> int {
        if h not in self.adj {
            return 0;
        }
        a: Adj = self.adj[h];
        n = 0;
        for k in a.out {
            peers: list[int] = a.out[k];
            for p in peers {
                if p in self.adj {
                    pa: Adj = self.adj[p];
                    if k in pa.inn {
                        inns: list[int] = pa.inn[k];
                        self._drop_handle(inns, h);
                    }
                }
                n += 1;
            }
        }
        for k in a.inn {
            srcs: list[int] = a.inn[k];
            for s in srcs {
                if s in self.adj {
                    sa: Adj = self.adj[s];
                    if k in sa.out {
                        outs: list[int] = sa.out[k];
                        self._drop_handle(outs, h);
                    }
                }
                n += 1;
            }
        }
        a.out.clear();
        a.inn.clear();
        return n;
    }

    def _drop_handle(lst: list[int], h: int) -> bool {
        i = 0;
        n = len(lst);
        while i < n {
            if lst[i] == h {
                lst.pop(i);
                return True;
            }
            i += 1;
        }
        return False;
    }

    def is_dead(h: int) -> bool {
        return h in self.dead;
    }

    def has_edge(eobj: int) -> bool {
        return eobj in self.row_of;
    }

    def _row_alloc(src: int, tgt: int, tag: int, eobj: int, undirected: bool) -> int {
        if self.free_rows {
            rid: int = self.free_rows.pop();
            row: EdgeRow = self.rows[rid];
            row.src = src;
            row.tgt = tgt;
            row.tag = tag;
            row.handle = eobj;
            row.undirected = undirected;
            row.live = True;
            self.row_of[eobj] = rid;
            return rid;
        }
        rid = len(self.rows);
        self.rows.append(
            EdgeRow(src=src, tgt=tgt, tag=tag, handle=eobj, undirected=undirected)
        );
        self.row_of[eobj] = rid;
        return rid;
    }

    def _row_retire(rid: int) {
        row: EdgeRow = self.rows[rid];
        if row.handle in self.row_of {
            del self.row_of[row.handle];
        }
        row.live = False;
        row.handle = 0;
        self.free_rows.append(rid);
    }

    def _drop_rid(lst: list[int], rid: int) {
        i = 0;
        n = len(lst);
        while i < n {
            if lst[i] == rid {
                del lst[i];
                return;
            }
            i += 1;
        }
    }

    def region_reg(h: int, rgn: int) {
        if rgn in self.regions {
            members: list[int] = self.regions[rgn];
            members.append(h);
        } else {
            self.regions[rgn] = [h];
        }
    }

    def connect(
        src: int,
        tgt: int,
        eobj: int,
        undirected: bool,
        tag: int,
        rgn_src: int,
        rgn_tgt: int
    ) -> int {
        if src in self.dead or tgt in self.dead {
            return -1;
        }
        sa: Adj = self.adj_of(src);
        ta: Adj = self.adj_of(tgt);
        if rgn_src != 0 and (not sa.rows_out) and (not sa.rows_in) {
            self.region_reg(src, rgn_src);
        }
        if rgn_tgt != 0 and tgt != src and (not ta.rows_out) and (not ta.rows_in) {
            self.region_reg(tgt, rgn_tgt);
        }
        rid: int = self._row_alloc(src, tgt, tag, eobj, undirected);
        sa.rows_out.append(rid);
        ta.rows_in.append(rid);
        return tgt;
    }

    def _tag_matches(tag: int, want: int) -> bool {
        if want == -1 or tag == want {
            return True;
        }
        return osp_is_a(tag, want);
    }

    def refs_into(
        origin: int,
        dir: int,
        edge_tag: int,
        edges_only: bool,
        out: list[int],
        seen: set[int]
    ) {
        if origin not in self.adj or origin in self.dead {
            return;
        }
        a: Adj = self.adj[origin];
        for rid in a.rows_out {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            eff = dir;
            if row.undirected {
                eff = 3;
            }
            if (eff == 2 or eff == 3) and self._tag_matches(row.tag, edge_tag) {
                o: int = row.handle if edges_only else row.tgt;
                if o not in seen {
                    seen.add(o);
                    out.append(o);
                }
            }
        }
        for rid in a.rows_in {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            eff = dir;
            if row.undirected {
                eff = 3;
            }
            if (eff == 1 or eff == 3) and self._tag_matches(row.tag, edge_tag) {
                o: int = row.handle if edges_only else row.src;
                if o not in seen {
                    seen.add(o);
                    out.append(o);
                }
            }
        }
        if edges_only {
            return;
        }
        if dir == 2 or dir == 3 {
            for k in a.out {
                if self._tag_matches(k, edge_tag) {
                    peers: list[int] = a.out[k];
                    for p in peers {
                        if p not in seen {
                            seen.add(p);
                            out.append(p);
                        }
                    }
                }
            }
        }
        if dir == 1 or dir == 3 {
            for k in a.inn {
                if self._tag_matches(k, edge_tag) {
                    srcs: list[int] = a.inn[k];
                    for s in srcs {
                        if s not in seen {
                            seen.add(s);
                            out.append(s);
                        }
                    }
                }
            }
        }
    }

    def refs(origin: int, dir: int, edge_tag: int, edges_only: bool) -> list[int] {
        out: list[int] = [];
        seen: set[int] = set();
        self.refs_into(origin, dir, edge_tag, edges_only, out, seen);
        return out;
    }

    def refs_many(
        origins: list[int], dir: int, edge_tag: int, edges_only: bool
    ) -> list[int] {
        out: list[int] = [];
        seen: set[int] = set();
        for origin in origins {
            self.refs_into(origin, dir, edge_tag, edges_only, out, seen);
        }
        return out;
    }

    def refs_edge_pred(
        origins: list[int],
        dir: int,
        edge_tag: int,
        edges_only: bool,
        pred: Callable[([int], bool)]
    ) -> list[int] {
        out: list[int] = [];
        seen: set[int] = set();
        for origin in origins {
            if origin not in self.adj or origin in self.dead {
                continue;
            }
            a: Adj = self.adj[origin];
            for rid in a.rows_out {
                row: EdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                eff = dir;
                if row.undirected {
                    eff = 3;
                }
                if (eff == 2 or eff == 3)
                    and self._tag_matches(row.tag, edge_tag)
                    and pred(row.handle) {
                    o: int = row.handle if edges_only else row.tgt;
                    if o not in seen {
                        seen.add(o);
                        out.append(o);
                    }
                }
            }
            for rid in a.rows_in {
                row: EdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                eff = dir;
                if row.undirected {
                    eff = 3;
                }
                if (eff == 1 or eff == 3)
                    and self._tag_matches(row.tag, edge_tag)
                    and pred(row.handle) {
                    o: int = row.handle if edges_only else row.src;
                    if o not in seen {
                        seen.add(o);
                        out.append(o);
                    }
                }
            }
        }
        return out;
    }

    def filter_handles(hs: list[int], pred: Callable[([int], bool)]) -> list[int] {
        out: list[int] = [];
        for h in hs {
            if pred(h) {
                out.append(h);
            }
        }
        return out;
    }

    def refs_chain(
        origins: list[int], dirs: list[int], tags: list[int], edges_only: bool
    ) -> list[int] {
        cur = origins;
        i = 0;
        n = len(dirs);
        while i < n {
            last = i == (n - 1);
            cur = self.refs_many(cur, dirs[i], tags[i], edges_only if last else False);
            i += 1;
        }
        return cur;
    }

    def conn_many(
        srcs: list[int],
        tgts: list[int],
        eobjs: list[int],
        undirected: bool,
        tag: int,
        rgn_src: int,
        rgn_tgt: int
    ) -> int {
        n = 0;
        k = 0;
        for s in srcs {
            for t in tgts {
                eobj: int = eobjs[k];
                k += 1;
                if self.connect(s, t, eobj, undirected, tag, rgn_src, rgn_tgt) < 0 {
                    return -1;
                }
                n += 1;
            }
        }
        return n;
    }

    def edge_peer(eobj: int, origin: int) -> int {
        if eobj not in self.row_of {
            return -1;
        }
        rid: int = self.row_of[eobj];
        row: EdgeRow = self.rows[rid];
        if not row.live {
            return -1;
        }
        if row.src == origin {
            return row.tgt;
        }
        return row.src;
    }

    def _unlink(rid: int) {
        row: EdgeRow = self.rows[rid];
        if row.src in self.adj {
            sa: Adj = self.adj[row.src];
            self._drop_rid(sa.rows_out, rid);
        }
        if row.tgt in self.adj {
            ta: Adj = self.adj[row.tgt];
            self._drop_rid(ta.rows_in, rid);
        }
    }

    def disconnect(eobj: int) -> bool {
        if eobj not in self.row_of {
            return False;
        }
        rid: int = self.row_of[eobj];
        row: EdgeRow = self.rows[rid];
        if not row.live {
            return False;
        }
        self._unlink(rid);
        self._row_retire(rid);
        return True;
    }

    def disconnect_between(src: int, tgt: int, dir: int, edge_tag: int) -> int {
        if src not in self.adj {
            return 0;
        }
        a: Adj = self.adj[src];
        hits: list[int] = [];
        hit_set: set[int] = set();
        for rid in a.rows_out {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            eff = dir;
            if row.undirected {
                eff = 3;
            }
            if (eff == 2 or eff == 3)
                and row.tgt == tgt
                and self._tag_matches(row.tag, edge_tag) {
                if rid not in hit_set {
                    hit_set.add(rid);
                    hits.append(rid);
                }
            }
        }
        for rid in a.rows_in {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            eff = dir;
            if row.undirected {
                eff = 3;
            }
            if (eff == 1 or eff == 3)
                and row.src == tgt
                and self._tag_matches(row.tag, edge_tag) {
                if rid not in hit_set {
                    hit_set.add(rid);
                    hits.append(rid);
                }
            }
        }
        for rid in hits {
            self._unlink(rid);
            self._row_retire(rid);
        }
        return len(hits);
    }

    def disconnect_between_pred(
        src: int, tgt: int, dir: int, edge_tag: int, pred: Callable[([int], bool)]
    ) -> int {
        if src not in self.adj {
            return 0;
        }
        a: Adj = self.adj[src];
        hits: list[int] = [];
        hit_set: set[int] = set();
        for rid in a.rows_out {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            eff = dir;
            if row.undirected {
                eff = 3;
            }
            if (eff == 2 or eff == 3)
                and row.tgt == tgt
                and self._tag_matches(row.tag, edge_tag)
                and pred(row.handle) {
                if rid not in hit_set {
                    hit_set.add(rid);
                    hits.append(rid);
                }
            }
        }
        for rid in a.rows_in {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            eff = dir;
            if row.undirected {
                eff = 3;
            }
            if (eff == 1 or eff == 3)
                and row.src == tgt
                and self._tag_matches(row.tag, edge_tag)
                and pred(row.handle) {
                if rid not in hit_set {
                    hit_set.add(rid);
                    hits.append(rid);
                }
            }
        }
        for rid in hits {
            self._unlink(rid);
            self._row_retire(rid);
        }
        return len(hits);
    }

    def light_disconnect_between(src: int, tgt: int, dir: int, edge_tag: int) -> int {
        n = 0;
        if src not in self.adj {
            return 0;
        }
        a: Adj = self.adj[src];
        if dir == 2 or dir == 3 {
            ktags: list[int] = [];
            for k in a.out {
                if self._tag_matches(k, edge_tag) {
                    ktags.append(k);
                }
            }
            for k in ktags {
                while self.light_remove_one(src, tgt, k) {
                    n += 1;
                }
            }
        }
        if dir == 1 or dir == 3 {
            ktags2: list[int] = [];
            for k in a.inn {
                if self._tag_matches(k, edge_tag) {
                    ktags2.append(k);
                }
            }
            for k in ktags2 {
                while self.light_remove_one(tgt, src, k) {
                    n += 1;
                }
            }
        }
        return n;
    }

    def disconnect_between_many(
        srcs: list[int], tgts: list[int], dir: int, edge_tag: int
    ) -> int {
        n = 0;
        for s in srcs {
            for t in tgts {
                n += self.disconnect_between(s, t, dir, edge_tag);
            }
        }
        return n;
    }

    def node_destroy(h: int) -> int {
        if h in self.dead {
            return 0;
        }
        self.dead[h] = 1;
        if h not in self.adj {
            return 0;
        }
        n0: int = self.light_detach(h);
        a: Adj = self.adj[h];
        gone: list[int] = [];
        for rid in a.rows_out {
            row: EdgeRow = self.rows[rid];
            if row.live {
                gone.append(rid);
            }
        }
        for rid in a.rows_in {
            row: EdgeRow = self.rows[rid];
            if row.live {
                gone.append(rid);
            }
        }
        n = n0;
        for rid in gone {
            row: EdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            self._unlink(rid);
            self._row_retire(rid);
            n += 1;
        }
        return n;
    }

    def destroy(h: int) -> int {
        if h in self.row_of {
            return 1 if self.disconnect(h) else 0;
        }
        return self.node_destroy(h);
    }

    def destroy_all(hs: list[int]) -> int {
        n = 0;
        for h in hs {
            n += self.destroy(h);
        }
        return n;
    }

    def drop_node(h: int) -> int {
        n = self.node_destroy(h);
        if h in self.adj {
            self.adj.pop(h);
        }
        if h in self.dead {
            self.dead.pop(h);
        }
        return n;
    }

    def region_died(rgn: int) -> int {
        if rgn not in self.regions {
            return 0;
        }
        members: list[int] = self.regions[rgn];
        del self.regions[rgn];
        stash: list[Adj] = [];
        for h in members {
            if h in self.adj {
                self.light_detach(h);
                a: Adj = self.adj[h];
                stash.append(a);
                self.adj.pop(h);
            }
            if h in self.dead {
                self.dead.pop(h);
            }
        }
        n = 0;
        for a in stash {
            for rid in a.rows_out {
                row: EdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                if row.tgt in self.adj {
                    ta: Adj = self.adj[row.tgt];
                    self._drop_rid(ta.rows_in, rid);
                }
                self._row_retire(rid);
                n += 1;
            }
            for rid in a.rows_in {
                row: EdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                if row.src in self.adj {
                    sa: Adj = self.adj[row.src];
                    self._drop_rid(sa.rows_out, rid);
                }
                self._row_retire(rid);
                n += 1;
            }
        }
        return n;
    }
}

def _new_graph -> OspGraph {
    return OspGraph(adj={}, rows=[], free_rows=[], row_of={}, dead={}, regions={});
}

glob DEFAULT_GRAPH: OspGraph = _new_graph();

def:pub osp_adj_pairs(origin: int, dir: int) -> list[int] {
    out: list[int] = [];
    if origin in DEFAULT_GRAPH.adj {
        a: Adj = DEFAULT_GRAPH.adj[origin];
        if dir == 2 {
            for rid in a.rows_out {
                row: EdgeRow = DEFAULT_GRAPH.rows[rid];
                if row.live {
                    out.append(row.tag);
                    out.append(row.tgt);
                }
            }
            for k in a.out {
                peers: list[int] = a.out[k];
                for t in peers {
                    out.append(k);
                    out.append(t);
                }
            }
        } else {
            for rid in a.rows_in {
                row: EdgeRow = DEFAULT_GRAPH.rows[rid];
                if row.live {
                    out.append(row.tag);
                    out.append(row.src);
                }
            }
            for k in a.inn {
                srcs: list[int] = a.inn[k];
                for t in srcs {
                    out.append(k);
                    out.append(t);
                }
            }
        }
    }
    return out;
}

def osp_has_edge(eh: int) -> int {
    return 1 if DEFAULT_GRAPH.has_edge(eh) else 0;
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
    return DEFAULT_GRAPH.connect(
        src, tgt, eobj, undirected != 0, edge_tag, rgn_src, rgn_tgt
    );
}

def osp_refs(origin: int, dir: int, edge_tag: int, edges_only: int) -> list[int] {
    return DEFAULT_GRAPH.refs(origin, dir, edge_tag, edges_only != 0);
}

def osp_refs_many(
    origins: list[int], dir: int, edge_tag: int, edges_only: int
) -> list[int] {
    return DEFAULT_GRAPH.refs_many(origins, dir, edge_tag, edges_only != 0);
}

def osp_refs_edge_pred(
    origins: list[int],
    dir: int,
    edge_tag: int,
    edges_only: int,
    pred: Callable[([int], bool)]
) -> list[int] {
    return DEFAULT_GRAPH.refs_edge_pred(origins, dir, edge_tag, edges_only != 0, pred);
}

def osp_filter(hs: list[int], pred: Callable[([int], bool)]) -> list[int] {
    return DEFAULT_GRAPH.filter_handles(hs, pred);
}

def osp_refs_chain(
    origins: list[int], dirs: list[int], tags: list[int], edges_only: int
) -> list[int] {
    return DEFAULT_GRAPH.refs_chain(origins, dirs, tags, edges_only != 0);
}

def osp_conn_many(
    srcs: list[int],
    tgts: list[int],
    eobjs: list[int],
    undirected: int,
    edge_tag: int,
    rgn_src: int,
    rgn_tgt: int
) -> int {
    return DEFAULT_GRAPH.conn_many(
        srcs, tgts, eobjs, undirected != 0, edge_tag, rgn_src, rgn_tgt
    );
}

def osp_disconn_between_pred(
    src: int, tgt: int, dir: int, edge_tag: int, pred: Callable[([int], bool)]
) -> int {
    return DEFAULT_GRAPH.disconnect_between_pred(src, tgt, dir, edge_tag, pred);
}

def osp_disconn_between_many(
    srcs: list[int], tgts: list[int], dir: int, edge_tag: int
) -> int {
    return DEFAULT_GRAPH.disconnect_between_many(srcs, tgts, dir, edge_tag);
}

def osp_wrap1(x: int) -> list[int] {
    out: list[int] = [];
    out.append(x);
    return out;
}

def osp_edge_peer(edge_handle: int, origin: int) -> int {
    return DEFAULT_GRAPH.edge_peer(edge_handle, origin);
}

def osp_conn_light(src: int, tgt: int, edge_tag: int, one_sided: int) -> int {
    return DEFAULT_GRAPH.connect_light(src, tgt, edge_tag, one_sided != 0);
}

def osp_light_remove(src: int, tgt: int, edge_tag: int) -> int {
    return 1 if DEFAULT_GRAPH.light_remove_one(src, tgt, edge_tag) else 0;
}

def osp_light_pairs(h: int, outgoing: int) -> list[int] {
    return DEFAULT_GRAPH.light_pairs(h, outgoing != 0);
}

def osp_light_detach(h: int) -> int {
    return DEFAULT_GRAPH.light_detach(h);
}

def osp_has_light(h: int) -> int {
    return 1 if DEFAULT_GRAPH.has_light(h) else 0;
}

def osp_light_disconn_between(src: int, tgt: int, dir: int, edge_tag: int) -> int {
    return DEFAULT_GRAPH.light_disconnect_between(src, tgt, dir, edge_tag);
}

def osp_drop_node(h: int) -> int {
    return DEFAULT_GRAPH.drop_node(h);
}

def osp_disconn_between(src: int, tgt: int, dir: int, edge_tag: int) -> int {
    return DEFAULT_GRAPH.disconnect_between(src, tgt, dir, edge_tag);
}

def osp_disconnect(edge_handle: int) -> int {
    return 1 if DEFAULT_GRAPH.disconnect(edge_handle) else 0;
}

def osp_is_dead(addr: int) -> int {
    return 1 if DEFAULT_GRAPH.is_dead(addr) else 0;
}

def osp_node_destroy(addr: int) -> int {
    return DEFAULT_GRAPH.node_destroy(addr);
}

def osp_destroy(h: int) -> int {
    return DEFAULT_GRAPH.destroy(h);
}

def osp_destroy_all(hs: list[int]) -> int {
    return DEFAULT_GRAPH.destroy_all(hs);
}

def osp_region_died(rgn: int) -> int {
    return DEFAULT_GRAPH.region_died(rgn);
}
