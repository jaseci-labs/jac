# Middle module for the cross-module obj-field walk-order gate (#7871 F).
# The obj field type and default reference an obj defined in xmodfield_far,
# a module the native pass walks after this one.

import from xmodfield_far { Point, make_point }

obj Wrapper {
    has inner: Point = make_point(1, 2),
        scale: int = 10;
}

def wrapper_checksum -> int {
    w: Wrapper = Wrapper();
    return (w.inner.x * 100 + w.inner.y) * w.scale;
}
