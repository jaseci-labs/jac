"""read() reads to end of file, not to the size the system reports.

A file that reports no size, such as anything under /proc, a pipe or a
character device, used to read as empty: read() seeked to the end, took
ftell() as the length and issued one fread() of exactly that many bytes.
"""

import ctypes;
import from tests.support { native_address }
import os;
import from tests.support { compile_native }

test "read() returns the whole file even when its size reports as zero" {
    if not os.path.exists("/proc/self/status") {
        testskip("procfs is where a zero-sized regular file is available");
    }
    (eng, _) = compile_native("read_to_eof.jac");
    expected_len = len(open("/proc/self/status").read());
    assert expected_len > 100 , "the reference read came back too small";
    for (name, want) in [
        ("status_len", expected_len),
        ("status_has_marker", 1),
        ("cmdline_len", len(open("/proc/self/cmdline", "rb").read()))
    ] {
        address = native_address(eng, name);
        assert isinstance(address, int) and address != 0 , name;
        got = ctypes.CFUNCTYPE(ctypes.c_int64)(address)();
        assert got == want , f"{name}: {got} != {want}";
    }
}
