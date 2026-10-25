import from c { def tcgetattr(fd: i32, buf: bytes) -> i32;  }
import from c { def tcsetattr(fd: i32, act: i32, buf: bytes) -> i32;  }
import from c { def cfgetispeed(buf: bytes) -> u32;  }
import from c { def cfgetospeed(buf: bytes) -> u32;  }
import from c { def cfsetispeed(buf: bytes, speed: u32) -> i32;  }
import from c { def cfsetospeed(buf: bytes, speed: u32) -> i32;  }

glob _T_SIZE: int = 60,
     _OFF_IFLAG: int = 0,
     _OFF_OFLAG: int = 4,
     _OFF_CFLAG: int = 8,
     _OFF_LFLAG: int = 12,
     _OFF_CC: int = 17,
     _NCCS: int = 32,
     _FLAG_BYTES: int = 4;

def:pub new_buf -> bytes;

def:pub word_at(buf: bytes, off: int) -> int;

def:pub put_word(buf: bytes, off: int, v: int) -> bytes;

def:pub get_attrs(fd: int) -> tuple[(bytes, int)];

def:pub set_attrs(fd: int, when: int, blob: bytes) -> int;

def:pub in_speed(buf: bytes) -> int;

def:pub out_speed(buf: bytes) -> int;

def:pub set_speeds(buf: bytes, ispeed: int, ospeed: int) -> int;

glob _TCSANOW: int = 0,
     _TCSADRAIN: int = 1,
     _TCSAFLUSH: int = 2;

glob _TIOCGWINSZ: int = 21523;

glob _VINTR: int = 0,
     _VQUIT: int = 1,
     _VERASE: int = 2,
     _VKILL: int = 3,
     _VEOF: int = 4,
     _VTIME: int = 5,
     _VMIN: int = 6,
     _VSWTC: int = 7,
     _VSTART: int = 8,
     _VSTOP: int = 9,
     _VSUSP: int = 10,
     _VEOL: int = 11,
     _VREPRINT: int = 12,
     _VDISCARD: int = 13,
     _VWERASE: int = 14,
     _VLNEXT: int = 15,
     _VEOL2: int = 16;

glob _IGNBRK: int = 1,
     _BRKINT: int = 2,
     _IGNPAR: int = 4,
     _PARMRK: int = 8,
     _INPCK: int = 16,
     _ISTRIP: int = 32,
     _INLCR: int = 64,
     _IGNCR: int = 128,
     _ICRNL: int = 256,
     _IXON: int = 1024,
     _IXANY: int = 2048,
     _IXOFF: int = 4096;

glob _OPOST: int = 1,
     _ONLCR: int = 4;

glob _CSIZE: int = 48,
     _CSTOPB: int = 64,
     _CREAD: int = 128,
     _PARENB: int = 256,
     _PARODD: int = 512,
     _CS7: int = 32,
     _CS8: int = 48,
     _HUPCL: int = 1024;

glob _ECHO: int = 8,
     _ECHOE: int = 16,
     _ECHOK: int = 32,
     _ECHONL: int = 64,
     _ICANON: int = 2,
     _IEXTEN: int = 32768,
     _ISIG: int = 1,
     _NOFLSH: int = 128,
     _TOSTOP: int = 256;
