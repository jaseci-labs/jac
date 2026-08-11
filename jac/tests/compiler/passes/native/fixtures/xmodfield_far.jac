# Far module for the cross-module obj-field walk-order gate (#7871 F).
# Defines the obj that xmodfield_mid embeds as a field type; the native pass
# walks this module AFTER the module whose field types reference Point.

obj Point {
    has x: int = 0,
        y: int = 0;
}

def make_point(x: int, y: int) -> Point {
    p: Point = Point();
    p.x = x;
    p.y = y;
    return p;
}
