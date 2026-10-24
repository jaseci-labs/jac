glob MAP_PREFIX: str = "map:",
     DEPS_PREFIX: str = "deps:",
     DEPS_SEP: str = "=>",
     MAX_TEXT_EDGES: int = 80,
     MAX_DEPS_WIRES: int = 80,
     MAX_TEXT_MATRIX: int = 40;

obj GraphNode {
    has key: str,
        label: str,
        kind: str = "module",
        modules: int = 0,
        inner: int = 0,
        layer: int = 0,
        cycle: int = -1,
        fed_from_outside: int = 0,
        feeds_outside: int = 0,
        violations: int = 0,
        rules: list[str] = [];
}

obj GraphEdge {
    has src: str,
        dst: str,
        wires: list[WireInfo] = [],
        back: bool = False,
        violations: int = 0;

    def count -> int;
}

obj GraphLevel {
    has scope: str,
        nodes: list[GraphNode] = [],
        edges: dict[tuple[str, str], GraphEdge] = {},
        cycles: list[list[str]] = [],
        index: dict[str, int] = {},
        wires: int = 0,
        back_wires: int = 0,
        inner_wires: int = 0,
        violations: int = 0;

    def node_of(key: str) -> (GraphNode | None);
    def label_of(key: str) -> str;
    def edge_of(src: str, dst: str) -> (GraphEdge | None);
    def out_edges(key: str) -> list[GraphEdge];
    def in_edges(key: str) -> list[GraphEdge];
    def back_edges -> list[GraphEdge];
    def layers -> list[list[GraphNode]];
    def title -> str;
}

def in_scope(key: str, scope: str) -> bool;

def group_of(key: str, scope: str) -> str;

def effective_scope(
    model: ProjectModel, scope: str, only: (set[str] | None) = None
) -> str;

def parent_scope(
    model: ProjectModel, scope: str, only: (set[str] | None) = None
) -> (str | None);

def scope_for(model: ProjectModel, key: str) -> str;

def graph_level(
    model: ProjectModel, scope: str = "", only: (set[str] | None) = None
) -> GraphLevel;

def order_groups(names: list[str], weights: dict[tuple[str, str], int]) -> list[str];

def strong_components(
    names: list[str], weights: dict[tuple[str, str], int]
) -> list[list[str]];

def edge_wires(
    model: ProjectModel, src: str, dst: str, only: (set[str] | None) = None
) -> list[WireInfo];

def edge_scope(src: str, dst: str) -> str;

def deps_key(src: str, dst: str) -> str;

def parse_deps_key(key: str) -> (tuple[str, str] | None);

def split_spec(key: str) -> tuple[str, str];

def level_dict(level: GraphLevel, model: ProjectModel) -> dict[str, any];

def level_text(level: GraphLevel, model: ProjectModel) -> str;

def matrix_text(level: GraphLevel) -> list[str];

def deps_text(
    model: ProjectModel, src: str, dst: str, only: (set[str] | None) = None
) -> str;

impl GraphEdge.count -> int {
    return len(self.wires);
}

impl GraphLevel.node_of(key: str) -> (GraphNode | None) {
    i = self.index.get(key, -1);
    return self.nodes[i] if i >= 0 else None;
}

impl GraphLevel.label_of(key: str) -> str {
    nd = self.node_of(key);
    return nd.label if nd is not None else key;
}

impl GraphLevel.edge_of(src: str, dst: str) -> (GraphEdge | None) {
    return self.edges.get((src, dst));
}

impl GraphLevel.out_edges(key: str) -> list[GraphEdge] {
    found = [
        e
        for e in self.edges.values()
        if e.src == key
    ];
    found.sort(key=GraphEdge.count, reverse=True);
    return found;
}

impl GraphLevel.in_edges(key: str) -> list[GraphEdge] {
    found = [
        e
        for e in self.edges.values()
        if e.dst == key
    ];
    found.sort(key=GraphEdge.count, reverse=True);
    return found;
}

impl GraphLevel.back_edges -> list[GraphEdge] {
    found = [
        e
        for e in self.edges.values()
        if e.back
    ];
    found.sort(key=GraphEdge.count, reverse=True);
    return found;
}

