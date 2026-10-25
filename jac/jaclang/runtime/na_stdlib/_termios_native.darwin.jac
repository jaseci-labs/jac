import from c { def tcgetattr(fd: i32, buf: bytes) -> i32;  }
import from c { def tcsetattr(fd: i32, act: i32, buf: bytes) -> i32;  }
import from c { def cfgetispeed(buf: bytes) -> u64;  }
import from c { def cfgetospeed(buf: bytes) -> u64;  }
import from c { def cfsetispeed(buf: bytes, speed: u64) -> i32;  }
import from c { def cfsetospeed(buf: bytes, speed: u64) -> i32;  }

glob _T_SIZE: int = 72,
     _OFF_IFLAG: int = 0,
     _OFF_OFLAG: int = 8,
     _OFF_CFLAG: int = 16,
     _OFF_LFLAG: int = 24,
     _OFF_CC: int = 32,
     _NCCS: int = 20,
     _FLAG_BYTES: int = 8;

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

glob _TIOCGWINSZ: int = 1074295912;

glob _VINTR: int = 8,
     _VQUIT: int = 9,
     _VERASE: int = 3,
     _VKILL: int = 5,
     _VEOF: int = 0,
     _VTIME: int = 17,
     _VMIN: int = 16,
     _VSTART: int = 12,
     _VSTOP: int = 13,
     _VSUSP: int = 10,
     _VEOL: int = 1,
     _VREPRINT: int = 6,
     _VDISCARD: int = 15,
     _VWERASE: int = 4,
     _VLNEXT: int = 14,
     _VEOL2: int = 2;

glob _IGNBRK: int = 1,
     _BRKINT: int = 2,
     _IGNPAR: int = 4,
     _PARMRK: int = 8,
     _INPCK: int = 16,
     _ISTRIP: int = 32,
     _INLCR: int = 64,
     _IGNCR: int = 128,
     _ICRNL: int = 256,
     _IXON: int = 512,
     _IXANY: int = 2048,
     _IXOFF: int = 1024;

glob _OPOST: int = 1,
     _ONLCR: int = 2;

glob _CSIZE: int = 768,
     _CSTOPB: int = 1024,
     _CREAD: int = 2048,
     _PARENB: int = 4096,
     _PARODD: int = 8192,
     _CS7: int = 512,
     _CS8: int = 768,
     _HUPCL: int = 16384;

glob _ECHO: int = 8,
     _ECHOE: int = 2,
     _ECHOK: int = 4,
     _ECHONL: int = 16,
     _ICANON: int = 256,
     _IEXTEN: int = 1024,
     _ISIG: int = 128,
     _NOFLSH: int = 2147483648,
     _TOSTOP: int = 4194304;
