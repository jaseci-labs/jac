def:pub new_buf -> bytes;

def:pub word_at(buf: bytes, off: int) -> int;

def:pub put_word(buf: bytes, off: int, v: int) -> bytes;

def:pub get_attrs(fd: int) -> tuple[(bytes, int)];

def:pub set_attrs(fd: int, when: int, blob: bytes) -> int;

def:pub in_speed(buf: bytes) -> int;

def:pub out_speed(buf: bytes) -> int;

def:pub set_speeds(buf: bytes, ispeed: int, ospeed: int) -> int;

glob _BRKINT: int,
     _CREAD: int,
     _CS7: int,
     _CS8: int,
     _CSIZE: int,
     _CSTOPB: int,
     _ECHO: int,
     _ECHOE: int,
     _ECHOK: int,
     _ECHONL: int,
     _HUPCL: int,
     _ICANON: int,
     _ICRNL: int,
     _IEXTEN: int,
     _IGNBRK: int,
     _IGNCR: int,
     _IGNPAR: int,
     _INLCR: int,
     _INPCK: int,
     _ISIG: int,
     _ISTRIP: int,
     _IXANY: int,
     _IXOFF: int,
     _IXON: int,
     _NCCS: int,
     _NOFLSH: int,
     _OFF_CC: int,
     _OFF_CFLAG: int,
     _OFF_IFLAG: int,
     _OFF_LFLAG: int,
     _OFF_OFLAG: int,
     _ONLCR: int,
     _OPOST: int,
     _PARENB: int,
     _PARMRK: int,
     _PARODD: int,
     _TCSADRAIN: int,
     _TCSAFLUSH: int,
     _TCSANOW: int,
     _TIOCGWINSZ: int,
     _TOSTOP: int,
     _VDISCARD: int,
     _VEOF: int,
     _VEOL: int,
     _VEOL2: int,
     _VERASE: int,
     _VINTR: int,
     _VKILL: int,
     _VLNEXT: int,
     _VMIN: int,
     _VQUIT: int,
     _VREPRINT: int,
     _VSTART: int,
     _VSTOP: int,
     _VSUSP: int,
     _VTIME: int,
     _VWERASE: int;
