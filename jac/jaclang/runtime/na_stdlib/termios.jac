glob TCSANOW: int = _TCSANOW,
     TCSADRAIN: int = _TCSADRAIN,
     TCSAFLUSH: int = _TCSAFLUSH;

glob TIOCGWINSZ: int = _TIOCGWINSZ;

glob VINTR: int = _VINTR,
     VQUIT: int = _VQUIT,
     VERASE: int = _VERASE,
     VKILL: int = _VKILL,
     VEOF: int = _VEOF,
     VTIME: int = _VTIME,
     VMIN: int = _VMIN,
     VSTART: int = _VSTART,
     VSTOP: int = _VSTOP,
     VSUSP: int = _VSUSP,
     VEOL: int = _VEOL,
     VREPRINT: int = _VREPRINT,
     VDISCARD: int = _VDISCARD,
     VWERASE: int = _VWERASE,
     VLNEXT: int = _VLNEXT,
     VEOL2: int = _VEOL2;

glob IGNBRK: int = _IGNBRK,
     BRKINT: int = _BRKINT,
     IGNPAR: int = _IGNPAR,
     PARMRK: int = _PARMRK,
     INPCK: int = _INPCK,
     ISTRIP: int = _ISTRIP,
     INLCR: int = _INLCR,
     IGNCR: int = _IGNCR,
     ICRNL: int = _ICRNL,
     IXON: int = _IXON,
     IXANY: int = _IXANY,
     IXOFF: int = _IXOFF;

glob OPOST: int = _OPOST,
     ONLCR: int = _ONLCR;

glob CSIZE: int = _CSIZE,
     CSTOPB: int = _CSTOPB,
     CREAD: int = _CREAD,
     PARENB: int = _PARENB,
     PARODD: int = _PARODD,
     CS7: int = _CS7,
     CS8: int = _CS8,
     HUPCL: int = _HUPCL;

glob ECHO: int = _ECHO,
     ECHOE: int = _ECHOE,
     ECHOK: int = _ECHOK,
     ECHONL: int = _ECHONL,
     ICANON: int = _ICANON,
     IEXTEN: int = _IEXTEN,
     ISIG: int = _ISIG,
     NOFLSH: int = _NOFLSH,
     TOSTOP: int = _TOSTOP;

def _fail(op: str);

def:pub tcgetattr(fd: int) -> list[any];

def _cc_byte(e: any) -> int;

def _pack_attrs(base: bytes, attrs: list[any]) -> bytes;

def:pub tcsetattr(fd: int, when: int, attrs: list[any]);

def _put_byte(buf: bytes, off: int, value: int) -> bytes;
