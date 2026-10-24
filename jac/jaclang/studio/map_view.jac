import from jaclang.osprey.ui.cells { StyleAttrs, TextSpan }
import from jaclang.osprey.ui.width { display_width }

glob MAP_VIEWS: list[str] = [
         "matrix",
         "layers",
         "issues",
         "roles",
         "iface",
         "rules",
         "clusters"
     ],
     LIST_VIEWS: list[str] = ["issues", "roles", "iface", "rules", "clusters"],
     ITEM_HINTS: dict[str, str] = {
         "violation": " Enter lists the wires · Space adds them to the context",
         "back": " Enter lists the wires · Space adds them to the context",
         "cycle": " Enter shows the cycle in the layers view · Space adds this level to the context",
         "module": " Enter shows its wiring · s slice · b blast radius · Space adds it to the context",
         "export": " Enter shows the blast radius of this name · Space adds its module to the context",
         "import": " Enter shows the provider's wiring · Space adds it to the context",
         "group": " Enter opens that package in the map",
         "rule": " Enter lists the wires the rule admits",
         "arm": " Enter lists the wires that use this permission",
         "wire": " Enter shows the wire in the wiring view · Space adds it to the context",
         "cluster": " Enter maps just this cluster's modules (x clears)",
         "split": " Enter opens the package in the map",
         "hint": ""
     },
     DETAIL_LINES: int = 4,
     GUTTER: int = 4,
     C_FEEDS_IT: int = 179,
     C_IT_FEEDS: int = 117,
     C_BACK: int = 203,
     C_CYCLE: int = 176,
     C_BOX: int = 237,
     C_CROSS: int = 236;

obj MapItem {
    has kind: str,
        label: str,
        detail: str = "",
        src: str = "",
        dst: str = "",
        key: str = "",
        section: str = "";
}

obj MapState {
    has scope: str = "",
        level: (GraphLevel | None) = None,
        sig: tuple[int, int, int] = (0, 0, 0),
        view: str = "matrix",
        r: int = 0,
        c: int = 0,
        top: int = 0,
        left: int = 0,
        sel: int = 0,
        item: int = 0,
        scroll: int = 0,
        width: int = 80,
        only: (set[str] | None) = None,
        only_label: str = "",
        only_spec: str = "",
        data: dict[str, any] = {};

    def selected_node -> (GraphNode | None);
    def selected_item -> (MapItem | None);
    def group_key -> str;
    def selected_edge -> (GraphEdge | None);
    def select_key(key: str) -> None;
    def set_view(view: str) -> None;
}

def crumbs(scope: str) -> str;

def view_tabs(view: str) -> str;

def node_token(nd: GraphNode) -> str;

def issue_items(level: GraphLevel) -> list[MapItem];

def view_items(state: MapState, lvl: GraphLevel) -> list[MapItem];

def roles_items(
    rep: RolesReport, scope: str, only: (set[str] | None)
) -> list[MapItem];

def iface_items(rep: InterfaceReport) -> list[MapItem];

def rules_items(rep: IntentReport) -> list[MapItem];

def clusters_items(rep: ClusterReport) -> list[MapItem];

def short_key(key: str, scope: str) -> str;

def map_move(state: MapState, key: str) -> bool;

def map_lines(state: MapState, w: int, h: int, focused: bool) -> list[list[TextSpan]];

def matrix_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]];

def layer_layout(
    level: GraphLevel, w: int, spaced: bool
) -> tuple[list[tuple[int, int, int, int]], int];

def layers_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]];

def list_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]];

def node_detail(level: GraphLevel, nd: GraphNode, w: int) -> list[list[TextSpan]];

def edge_detail(level: GraphLevel, e: GraphEdge, w: int) -> list[list[TextSpan]];

def chip_line(
    head: str, chips: list[tuple[str, StyleAttrs]], w: int
) -> list[TextSpan];

def neighbour_style(level: GraphLevel, sel: GraphNode, nd: GraphNode) -> StyleAttrs;

impl MapState.selected_node -> (GraphNode | None) {
    lvl = self.level;
    if lvl is None or not lvl.nodes {
        return None;
    }
    if self.view == "matrix" {
        return lvl.nodes[self.r] if self.r == self.c else None;
    }
    if self.view == "layers" {
        return lvl.nodes[min(self.sel, len(lvl.nodes) - 1)];
    }
    return None;
}

