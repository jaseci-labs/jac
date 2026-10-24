obj Effect {}


obj SendPrompt(Effect) {
    has text: str;
}


obj CopyToClipboard(Effect) {
    has text: str;
}


obj SpawnProcess(Effect) {
    has command: list[str];
}


obj Quit(Effect) {}


walker UiEvent {
    has handled: bool = False,
        propagation_stopped: bool = False,
        default_prevented: bool = False,
        effects: list[Effect] = [];
}


walker InsertText(UiEvent) {
    has text: str = "";
}


walker Submit(UiEvent) {}


walker Cancel(UiEvent) {}


walker MoveFocus(UiEvent) {
    has direction: str = "next";
}


walker StreamChunk(UiEvent) {
    has text: str = "";
}


walker Resize(UiEvent) {
    has width: int = 0,
        height: int = 0;
}


walker TranscriptChanged(UiEvent) {
    has revision: int = 0;
}


obj DispatchRecord {
    has node_id: str,
        delivered: bool,
        stopped_propagation: bool;
}


def _get_focus_node(session: UiSession) -> UiNode | None;


def _set_focus(session: UiSession, n: UiNode | None);


def containment_path(target: UiNode) -> list[UiNode];


def topmost_modal_overlay(session: UiSession) -> Overlay | None;


def resolve_input_target(session: UiSession) -> UiNode | None;


def resolve_target(
    session: UiSession, explicit_target: UiNode | None = None
) -> UiNode | None;


def run_default_action(session: UiSession, event: UiEvent);


def _default_move_focus(session: UiSession, event: MoveFocus);


def dispatch_event(
    session: UiSession, event: UiEvent, target: UiNode | None = None
) -> UiEvent;


def dispatch_event_with_effects(
    session: UiSession, event: UiEvent, target: UiNode | None = None,
) -> list[Effect];


def pending_effects(event: UiEvent) -> list[Effect];


def consume_effects(event: UiEvent) -> list[Effect];


def trace_event_path(session: UiSession, target: UiNode | None = None) -> list[str];

impl _get_focus_node(session: UiSession) -> UiNode | None {
    if session.disposed or session.ui_root is None or not session.focus_id {
        return None;
    }
    if session.focus_id not in session.tracked_node_ids {
        return None;
    }
    return find_node_by_jid(session.ui_root, session.focus_id);
}


impl _set_focus(session: UiSession, n: UiNode | None) {
    if n is None {
        session.focus_id = "";
        return;
    }
    session.focus_id = node_id(n);
}


impl containment_path(target: UiNode) -> list[UiNode] {
    path: list[UiNode] = [target];
    current: UiNode = target;
    while True {
        parents = [current<-:Child:<-];
        if not parents {
            break;
        }
        current = parents[0];
        path.append(current);
        if isinstance(current, Screen) {
            break;
        }
    }
    return path;
}


impl topmost_modal_overlay(session: UiSession) -> Overlay | None {
    screen = session.current_screen;
    if screen is None {
        return None;
    }
    best: Overlay | None = None;
    best_z = -1;
    for candidate in [screen->:Layer:->] {
        for layer_edge in [edge screen->:Layer:->candidate] {
            if layer_edge.modal and layer_edge.z_index > best_z {
                best_z = layer_edge.z_index;
                best = candidate;
            }
        }
    }
    return best;
}


impl resolve_input_target(session: UiSession) -> UiNode | None {
    modal = topmost_modal_overlay(session);
    if modal is not None {
        return modal;
    }
    focused = _get_focus_node(session);
    if focused is not None {
        return focused;
    }
    return session.current_screen;
}


impl resolve_target(
    session: UiSession, explicit_target: UiNode | None = None
) -> UiNode | None {
    if explicit_target is not None {
        return explicit_target;
    }
    return resolve_input_target(session);
}


impl run_default_action(session: UiSession, event: UiEvent) {
    if isinstance(event, MoveFocus) {
        _default_move_focus(session, event);
    }
}


impl _default_move_focus(session: UiSession, event: MoveFocus) {
    focused = _get_focus_node(session);
    if focused is None {
        return;
    }
    parents = [focused<-:Child:<-];
    if not parents {
        return;
    }
    siblings = ordered_children(parents[0]);
    index = -1;
    for i in range(len(siblings)) {
        if siblings[i] is focused {
            index = i;
            break;
        }
    }
    if index < 0 {
        return;
    }
    if event.direction == "prev" {
        next_index = index - 1;
    } else {
        next_index = index + 1;
    }
    if next_index < 0 or next_index >= len(siblings) {
        return;
    }
    _set_focus(session, siblings[next_index]);
}


impl dispatch_event(
    session: UiSession, event: UiEvent, target: UiNode | None = None
) -> UiEvent {
    if session.disposed {
        raise ValueError("UiSession is disposed");
    }
    resolved = resolve_target(session, target);
    if resolved is None {
        return event;
    }
    path = containment_path(resolved);
    for stop in path {
        stop spawn event;
        if event.propagation_stopped {
            break;
        }
    }
    if not event.default_prevented {
        run_default_action(session, event);
    }
    return event;
}


impl dispatch_event_with_effects(
    session: UiSession, event: UiEvent, target: UiNode | None = None,
) -> list[Effect] {
    dispatch_event(session, event, target);
    return consume_effects(event);
}


impl pending_effects(event: UiEvent) -> list[Effect] {
    return list(event.effects);
}


impl consume_effects(event: UiEvent) -> list[Effect] {
    effects = event.effects;
    event.effects = [];
    return effects;
}


impl trace_event_path(session: UiSession, target: UiNode | None = None) -> list[str] {
    resolved = resolve_target(session, target);
    if resolved is None {
        return [];
    }
    ids: list[str] = [];
    for stop in containment_path(resolved) {
        ids.append(node_id(stop));
    }
    return ids;
}