impl GraphLevel.layers -> list[list[GraphNode]] {
    out: list[list[GraphNode]] = [];
    for nd in self.nodes {
        while len(out) <= nd.layer {
            out.append([]);
        }
        out[nd.layer].append(nd);
    }
    return out;
}

impl GraphLevel.title -> str {
    return self.scope or "project";
}

impl in_scope(key: str, scope: str) -> bool {
    return not scope or key == scope or key.startswith(scope + ".");
}

impl group_of(key: str, scope: str) -> str {
    if not scope {
        return key.split(".")[0];
    }
    if key == scope {
        return key;
    }
    if key.startswith(scope + ".") {
        return scope + "." + key[len(scope) + 1:].split(".")[0];
    }
    return "";
}

impl effective_scope(
    model: ProjectModel, scope: str, only: (set[str] | None) = None
) -> str {
    while True {
        groups: dict[str, bool] = {};
        for (k, m) in model.modules.items() {
            if m.kind != "module"
                or not in_scope(k, scope)
                or (only is not None and k not in only) {
                continue;
            }
            g = group_of(k, scope);
            groups[g] = groups.get(g, False) or k != g;
        }
        if len(groups) != 1 {
            return scope;
        }
        (single, is_pkg) = list(groups.items())[0];
        if not is_pkg or single == scope {
            return scope;
        }
        scope = single;
    }
}

impl parent_scope(
    model: ProjectModel, scope: str, only: (set[str] | None) = None
) -> (str | None) {
    if not scope {
        return None;
    }
    current = effective_scope(model, scope, only);
    up = scope;
    while up {
        up = up.rsplit(".", 1)[0] if "." in up else "";
        if effective_scope(model, up, only) != current {
            return up;
        }
    }
    return None;
}

impl scope_for(model: ProjectModel, key: str) -> str {
    key = key.strip().strip(".");
    if not key {
        return "";
    }
    with model.lock {
        for k in model.modules.keys() {
            if k.startswith(key + ".") and model.modules[k].kind == "module" {
                return key;
            }
        }
        parts = key.split(".");
        while parts and ".".join(parts) not in model.modules {
            parts = parts[:-1];
        }
    }
    mod_key = ".".join(parts) if parts else key;
    return mod_key.rsplit(".", 1)[0] if "." in mod_key else "";
}

impl graph_level(
    model: ProjectModel, scope: str = "", only: (set[str] | None) = None
) -> GraphLevel {
    with model.lock {
        scope = effective_scope(model, scope, only);
        level = GraphLevel(scope=scope);
        groups: dict[str, GraphNode] = {};
        for (k, m) in model.modules.items() {
            if m.kind != "module"
                or not in_scope(k, scope)
                or (only is not None and k not in only) {
                continue;
            }
            g = group_of(k, scope);
            gn = groups.get(g);
            if gn is None {
                label = g[len(scope) + 1:] if scope and g != scope else g;
                gn = GraphNode(key=g, label=label or g);
                groups[g] = gn;
            }
            gn.modules += 1;
            if k != g {
                gn.kind = "package";
            }
        }
        for w in model.wires {
            pm = model.modules.get(w.provider);
            cm = model.modules.get(w.consumer);
            if pm is None or cm is None or pm.kind != "module" or cm.kind != "module" {
                continue;
            }
            if only is not None
                and (w.provider not in only or w.consumer not in only) {
                continue;
            }
            a = group_of(w.provider, scope);
            b = group_of(w.consumer, scope);
            bad = bool(w.violation);
            if a and b and a == b {
                groups[a].inner += 1;
                level.inner_wires += 1;
            } elif a and b {
                e = level.edges.get((a, b));
                if e is None {
                    e = GraphEdge(src=a, dst=b);
                    level.edges[(a, b)] = e;
                }
                e.wires.append(w);
                level.wires += 1;
                if bad {
                    e.violations += 1;
                }
            } elif a {
                groups[a].feeds_outside += 1;
            } elif b {
                groups[b].fed_from_outside += 1;
            }
            if bad {
                for g in {a, b} {
                    if g in groups {
                        groups[g].violations += 1;
                    }
                }
                if a or b {
                    level.violations += 1;
                }
            }
        }
        for r in model.rules {
            for m in [r->:Governs:->] {
                g = group_of(m.key, scope);
                if g in groups and r.name not in groups[g].rules {
                    groups[g].rules.append(r.name);
                }
            }
        }
    }
    names = sorted(groups.keys());
    weights: dict[tuple[str, str], int] = {};
    for (pair, e) in level.edges.items() {
        weights[pair] = e.count();
    }
    order = order_groups(names, weights);
    rank = {g: i for (i, g) in enumerate(order)};
    feeders: dict[str, list[str]] = {g: [] for g in order};
    for (a, b) in level.edges.keys() {
        feeders[b].append(a);
    }
    for g in order {
        deepest = -1;
        for a in feeders[g] {
            if rank[a] < rank[g] {
                deepest = max(deepest, groups[a].layer);
            }
        }
        groups[g].layer = deepest + 1;
    }
    order = [g for (_, _, g) in sorted([(groups[g].layer, rank[g], g) for g in order])];
    level.nodes = [groups[g] for g in order];
    level.index = {g: i for (i, g) in enumerate(order)};
    for e in level.edges.values() {
        e.back = level.index[e.src] > level.index[e.dst];
        if e.back {
            level.back_wires += e.count();
        }
    }
    level.cycles = strong_components(order, weights);
    for (ci, comp) in enumerate(level.cycles) {
        for g in comp {
            groups[g].cycle = ci;
        }
    }
    return level;
}