impl MapState.selected_item -> (MapItem | None) {
    lvl = self.level;
    if lvl is None or self.view not in LIST_VIEWS {
        return None;
    }
    items = view_items(self, lvl);
    return items[self.item] if 0 <= self.item < len(items) else None;
}

impl MapState.group_key -> str {
    lvl = self.level;
    if lvl is None or not lvl.nodes {
        return self.scope;
    }
    i = self.r if self.view == "matrix" else self.sel;
    return lvl.nodes[min(max(i, 0), len(lvl.nodes) - 1)].key;
}

impl MapState.selected_edge -> (GraphEdge | None) {
    lvl = self.level;
    if lvl is None or not lvl.nodes {
        return None;
    }
    if self.view == "matrix" and self.r != self.c {
        return lvl.edge_of(lvl.nodes[self.r].key, lvl.nodes[self.c].key);
    }
    if self.view == "issues" {
        items = issue_items(lvl);
        if 0 <= self.item < len(items) and items[self.item].kind != "cycle" {
            return lvl.edge_of(items[self.item].src, items[self.item].dst);
        }
    }
    return None;
}

impl MapState.select_key(key: str) -> None {
    lvl = self.level;
    if lvl is None {
        return;
    }
    i = lvl.index.get(key, -1);
    if i < 0 {
        return;
    }
    (self.r, self.c, self.sel) = (i, i, i);
}

impl MapState.set_view(view: str) -> None {
    if view == self.view {
        return;
    }
    if self.view == "matrix" {
        self.sel = self.r;
    } elif self.view == "layers" {
        (self.r, self.c) = (self.sel, self.sel);
    }
    self.view = view;
    self.scroll = 0;
    self.item = 0;
}

impl crumbs(scope: str) -> str {
    return " ▸ ".join(scope.split(".")) if scope else "project";
}

impl view_tabs(view: str) -> str {
    return " ".join([(f"[{v}]" if v == view else v) for v in MAP_VIEWS]) + "  v";
}

impl node_token(nd: GraphNode) -> str {
    mark = "↻" if nd.cycle >= 0 else "";
    slash = "/" if nd.kind == "package" else "";
    return f" {mark}{nd.label}{slash} {nd.modules} ";
}

impl issue_items(level: GraphLevel) -> list[MapItem] {
    items: list[MapItem] = [];
    def name(key: str) -> str {
        nd = level.node_of(key);
        return nd.label if nd is not None else key;
    }
    bad = [
        e
        for e in level.edges.values()
        if e.violations
    ];
    bad.sort(key=GraphEdge.count, reverse=True);
    for e in bad {
        items.append(
            MapItem(
                kind="violation",
                label=f"{name(e.src)} → {name(e.dst)}",
                detail=f"{e.violations} of {e.count()} wire(s) break a rule",
                src=e.src,
                dst=e.dst
            )
        );
    }
    for e in level.back_edges() {
        a = level.node_of(e.src);
        b = level.node_of(e.dst);
        where = f"L{a.layer} feeds L{b.layer}"
            if a is not None and b is not None
            else "";
        items.append(
            MapItem(
                kind="back",
                label=f"{name(e.src)} → {name(e.dst)}",
                detail=f"{e.count()} wire(s), {where}",
                src=e.src,
                dst=e.dst
            )
        );
    }
    for (ci, comp) in enumerate(level.cycles) {
        items.append(
            MapItem(
                kind="cycle",
                label=f"cycle {ci + 1}: {len(comp)} groups",
                detail=", ".join([name(g) for g in comp]),
                src=comp[0]
            )
        );
    }
    return items;
}

