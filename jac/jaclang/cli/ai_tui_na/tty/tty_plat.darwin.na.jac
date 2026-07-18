import from "/usr/lib/libSystem.B.dylib" {
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

glob O_NONBLOCK: int = 4,
     TIOCGWINSZ: int = 0x40087468,
     IXON: int = 0x00000200,
     ECHONL: int = 0x00000010,
     ICANON: int = 0x00000100,
     ISIG: int = 0x00000080,
     IEXTEN: int = 0x00000400,
     CSIZE: int = 0x00000300,
     PARENB: int = 0x00001000,
     CS8: int = 0x00000300,
     TERMIOS_SZ: int = 44,
     VMIN_OFF: int = 32,
     VMIN_VAL: int = 1,
     VTIME_OFF: int = 33,
     VTIME_VAL: int = 0;
