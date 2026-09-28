import from typing { cast }

walker CoalesceBBPass(TreePass) {
    has basic_blocks: dict[int, dict[str, list[UniCFGNode]]] = {},
        bb_counter: int = 0;

    can prepare with entry;
    def get_bb(nd: UniCFGNode) -> list[UniCFGNode];
    can coalesce_collect with UniNode entry;
    def printgraph_cfg -> str;
    def _node_label(nd: UniNode) -> str;
    def _has_bool_sc(condition: Expr) -> bool;
}

def cfg_dot_from_file(file_name: str) -> str;