impl map_move(state: MapState, key: str) -> bool {
    lvl = state.level;
    if lvl is None or not lvl.nodes {
        return False;
    }
    n = len(lvl.nodes);
    if state.view == "matrix" {
        if key in ["up", "k"] {
            state.r = max(0, state.r - 1);
        } elif key in ["down", "j"] {
            state.r = min(n - 1, state.r + 1);
        } elif key in ["left", "h"] {
            state.c = max(0, state.c - 1);
        } elif key in ["right", "l"] {
            state.c = min(n - 1, state.c + 1);
        } elif key == "page_down" {
            state.r = min(n - 1, state.r + 10);
        } elif key == "page_up" {
            state.r = max(0, state.r - 10);
        } elif key in ["home", "g"] {
            (state.r, state.c) = (0, 0);
        } elif key in ["end", "G"] {
            (state.r, state.c) = (n - 1, n - 1);
        } elif key == "d" {
            state.c = state.r;
        } elif key == "t" {
            (state.r, state.c) = (state.c, state.r);
        } else {
            return False;
        }
        return True;
    }
    if state.view == "layers" {
        (boxes, _) = layer_layout(lvl, state.width, False);
        pos = 0;
        for (bi, b) in enumerate(boxes) {
            if b[0] == state.sel {
                pos = bi;
            }
        }
        if not boxes {
            return False;
        }
        if key in ["left", "h"] {
            pos = max(0, pos - 1);
        } elif key in ["right", "l"] {
            pos = min(len(boxes) - 1, pos + 1);
        } elif key in ["up", "k", "down", "j"] {
            step = -1 if key in ["up", "k"] else 1;
            here = boxes[pos];
            mid = (here[2] + here[3]) // 2;
            line = here[1] + step;
            best = -1;
            while best < 0 and 0 <= line <= boxes[-1][1] {
                gap = 10 ** 6;
                for (bi, b) in enumerate(boxes) {
                    if b[1] == line {
                        d = abs((b[2] + b[3]) // 2 - mid);
                        if d < gap {
                            (gap, best) = (d, bi);
                        }
                    }
                }
                line += step;
            }
            if best >= 0 {
                pos = best;
            }
        } elif key in ["home", "g"] {
            pos = 0;
        } elif key in ["end", "G"] {
            pos = len(boxes) - 1;
        } else {
            return False;
        }
        state.sel = boxes[pos][0];
        return True;
    }
    if state.view == "iface" and key in ["left", "h", "right", "l"] {
        step = -1 if key in ["left", "h"] else 1;
        state.sel = (state.sel + step) % n;
        (state.r, state.c, state.item, state.scroll) = (state.sel, state.sel, 0, 0);
        return True;
    }
    total = len(view_items(state, lvl));
    if key in ["up", "k"] {
        state.item = max(0, state.item - 1);
    } elif key in ["down", "j"] {
        state.item = min(max(total - 1, 0), state.item + 1);
    } elif key == "page_down" {
        state.item = min(max(total - 1, 0), state.item + 10);
    } elif key == "page_up" {
        state.item = max(0, state.item - 10);
    } elif key in ["home", "g"] {
        state.item = 0;
    } elif key in ["end", "G"] {
        state.item = max(total - 1, 0);
    } else {
        return False;
    }
    return True;
}

impl map_lines(state: MapState, w: int, h: int, focused: bool) -> list[list[TextSpan]] {
    state.width = w;
    lvl = state.level;
    if lvl is None or not lvl.nodes {
        out = [
            plain(
                "  No wired modules here. The map shows modules that archwire.jac covers.",
                w,
                THEME.dim
            )
        ];
        while len(out) < h {
            out.append(blank(w));
        }
        return out;
    }
    if state.view == "layers" {
        return layers_lines(state, lvl, w, h, focused);
    }
    if state.view in LIST_VIEWS {
        return list_lines(state, lvl, w, h, focused);
    }
    return matrix_lines(state, lvl, w, h, focused);
}

impl matrix_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]] {
    nodes = lvl.nodes;
    n = len(nodes);
    state.r = min(state.r, n - 1);
    state.c = min(state.c, n - 1);
    top_count = 0;
    for e in lvl.edges.values() {
        top_count = max(top_count, e.count());
    }
    cw = max(len(str(top_count)), len(str(n)), 2) + 1;
    lw = 4;
    for nd in nodes {
        lw = max(lw, display_width(nd.label) + (2 if nd.kind == "package" else 1));
    }
    lw = min(lw, 24, max(w // 3, 8));
    pre = 4 + 1 + lw + 1;
    vis_c = max(1, (w - pre) // cw);
    body = max(1, h - 2 - DETAIL_LINES);
    if state.r < state.top {
        state.top = state.r;
    }
    if state.r >= state.top + body {
        state.top = state.r - body + 1;
    }
    if state.c < state.left {
        state.left = state.c;
    }
    if state.c >= state.left + vis_c {
        state.left = state.c - vis_c + 1;
    }
    cols = range(state.left, min(n, state.left + vis_c));
    head: list[TextSpan] = [sp(" " * pre, None)];
    for j in cols {
        a = THEME.accent if j == state.c else THEME.faint;
        head.append(sp(str(j + 1).rjust(cw), a));
    }
    out = [fit(head, w, None)];
    for i in range(state.top, min(n, state.top + body)) {
        nd = nodes[i];
        on_row = i == state.r;
        label = nd.label + ("/" if nd.kind == "package" else "");
        if display_width(label) > lw - 1 {
            label = label[:lw - 2] + "…";
        }
        row: list[TextSpan] = [
            sp(f"{i + 1:>3} ", THEME.accent if on_row else THEME.faint),
            sp("↻" if nd.cycle >= 0 else " ", StyleAttrs(fg=C_CYCLE)),
            sp(
                label.ljust(lw),
                StyleAttrs(fg=255, bold=True) if on_row else kind_attrs(nd.kind)
            ),
            sp(" ", None)
        ];
        for j in cols {
            if i == j {
                text = "·";
                a = THEME.faint;
            } else {
                e = lvl.edge_of(nd.key, nodes[j].key);
                text = str(e.count()) if e is not None else "";
                a = THEME.text;
                if e is not None and e.violations {
                    a = StyleAttrs(fg=C_BACK, bold=True);
                } elif e is not None and e.back {
                    a = THEME.warn;
                }
            }
            bg: (int | None) = None;
            if i == state.r and j == state.c {
                bg = C_SEL_FOCUS if focused else C_SEL;
            } elif on_row or j == state.c {
                bg = C_CROSS;
            }
            row.append(sp(text.rjust(cw), with_bg(a, bg) if bg is not None else a));
        }
        out.append(fit(row, w, None));
    }
    while len(out) < h - DETAIL_LINES - 1 {
        out.append(blank(w));
    }
    out.append(fit([sp("─" * w, THEME.faint)], w, None));
    nd_sel = state.selected_node();
    e_sel = state.selected_edge();
    if nd_sel is not None {
        detail = node_detail(lvl, nd_sel, w);
    } elif e_sel is not None {
        detail = edge_detail(lvl, e_sel, w);
    } else {
        row_name = nodes[state.r].label;
        col_name = nodes[state.c].label;
        detail = [
            plain(f" {row_name} does not feed {col_name}.", w, THEME.dim),
            plain(
                " d jumps to the diagonal, t swaps the row and column.", w, THEME.faint
            )
        ];
    }
    out += detail[:DETAIL_LINES];
    while len(out) < h {
        out.append(blank(w));
    }
    return out[:h];
}

impl layer_layout(
    level: GraphLevel, w: int, spaced: bool
) -> tuple[list[tuple[int, int, int, int]], int] {
    boxes: list[tuple[int, int, int, int]] = [];
    line = 0;
    for (li, band) in enumerate(level.layers()) {
        if not band {
            continue;
        }
        if li > 0 and spaced {
            line += 1;
        }
        x = GUTTER;
        for nd in band {
            tw = display_width(node_token(nd));
            if x + tw > w and x > GUTTER {
                line += 1;
                x = GUTTER;
            }
            boxes.append((level.index[nd.key], line, x, x + tw));
            x += tw + 1;
        }
        line += 1;
    }
    return (boxes, line);
}

impl neighbour_style(level: GraphLevel, sel: GraphNode, nd: GraphNode) -> StyleAttrs {
    feeds_it = level.edge_of(nd.key, sel.key);
    it_feeds = level.edge_of(sel.key, nd.key);
    if feeds_it is not None and not feeds_it.back {
        return StyleAttrs(fg=C_FEEDS_IT, bg=C_BOX, bold=True);
    }
    if it_feeds is not None and not it_feeds.back {
        return StyleAttrs(fg=C_IT_FEEDS, bg=C_BOX, bold=True);
    }
    if feeds_it is not None or it_feeds is not None {
        return StyleAttrs(fg=C_BACK, bg=C_BOX, bold=True);
    }
    if sel.cycle >= 0 and nd.cycle == sel.cycle {
        return StyleAttrs(fg=C_CYCLE, bg=C_BOX);
    }
    return StyleAttrs(fg=C_DIM, bg=C_BOX);
}

impl layers_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]] {
    n = len(lvl.nodes);
    state.sel = min(state.sel, n - 1);
    sel = lvl.nodes[state.sel];
    body = max(1, h - 2 - DETAIL_LINES);
    (boxes, total) = layer_layout(lvl, w, False);
    spaced = total * 2 - 1 <= body;
    if spaced {
        (boxes, total) = layer_layout(lvl, w, True);
    }
    rows: list[list[TextSpan]] = [];
    for i in range(total) {
        rows.append([]);
    }
    xs: list[int] = [0] * total;
    sel_line = 0;
    band_first: dict[int, int] = {};
    for (idx, line, x0, x1) in boxes {
        nd = lvl.nodes[idx];
        if nd.layer not in band_first {
            band_first[nd.layer] = line;
        }
        if xs[line] == 0 {
            gut = f"L{nd.layer}" if band_first[nd.layer] == line else "";
            rows[line].append(sp(gut.ljust(GUTTER), THEME.faint));
            xs[line] = GUTTER;
        }
        if x0 > xs[line] {
            rows[line].append(sp(" " * (x0 - xs[line]), None));
        }
        if idx == state.sel {
            a = StyleAttrs(fg=255, bg=C_SEL_FOCUS if focused else C_SEL, bold=True);
            sel_line = line;
        } else {
            a = neighbour_style(lvl, sel, nd);
        }
        rows[line].append(sp(node_token(nd), a));
        xs[line] = x1;
    }
    if spaced {
        for i in range(total) {
            if not rows[i] {
                rows[i] = [sp("  ┆", THEME.faint)];
            }
        }
    }
    if sel_line < state.scroll {
        state.scroll = sel_line;
    }
    if sel_line >= state.scroll + body {
        state.scroll = sel_line - body + 1;
    }
    out: list[list[TextSpan]] = [];
    for i in range(state.scroll, min(total, state.scroll + body)) {
        out.append(fit(rows[i], w, None));
    }
    while len(out) < h - DETAIL_LINES - 1 {
        out.append(blank(w));
    }
    legend = [
        sp("─ ", THEME.faint),
        sp("feeds it", StyleAttrs(fg=C_FEEDS_IT)),
        sp(" · ", THEME.faint),
        sp("it feeds", StyleAttrs(fg=C_IT_FEEDS)),
        sp(" · ", THEME.faint),
        sp("only backward", StyleAttrs(fg=C_BACK)),
        sp(" · ", THEME.faint),
        sp("↻ same cycle", StyleAttrs(fg=C_CYCLE)),
        sp(" ", THEME.faint)
    ];
    used = sum([display_width(s.text) for s in legend]);
    legend.append(sp("─" * max(0, w - used), THEME.faint));
    out.append(fit(legend, w, None));
    out += node_detail(lvl, sel, w)[:DETAIL_LINES];
    while len(out) < h {
        out.append(blank(w));
    }
    return out[:h];
}

impl short_key(key: str, scope: str) -> str {
    return key[len(scope) + 1:] if scope and key.startswith(scope + ".") else key;
}

impl view_items(state: MapState, lvl: GraphLevel) -> list[MapItem] {
    if state.view == "issues" {
        heads = {
            "violation": "Rule violations: wires an archwire rule does not admit",
            "back": f"Backward wires: {lvl.back_wires} of {lvl.wires} run from a later group to an earlier one",
            "cycle": "Cycles: groups that reach each other through wires"
        };
        items = issue_items(lvl);
        for it in items {
            it.section = heads[it.kind];
        }
        return items;
    }
    held = state.data.get(state.view);
    if held is None {
        return [];
    }
    found = held[1];
    if state.view == "roles" {
        return roles_items(found, lvl.scope, state.only);
    }
    if state.view == "iface" {
        return iface_items(found);
    }
    if state.view == "rules" {
        return rules_items(found);
    }
    if state.view == "clusters" {
        return clusters_items(found);
    }
    return [];
}

impl roles_items(
    rep: RolesReport, scope: str, only: (set[str] | None)
) -> list[MapItem] {
    items: list[MapItem] = [];
    for role in ROLE_ORDER {
        group = [
            r
            for r in rep.by_role(role)
            if only is None or r.key in only
        ];
        if not group {
            continue;
        }
        for r in group {
            items.append(
                MapItem(
                    kind="module",
                    label=short_key(r.key, scope),
                    detail=f"feeds {r.consumers} · fed by {r.providers} · {r.names_out} name(s) out",
                    key=r.key,
                    section=f"{role} ({len(group)}): {ROLE_TEXT[role]}"
                )
            );
        }
    }
    return items;
}

impl iface_items(rep: InterfaceReport) -> list[MapItem] {
    items: list[MapItem] = [];
    about = f"Interface of {rep.key}   ← → another group";
    for h in rep.hints {
        items.append(MapItem(kind="hint", label=h, section=about));
    }
    if not rep.hints {
        items.append(
            MapItem(
                kind="hint",
                label=f"{len(rep.exports)} name(s) leave over {rep.out_wires} wire(s); {len(
                    rep.imports
                )} enter over {rep.in_wires}",
                section=about
            )
        );
    }
    head = f"Exports: {len(rep.exports)} name(s) leave over {rep.out_wires} wire(s)";
    for c in rep.exports {
        users = ", ".join([u.rsplit(".", 1)[-1] for u in c.others[:4]]);
        more = f" +{len(c.others) - 4}" if len(c.others) > 4 else "";
        items.append(
            MapItem(
                kind="export",
                label=f"{short_key(c.provider, rep.key)}.{c.name}",
                detail=f"{len(c.others)} user(s): {users}{more}",
                key=c.provider if c.name == WHOLE else f"{c.provider}.{c.name}",
                section=head
            )
        );
    }
    for (g, n) in sorted(
        rep.out_by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
    ) {
        items.append(
            MapItem(
                kind="group",
                label=g,
                detail=f"{n} wire(s)",
                key=g,
                section="Exported to"
            )
        );
    }
    head = f"Imports: {len(rep.imports)} name(s) enter over {rep.in_wires} wire(s)";
    for c in rep.imports {
        items.append(
            MapItem(
                kind="import",
                label=f"{c.provider}.{c.name}",
                detail=f"used by {len(c.others)} inside",
                key=c.provider,
                section=head
            )
        );
    }
    for (g, n) in sorted(
        rep.in_by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
    ) {
        items.append(
            MapItem(
                kind="group",
                label=g,
                detail=f"{n} wire(s)",
                key=g,
                section="Imported from"
            )
        );
    }
    return items;
}

