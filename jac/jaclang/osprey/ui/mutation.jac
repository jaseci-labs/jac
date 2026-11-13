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
