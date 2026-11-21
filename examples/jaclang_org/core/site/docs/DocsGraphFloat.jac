glob ROW_H: float = 16.0,
     COL_W: float = 44.0,
     PAD_X: float = 8.0,
     PAD_Y: float = 12.0,
     LABEL_W: float = 150.0,
     JOURNEY_MS: float = 1400.0;

def _short(t: str) -> str;

def _edge_d(e: dict[str, any]) -> str;

"""Lay out `n` and what it holds below the node `parent` of the model."""
def _push(n: TreeNode, depth: int, acc: dict[str, any], parent: int);

"""Where a click on `n` goes: the page, or a section's first page."""
def _first_page(n: TreeNode) -> str;

def _model(tree: list[TreeNode], version: str) -> dict[str, any];

"""The model's nodes from its root down to the page at `cur_path`: the root
alone when no page is there."""
def _chain(m: dict[str, any], cur_path: str) -> list[int];

def:pub DocsGraphFloat(
    tree: list[TreeNode], version: str, cur_path: str, on_go: any = None
) -> JsxElement;