impl rules_items(rep: IntentReport) -> list[MapItem] {
    items: list[MapItem] = [];
    nviol = sum([len(v) for v in rep.violations.values()]);
    pct = int(100 * rep.admitted / rep.crossing) if rep.crossing else 100;
    about = "Intent vs reality (every archwire in the project)";
    items.append(
        MapItem(
            kind="hint",
            label=f"{rep.crossing} wire(s) cross a package boundary; {rep.admitted} ({pct}%) admitted by a rule; {nviol} violate one",
            section=about
        )
    );
    if not rep.unused_arms() and sum([len(r.arms) for r in rep.rules]) >= 10 {
        items.append(
            MapItem(
                kind="hint",
                label="Every permission is used: the rules mirror the wiring, so they record dependencies rather than limit them",
                section=about
            )
        );
    }
    for r in rep.rules {
        tg = " | ".join(r.targets[:5]) + (" …" if len(r.targets) > 5 else "");
        items.append(
            MapItem(
                kind="rule",
                label=f"{r.name}: {' | '.join(r.sources)} --> {tg}",
                detail=f"{r.wires} wire(s) · governs {r.governs}",
                key=r.key,
                section="Rules by use"
            )
        );
    }
    for (r, a) in rep.thin_arms() {
        items.append(
            MapItem(
                kind="arm",
                label=f"{a.source} --> {a.target}",
                detail=r.name,
                key=r.key,
                src=a.source,
                dst=a.target,
                section="Permissions only one wire uses (the easiest to tighten)"
            )
        );
    }
    for (r, a) in rep.unused_arms() {
        items.append(
            MapItem(
                kind="hint",
                label=f"{a.source} --> {a.target}",
                detail=r.name,
                section="Permissions no wire uses"
            )
        );
    }
    for r in rep.dead_rules() {
        items.append(
            MapItem(
                kind="hint",
                label=r.name,
                detail=f"{' | '.join(r.sources)} --> {' | '.join(r.targets)}",
                section="Rules no wire uses"
            )
        );
    }
    for (code, ws) in sorted(rep.violations.items()) {
        for w in ws {
            items.append(
                MapItem(
                    kind="wire",
                    label=f"{w.provider} ++> {w.consumer}",
                    detail=w.violation,
                    src=w.provider,
                    dst=w.consumer,
                    key=f"wire:{w.provider}->{w.consumer}"
                        + (f".{w.scope}" if w.scope else ""),
                    section=f"Violations {code}"
                )
            );
        }
    }
    return items;
}

