"""Platform constants a portable module holds as 0, read from the selected variant."""

import from jaclang.runtime.python.modules.errno_constants { EAGAIN, ENOENT }
import from jaclang.runtime.python.layouts_platform {
    EAGAIN as LAYOUT_EAGAIN,
    PTHREAD_ATTR_SIZE
}

glob ATTR_TWICE: Final[i64] = PTHREAD_ATTR_SIZE * 2;

def errno_pair -> int {
    pairs = [(1, EAGAIN), (2, ENOENT)];
    total = 0;
    for (_, code) in pairs {
        total = total * 1000 + code;
    }
    return total;
}

def layout_eagain -> int {
    return int(LAYOUT_EAGAIN);
}

def attr_buffer -> int {
    attrs = __alloca(PTHREAD_ATTR_SIZE);
    __mem_store_i64(attrs, 5);
    return __mem_load_i64(attrs);
}

def attr_twice_buffer -> int {
    attrs = __alloca(ATTR_TWICE);
    __mem_store_i64(attrs, 6);
    return __mem_load_i64(attrs);
}

def attr_twice -> int {
    return int(ATTR_TWICE);
}
