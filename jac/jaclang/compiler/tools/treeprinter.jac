import builtins;
import html;

glob id_bag: dict[int, any] = {},
     id_state: dict[str, int] = {"used": 0};

def node_to_dict(nd: UniNode) -> dict[(str, str)];

def printgraph_ast_tree(
    root_node: UniNode, dot_lines: (list[str] | None) = None
) -> str;

def print_ast_tree(
    root_node: UniNode,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    max_depth: (int | None) = None
) -> str;

class SymbolTree {
    def init(
        self: SymbolTree,
        node_name: str,
        parent: (SymbolTree | None) = None,
        children: (list[SymbolTree] | None) = None
    ) -> None;

    has parent: (SymbolTree | None) {
        getter;
        setter(self: SymbolTree, parent_node: (SymbolTree | None));
    }
}

def _build_symbol_tree_common(
    nd: UniScopeNode, parent_node: (SymbolTree | None) = None
) -> SymbolTree;

def print_symtab_tree(
    root_node: UniScopeNode,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str;

def get_symtab_tree_str(
    root_node: SymbolTree,
    marker: str = '+-- ',
    level_markers: (list[bool] | None) = None,
    output_file: (str | None) = None,
    depth: (int | None) = None
) -> str;

def printgraph_symtab_tree(nd: UniScopeNode) -> str;