impl order_groups(names: list[str], weights: dict[tuple[str, str], int]) -> list[str] {
    outs: dict[str, dict[str, int]] = {n: {} for n in names};
    ins: dict[str, dict[str, int]] = {n: {} for n in names};
    for ((a, b), wt) in weights.items() {
        if a != b and a in outs and b in ins {
            outs[a][b] = wt;
            ins[b][a] = wt;
        }
    }
    out_w = {n: sum(outs[n].values()) for n in names};
    in_w = {n: sum(ins[n].values()) for n in names};
    rem = set(names);
    front: list[str] = [];
    back: list[str] = [];
    def take(v: str) {
        rem.discard(v);
        for (u, wt) in outs[v].items() {
            if u in rem {
                in_w[u] -= wt;
            }
        }
        for (u, wt) in ins[v].items() {
            if u in rem {
                out_w[u] -= wt;
            }
        }
    }
    while rem {
        moved = True;
        while moved {
            moved = False;
            for v in sorted(rem) {
                if v not in rem {
                    continue;
                }
                if in_w[v] == 0 {
                    front.append(v);
                    take(v);
                    moved = True;
                } elif out_w[v] == 0 {
                    back.insert(0, v);
                    take(v);
                    moved = True;
                }
            }
        }
        if rem {
            best = "";
            best_delta = 0;
            for v in sorted(rem) {
                delta = out_w[v] - in_w[v];
                if not best or delta > best_delta {
                    best = v;
                    best_delta = delta;
                }
            }
            front.append(best);
            take(best);
        }
    }
    return front + back;
}

impl strong_components(
    names: list[str], weights: dict[tuple[str, str], int]
) -> list[list[str]] {
    fwd: dict[str, list[str]] = {n: [] for n in names};
    rev: dict[str, list[str]] = {n: [] for n in names};
    for (a, b) in weights.keys() {
        if a != b and a in fwd and b in fwd {
            fwd[a].append(b);
            rev[b].append(a);
        }
    }
    seen: set[str] = set();
    finished: list[str] = [];
    for start in names {
        if start in seen {
            continue;
        }
        seen.add(start);
        stack = [(start, iter(sorted(fwd[start])))];
        while stack {
            (v, it) = stack[-1];
            nxt = next(it, None);
            if nxt is None {
                stack.pop();
                finished.append(v);
            } elif nxt not in seen {
                seen.add(nxt);
                stack.append((nxt, iter(sorted(fwd[nxt]))));
            }
        }
    }
    placed: set[str] = set();
    comps: list[list[str]] = [];
    for start in reversed(finished) {
        if start in placed {
            continue;
        }
        comp: list[str] = [];
        todo = [start];
        placed.add(start);
        while todo {
            v = todo.pop();
            comp.append(v);
            for u in rev[v] {
                if u not in placed {
                    placed.add(u);
                    todo.append(u);
                }
            }
        }
        if len(comp) > 1 {
            comps.append(comp);
        }
    }
    ordered: list[list[str]] = [];
    for comp in comps {
        members = set(comp);
        ordered.append(
            [
                n
                for n in names
                if n in members
            ]
        );
    }
    ordered.sort(key=len, reverse=True);
    return ordered;
}

