import from jaclang.compiler.ir.identity { GraphNode }
import type from jaclang.compiler.ir.syntax.edges { Role }
import type from collections.abc { Sequence }
import from jaclang.compiler.frontend.source_locations { CodeLocInfo }
import from jaclang.compiler.ir.enums { CodeContext }
import from jaclang.compiler.ir.enums { Tokens as Tok }

import type from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
import type from jaclang.compiler.ir.syntax.nodes { Token }

walker TreeWalker {}

node UniNode(GraphNode) {
    has _ctx_parent: (UniNode | None) postinit,
        _struct_frozen: bool postinit,
        _in_mod_nodes: list[UniNode] postinit,
        loc: CodeLocInfo postinit,
        _role_shapes: (dict[type, str] | None) postinit,
        __sub_node_tab: (dict[(type, list[UniNode])] | None) postinit,
        ct_pruned: bool postinit;

    def postinit -> None;
    can walk_kids with TreeWalker entry;

    has kid: list[UniNode] { getter; }
    has parent: (UniNode | None) { getter; }
    has _sub_node_tab: dict[(type, list[UniNode])] { getter; }

    def _link(
        kid: Sequence[UniNode], roles: dict[type, UniNode | Sequence[UniNode] | None]
    ) -> None;

    def detached_copy -> UniNode;
    def __deepcopy__(memo: dict) -> UniNode;
    def _assert_thawed -> None;
    def freeze_structure -> None;
    def thaw_structure -> None;
    def structure_thawed -> StructureThaw;
    def _attach(child: UniNode, role: type[Role], check_only: bool = False) -> None;
    def _role_clear(role: type[Role]) -> None;
    def _as_node_list(value: Sequence[UniNode]) -> list[UniNode];
    def _children -> list[UniNode];
    def _role_shaped(
        role: type[Role], found: list[UniNode]
    ) -> UniNode | list[UniNode] | None;

    def _role_set(role: type[Role], value: UniNode | Sequence[UniNode] | None) -> None;
    def _construct_sub_node_tab -> None;
    def _invalidate_sub_node_tab -> None;

    has sym_tab: UniScopeNode { getter; }

    def add_kids_left(
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False,
        role: (type[Role] | None) = None
    ) -> UniNode;

    def add_kids_right(
        nodes: Sequence[UniNode],
        pos_update: bool = True,
        parent_update: bool = False,
        role: (type[Role] | None) = None
    ) -> UniNode;

    def insert_kids_at_pos(
        nodes: Sequence[UniNode],
        pos: int,
        pos_update: bool = True,
        role: (type[Role] | None) = None
    ) -> UniNode;

    def set_kids(nodes: Sequence[UniNode], pos_update: bool = True) -> UniNode;
    def replace_kid(old: UniNode, new: UniNode) -> UniNode;
    def set_parent(parent: UniNode) -> UniNode;
    def resolve_tok_range -> tuple[(Token, Token)];
    def gen_token(name: Tok, value: (str | None) = None) -> Token;
    def get_all_sub_nodes[T](typ: type[T]) -> list[T] {
        result: list[T] = [];
        if typ in self._sub_node_tab {
            for i in self._sub_node_tab[typ] {
                if isinstance(i, typ) {
                    result.append(i);
                }
            }
        }
        return result;
    }

    def find_parent_of_type[T](typ: type[T]) -> (T | None) {
        nd: (UniNode | None) = self.parent;
        while nd is not None {
            if isinstance(nd, typ) {
                return nd;
            }
            nd = nd.parent;
        }
        return None;
    }

    def parent_of_type[T](typ: type[T]) -> T {
        ret = self.find_parent_of_type(typ);
        if isinstance(ret, typ) {
            return ret;
        }
        raise ValueError(f"Parent of type {typ} not found from{type(self)}.");
    }

    def codespace -> CodeContext;
    def in_client_context -> bool;
    def in_native_context -> bool;
    def flatten -> list[UniNode];
    def __repr__ -> str;
}

obj StructureThaw {
    has target: UniNode,
        refreeze: bool = False;

    def __enter__ -> StructureThaw;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}


node TypedNode(UniNode) {}
