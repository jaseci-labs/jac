"""Class patterns over archetypes an imported module defines."""

import from xmod_isinstance_lib { Shape, Circle, Square }

def shape_kind(k: int) -> int {
    s: Shape = Shape(tag=0);
    if k == 0 {
        s = Circle(tag=1, r=2);
    } elif k == 1 {
        s = Square(tag=2, s=3);
    }
    match s {
        case Circle():
            return 1;

        case Square():
            return 2;

    }
    return 0;
}
