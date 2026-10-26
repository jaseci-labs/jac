impl _mi(mode: list[any], i: int) -> int {
    v = mode[i];
    if isinstance(v, int) {
        r: int = v;
        return r;
    }
    return 0;
}

impl _set_cc(value: any) -> list[any] {
    out: list[any] = [];
    if isinstance(value, list) {
        i: int = 0;
        while i < len(value) {
            if i == VMIN {
                out.append(1);
            } elif i == VTIME {
                out.append(0);
            } else {
                out.append(value[i]);
            }
            i += 1;
        }
    }
    return out;
}

impl setraw(fd: int, when: int = TCSAFLUSH) -> list[any] {
    original: list[any] = tcgetattr(fd);
    cc: list[any] = _set_cc(original[CC]);
    new: list[any] = [
        _mi(original, IFLAG)
            & ~(
                IGNBRK
                | BRKINT
                | IGNPAR
                | PARMRK
                | INPCK
                | ISTRIP
                | INLCR
                | IGNCR
                | ICRNL
                | IXON
                | IXANY
                | IXOFF
            ),
        _mi(original, OFLAG) & ~OPOST,
        (_mi(original, CFLAG) & ~(PARENB | CSIZE)) | CS8,
        _mi(original, LFLAG)
            & ~(
                ECHO | ECHOE | ECHOK | ECHONL | ICANON | IEXTEN | ISIG | NOFLSH | TOSTOP
            ),
        original[4],
        original[5],
        cc
    ];
    tcsetattr(fd, when, new);
    return original;
}

impl setcbreak(fd: int, when: int = TCSAFLUSH) -> list[any] {
    original: list[any] = tcgetattr(fd);
    cc: list[any] = _set_cc(original[CC]);
    new: list[any] = [
        original[IFLAG],
        original[OFLAG],
        original[CFLAG],
        _mi(original, LFLAG) & ~(ECHO | ICANON),
        original[4],
        original[5],
        cc
    ];
    tcsetattr(fd, when, new);
    return original;
}
