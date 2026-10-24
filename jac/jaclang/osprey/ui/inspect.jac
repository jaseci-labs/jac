obj InspectFinding {
    has kind: str,
        detail: str;
}


obj InvalidationExplanation {
    has node_id: str,
        origin: str,
        layout_root_id: str,
        damage_reason: str;
}


def _node_label(n: UiNode) -> str;


def _node_sort_key(n: UiNode) -> str;


def _binding_line_key(binding: Binding) -> str;


def _walk_nodes(session: UiSession) -> list[UiNode];


def dump_graph(session: UiSession) -> str;


def dump_session_bindings(session: UiSession) -> str;


def dump_event_path(
    session: UiSession, event: any, target: UiNode | None = None,
) -> str;


def explain_invalidation(session: UiSession, n: UiNode,) -> InvalidationExplanation;


def dump_layout(session: UiSession, n: UiNode) -> str;


def dump_damage(session: UiSession, frame: any = None) -> str;


def dump_lifetimes(session: UiSession, n: UiNode) -> str;


def _detect_cycles(session: UiSession) -> list[InspectFinding];


def _detect_duplicate_keys(session: UiSession) -> list[InspectFinding];


def _detect_invalid_ranks(session: UiSession) -> list[InspectFinding];


def validate_invariants(session: UiSession) -> list[InspectFinding];

impl _node_label(n: UiNode) -> str {
    kind = type(n).__name__;
    return kind + "[" + n.key + "]:" + node_id(n);
}


impl _node_sort_key(n: UiNode) -> str {
    return n.key + ":" + node_id(n);
}


impl _binding_line_key(binding: Binding) -> str {
    return binding.target_id + ":" + binding.event_type;
}


impl _walk_nodes(session: UiSession) -> list[UiNode] {
    out: list[UiNode] = [];
    if session.ui_root is None {
        return out;
    }
    stack: list[UiNode] = [session.ui_root];
    while stack {
        current = stack.pop();
        out.append(current);
        if isinstance(current, UiContainer) {
            kids = ordered_children(current);
            i = len(kids) - 1;
            while i >= 0 {
                stack.append(kids[i]);
                i -= 1;
            }
        }
    }
    return out;
}


impl dump_graph(session: UiSession) -> str {
    lines: list[str] = [];
    nodes = _walk_nodes(session);
    nodes.sort(key=_node_sort_key);
    for n in nodes {
        lines.append("NODE " + _node_label(n));
        if isinstance(n, UiContainer) {
            for child in ordered_children(n) {
                rank = child_rank(n, child);
                lines.append(
                    "  Child(rank=" + str(rank) + ") -> " + _node_label(child)
                );
            }
        }
        for target in [n->:Owns:->] {
            lines.append("  Owns -> " + _node_label(target as UiNode));
        }
        for target in [n->:Feeds:->] {
            lines.append("  Feeds -> " + _node_label(target as UiNode));
        }
        for target in [n->:FocusNext:->] {
            lines.append("  FocusNext -> " + _node_label(target as UiNode));
        }
        if isinstance(n, Screen) {
            for target in [n->:Layer:->] {
                z = 0;
                modal = False;
                for layer_edge in [edge n->:Layer:->target] {
                    z = layer_edge.z_index;
                    modal = layer_edge.modal;
                }
                lines.append(
                    "  Layer(z="
                        + str(z)
                        + ",modal="
                        + str(modal)
                        + ") -> "
                        + _node_label(target as UiNode)
                );
            }
        }
    }
    return "\n".join(lines);
}


impl dump_session_bindings(session: UiSession) -> str {
    lines: list[str] = [];
    sources = sorted(session.bindings.by_source.keys());
    for source_id in sources {
        bindings = list(session.bindings.by_source[source_id]);
        bindings.sort(key=_binding_line_key);
        for binding in bindings {
            lines.append(
                source_id + " -> " + binding.target_id + " [" + binding.event_type + "]"
            );
        }
    }
    return "\n".join(lines);
}


impl dump_event_path(
    session: UiSession, event: any, target: UiNode | None = None,
) -> str {
    resolved = resolve_target(session, target);
    lines: list[str] = [];
    if resolved is None {
        lines.append("target=<none>");
    } else {
        lines.append("target=" + _node_label(resolved));
        path = containment_path(resolved);
        path_keys = [stop.key for stop in path];
        path_ids = [node_id(stop) for stop in path];
        lines.append("path_keys=" + ",".join(path_keys));
        lines.append("path_ids=" + ",".join(path_ids));
    }
    handled = False;
    stopped = False;
    prevented = False;
    if isinstance(event, UiEvent) {
        handled = event.handled;
        stopped = event.propagation_stopped;
        prevented = event.default_prevented;
    }
    lines.append("handled=" + str(handled));
    lines.append("propagation_stopped=" + str(stopped));
    lines.append("default_prevented=" + str(prevented));
    return "\n".join(lines);
}


