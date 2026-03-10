"""Gap #47: Undeclared self-attribute assignment not flagged for archetypes.

In Jac, obj/node/edge/walker archetypes have a fixed set of attributes
declared via 'has'. Unlike Python classes, these archetypes do NOT allow
monkey-patching -- assigning to self.new_attr in init where new_attr is
not in the 'has' block should be a type error.

Regular Python-style 'class' declarations DO allow dynamic attributes
in __init__, following standard Python conventions.

Currently, _populate_self_member_symbols() in DeclImplMatchPass
propagates all self.x = value assignments to the archetype symbol table,
effectively allowing monkey patching for all archetype types.

Expected errors:
  1. MyObj.init assigns self.extra       (undeclared on obj)
  2. MyNode.init assigns self.extra      (undeclared on node)
  3. MyEdge.init assigns self.extra      (undeclared on edge)
  4. MyWalker.init assigns self.extra    (undeclared on walker)

No errors expected for:
  - self.name = name (declared 'has' field, valid assignment)
  - FlexibleClass.__init__ assigns self.extra (class allows dynamic attrs)
"""

# --- obj: no monkey patching allowed ---
obj MyObj {
    has name: str;

    def init(name: str) -> None {
        self.name = name;           # Ok: declared field
        self.extra = 42;            # Error: undeclared attribute on obj
    }
}

# --- node: no monkey patching allowed ---
node MyNode {
    has label: str;

    def init(label: str) -> None {
        self.label = label;         # Ok: declared field
        self.extra = "data";        # Error: undeclared attribute on node
    }
}

# --- edge: no monkey patching allowed ---
edge MyEdge {
    has weight: float;

    def init(weight: float) -> None {
        self.weight = weight;       # Ok: declared field
        self.extra = True;          # Error: undeclared attribute on edge
    }
}

# --- walker: no monkey patching allowed ---
walker MyWalker {
    has target: str;

    def init(target: str) -> None {
        self.target = target;       # Ok: declared field
        self.extra = [];            # Error: undeclared attribute on walker
    }
}

# --- class: dynamic attributes ARE allowed (Python style) ---
class FlexibleClass {
    has name: str;

    def init(self: FlexibleClass, name: str) -> None {
        self.name = name;           # Ok: declared field
        self.extra = 42;            # Ok: class allows dynamic attributes
    }
}

with entry {
    o = MyObj(name="test");
    n = MyNode(label="node1");
    e = MyEdge(weight=1.5);
    w = MyWalker(target="goal");
    c = FlexibleClass(name="flex");
}
