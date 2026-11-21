"""`NameAtom.sem_token`'s shape, reduced to the two things that block it.

Both halves are read back by value, because both have a failure mode that a
seam count cannot see.

An enum member's value is derived from the *syntax* of its initialiser, so a
member written `1 << 0` has no value at all. For a Jac `enum` that silently
becomes `0` -- `CLASS` and `ENUM` both answer `0`, colliding with the literal
`NAMESPACE`, and no diagnostic says so -- while a class-form enum
(`class M(IntFlag)`, which is what `JacSemTokenModifier` is) drops the member
from its layout entirely and the read refuses with E5092. `NAMESPACE`,
`PARAM` and `LITERAL_ONE` are literals so they lower today; every other
member here is a constant expression.

`__class__.__name__` needs the *runtime* class of its receiver, and that
works off a receiver whose static type names one archetype and lowers to a
pointer to it (`known_name_rank` below, which walks vtable slot 0). It did
not work when the receiver lowers to something else. Two such storages are
here, and `sem_token` reads through the first: `type(self.type).__name__`,
where `self.type` is `TypeBase | None` -- a class reached through a
typing-only import, so the slot is an opaque object pointer with no struct
behind it, which is what a type-erased generic slot (`Box[T].held`) is too.
The second is an option, a JacOpt whose payload only means anything on the
present arm.

`sem_token_of` puts both halves in the shape the real accessor has, including
the `tuple[A, B] | None` return: an absent answer is `None`, and a present one
is a tuple of one member from each enum.

Refs #8039, #8052
"""

import from enum { IntFlag }

enum TokKind: int { NAMESPACE = 0, CLASS = 1 << 1, ENUM = (1 << 1) | 1, PARAM = 7 }

class TokMod(IntFlag) {
    with entry {
        DECLARATION = 1 << 0;
        DEFINITION = 1 << 1;
        READONLY = 1 << 2;
        LITERAL_ONE = 1;
    }
}

obj Node {
    has n: int = 3;
}

obj Leaf(Node) {
    has l: int = 4;
}

obj Branch(Node) {
    has b: int = 5;
}

"""A type-erased generic slot: the receiver is an opaque object pointer."""
obj Box[T] {
    has held: T;
}

"""An option: the receiver is a JacOpt, not the payload pointer."""
obj Slot {
    has held: (Node | None) = None;
}


"""A Jac `enum` whose members are constant expressions."""
def kind_of(pick: int) -> int {
    if pick == 0 {
        return TokKind.NAMESPACE;
    }
    if pick == 1 {
        return TokKind.CLASS;
    }
    if pick == 2 {
        return TokKind.ENUM;
    }
    return TokKind.PARAM;
}


"""A class-form enum (`IntFlag`) whose members are constant expressions."""
def mod_of(pick: int) -> int {
    if pick == 0 {
        return TokMod.DECLARATION;
    }
    if pick == 1 {
        return TokMod.DEFINITION;
    }
    if pick == 2 {
        return TokMod.READONLY;
    }
    return TokMod.LITERAL_ONE;
}


"""The two enums combined, the way a `sem_token` return does."""
def kind_and_mod(pick: int) -> int {
    return kind_of(pick) * 100 + mod_of(pick);
}


def _rank(name: str) -> int {
    if name == "Leaf" {
        return 1;
    }
    if name == "Branch" {
        return 2;
    }
    if name == "Node" {
        return 3;
    }
    if name == "NoneType" {
        return 9;
    }
    return 0;
}


"""`type(x).__name__` off the opaque generic slot."""
def open_name(pick: int) -> str {
    if pick == 1 {
        return type(Box(held=Leaf()).held).__name__;
    }
    if pick == 2 {
        return type(Box(held=Branch()).held).__name__;
    }
    return type(Box(held=Node()).held).__name__;
}


def open_name_rank(pick: int) -> int {
    return _rank(open_name(pick));
}


"""The `__class__` spelling of the same open read."""
def open_dunder_rank(pick: int) -> int {
    if pick == 1 {
        return _rank(Box(held=Leaf()).held.__class__.__name__);
    }
    if pick == 2 {
        return _rank(Box(held=Branch()).held.__class__.__name__);
    }
    return _rank(Box(held=Node()).held.__class__.__name__);
}


"""Fill the option slot: 0 leaves it unset, so its class is `NoneType`."""
def _fill(pick: int) -> Slot {
    s = Slot();
    if pick == 1 {
        s.held = Leaf();
    } elif pick == 2 {
        s.held = Branch();
    } elif pick == 3 {
        s.held = Node();
    }
    return s;
}


"""The same read off an option, whose payload is only live on one arm."""
def opt_name_rank(pick: int) -> int {
    return _rank(type(_fill(pick).held).__name__);
}


"""The control: a receiver whose static type names an archetype it lowers to.

This lowers today, through the class-name constant in vtable slot 0, and has
to keep answering the runtime class rather than the declared one.
"""
def _declared_name(n: Node) -> str {
    return n.__class__.__name__;
}


def known_name_rank(pick: int) -> int {
    if pick == 1 {
        return _rank(_declared_name(Leaf()));
    }
    if pick == 2 {
        return _rank(_declared_name(Branch()));
    }
    return _rank(_declared_name(Node()));
}


"""Both halves at once, in `NameAtom.sem_token`'s exact shape.

An open-receiver class-name read selects a member from each enum, and the
pair comes back as `tuple[A, B] | None`.
"""
def sem_token_of(pick: int) -> (tuple[(TokKind, TokMod)] | None) {
    if pick == 0 {
        return None;
    }
    name = type(_fill(pick).held).__name__;
    if name == "Leaf" {
        return (TokKind.CLASS, TokMod.DECLARATION);
    }
    if name == "Branch" {
        return (TokKind.ENUM, TokMod.DEFINITION);
    }
    return (TokKind.PARAM, TokMod.READONLY);
}


"""Decode the option and both members of the tuple back to one int."""
def sem_token_rank(pick: int) -> int {
    tok = sem_token_of(pick);
    if tok is None {
        return -1;
    }
    return tok[0] * 100 + tok[1];
}
