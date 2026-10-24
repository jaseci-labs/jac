glob RANK_GAP: int = 1024,
     MIN_RANK: int = 0;


obj MutationResult {
    has graph_revision: int,
        layout_root_id: str = "";
}


def _next_rank_after(parent: UiContainer, sibling: UiNode | None) -> int;


def _normalize_child_ranks(parent: UiContainer);


def _validate_mount(parent: UiContainer, child: UiNode);


def _connect_child(parent: UiContainer, child: UiNode, rank: int) -> MutationResult;


def append_child(parent: UiContainer, child: UiNode) -> MutationResult;


def insert_before(
    parent: UiContainer, child: UiNode, sibling: UiNode,
) -> MutationResult;


def insert_after(
    parent: UiContainer, child: UiNode, sibling: UiNode,
) -> MutationResult;


def move_before(child: UiNode, sibling: UiNode) -> MutationResult;


def move_after(child: UiNode, sibling: UiNode) -> MutationResult;


def detach(child: UiNode) -> MutationResult;


def replace(old: UiNode, new: UiNode) -> MutationResult;


def clear_ui_edges(n: UiNode);


def dispose_subtree(n: UiNode);

impl _next_rank_after(parent: UiContainer, sibling: UiNode | None) -> int {
    children = ordered_children(parent);
    if sibling is None {
        if not children {
            return RANK_GAP;
        }
        last = children[-1];
        for e in [edge parent->:Child:->last] {
            return e.rank + RANK_GAP;
        }
        return RANK_GAP;
    }
    idx = children.index(sibling);
    if idx == 0 {
        for e in [edge parent->:Child:->sibling] {
            return max(MIN_RANK, e.rank // 2);
        }
        return RANK_GAP;
    }
    prev = children[idx - 1];
    prev_rank = 0;
    sib_rank = 0;
    for e in [edge parent->:Child:->prev] {
        prev_rank = e.rank;
    }
    for e in [edge parent->:Child:->sibling] {
        sib_rank = e.rank;
    }
    gap = sib_rank - prev_rank;
    if gap > 1 {
        return prev_rank + (gap // 2);
    }
    _normalize_child_ranks(parent);
    return _next_rank_after(parent, sibling);
}


impl _normalize_child_ranks(parent: UiContainer) {
    children = ordered_children(parent);
    rank = RANK_GAP;
    for child in children {
        for e in [edge parent->:Child:->child] {
            e.rank = rank;
        }
        rank += RANK_GAP;
    }
}


impl _validate_mount(parent: UiContainer, child: UiNode) {
    existing = child_parent(child);
    if existing is not None and existing is not parent {
        raise ValueError("UI node already has a parent: " + child.key);
    }
    if is_child_ancestor(child, parent) {
        raise ValueError("Child mount would create a cycle: " + child.key);
    }
    if child.key {
        for sibling in ordered_children(parent) {
            if sibling is not child and sibling.key == child.key {
                raise ValueError("Duplicate sibling key under parent: " + child.key);
            }
        }
    }
}


impl _connect_child(parent: UiContainer, child: UiNode, rank: int) -> MutationResult {
    _validate_mount(parent, child);
    if rank < MIN_RANK {
        raise ValueError("Child rank must be non-negative");
    }
    existing = child_parent(child);
    if existing is not None {
        for e in [edge existing->:Child:->child] {
            del e;
        }
    }
    parent +>:Child(rank=rank):+> child;
    return MutationResult(graph_revision=1, layout_root_id=jid(parent),);
}


impl append_child(parent: UiContainer, child: UiNode) -> MutationResult {
    rank = _next_rank_after(parent, None);
    return _connect_child(parent, child, rank);
}


impl insert_before(
    parent: UiContainer, child: UiNode, sibling: UiNode,
) -> MutationResult {
    if sibling not in ordered_children(parent) {
        raise ValueError("insert_before sibling is not a child of parent");
    }
    rank = _next_rank_after(parent, sibling);
    return _connect_child(parent, child, rank);
}


impl insert_after(
    parent: UiContainer, child: UiNode, sibling: UiNode,
) -> MutationResult {
    children = ordered_children(parent);
    if sibling not in children {
        raise ValueError("insert_after sibling is not a child of parent");
    }
    idx = children.index(sibling);
    if idx + 1 < len(children) {
        return insert_before(parent, child, children[idx + 1]);
    }
    return append_child(parent, child);
}


impl move_before(child: UiNode, sibling: UiNode) -> MutationResult {
    parent = child_parent(child);
    if parent is None {
        raise ValueError("move_before requires a mounted child");
    }
    if sibling not in ordered_children(parent) {
        raise ValueError("move_before sibling is not a child of parent");
    }
    if child is sibling {
        return MutationResult(graph_revision=0, layout_root_id=jid(parent));
    }
    for e in [edge parent->:Child:->child] {
        del e;
    }
    rank = _next_rank_after(parent, sibling);
    return _connect_child(parent, child, rank);
}


impl move_after(child: UiNode, sibling: UiNode) -> MutationResult {
    parent = child_parent(child);
    if parent is None {
        raise ValueError("move_after requires a mounted child");
    }
    children = ordered_children(parent);
    if sibling not in children {
        raise ValueError("move_after sibling is not a child of parent");
    }
    idx = children.index(sibling);
    if idx + 1 < len(children) {
        return move_before(child, children[idx + 1]);
    }
    for e in [edge parent->:Child:->child] {
        del e;
    }
    return append_child(parent, child);
}


impl detach(child: UiNode) -> MutationResult {
    parent = child_parent(child);
    if parent is None {
        return MutationResult(graph_revision=0, layout_root_id="");
    }
    for e in [edge parent->:Child:->child] {
        del e;
    }
    return MutationResult(graph_revision=1, layout_root_id=jid(parent));
}


impl replace(old: UiNode, new: UiNode) -> MutationResult {
    parent = child_parent(old);
    if parent is None {
        raise ValueError("replace requires the old node to be mounted");
    }
    siblings = ordered_children(parent);
    if old not in siblings {
        raise ValueError("replace old node is not mounted under its parent");
    }
    idx = siblings.index(old);
    next_sibling = siblings[idx + 1] if idx + 1 < len(siblings) else None;
    prev_sibling = siblings[idx - 1] if idx > 0 else None;
    detach(old);
    if next_sibling is not None {
        return insert_before(parent, new, next_sibling);
    }
    if prev_sibling is not None {
        return insert_after(parent, new, prev_sibling);
    }
    return append_child(parent, new);
}


impl clear_ui_edges(n: UiNode) {
    if isinstance(n, UiContainer) {
        for child in list([n->:Child:->]) {
            clear_ui_edges(child);
            for e in [edge n->:Child:->child] {
                del e;
            }
        }
    }
    for target in list([n->:Owns:->]) {
        for e in [edge n->:Owns:->target] {
            del e;
        }
    }
    for target in list([n->:Feeds:->]) {
        for e in [edge n->:Feeds:->target] {
            del e;
        }
    }
    for target in list([n->:FocusNext:->]) {
        for e in [edge n->:FocusNext:->target] {
            del e;
        }
    }
    for parent in list([n<-:Child:<-]) {
        for e in [edge parent->:Child:->n] {
            del e;
        }
    }
    for source in list([n<-:Owns:<-]) {
        for e in [edge source->:Owns:->n] {
            del e;
        }
    }
    for source in list([n<-:Feeds:<-]) {
        for e in [edge source->:Feeds:->n] {
            del e;
        }
    }
    for source in list([n<-:FocusNext:<-]) {
        for e in [edge source->:FocusNext:->n] {
            del e;
        }
    }
    for source in list([n<-:Layer:<-]) {
        for e in [edge source->:Layer:->n] {
            del e;
        }
    }
    for target in list([n->:Layer:->]) {
        for e in [edge n->:Layer:->target] {
            del e;
        }
    }
}


impl dispose_subtree(n: UiNode) {
    if isinstance(n, UiContainer) {
        for child in list(ordered_children(n)) {
            dispose_subtree(child);
        }
    }
    clear_ui_edges(n);
    del n;
}
