glob _isa: dict[int, set[int]] = {},
     _has_subs: set[int] = set();

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
    for t in anc {
        if t != tag {
            _has_subs.add(t);
        }
    }
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

obj OspEdgeTypeDesc {
    has tag: int,
        factory: Callable[([], int)];
}

glob _edge_types: dict[str, OspEdgeTypeDesc] = {};

def osp_register_edge_type(name: str, tag: int, factory: Callable[([], int)]) {
    _edge_types[name] = OspEdgeTypeDesc(tag=tag, factory=factory);
}

def osp_edge_type(name: str) -> OspEdgeTypeDesc {
    desc = _edge_types.get(name);
    if desc is None {
        raise TypeError("graph operation requires a registered edge type");
    }
    return desc;
}

def osp_new_edge(desc: OspEdgeTypeDesc) -> int {
    return desc.factory();
}

glob _NO_ROWS: list[int] = [];

obj OspEdgeRow {
    has src: int,
        tgt: int,
        tag: int,
        handle: int,
        undirected: bool = False,
        live: bool = True,
        pos_out: int = -1,
        pos_in: int = -1;
}

obj OspAdj {
    has rows_out: list[int],
        rows_in: list[int],
        out: dict[int, list[int]],
        inn: dict[int, list[int]];
}

obj OspGraph {
    has adj: dict[int, OspAdj],
        rows: list[OspEdgeRow],
        free_rows: list[int],
        row_of: dict[int, int],
        dead: dict[int, int],
        regions: dict[int, list[int]],
        index_at: int = 8,
        tags_out: dict[int, dict[int, list[int]]] = {},
        tags_in: dict[int, dict[int, list[int]]] = {},
        holes_out: dict[int, int] = {},
        holes_in: dict[int, int] = {};

    def adj_of(h: int) -> OspAdj {
        if h in self.adj {
            found: OspAdj = self.adj[h];
            return found;
        }
        made = OspAdj(rows_out=[], rows_in=[], out={}, inn={});
        self.adj[h] = made;
        return made;
    }

    def has_light(h: int) -> bool {
        if h not in self.adj {
            return False;
        }
        a: OspAdj = self.adj[h];
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
        sa: OspAdj = self.adj_of(src);
        ta: OspAdj = self.adj_of(tgt);
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
        sa: OspAdj = self.adj[src];
        if tag not in sa.out {
            return False;
        }
        outs: list[int] = sa.out[tag];
        if not self._drop_handle(outs, tgt) {
            return False;
        }
        if tgt in self.adj {
            ta: OspAdj = self.adj[tgt];
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
        a: OspAdj = self.adj[h];
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
        a: OspAdj = self.adj[h];
        n = 0;
        for k in a.out {
            peers: list[int] = a.out[k];
            for p in peers {
                if p in self.adj {
                    pa: OspAdj = self.adj[p];
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
                    sa: OspAdj = self.adj[s];
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
            row: OspEdgeRow = self.rows[rid];
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
            OspEdgeRow(src=src, tgt=tgt, tag=tag, handle=eobj, undirected=undirected)
        );
        self.row_of[eobj] = rid;
        return rid;
    }

    def _row_retire(rid: int) {
        row: OspEdgeRow = self.rows[rid];
        if row.handle in self.row_of {
            del self.row_of[row.handle];
        }
        row.live = False;
        row.handle = 0;
        row.pos_out = -1;
        row.pos_in = -1;
        self.free_rows.append(rid);
    }

    def _compact(lst: list[int], outgoing: bool) {
        j = 0;
        n = len(lst);
        i = 0;
        while i < n {
            rid: int = lst[i];
            if rid >= 0 {
                if j != i {
                    lst[j] = rid;
                    row: OspEdgeRow = self.rows[rid];
                    if outgoing {
                        row.pos_out = j;
                    } else {
                        row.pos_in = j;
                    }
                }
                j += 1;
            }
            i += 1;
        }
        while len(lst) > j {
            lst.pop();
        }
    }

    def _slot_clear(
        lst: list[int], pos: int, rid: int, holes: int, outgoing: bool
    ) -> int {
        n = len(lst);
        if pos < 0 or pos >= n or lst[pos] != rid {
            return holes;
        }
        if pos == n - 1 {
            lst.pop();
            while lst and lst[len(lst) - 1] < 0 {
                lst.pop();
                holes -= 1;
            }
            return holes;
        }
        lst[pos] = -1;
        holes += 1;
        if holes * 2 > len(lst) {
            self._compact(lst, outgoing);
            return 0;
        }
        return holes;
    }

    def _tag_drop(d: dict[int, list[int]], rid: int, outgoing: bool) {
        row: OspEdgeRow = self.rows[rid];
        tag = row.tag;
        if tag not in d {
            return;
        }
        tl: list[int] = d[tag];
        key = row.pos_out if outgoing else row.pos_in;
        lo = 0;
        hi = len(tl);
        while lo < hi {
            mid = (lo + hi) // 2;
            m: OspEdgeRow = self.rows[tl[mid]];
            if (m.pos_out if outgoing else m.pos_in) < key {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if lo < len(tl) and tl[lo] == rid {
            tl.pop(lo);
        }
        if not tl {
            del d[tag];
        }
    }

    def _drop_side(h: int, a: OspAdj, rid: int, outgoing: bool) {
        lst: list[int] = a.rows_out if outgoing else a.rows_in;
        tags: dict[int, dict[int, list[int]]] = self.tags_out
            if outgoing
            else self.tags_in;
        if h not in tags {
            i = 0;
            n = len(lst);
            while i < n {
                if lst[i] == rid {
                    lst.pop(i);
                    return;
                }
                i += 1;
            }
            return;
        }
        row: OspEdgeRow = self.rows[rid];
        d: dict[int, list[int]] = tags[h];
        self._tag_drop(d, rid, outgoing);
        holes_of: dict[int, int] = self.holes_out if outgoing else self.holes_in;
        holes = self._slot_clear(
            lst,
            row.pos_out if outgoing else row.pos_in,
            rid,
            holes_of.get(h, 0),
            outgoing
        );
        if d and holes > 0 {
            holes_of[h] = holes;
        } elif h in holes_of {
            del holes_of[h];
        }
        if not d {
            del tags[h];
        }
    }

    def _add_side(h: int, a: OspAdj, rid: int, tag: int, outgoing: bool) {
        lst: list[int] = a.rows_out if outgoing else a.rows_in;
        tags: dict[int, dict[int, list[int]]] = self.tags_out
            if outgoing
            else self.tags_in;
        row: OspEdgeRow = self.rows[rid];
        if outgoing {
            row.pos_out = len(lst);
        } else {
            row.pos_in = len(lst);
        }
        lst.append(rid);
        if h in tags {
            d: dict[int, list[int]] = tags[h];
            if tag in d {
                tl: list[int] = d[tag];
                tl.append(rid);
            } else {
                d[tag] = [rid];
            }
        } elif len(lst) > self.index_at {
            self._build_index(h, lst, outgoing);
        }
    }

    def _live_rows(h: int, a: OspAdj, outgoing: bool) -> int {
        if outgoing {
            return len(a.rows_out) - self.holes_out.get(h, 0);
        }
        return len(a.rows_in) - self.holes_in.get(h, 0);
    }

    def region_reg(h: int, rgn: int) {
        if rgn in self.regions {
            members: list[int] = self.regions[rgn];
            members.append(h);
        } else {
            self.regions[rgn] = [h];
        }
    }

    def _no_rows(h: int, a: OspAdj) -> bool {
        return self._live_rows(h, a, True) == 0 and self._live_rows(h, a, False) == 0;
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
        sa: OspAdj = self.adj_of(src);
        ta: OspAdj = self.adj_of(tgt);
        if rgn_src != 0 and self._no_rows(src, sa) {
            self.region_reg(src, rgn_src);
        }
        if rgn_tgt != 0 and tgt != src and self._no_rows(tgt, ta) {
            self.region_reg(tgt, rgn_tgt);
        }
        rid: int = self._row_alloc(src, tgt, tag, eobj, undirected);
        self._add_side(src, sa, rid, tag, True);
        self._add_side(tgt, ta, rid, tag, False);
        return tgt;
    }

    def _build_index(h: int, lst: list[int], outgoing: bool) {
        d: dict[int, list[int]] = {};
        i = 0;
        n = len(lst);
        while i < n {
            rid: int = lst[i];
            row: OspEdgeRow = self.rows[rid];
            if outgoing {
                row.pos_out = i;
            } else {
                row.pos_in = i;
            }
            tag = row.tag;
            if tag in d {
                tl: list[int] = d[tag];
                tl.append(rid);
            } else {
                d[tag] = [rid];
            }
            i += 1;
        }
        if outgoing {
            self.tags_out[h] = d;
        } else {
            self.tags_in[h] = d;
        }
    }

    def _narrowed(h: int, outgoing: bool, want: int) -> bool {
        if want == -1 {
            return True;
        }
        return h in (self.tags_out if outgoing else self.tags_in);
    }

    def _tag_matches(tag: int, want: int) -> bool {
        if want == -1 or tag == want {
            return True;
        }
        return osp_is_a(tag, want);
    }

    def _rows_for(h: int, a: OspAdj, outgoing: bool, want: int) -> list[int] {
        if not self._narrowed(h, outgoing, want) or want == -1 {
            return a.rows_out if outgoing else a.rows_in;
        }
        tags: dict[int, dict[int, list[int]]] = self.tags_out
            if outgoing
            else self.tags_in;
        d: dict[int, list[int]] = tags[h];
        if want not in _has_subs {
            if want in d {
                exact: list[int] = d[want];
                return exact;
            }
            return _NO_ROWS;
        }
        hits: list[list[int]] = [];
        for k in d {
            if k == want or osp_is_a(k, want) {
                hits.append(d[k]);
            }
        }
        if not hits {
            return _NO_ROWS;
        }
        if len(hits) == 1 {
            only: list[int] = hits[0];
            return only;
        }
        slots: list[int] = [];
        for lst in hits {
            for rid in lst {
                if rid >= 0 {
                    row: OspEdgeRow = self.rows[rid];
                    slots.append(row.pos_out if outgoing else row.pos_in);
                }
            }
        }
        slots.sort();
        all_rows: list[int] = a.rows_out if outgoing else a.rows_in;
        merged: list[int] = [];
        for p in slots {
            merged.append(all_rows[p]);
        }
        return merged;
    }

    def _collect(
        origin: int, dir: int, edge_tag: int, edges_only: bool, out: list[int]
    ) {
        if origin not in self.adj or origin in self.dead {
            return;
        }
        a: OspAdj = self.adj[origin];
        out_ok = dir == 2 or dir == 3;
        in_ok = dir == 1 or dir == 3;
        nar = self._narrowed(origin, True, edge_tag);
        for rid in self._rows_for(origin, a, True, edge_tag) {
            if rid < 0 {
                continue;
            }
            row: OspEdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            if (out_ok or row.undirected)
                and (nar or self._tag_matches(row.tag, edge_tag)) {
                o: int = row.handle if edges_only else row.tgt;
                out.append(o);
            }
        }
        nar = self._narrowed(origin, False, edge_tag);
        for rid in self._rows_for(origin, a, False, edge_tag) {
            if rid < 0 {
                continue;
            }
            row: OspEdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            if (in_ok or row.undirected)
                and (nar or self._tag_matches(row.tag, edge_tag)) {
                o: int = row.handle if edges_only else row.src;
                out.append(o);
            }
        }
        if edges_only {
            return;
        }
        if out_ok {
            for k in a.out {
                if self._tag_matches(k, edge_tag) {
                    peers: list[int] = a.out[k];
                    for p in peers {
                        out.append(p);
                    }
                }
            }
        }
        if in_ok {
            for k in a.inn {
                if self._tag_matches(k, edge_tag) {
                    srcs: list[int] = a.inn[k];
                    for s in srcs {
                        out.append(s);
                    }
                }
            }
        }
    }

    def _dedup_tail(out: list[int], start: int, seen: set[int]) {
        j = start;
        i = start;
        n = len(out);
        while i < n {
            v: int = out[i];
            if v not in seen {
                seen.add(v);
                out[j] = v;
                j += 1;
            }
            i += 1;
        }
        while len(out) > j {
            out.pop();
        }
    }

    def refs_into(
        origin: int,
        dir: int,
        edge_tag: int,
        edges_only: bool,
        out: list[int],
        seen: set[int]
    ) {
        start = len(out);
        self._collect(origin, dir, edge_tag, edges_only, out);
        self._dedup_tail(out, start, seen);
    }

    def refs(origin: int, dir: int, edge_tag: int, edges_only: bool) -> list[int] {
        out: list[int] = [];
        self._collect(origin, dir, edge_tag, edges_only, out);
        n = len(out);
        if n < 2 {
            return out;
        }
        if n > 16 {
            seen: set[int] = set();
            self._dedup_tail(out, 0, seen);
            return out;
        }
        j = 0;
        i = 0;
        while i < n {
            v: int = out[i];
            k = 0;
            while k < j and out[k] != v {
                k += 1;
            }
            if k == j {
                out[j] = v;
                j += 1;
            }
            i += 1;
        }
        while len(out) > j {
            out.pop();
        }
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
        out_ok = dir == 2 or dir == 3;
        in_ok = dir == 1 or dir == 3;
        for origin in origins {
            if origin not in self.adj or origin in self.dead {
                continue;
            }
            a: OspAdj = self.adj[origin];
            nar = self._narrowed(origin, True, edge_tag);
            for rid in self._rows_for(origin, a, True, edge_tag) {
                if rid < 0 {
                    continue;
                }
                row: OspEdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                if (out_ok or row.undirected)
                    and (nar or self._tag_matches(row.tag, edge_tag))
                    and pred(row.handle) {
                    o: int = row.handle if edges_only else row.tgt;
                    if o not in seen {
                        seen.add(o);
                        out.append(o);
                    }
                }
            }
            nar = self._narrowed(origin, False, edge_tag);
            for rid in self._rows_for(origin, a, False, edge_tag) {
                if rid < 0 {
                    continue;
                }
                row: OspEdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                if (in_ok or row.undirected)
                    and (nar or self._tag_matches(row.tag, edge_tag))
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
        row: OspEdgeRow = self.rows[rid];
        if not row.live {
            return -1;
        }
        if row.src == origin {
            return row.tgt;
        }
        if row.tgt == origin {
            return row.src;
        }
        return -1;
    }

    def _unlink(rid: int) {
        row: OspEdgeRow = self.rows[rid];
        if row.src in self.adj {
            sa: OspAdj = self.adj[row.src];
            self._drop_side(row.src, sa, rid, True);
        }
        if row.tgt in self.adj {
            ta: OspAdj = self.adj[row.tgt];
            self._drop_side(row.tgt, ta, rid, False);
        }
    }

    def disconnect(eobj: int) -> bool {
        if eobj not in self.row_of {
            return False;
        }
        rid: int = self.row_of[eobj];
        row: OspEdgeRow = self.rows[rid];
        if not row.live {
            return False;
        }
        self._unlink(rid);
        self._row_retire(rid);
        return True;
    }

    def _between_hits(
        from_h: int,
        to_h: int,
        edge_tag: int,
        any_row: bool,
        hits: list[int],
        hit_set: set[int]
    ) {
        if from_h not in self.adj {
            return;
        }
        fa: OspAdj = self.adj[from_h];
        cand = self._rows_for(from_h, fa, True, edge_tag);
        nar = self._narrowed(from_h, True, edge_tag);
        if to_h in self.adj {
            ta: OspAdj = self.adj[to_h];
            other = self._rows_for(to_h, ta, False, edge_tag);
            if len(other) < len(cand) {
                cand = other;
                nar = self._narrowed(to_h, False, edge_tag);
            }
        }
        for rid in cand {
            if rid < 0 {
                continue;
            }
            row: OspEdgeRow = self.rows[rid];
            if not row.live {
                continue;
            }
            if row.src == from_h
                and row.tgt == to_h
                and (any_row or row.undirected)
                and (nar or self._tag_matches(row.tag, edge_tag)) {
                if rid not in hit_set {
                    hit_set.add(rid);
                    hits.append(rid);
                }
            }
        }
    }

    def disconnect_between(src: int, tgt: int, dir: int, edge_tag: int) -> int {
        if src not in self.adj {
            return 0;
        }
        hits: list[int] = [];
        hit_set: set[int] = set();
        self._between_hits(src, tgt, edge_tag, dir == 2 or dir == 3, hits, hit_set);
        self._between_hits(tgt, src, edge_tag, dir == 1 or dir == 3, hits, hit_set);
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
        cands: list[int] = [];
        hit_set: set[int] = set();
        self._between_hits(src, tgt, edge_tag, dir == 2 or dir == 3, cands, hit_set);
        self._between_hits(tgt, src, edge_tag, dir == 1 or dir == 3, cands, hit_set);
        hits: list[int] = [];
        for rid in cands {
            row: OspEdgeRow = self.rows[rid];
            if pred(row.handle) {
                hits.append(rid);
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
        a: OspAdj = self.adj[src];
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
        a: OspAdj = self.adj[h];
        gone: list[int] = [];
        for rid in a.rows_out {
            if rid < 0 {
                continue;
            }
            row: OspEdgeRow = self.rows[rid];
            if row.live {
                gone.append(rid);
            }
        }
        for rid in a.rows_in {
            if rid < 0 {
                continue;
            }
            row: OspEdgeRow = self.rows[rid];
            if row.live {
                gone.append(rid);
            }
        }
        n = n0;
        for rid in gone {
            row: OspEdgeRow = self.rows[rid];
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

    def _forget_index(h: int) {
        if h in self.tags_out {
            del self.tags_out[h];
        }
        if h in self.tags_in {
            del self.tags_in[h];
        }
        if h in self.holes_out {
            del self.holes_out[h];
        }
        if h in self.holes_in {
            del self.holes_in[h];
        }
    }

    def drop_node(h: int) -> int {
        n = self.node_destroy(h);
        self._forget_index(h);
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
        stash: list[OspAdj] = [];
        for h in members {
            if h in self.adj {
                self.light_detach(h);
                a: OspAdj = self.adj[h];
                stash.append(a);
                self.adj.pop(h);
            }
            self._forget_index(h);
            if h in self.dead {
                self.dead.pop(h);
            }
        }
        n = 0;
        for a in stash {
            for rid in a.rows_out {
                if rid < 0 {
                    continue;
                }
                row: OspEdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                if row.tgt in self.adj {
                    ta: OspAdj = self.adj[row.tgt];
                    self._drop_side(row.tgt, ta, rid, False);
                }
                self._row_retire(rid);
                n += 1;
            }
            for rid in a.rows_in {
                if rid < 0 {
                    continue;
                }
                row: OspEdgeRow = self.rows[rid];
                if not row.live {
                    continue;
                }
                if row.src in self.adj {
                    sa: OspAdj = self.adj[row.src];
                    self._drop_side(row.src, sa, rid, True);
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
        a: OspAdj = DEFAULT_GRAPH.adj[origin];
        if dir == 2 {
            for rid in a.rows_out {
                if rid < 0 {
                    continue;
                }
                row: OspEdgeRow = DEFAULT_GRAPH.rows[rid];
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
                if rid < 0 {
                    continue;
                }
                row: OspEdgeRow = DEFAULT_GRAPH.rows[rid];
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