impl clusters_items(rep: ClusterReport) -> list[MapItem] {
    items: list[MapItem] = [];
    def short(g: str) -> str {
        return short_key(g, rep.scope);
    }
    items.append(
        MapItem(
            kind="hint",
            label=f"{rep.modules} wired module(s) in {len(
                rep.clusters
            )} cluster(s), modularity {rep.modularity:.2f}; {int(
                rep.purity * 100
            )}% sit in a cluster their own package leads",
            section=f"Natural clusters of {rep.scope or 'the project'}"
        )
    );
    tiny = [
        cl
        for cl in rep.clusters
        if len(cl.members) <= 2
    ];
    if tiny {
        items.append(
            MapItem(
                kind="hint",
                label=f"plus {len(tiny)} pair(s) of modules wired only to each other",
                section=f"Natural clusters of {rep.scope or 'the project'}"
            )
        );
    }
    for cl in rep.clusters {
        if len(cl.members) <= 2 {
            continue;
        }
        comp = sorted(
            cl.by_group.items(), key=lambda (kv: tuple[str, int]) -> int { -kv[1] }
        );
        items.append(
            MapItem(
                kind="cluster",
                label=f"#{cl.id}  {len(cl.members)} modules, {int(cl.share * 100)}% {short(
                    cl.label
                )}",
                detail=", ".join([f"{short(g)} {n}" for (g, n) in comp[:5]]),
                key=str(cl.id),
                section="Clusters, largest first"
            )
        );
    }
    for (g, parts) in rep.split {
        items.append(
            MapItem(
                kind="split",
                label=short(g),
                detail=", ".join([f"#{c} {n}" for (c, n) in parts]),
                key=g,
                section="Packages the wiring splits"
            )
        );
    }
    for m in rep.misplaced {
        items.append(
            MapItem(
                kind="module",
                label=short(m.key),
                detail=f"{int(m.best_share * 100)}% of its consumers in {short(
                    m.best
                )}; {int(m.own_share * 100)}% of its wiring stays in {short(m.home)}",
                key=m.key,
                section="Modules that look misplaced"
            )
        );
    }
    return items;
}

