obj OverlayBounds {
    has x: int = 0,
        y: int = 0,
        width: int = 0,
        height: int = 0;

    def is_empty -> bool;
}


obj OverlayOpenResult {
    has overlay_id: str,
        saved_focus_id: str,
        initial_focus_id: str;
}


obj OverlayCloseResult {
    has restored_focus_id: str,
        damage: OverlayBounds,
        overlay_id: str;
}


obj RankedOverlay {
    has z_index: int,
        overlay: Overlay;
}


def _layer_z(screen: Screen, overlay: Overlay) -> int;


def _ranked_overlay_asc(pair: RankedOverlay) -> int;


def _ranked_overlay_desc(pair: RankedOverlay) -> int;


def _layer_pairs(screen: Screen) -> list[RankedOverlay];


def layers_paint_order(screen: Screen) -> list[Overlay];


def layers_input_order(screen: Screen) -> list[Overlay];


def _collect_focusable(n: UiNode) -> list[UiNode];


def _collect_subtree_ids(n: UiNode) -> list[str];


def focus_order(session: UiSession, screen: Screen) -> list[UiNode];


def advance_focus(session: UiSession, direction: str = "next",) -> UiNode | None;


def open_modal_overlay(
    session: UiSession,
    screen: Screen,
    overlay: Overlay,
    initial_focus: UiNode | None = None,
    z_index: int = 10,
) -> OverlayOpenResult;


def close_overlay(session: UiSession, overlay: Overlay,) -> OverlayCloseResult;

impl OverlayBounds.is_empty -> bool {
    return self.width <= 0 or self.height <= 0;
}


impl _layer_z(screen: Screen, overlay: Overlay) -> int {
    for layer_edge in [edge screen->:Layer:->overlay] {
        return layer_edge.z_index;
    }
    return 0;
}


impl _ranked_overlay_asc(pair: RankedOverlay) -> int {
    return pair.z_index;
}


impl _ranked_overlay_desc(pair: RankedOverlay) -> int {
    return -pair.z_index;
}


impl _layer_pairs(screen: Screen) -> list[RankedOverlay] {
    pairs: list[RankedOverlay] = [];
    for candidate in [screen->:Layer:->] {
        pairs.append(
            RankedOverlay(z_index=_layer_z(screen, candidate), overlay=candidate,)
        );
    }
    return pairs;
}


impl layers_paint_order(screen: Screen) -> list[Overlay] {
    pairs = _layer_pairs(screen);
    pairs.sort(key=_ranked_overlay_asc);
    return [p.overlay for p in pairs];
}


impl layers_input_order(screen: Screen) -> list[Overlay] {
    pairs = _layer_pairs(screen);
    pairs.sort(key=_ranked_overlay_desc);
    return [p.overlay for p in pairs];
}


impl _collect_focusable(n: UiNode) -> list[UiNode] {
    out: list[UiNode] = [];
    if isinstance(n, Overlay) {
        out.append(n);
    } elif not isinstance(n, UiContainer) {
        out.append(n);
    }
    if isinstance(n, UiContainer) {
        for child in ordered_children(n) {
            for leaf in _collect_focusable(child) {
                out.append(leaf);
            }
        }
    }
    return out;
}


impl _collect_subtree_ids(n: UiNode) -> list[str] {
    ids: list[str] = [node_id(n)];
    if isinstance(n, UiContainer) {
        for child in ordered_children(n) {
            for sid in _collect_subtree_ids(child) {
                ids.append(sid);
            }
        }
    }
    return ids;
}


impl focus_order(session: UiSession, screen: Screen) -> list[UiNode] {
    _ = session;
    structural = _collect_focusable(screen);
    if not structural {
        return [];
    }
    ordered: list[UiNode] = [];
    visited: set[str] = set();
    for n in structural {
        nid = node_id(n);
        if nid in visited {
            continue;
        }
        current: UiNode | None = n;
        while current is not None {
            cid = node_id(current);
            if cid in visited {
                break;
            }
            ordered.append(current);
            visited.add(cid);
            nxts = [current->:FocusNext:->];
            if not nxts {
                break;
            }
            current = nxts[0];
        }
    }
    return ordered;
}


impl advance_focus(session: UiSession, direction: str = "next",) -> UiNode | None {
    screen = session.current_screen;
    if screen is None {
        return None;
    }
    order = focus_order(session, screen);
    if not order {
        return None;
    }
    focused = get_focus_node(session);
    if focused is None {
        set_focus(session, order[0]);
        return order[0];
    }
    idx = 0;
    found = -1;
    for (i, n) in enumerate(order) {
        if n is focused {
            found = i;
            break;
        }
    }
    if found >= 0 {
        idx = found;
    }
    if direction == "prev" {
        idx = (idx - 1) % len(order);
    } else {
        idx = (idx + 1) % len(order);
    }
    target = order[idx];
    set_focus(session, target);
    return target;
}


impl open_modal_overlay(
    session: UiSession,
    screen: Screen,
    overlay: Overlay,
    initial_focus: UiNode | None = None,
    z_index: int = 10,
) -> OverlayOpenResult {
    saved = session.focus_id;
    existing = False;
    for _cand in [screen->:Layer:->overlay] {
        existing = True;
    }
    if existing {
        for layer_edge in [edge screen->:Layer:->overlay] {
            layer_edge.z_index = z_index;
            layer_edge.modal = True;
        }
    } else {
        screen +>:Layer(z_index=z_index, modal=True):+> overlay;
    }
    track_node(session, overlay);
    if isinstance(overlay, UiContainer) {
        for child in ordered_children(overlay) {
            track_node(session, child);
        }
    }
    session.saved_focus_id = saved;
    target = overlay if initial_focus is None else initial_focus;
    track_node(session, target);
    set_focus(session, target);
    return OverlayOpenResult(
        overlay_id=node_id(overlay),
        saved_focus_id=saved,
        initial_focus_id=node_id(target),
    );
}


impl close_overlay(session: UiSession, overlay: Overlay,) -> OverlayCloseResult {
    overlay_id = node_id(overlay);
    damage = OverlayBounds(x=0, y=0, width=0, height=0);
    layout_entry = session.renderer.layout.get(overlay_id);
    if layout_entry is not None {
        x = int(layout_entry.get("x", 0));
        y = int(layout_entry.get("y", 0));
        w = int(layout_entry.get("width", 0));
        h = int(layout_entry.get("height", 0));
        damage = OverlayBounds(x=x, y=y, width=w, height=h);
    }

    subtree_ids = _collect_subtree_ids(overlay);

    restored = "";
    saved = session.saved_focus_id;
    session.saved_focus_id = "";
    if saved and saved in session.tracked_node_ids and saved not in subtree_ids {
        session.focus_id = saved;
        restored = saved;
    } else {
        session.focus_id = "";
    }

    for parent in list([overlay<-:Layer:<-]) {
        for e in [edge parent->:Layer:->overlay] {
            del e;
        }
    }
    dispose_subtree(overlay);
    for sid in subtree_ids {
        if sid in session.tracked_node_ids {
            session.tracked_node_ids.remove(sid);
        }
        release_capabilities(session, sid);
        if sid in session.renderer.layout {
            del session.renderer.layout[sid];
        }
    }
    session.graph_revision += 1;
    return OverlayCloseResult(
        restored_focus_id=restored, damage=damage, overlay_id=overlay_id,
    );
}
