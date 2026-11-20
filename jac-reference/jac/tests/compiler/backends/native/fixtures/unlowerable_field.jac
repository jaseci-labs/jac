# Fixture for the no-rescue diagnostic gate (#7871 F). A field whose declared
# type has no native lowering erases to an opaque slot, and the refusal it
# would have raised is spent on the field rather than on the module
# (`_opaque_field_if_unlowerable`). The gate is what that erasure costs: the
# slot holds nothing the native side wrote, so every callable that touches it
# must refuse by name instead of reading its bits.
#
# `read_view` is the touch, and must demote. `holder_tag` and `read_tag` never
# name the erased slot, and must keep lowering -- that contrast is the whole
# point of spending the refusal on the field.

obj Holder {
    has view: memoryview,
        tag: int = 7;
}

def read_view(h: Holder) -> int {
    v = h.view;
    return 1;
}

def read_tag(h: Holder) -> int {
    return h.tag;
}

def holder_tag -> int {
    return 7;
}

glob _x: int = 1;