impl list_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]] {
    items = view_items(state, lvl);
    if not items {
        msg = "  Cleanly layered: no backward wires, cycles or rule violations at this level."
            if state.view == "issues"
            else "  Working it out…";
        out = [plain(msg, w, THEME.ok if state.view == "issues" else THEME.dim)];
        while len(out) < h {
            out.append(blank(w));
        }
        return out;
    }
    state.item = min(state.item, len(items) - 1);
    colors = {
        "violation": THEME.err,
        "wire": THEME.err,
        "back": THEME.warn,
        "cycle": StyleAttrs(fg=C_CYCLE),
        "export": StyleAttrs(fg=C_IT_FEEDS),
        "import": StyleAttrs(fg=C_FEEDS_IT),
        "rule": THEME.accent2,
        "arm": THEME.warn,
        "cluster": StyleAttrs(fg=C_CYCLE),
        "split": THEME.warn,
        "hint": THEME.text,
        "group": THEME.dim
    };
    lines: list[list[TextSpan]] = [];
    sel_line = 0;
    last = "";
    for (i, it) in enumerate(items) {
        if it.section != last {
            if lines {
                lines.append(blank(w));
            }
            lines.append(fit([sp(" " + it.section, THEME.accent2)], w, None));
            last = it.section;
        }
        a = colors.get(it.kind, THEME.text);
        spans = [sp("   " + it.label, a)];
        if it.detail {
            spans.append(sp("   " + it.detail, THEME.dim));
        }
        line = fit(spans, w, None);
        if i == state.item {
            line = restyle(line, C_SEL_FOCUS if focused else C_SEL);
            sel_line = len(lines);
        }
        lines.append(line);
    }
    body = max(1, h - 2);
    if sel_line < state.scroll {
        state.scroll = sel_line;
    }
    if sel_line >= state.scroll + body {
        state.scroll = sel_line - body + 1;
    }
    out = lines[state.scroll:state.scroll + body];
    while len(out) < h - 1 {
        out.append(blank(w));
    }
    out.append(plain(ITEM_HINTS.get(items[state.item].kind, ""), w, THEME.faint));
    return out[:h];
}