impl edge_scope(src: str, dst: str) -> str {
    a = src.split(".");
    b = dst.split(".");
    n = 0;
    while n < min(len(a), len(b)) and a[n] == b[n] {
        n += 1;
    }
    if n == len(a) or n == len(b) {
        n = min(len(a), len(b));
        return ".".join(a[:n]) if n == len(a) else ".".join(b[:n]);
    }
    return ".".join(a[:n]);
}

impl edge_wires(
    model: ProjectModel, src: str, dst: str, only: (set[str] | None) = None
) -> list[WireInfo] {
    scope = edge_scope(src, dst);
    found: list[WireInfo] = [];
    for w in model.wires {
        pm = model.modules.get(w.provider);
        cm = model.modules.get(w.consumer);
        if pm is None or cm is None or pm.kind != "module" or cm.kind != "module" {
            continue;
        }
        if only is not None and (w.provider not in only or w.consumer not in only) {
            continue;
        }
        if group_of(w.provider, scope) == src and group_of(w.consumer, scope) == dst {
            found.append(w);
        }
    }
    return found;
}

impl deps_key(src: str, dst: str) -> str {
    return f"{DEPS_PREFIX}{src}{DEPS_SEP}{dst}";
}

impl split_spec(key: str) -> tuple[str, str] {
    if "?" in key {
        (head, spec) = key.split("?", 1);
        return (head, spec);
    }
    return (key, "");
}

impl parse_deps_key(key: str) -> (tuple[str, str] | None) {
    if not key.startswith(DEPS_PREFIX) {
        return None;
    }
    body = split_spec(key[len(DEPS_PREFIX):])[0];
    if DEPS_SEP not in body {
        return None;
    }
    (src, dst) = body.split(DEPS_SEP, 1);
    return (src, dst) if src and dst else None;
}

impl level_dict(level: GraphLevel, model: ProjectModel) -> dict[str, any] {
    up = parent_scope(model, level.scope);
    return {
        "scope": level.scope,
        "parent": up,
        "groups": [
            {
                "key": nd.key,
                "label": nd.label,
                "kind": nd.kind,
                "modules": nd.modules,
                "layer": nd.layer,
                "cycle": nd.cycle,
                "wires_inside": nd.inner,
                "fed_from_outside": nd.fed_from_outside,
                "feeds_outside": nd.feeds_outside,
                "rules": nd.rules,
                "violations": nd.violations
            } for nd in level.nodes
        ],
        "edges": [
            {
                "from": e.src,
                "to": e.dst,
                "wires": e.count(),
                "backward": e.back,
                "violations": e.violations
            } for e in sorted(level.edges.values(), key=GraphEdge.count, reverse=True)
        ],
        "cycles": level.cycles,
        "totals": {
            "groups": len(level.nodes),
            "wires_between": level.wires,
            "backward_wires": level.back_wires,
            "wires_inside": level.inner_wires,
            "violations": level.violations
        }
    };
}

