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
