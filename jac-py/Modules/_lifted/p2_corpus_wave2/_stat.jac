def _c_mode_ok(op: int) -> int {
    if (op < 0) {
        return 0;
    }
    return 1;
}

def stat_S_IMODE(omode: int) -> int {
    if not _c_mode_ok(omode) {
        return -1;
    }
    return omode & 4095;
}

def stat_S_IFMT(omode: int) -> int {
    if not _c_mode_ok(omode) {
        return -1;
    }
    return omode & 61440;
}
