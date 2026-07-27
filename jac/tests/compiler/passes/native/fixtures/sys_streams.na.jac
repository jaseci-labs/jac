"""Native sys.stdout / sys.stderr stream objects (#7593 item 4).

The write() count is laundered through a comparison because the sv
checker types sys.stdout as Unknown (typeshed `TextIO | MaybeNone` does
not resolve), so returning it from an int-typed def fails E1001. The
comparison still pins the native byte-count value.
"""

import sys;

def write_out() -> int {
    n = sys.stdout.write("out-bytes\n");
    sys.stdout.flush();
    return 10 if n == 10 else 0;
}

def write_err() -> int {
    n = sys.stderr.write("err-7\n");
    sys.stderr.flush();
    return 6 if n == 6 else 0;
}
