# Fixture for the no-rescue diagnostic gate (#7871 F): a field whose declared
# type has no native lowering must be a loud E5092 naming the type, never a
# silent opaque i8* substitute.

obj Holder {
    has view: memoryview,
        tag: int = 7;
}

def holder_tag -> int {
    return 7;
}

glob _x: int = 1;
