import termios;

glob IFLAG: int = 0,
     OFLAG: int = 1,
     CFLAG: int = 2,
     LFLAG: int = 3,
     CC: int = 6;


def _mi(mode: list[any], i: int) -> int {
    v = mode[i];
    if isinstance(v, int) {
        r: int = v;
        return r;
    }
    return 0;
}


def _set_cc(mode: list[any]) {
    ccv = mode[CC];
    if isinstance(ccv, list) {
        ccn: list[any] = list(ccv);
        mode[CC] = ccn;
        if len(ccn) > termios.VMIN {
            ccn[termios.VMIN] = 1;
        }
        if len(ccn) > termios.VTIME {
            ccn[termios.VTIME] = 0;
        }
    }
}


def:pub cfmakeraw(mode: list[any]) {
    mode[IFLAG] = _mi(mode, IFLAG)
        & ~(
            termios.IGNBRK
            | termios.BRKINT
            | termios.IGNPAR
            | termios.PARMRK
            | termios.INPCK
            | termios.ISTRIP
            | termios.INLCR
            | termios.IGNCR
            | termios.ICRNL
            | termios.IXON
            | termios.IXANY
            | termios.IXOFF
        );
    mode[OFLAG] = _mi(mode, OFLAG) & ~termios.OPOST;
    mode[CFLAG] = _mi(mode, CFLAG) & ~(termios.PARENB | termios.CSIZE);
    mode[CFLAG] = _mi(mode, CFLAG) | termios.CS8;
    mode[LFLAG] = _mi(mode, LFLAG)
        & ~(
            termios.ECHO
            | termios.ECHOE
            | termios.ECHOK
            | termios.ECHONL
            | termios.ICANON
            | termios.IEXTEN
            | termios.ISIG
            | termios.NOFLSH
            | termios.TOSTOP
        );
    _set_cc(mode);
}


def:pub cfmakecbreak(mode: list[any]) {
    mode[LFLAG] = _mi(mode, LFLAG) & ~(termios.ECHO | termios.ICANON);
    _set_cc(mode);
}


def:pub setraw(fd: int, when: int = 2) -> list[any] {
    mode: list[any] = termios.tcgetattr(fd);
    new: list[any] = list(mode);
    cfmakeraw(new);
    termios.tcsetattr(fd, when, new);
    return mode;
}


def:pub setcbreak(fd: int, when: int = 2) -> list[any] {
    mode: list[any] = termios.tcgetattr(fd);
    new: list[any] = list(mode);
    cfmakecbreak(new);
    termios.tcsetattr(fd, when, new);
    return mode;
}