impl explain_invalidation(session: UiSession, n: UiNode,) -> InvalidationExplanation {
    nid = node_id(n);
    origin = "";
    layout_root_id = "";
    damage_reason = "none";
    for record in session.invalidation_journal {
        if record.node_id == nid or record.layout_root_id == nid {
            origin = record.reason;
            layout_root_id = record.layout_root_id;
            damage_reason = record.reason;
        }
    }
    return InvalidationExplanation(
        node_id=nid,
        origin=origin,
        layout_root_id=layout_root_id,
        damage_reason=damage_reason,
    );
}


impl dump_layout(session: UiSession, n: UiNode) -> str {
    nid = node_id(n);
    lines: list[str] = ["node=" + _node_label(n)];
    ent = session.renderer.layout.get(nid, None);
    if ent is None {
        lines.append("layout=<none>");
        return "\n".join(lines);
    }
    if isinstance(ent, dict) {
        for key in sorted(ent.keys()) {
            lines.append(str(key) + "=" + str(ent[key]));
        }
    } else {
        lines.append("layout=" + str(ent));
    }
    return "\n".join(lines);
}


impl dump_damage(session: UiSession, frame: any = None) -> str {
    _ = frame;
    lines: list[str] = [];
    for (i, row) in enumerate(session.renderer.damage) {
        lines.append("damage[" + str(i) + "]=" + str(row));
    }
    if session.renderer.cursor_holder_id {
        lines.append("cursor_holder=" + session.renderer.cursor_holder_id);
    }
    return "\n".join(lines);
}


impl dump_lifetimes(session: UiSession, n: UiNode) -> str {
    nid = node_id(n);
    lines: list[str] = ["node=" + _node_label(n)];
    parents = [n<-:Child:<-];
    if parents {
        lines.append("parent=" + _node_label(parents[0]));
    } else {
        lines.append("parent=<none>");
    }
    if isinstance(n, UiContainer) {
        keys = ordered_child_keys(n);
        lines.append("children=" + ",".join(keys));
    }
    owns = [node_id(t as UiNode) for t in [n->:Owns:->]];
    if owns {
        lines.append("owns=" + ",".join(owns));
    }
    owned_by = [node_id(t as UiNode) for t in [n<-:Owns:<-]];
    if owned_by {
        lines.append("owned_by=" + ",".join(owned_by));
    }
    target_bindings = list(session.bindings.by_target.get(nid, []));
    for binding in target_bindings {
        lines.append("binding=" + binding.source_id + ":" + binding.event_type);
    }
    caps = session.capabilities.by_node.get(nid, []);
    if caps {
        lines.append("capabilities=" + ",".join(caps));
    }
    if session.focus_id == nid {
        lines.append("focus=True");
    }
    return "\n".join(lines);
}


impl _detect_cycles(session: UiSession) -> list[InspectFinding] {
    findings: list[InspectFinding] = [];
    if session.ui_root is None {
        return findings;
    }

    color: dict[str, int] = {};
    stack: list[UiNode] = [session.ui_root];
    enter: list[bool] = [True];
    while stack {
        n = stack[len(stack) - 1];
        entering = enter[len(enter) - 1];
        nid = node_id(n);
        if entering {
            enter[len(enter) - 1] = False;
            state = color.get(nid, 0);
            if state == 1 {
                findings.append(InspectFinding(kind="cycle", detail=nid));
                stack.pop();
                enter.pop();
                continue;
            }
            if state == 2 {
                stack.pop();
                enter.pop();
                continue;
            }
            color[nid] = 1;
            if isinstance(n, UiContainer) {
                for child in ordered_children(n) {
                    stack.append(child);
                    enter.append(True);
                }
            }
        } else {
            color[nid] = 2;
            stack.pop();
            enter.pop();
        }
    }
    return findings;
}


impl _detect_duplicate_keys(session: UiSession) -> list[InspectFinding] {
    findings: list[InspectFinding] = [];
    for n in _walk_nodes(session) {
        if isinstance(n, UiContainer) {
            for dup in duplicate_sibling_keys(n) {
                findings.append(
                    InspectFinding(kind="duplicate_key", detail=n.key + "/" + dup,)
                );
            }
        }
    }
    return findings;
}


impl _detect_invalid_ranks(session: UiSession) -> list[InspectFinding] {
    findings: list[InspectFinding] = [];
    for n in _walk_nodes(session) {
        if not isinstance(n, UiContainer) {
            continue;
        }
        prev = -1;
        for child in ordered_children(n) {
            rank = child_rank(n, child);
            if rank < 0 {
                findings.append(
                    InspectFinding(kind="invalid_rank", detail=node_id(child),)
                );
            } elif rank <= prev {
                findings.append(
                    InspectFinding(
                        kind="invalid_rank", detail=node_id(child) + " non-increasing",
                    )
                );
            }
            prev = rank;
        }
    }
    return findings;
}


impl validate_invariants(session: UiSession) -> list[InspectFinding] {
    findings: list[InspectFinding] = [];
    for leak in validate_session(session) {
        findings.append(InspectFinding(kind=leak.kind, detail=leak.detail));
    }
    findings.extend(_detect_cycles(session));
    findings.extend(_detect_duplicate_keys(session));
    findings.extend(_detect_invalid_ranks(session));
    return findings;
}
