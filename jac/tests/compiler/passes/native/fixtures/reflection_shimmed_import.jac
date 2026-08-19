"""Reflection beside an na_stdlib import -- the crash, not just the silence.

A reflection call that lowered to nothing handed a null back to whatever
consumed it. Alone that produced a blank line; with a shimmed stdlib module
pulled in beside it, the null reached a consumer that dereferenced it and
`jac run` died with `Segmentation fault at address 0x0 / aborting due to
recursive panic` -- no diagnostic, no file, no line.

Refusing at the capability gate removes the crash by construction: the null is
never created, because the call never reaches lowering.
"""

import json;


obj Foo {
    has x: int = 1;
}


with entry {
    f = Foo();
    print(json.dumps({"present": 1}));
    print(hasattr(f, "x"));
}