impl chip_line(
    head: str, chips: list[tuple[str, StyleAttrs]], w: int
) -> list[TextSpan] {
    spans = [sp(head, THEME.dim)];
    used = display_width(head);
    for (k, (text, a)) in enumerate(chips) {
        sep = ", " if k else "";
        need = display_width(sep + text);
        rest = len(chips) - k;
        if used + need > w - 8 and rest > 0 {
            spans.append(sp(f"{sep}+{rest} more", THEME.faint));
            break;
        }
        if sep {
            spans.append(sp(sep, THEME.faint));
        }
        spans.append(sp(text, a));
        used += need;
    }
    if not chips {
        spans.append(sp("nothing at this level", THEME.faint));
    }
    return fit(spans, w, None);
}

impl node_detail(level: GraphLevel, nd: GraphNode, w: int) -> list[list[TextSpan]] {
    bits = [
        f"{nd.modules} module" + ("s" if nd.modules != 1 else ""),
        f"layer {nd.layer}"
    ];
    if nd.cycle >= 0 {
        bits.append(f"cycle {nd.cycle + 1} ({len(level.cycles[nd.cycle])} groups)");
    }
    if nd.rules {
        bits.append("rules " + ", ".join(nd.rules));
    }
    if nd.inner {
        bits.append(f"{nd.inner} wires inside");
    }
    head = [
        sp(" " + kind_icon(nd.kind) + " ", kind_attrs(nd.kind)),
        sp(
            nd.label + ("/" if nd.kind == "package" else ""),
            StyleAttrs(fg=255, bold=True)
        ),
        sp("  " + " · ".join(bits), THEME.dim)
    ];
    if nd.violations {
        head.append(sp(f"  {nd.violations} rule violation(s)", THEME.err));
    }
    def label(key: str) -> str {
        other = level.node_of(key);
        return other.label if other is not None else key;
    }
    fed = [
        (
            f"{label(e.src)} {e.count()}" + (" ↺" if e.back else ""),
            StyleAttrs(fg=C_BACK if e.back else C_FEEDS_IT)
        ) for e in level.in_edges(nd.key)
    ];
    feeds = [
        (
            f"{label(e.dst)} {e.count()}" + (" ↺" if e.back else ""),
            StyleAttrs(fg=C_BACK if e.back else C_IT_FEEDS)
        ) for e in level.out_edges(nd.key)
    ];
    outside = f" outside this level: fed by {nd.fed_from_outside} wire(s), feeds {nd.feeds_outside}";
    act = "  Enter opens it" if nd.kind == "package" else "  Enter shows its wiring";
    return [
        fit(head, w, None),
        chip_line(" fed by  ", fed, w),
        chip_line(" feeds   ", feeds, w),
        fit([sp(outside, THEME.faint), sp(act, THEME.faint)], w, None)
    ];
}

