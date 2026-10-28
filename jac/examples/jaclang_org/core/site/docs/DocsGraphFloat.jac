glob ROW_H: float = 16.0,
     COL_W: float = 44.0,
     PAD_X: float = 8.0,
     PAD_Y: float = 12.0,
     LABEL_W: float = 150.0,
     JOURNEY_MS: float = 1400.0;

def _short(t: str) -> str;

def _edge_d(e: dict[str, any]) -> str;

def _push(n: TreeNode, depth: int, acc: dict[str, any], px: float, py: float);

def _model(tree: list[TreeNode], version: str) -> dict[str, any];

def _chain(index: dict[str, any], cur_path: str) -> list[int];

def:pub DocsGraphFloat(
    tree: list[TreeNode], version: str, cur_path: str, on_go: any = None
) -> JsxElement;
