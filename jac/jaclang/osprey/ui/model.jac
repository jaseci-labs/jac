node UiNode {
    has key: str = "";
}


node UiContainer(UiNode) {}


node UiRegion(UiNode) {}


node UiSessionRoot(UiContainer) {}


node Screen(UiContainer) {}


node Overlay(UiContainer) {}


node MainScreen(Screen) {}


node Header(UiRegion) {
    has title: str = "";
}


node TranscriptView(UiRegion) {
    has scroll_offset: int = 0,
        follow_tail: bool = True,
        source_id: str = "",
        observed_revision: int = 0;
}


node Prompt(UiRegion) {
    has draft: str = "",
        mode: str = "insert",
        caret: int = 0,
        sel_anchor: int = -1,
        sel_end: int = -1,
        history: list[str] = [],
        history_index: int = -1;
}


node Status(UiRegion) {
    has phase: str = "";
}


node ApprovalOverlay(Overlay) {}


edge Child: UiContainer --> UiNode {
    has rank: int;
}


edge Owns: UiNode --> UiNode {}


edge Feeds: UiNode --> UiNode {}


edge FocusNext: UiNode --> UiNode {}


edge Layer: Screen --> Overlay {
    has z_index: int,
        modal: bool = False;
}


obj RankedChild {
    has rank: int,
        nd: UiNode;
}


def node_id(n: UiNode) -> str;


def _ranked_child_key(pair: RankedChild) -> int;


def ordered_children(parent: UiContainer) -> list[UiNode];


def ordered_child_keys(parent: UiContainer) -> list[str];


def child_rank(parent: UiContainer, child: UiNode) -> int;


def child_parent(child: UiNode) -> UiContainer | None;


def enclosing_screen(n: UiNode) -> Screen | None;


def duplicate_sibling_keys(parent: UiContainer) -> list[str];


def is_child_ancestor(ancestor: UiNode, child: UiNode) -> bool;

def find_node_by_jid(n: UiNode, target_jid: str) -> UiNode | None;
