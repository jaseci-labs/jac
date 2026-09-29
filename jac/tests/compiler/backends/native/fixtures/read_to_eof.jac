"""Reading a whole file, including one whose size the system reports as zero."""

def status_len -> int {
    return len(open("/proc/self/status").read());
}

def status_has_marker -> int {
    return 1 if "VmHWM" in open("/proc/self/status").read() else 0;
}

def cmdline_len -> int {
    return len(open("/proc/self/cmdline", "rb").read());
}
