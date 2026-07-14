import enum;
import re;
import from dataclasses { fields, is_dataclass }
import from jaclang.byllm._optdeps.loguru { logger }


def _class_info(arch: object) -> object {
    import from jaclang.jac0core.mtp { fetch_mtir }
    try {
        return fetch_mtir(type(arch));
    } except Exception {
        return None;
    }
}


def _safe_repr(value: object, limit: int = 120) -> str {
    try {
        text = repr(value);
    } except Exception {
        text = f"<{type(value).__name__}>";
    }
    if len(text) <= limit {
        return text;
    }
    keep = (limit - 5) // 2;
    return text[:keep] + " ... " + text[-keep:];
}


def _describe_arch(arch: object) -> str {
    if arch is None {
        return "(none)";
    }
    cls = type(arch);
    ci = _class_info(arch);
    head = (ci.semstr if (ci is not None and ci.semstr) else "") or cls.__name__;
    fsem: dict = {};
    if ci is not None {
        for fi in (ci.fields or []) {
            if fi.semstr {
                fsem[fi.name] = fi.semstr;
            }
        }
    }
    parts: list = [];
    if is_dataclass(arch) {
        for f in fields(arch) {
            if f.name.startswith("_") {
                continue;
            }
            val = _safe_repr(getattr(arch, f.name));
            label = f"{f.name} ({fsem[f.name]})" if f.name in fsem else f.name;
            parts.append(f"{label}={val}");
        }
    }
    if parts {
        return head + "(" + ", ".join(parts) + ")";
    }
    return head;
}


def _ability_fires(osf: object, wkr: object) -> bool {
    trig = None;
    try {
        trig = osf.trigger;
    } except Exception {
        return False;
    }
    if trig is None {
        return True;
    }
    if wkr is None {
        return False;
    }
    try {
        return isinstance(wkr, trig);
    } except Exception {
        return False;
    }
}


def _node_run_desc(node_arch: object, wkr: object) -> str {
    ci = _class_info(node_arch);
    msem: dict = {};
    if ci is not None {
        for mi in (ci.methods or []) {
            if mi.semstr {
                msem[mi.name] = mi.semstr;
            }
        }
    }
    funcs = type(node_arch)?._jac_entry_funcs_ or [];
    parts: list = [];
    for osf in funcs {
        if not _ability_fires(osf, wkr) {
            continue;
        }
        sem = msem.get(osf.name, "");
        parts.append(osf.name + (f": {sem}" if sem else ""));
    }
    return "; ".join(parts);
}


def _slugify(text: object) -> str {
    s = re.sub(r"\W+", "_", str(text)).strip("_");
    if not s {
        return "n";
    }
    if not (s[0].isalpha() or s[0] == "_") {
        s = "n_" + s;
    }
    return s;
}


def _first_field_value(arch: object) -> object {
    if is_dataclass(arch) {
        for f in fields(arch) {
            if not f.name.startswith("_") {
                return getattr(arch, f.name);
            }
        }
    }
    return None;
}


def _make_handles(recs: list) -> list {
    bases = [_slugify(type(r["node"]).__name__) for r in recs];
    counts: dict = {};
    for b in bases {
        counts[b] = counts.get(b, 0) + 1;
    }
    handles: list = [];
    used = set();
    for (i, r) in enumerate(recs) {
        base = bases[i];
        if counts[base] == 1 {
            cand = base;
        } else {
            disc = _first_field_value(r["node"]);
            cand = base + "_" + _slugify(disc)
                if disc is not None
                else base + "_" + str(i);
        }
        handle = cand;
        k = 2;
        while handle in used {
            handle = cand + "_" + str(k);
            k += 1;
        }
        used.add(handle);
        handles.append(handle);
    }
    return handles;
}


def _route_context -> tuple {
    import from jaclang.jac0core.osp_kernel { _current_scope }
    import from jaclang.jac0core.archetype { NodeAnchor, EdgeAnchor, WalkerAnchor }
    scope = _current_scope();
    if scope is None {
        return (None, None);
    }

    wkr = scope.wlk;
    if isinstance(wkr, (NodeAnchor, EdgeAnchor, WalkerAnchor)) {
        wkr = wkr.archetype;
    }
    here_anchor = scope.path[-1] if scope.path else None;
    return (wkr, here_anchor);
}


def _candidate_for(item: object, here_anchor: object) -> tuple {
    import from jaclang.jac0core.archetype { NodeArchetype, EdgeArchetype }
    if isinstance(item, EdgeArchetype) {
        ea = item.__jac__;
        direction = "out";
        dst_anchor = ea.target;
        if here_anchor is not None and ea.target.archetype is here_anchor.archetype {
            dst_anchor = ea.source;
            direction = "in";
        }
        if ea.is_undirected {
            direction = "undir";
        }
        return (item, dst_anchor.archetype, direction);
    }
    node_arch = item;
    edge_arch = None;
    direction = "out";
    if here_anchor is not None {
        here_arch = here_anchor.archetype;
        for ea in here_anchor.edges {
            other = None;
            dir2 = "out";
            if ea.source.archetype is here_arch {
                other = ea.target;
                dir2 = "out";
            } elif ea.target.archetype is here_arch {
                other = ea.source;
                dir2 = "in";
            }
            if ea.is_undirected {
                dir2 = "undir";
            }
            if other is not None and other.archetype is node_arch {
                edge_arch = ea.archetype;
                direction = dir2;
                break;
            }
        }
    }
    return (edge_arch, node_arch, direction);
}


