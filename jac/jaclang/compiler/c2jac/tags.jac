"""Tag types and TagTable for c2jac.

NodeTag captures how each pycparser C-AST node will be handled. TagTable stores
these tags keyed by id(c_node) — no node mutation (§11.5).
"""

enum Tier { TIER_A = "tier_a", TIER_B = "tier_b" }

enum Mechanism { PY_AST = "py_ast", DIRECT_IR = "direct_ir" }

enum Idiom {
    NONE = "none",
    OBJECT_CREATE = "object_create",
    LIST_OF_OBJECTS = "list_of_objects",
    FREE_ELIDE = "free_elide",
    REALLOC_ELIDE = "realloc_elide",
    PTR_REF = "ptr_ref",
    ENUM_AS_ENUM = "enum_as_enum",
    ENUM_AS_CONSTS = "enum_as_consts",
    C_FOR = "c_for",
    TIER_B = "tier_b"
}

"""Per-node annotation produced by the boundary table and analyzers."""
obj NodeTag {
    has tier: Tier,
        mechanism: Mechanism,
        idiom: Idiom = Idiom.NONE,
        reason: str = "",
        c_line: int = 0,
        snippet: str = "";
}

"""Stores NodeTags keyed by id(c_node) — no C-AST mutation."""
obj TagTable {
    has _data: dict[int, NodeTag] = {};

    def tag(c_node: object, nt: NodeTag) {
        self._data[id(c_node)] = nt;
    }

    def get(c_node: object) -> NodeTag | None {
        return self._data.get(id(c_node));
    }

    def tier_b_entries -> list[NodeTag] {
        return [
            v
            for v in self._data.values()
            if v.tier == Tier.TIER_B
        ];
    }
}
