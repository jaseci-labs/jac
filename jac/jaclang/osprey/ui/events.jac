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