def _resolve_choice(item: object, by_handle: dict, recs: list) -> object {
    if isinstance(item, bool) {
        return None;
    }
    if isinstance(item, int) {
        return recs[item]["node"] if 0 <= item < len(recs) else None;
    }
    handle = None;
    if isinstance(item, str) {
        handle = item;
    } elif hasattr(item, "value") {
        handle = item.value;
    }
    if handle is not None and handle in by_handle {
        return by_handle[handle];
    }
    return None;
}


def route_visit(candidates: list, model: object) -> list {
    import from jaclang.byllm.mtir { MTRuntime }
    import from jaclang.byllm.types { Message, MessageRole }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    if not candidates {
        return [];
    }

    call_params = model?.call_params or {};
    select = call_params.get("select", "all");

    if isinstance(select, int) and not isinstance(select, bool) and (select < 1) {
        select = "all";
    }
    intent = call_params.get("intent");
    incl_info = call_params.get("incl_info");

    (wkr, here_anchor) = _route_context();

    recs: list = [];
    for item in candidates {
        (edge_arch, node_arch, direction) = _candidate_for(item, here_anchor);
        recs.append(
            {"handle": "", "edge": edge_arch, "node": node_arch, "dir": direction}
        );
    }
    for (i, handle) in enumerate(_make_handles(recs)) {
        recs[i]["handle"] = handle;
    }

    lines: list = [];
    for r in recs {
        node_txt = _describe_arch(r["node"]);
        runs = _node_run_desc(r["node"], wkr);
        if runs {
            node_txt = node_txt + f" [runs: {runs}]";
        }
        if r["edge"] is None {
            lines.append(f"{r['handle']}) {node_txt}");
        } else {
            edge_txt = _describe_arch(r["edge"]);
            if r["dir"] == "in" {
                arrow = f"<--({edge_txt})--";
            } elif r["dir"] == "undir" {
                arrow = f"<-({edge_txt})->";
            } else {
                arrow = f"--({edge_txt})-->";
            }
            lines.append(f"{r['handle']}) here {arrow} {node_txt}");
        }
    }
    candidates_block = "\n".join(lines);

    user_parts: list = [];
    if intent {
        user_parts.append(f"Goal: {intent}");
    }
    if wkr is not None {
        user_parts.append(f"Walker:\n{_describe_arch(wkr)}");
    }
    if here_anchor is not None {
        user_parts.append(f"Current node:\n{_describe_arch(here_anchor.archetype)}");
    }
    user_parts.append(f"Candidates (choose by handle):\n{candidates_block}");
    if incl_info and isinstance(incl_info, dict) {
        user_parts.append("\n".join([f"{k} = {v}" for (k, v) in incl_info.items()]));
    }

    sys_txt = "You are routing a graph walker. Choose which candidate node(s) the " + "walker should visit next, by handle. Return only valid handles.";
    if select == 1 {
        sys_txt += " Choose exactly one.";
    } elif isinstance(select, int) and not isinstance(select, bool) {
        sys_txt += f" Choose exactly {select}.";
    } elif isinstance(select, tuple) and len(select) == 2 {
        sys_txt += f" Choose between {select[0]} and {select[1]} (inclusive).";
    }

    handles = [r["handle"] for r in recs];

    Choice = enum.Enum("RouteChoice", {h: h for h in handles}) if handles else None;
    resp_type = list[Choice] if Choice is not None else list;

    api_params = {
        k: v
        for (k, v) in call_params.items()
        if k not in ("select", "intent", "incl_info")
    };
    mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content=sys_txt),
            Message(role=MessageRole.USER, content="\n\n".join(user_parts)),

        ],
        resp_type=resp_type,
        stream=bool(call_params.get("stream", False)),
        tools=[],
        call_params=api_params,
        mtir=None,
    );

    raw = Jac.call_llm(model, mt_run);

    selected = raw if isinstance(raw, list) else [raw];
    by_handle = {r["handle"]: r["node"] for r in recs};
    chosen: list = [];
    seen_ids: set = set();
    for item in selected {
        picked = _resolve_choice(item, by_handle, recs);
        if picked is not None and id(picked) not in seen_ids {
            seen_ids.add(id(picked));
            chosen.append(picked);
        }
    }

    if select == 1 {
        chosen = chosen[:1];
    } elif isinstance(select, int) and not isinstance(select, bool) {
        chosen = chosen[:select];
    } elif isinstance(select, tuple) and len(select) == 2 {
        chosen = chosen[:select[1]];
        if len(chosen) < select[0] {
            logger.warning(
                f"visit-by routing: requested at least {select[0]} node(s) (select={select}) but the model selected {len(
                    chosen
                )} from {len(recs)} candidate(s)."
            );
        }
    }
    return chosen;
}
