import from "libc.so.6" {
    def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def read(
        fd: i32, buf: str, count: i32
    ) -> i32;  def write(fd: i32, buf: str, count: i32) -> i32;  def dup2(
        oldfd: i32, newfd: i32
    ) -> i32;  def fcntl(fd: i32, cmd: i32, arg: i32) -> i32;  def ioctl(
        fd: i32, request: i64, arg: str
    ) -> i32;  def tcgetattr(fd: i32, term: str) -> i32;  def tcsetattr(
        fd: i32, opt: i32, term: str
    ) -> i32;  def poll(fds: str, nfds: i32, timeout: i32) -> i32;  def calloc(
        n: int, sz: int
    ) -> int;  def free(p: int) -> None;  def memset(s: int, c: i32, n: int) -> int;  def memcpy(
        dst: int, src: str, n: int
    ) -> int;
}

glob O_NONBLOCK: int = 2048,
     TIOCGWINSZ: int = 0x5413,
     IXON: int = 0x00000400,
     ECHONL: int = 0x00000040,
     ICANON: int = 0x00000002,
     ISIG: int = 0x00000001,
     IEXTEN: int = 0x00008000,
     CSIZE: int = 0x00000030,
     PARENB: int = 0x00000100,
     CS8: int = 0x00000030,
     TERMIOS_SZ: int = 60,
     VMIN_OFF: int = 22,
     VMIN_VAL: int = 0,
     VTIME_OFF: int = 23,
     VTIME_VAL: int = 1;
