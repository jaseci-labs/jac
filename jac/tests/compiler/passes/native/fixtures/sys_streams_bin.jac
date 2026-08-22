"""AOT fixture: sys.stdout/sys.stderr share the libc stdio buffers with
print(), and stderr bytes stay on fd 2 (#7593 item 4)."""

import sys;

with entry {
    n = sys.stdout.write("A:");
    sys.stdout.write("bc\n");
    sys.stderr.write("E:err\n");
    print("n", n);
}
