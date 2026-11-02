"""`isinstance` in a module that never imports the operand's class.

Only `xmod_isinstance_foreign_base` is imported here, so this module's
candidate vtables and class index list `Actor` and `Player` but not the
subclasses `xmod_isinstance_foreign_leaf` defines. Each check below has to ask
the object's own vtable what it derives from.
"""

import from xmod_isinstance_foreign_base { Thing, Actor, NThing, NActor }

def foreign_is_actor(thing: Thing) -> int {
    return 1 if isinstance(thing, Actor) else 0;
}

def foreign_is_kind(thing: Thing, kind: type[Thing]) -> int {
    return 1 if isinstance(thing, kind) else 0;
}

walker ForeignLook {
    has found: int = -1;

    can look with NThing entry {
        self.found = 1 if isinstance(here, NActor) else 0;
    }
}

def foreign_node_is_actor(thing: NThing) -> int {
    look = thing spawn ForeignLook();
    return look.found;
}
