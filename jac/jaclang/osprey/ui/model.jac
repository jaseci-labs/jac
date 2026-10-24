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

impl node_id(n: UiNode) -> str {
    return jid(n);
}


impl _ranked_child_key(pair: RankedChild) -> int {
    return pair.rank;
}


impl ordered_children(parent: UiContainer) -> list[UiNode] {
    pairs: list[RankedChild] = [];
    for child in [parent->:Child:->] {
        for e in [edge parent->:Child:->child] {
            pairs.append(RankedChild(rank=e.rank, nd=child));
        }
    }
    pairs.sort(key=_ranked_child_key);
    return [pair.nd for pair in pairs];
}


impl ordered_child_keys(parent: UiContainer) -> list[str] {
    return [child.key for child in ordered_children(parent)];
}


impl child_rank(parent: UiContainer, child: UiNode) -> int {
    for e in [edge parent->:Child:->child] {
        return e.rank;
    }
    return -1;
}


impl child_parent(child: UiNode) -> UiContainer | None {
    parents = [child<-:Child:<-];
    if not parents {
        return None;
    }
    return parents[0];
}


impl enclosing_screen(n: UiNode) -> Screen | None {
    current: UiNode | None = n;
    while current is not None {
        if isinstance(current, Screen) {
            return current;
        }
        parents = [current<-:Child:<-];
        if not parents {
            return None;
        }
        current = parents[0];
    }
    return None;
}


impl duplicate_sibling_keys(parent: UiContainer) -> list[str] {
    seen: dict[str, int] = {};
    dups: list[str] = [];
    for child in ordered_children(parent) {
        if not child.key {
            continue;
        }
        count = seen.get(child.key, 0) + 1;
        seen[child.key] = count;
        if count == 2 {
            dups.append(child.key);
        }
    }
    return dups;
}


impl is_child_ancestor(ancestor: UiNode, child: UiNode) -> bool {
    current: UiNode | None = child;
    while current is not None {
        if current is ancestor {
            return True;
        }
        parents = [current<-:Child:<-];
        if not parents {
            return False;
        }
        current = parents[0];
    }
    return False;
}

impl find_node_by_jid(n: UiNode, target_jid: str) -> UiNode | None {
    if node_id(n) == target_jid {
        return n;
    }
    if isinstance(n, UiContainer) {
        for child in ordered_children(n) {
            found = find_node_by_jid(child, target_jid);
            if found is not None {
                return found;
            }
        }
    }
    return None;
}
