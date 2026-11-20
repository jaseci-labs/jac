"""Module-qualified references to imported archetypes.

`lib.Circle` reaches the class through the module, not through a name this
module binds, so its struct key has to come from the class itself: the same
module-scoped native name `import from` would have produced.
"""

import xmod_isinstance_lib as lib;

def chk_qualified(k: int) -> int {
    x: any = 0;
    if k == 0 {
        x = lib.Circle(tag=1, r=2);
    } elif k == 1 {
        x = lib.Square(tag=2, s=3);
    } else {
        x = lib.OtherKid(o=4, k=5);
    }
    if isinstance(x, lib.Shape) {
        return 1;
    }
    return 0;
}