impl level_text(level: GraphLevel, model: ProjectModel) -> str {
    lines: list[str] = [];
    mods = sum([nd.modules for nd in level.nodes]);
    lines.append(
        f"Architecture of {level.title()}: {len(level.nodes)} groups, {mods} modules, "
            + f"{level.wires} wires between groups ({level.back_wires} backward), "
            + f"{level.inner_wires} inside groups"
    );
    up = parent_scope(model, level.scope);
    if up is not None {
        lines.append(f"Up: {up or 'project'}");
    }
    lines.append("");
    lines.append("Groups, providers first (layer 0 is fed by nothing at this level):");
    for (i, nd) in enumerate(level.nodes) {
        bits = [f"{nd.modules} module" + ("s" if nd.modules != 1 else "")];
        if nd.cycle >= 0 {
            bits.append(f"cycle {nd.cycle + 1}");
        }
        if nd.rules {
            bits.append("rules " + ", ".join(nd.rules));
        }
        if nd.violations {
            bits.append(f"{nd.violations} rule violation(s)");
        }
        lines.append(
            f"  {i + 1:>3}. L{nd.layer} {nd.label}"
                + ("/" if nd.kind == "package" else "")
                + "  ("
                + ", ".join(bits)
                + ")"
        );
    }
    if level.nodes and len(level.nodes) <= MAX_TEXT_MATRIX {
        lines.append("");
        lines.append(
            "Matrix: the row feeds the column; numbers are wire counts, and a number left of the diagonal is a backward wire."
        );
        lines += matrix_text(level);
    }
    back = level.back_edges();
    if back {
        lines.append("");
        lines.append(
            f"Backward wires ({level.back_wires} of {level.wires}): a later group feeds an earlier one"
        );
        for e in back[:MAX_TEXT_EDGES] {
            lines.append(
                f"  {level.label_of(e.src)} -> {level.label_of(e.dst)}: {e.count()}"
            );
        }
    }
    if level.cycles {
        lines.append("");
        lines.append("Cycles (groups that feed each other through wires):");
        for (ci, comp) in enumerate(level.cycles) {
            labels = [level.label_of(g) for g in comp];
            lines.append(f"  {ci + 1}: " + ", ".join(labels));
        }
    }
    edges = sorted(level.edges.values(), key=GraphEdge.count, reverse=True);
    if edges {
        lines.append("");
        lines.append("Dependencies (provider -> consumer: wires):");
        for e in edges[:MAX_TEXT_EDGES] {
            mark = "  backward" if e.back else "";
            if e.violations {
                mark += f"  {e.violations} rule violation(s)";
            }
            lines.append(
                f"  {level.label_of(e.src)} -> {level.label_of(e.dst)}: {e.count()}{mark}"
            );
        }
        if len(edges) > MAX_TEXT_EDGES {
            lines.append(f"  ... and {len(edges) - MAX_TEXT_EDGES} more");
        }
    }
    return "\n".join(lines);
}

impl matrix_text(level: GraphLevel) -> list[str] {
    n = len(level.nodes);
    top = 0;
    for e in level.edges.values() {
        top = max(top, e.count());
    }
    cw = max(len(str(top)), len(str(n))) + 1;
    lw = min(max([len(nd.label) for nd in level.nodes] + [4]), 24);
    head = " " * (lw + 6) + "".join([str(j + 1).rjust(cw) for j in range(n)]);
    out = [head];
    for (i, a) in enumerate(level.nodes) {
        row = f"{i + 1:>3}. " + a.label[:lw].ljust(lw) + " ";
        for (j, b) in enumerate(level.nodes) {
            if i == j {
                row += "·".rjust(cw);
                continue;
            }
            e = level.edge_of(a.key, b.key);
            row += (str(e.count()) if e is not None else "").rjust(cw);
        }
        out.append(row.rstrip());
    }
    return out;
}

impl deps_text(
    model: ProjectModel, src: str, dst: str, only: (set[str] | None) = None
) -> str {
    with model.lock {
        found = edge_wires(model, src, dst, only);
    }
    lines = [f"Wires from {src} to {dst} ({len(found)}):"];
    for w in found[:MAX_DEPS_WIRES] {
        names = ", ".join(w.names) if w.names else "whole module";
        scope = f" (in {w.scope})" if w.scope else "";
        line = f"  {w.provider} ++> {w.consumer}{scope} {{ {names} }}";
        if w.violation {
            line += f"  VIOLATES: {w.violation}";
        }
        lines.append(line);
    }
    if len(found) > MAX_DEPS_WIRES {
        lines.append(f"  ... and {len(found) - MAX_DEPS_WIRES} more");
    }
    back = edge_wires(model, dst, src, only);
    if back {
        lines.append(
            f"{dst} also feeds {src} through {len(
                back
            )} wire(s), so the two depend on each other."
        );
    }
    return "\n".join(lines);
}
