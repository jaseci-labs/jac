"""Connection operands of unparameterized collection type.

`a ++> b` (and `del a -->? b` and the `+>:T:+>` / `-->:T:->` typed
forms) accept lists/tuples/sets/frozensets only when their element
type can be verified as a node. A *bare* (unparameterized) collection
— `list`, `tuple`, `set`, `frozenset` with no type arguments — would
otherwise smuggle through unchecked element types.

Diagnostic:
    E1118 — Connect/disconnect operand has unparameterized collection
            type whose element types cannot be verified.
"""

node Place { has name: str; }
edge Road { has length: int = 0; }

def make_bare_list() -> list { return []; }
def make_bare_tuple() -> tuple { return (); }
def make_bare_set() -> set { return {1, 2}; }
def make_bare_frozenset() -> frozenset { return frozenset(); }

with entry {
    a: Place = Place(name="A");
    b: Place = Place(name="B");

    # --- Bad: unparameterized collection on right side (E1118 each) ---
    bare_l: list = [];
    a ++> bare_l;                                    # E1118
    a ++> make_bare_list();                          # E1118
    bare_t: tuple = ();
    a ++> bare_t;                                    # E1118
    a ++> make_bare_tuple();                         # E1118
    bare_s: set = {1};
    a ++> bare_s;                                    # E1118
    a ++> make_bare_set();                           # E1118
    bare_f: frozenset = frozenset();
    a ++> bare_f;                                    # E1118
    a ++> make_bare_frozenset();                     # E1118

    # --- Bad: unparameterized list on left side (E1118 each) ---
    bare_l ++> b;                                    # E1118
    make_bare_list() ++> b;                          # E1118

    # --- Bad: unparameterized variants on disconnect (E1118 each) ---
    a del --> bare_l;                                # E1118
    bare_l del --> b;                                # E1118
    a del ->:Road:-> bare_l;                         # E1118 (typed-edge form)

    # --- Good: parameterized list of nodes — no E1118 ---
    typed_l: list[Place] = [Place(name="X")];
    a ++> typed_l;                                   # ok
    typed_l ++> b;                                   # ok
    a del --> typed_l;                               # ok

    # --- Good: list literal with element type inferable — no E1118 ---
    a ++> [Place(name="Y"), Place(name="Z")];        # ok
    a ++> [b];                                       # ok

    # --- Good: single node operand — no E1118 ---
    a ++> b;                                         # ok
    a del --> b;                                     # ok
}
