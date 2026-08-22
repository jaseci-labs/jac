"""Fixture: the consumer's own `Tone` is a function, not the imported enum.

The enum-constructor hook has to resolve its target through the callee's type
rather than its spelling: `Tone` here is this module's function, while an
imported module's enum carries the same name into the layout registry. `2` is
a declared member value of that enum, so a name-keyed hook would validate it,
return it unchanged, and print 2 where 6 is the answer.
"""

import from enum_ctor_shadow_lib { boost }


def Tone(x: int) -> int {
    return x * 3;
}


def run -> int {
    print(Tone(2));
    print(boost(2));
    return 0;
}


with entry {
    run();
}