impl edge_detail(level: GraphLevel, e: GraphEdge, w: int) -> list[list[TextSpan]] {
    a = level.node_of(e.src);
    b = level.node_of(e.dst);
    an = a.label if a is not None else e.src;
    bn = b.label if b is not None else e.dst;
    head = [
        sp(f" {an} → {bn}", StyleAttrs(fg=255, bold=True)),
        sp(f"  {e.count()} wire(s)", THEME.dim)
    ];
    if e.back and a is not None and b is not None {
        head.append(sp(f"  backward: L{a.layer} feeds L{b.layer}", THEME.warn));
    }
    if e.violations {
        head.append(sp(f"  {e.violations} break a rule", THEME.err));
    }
    sample = e.wires[0] if e.wires else None;
    first = "";
    if sample is not None {
        names = ", ".join(sample.names[:6]) if sample.names else "whole module";
        more = " …" if len(sample.names) > 6 else "";
        first = f" {sample.provider} ++> {sample.consumer} {{ {names}{more} }}";
    }
    rev = level.edge_of(e.dst, e.src);
    mutual = f" {bn} also feeds {an} ({rev.count()} wire(s)): the two depend on each other"
        if rev is not None
        else "";
    return [
        fit(head, w, None),
        plain(first, w, THEME.dim),
        plain(mutual, w, THEME.warn),
        plain(" Enter lists the wires · Space adds them to the context", w, THEME.faint)
    ];
}
