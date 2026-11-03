"""Platform constants a portable module holds as 0, read from the selected variant."""

import from jaclang.runtime.python.modules.errno_constants { EAGAIN, ENOENT }
import from jaclang.runtime.python.layouts_platform { EAGAIN as LAYOUT_EAGAIN }

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
