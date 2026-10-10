"""C standard library (libc) FFI bindings for the Jac-native runtime.

Centralises every libc symbol used across the engine so that no module
imports directly from the .so path.

Symbols grouped by category:
  - Time / PRNG   : time, srand48, drand48
  - I/O           : write, read
  - File I/O      : fopen, fread, fclose
  - Memory        : calloc, memcpy
  - Process       : getpid, _exit, getcwd, getenv

Bun reference:
  bun/src/bun.js/bindings/ — various POSIX wrappers
"""

import from "libc.so.6" {
    # ── Time / PRNG ───────────────────────────────────────────────────────────
    def time(t: int) -> int;  def srand48(seed: int) -> None;  def drand48 -> float;
    # ── Low-level I/O ─────────────────────────────────────────────────────────
    def write(fd: int, buf: str, count: int) -> int;  def read(
        fd: int, buf: int, count: int
    ) -> int;  def poll(fds: int, nfds: int, timeout: int) -> int;   # struct pollfd* (fd i32, events i16, revents i16)
    # ── Buffered file I/O ─────────────────────────────────────────────────────
    def fopen(path: str, mode: str) -> int;  def fread(
        buf: int, size: int, count: int, stream: int
    ) -> int;  def fwrite(buf: int, size: int, count: int, stream: int) -> int;  def fclose(
        stream: int
    ) -> i32;  def fflush(stream: int) -> i32;
    # ── Memory ────────────────────────────────────────────────────────────────
    def calloc(n: int, size: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def memmove(dst: int, src: int, n: int) -> int;  def memset(
        dst: int, c: i32, n: int
    ) -> int;  def free(ptr: int) -> None;  def realloc(ptr: int, size: int) -> int;
    # ── Process ───────────────────────────────────────────────────────────────
    def fork -> int;  def execve(path: str, argv: int, envp: int) -> int;  def execvpe(
        file: str, argv: int, envp: int
    ) -> int;  def posix_spawn(  # PATH search + custom env (glibc)
        pid: int, path: str, file_actions: int, attrp: int, argv: int, envp: int
    ) -> int;  def posix_spawnp(
        pid: int, file: str, file_actions: int, attrp: int, argv: int, envp: int
    ) -> int;  def posix_spawn_file_actions_init(fa: int) -> int;  def posix_spawn_file_actions_destroy(
        fa: int
    ) -> int;  def posix_spawn_file_actions_adddup2(
        fa: int, fd: int, newfd: int
    ) -> int;  def posix_spawn_file_actions_addclose(fa: int, fd: int) -> int;
    # glibc extension — chdir in the child without fork (avoids RLIMIT_AS COW blow-up)
    def posix_spawn_file_actions_addchdir_np(fa: int, path: str) -> int;  def waitpid(
        pid: int, status: int, options: int
    ) -> int;  def pipe(fds: int) -> int;  def dup2(oldfd: int, newfd: int) -> int;  def dup(
        fd: int
    ) -> int;  def setsid -> int;  def getpid -> i32;  def getppid -> int;  def _exit(
        code: int
    ) -> None;  def abort -> None;  def getcwd(buf: int, size: int) -> str;  def mkdtemp(
        template: int
    ) -> int;  def chdir(path: str) -> int;  def getenv(name: str) -> str;  def setenv(
        name: str, value: str, overwrite: int
    ) -> int;  def kill(pid: int, sig: int) -> int;  def unlink(path: str) -> int;  def umask(
        mask: int
    ) -> int;  def getuid -> int;  def getgid -> int;  def geteuid -> int;  def getegid -> int;  def setuid(
        uid: int
    ) -> int;  def setgid(gid: int) -> int;  def seteuid(uid: int) -> int;  def setegid(
        gid: int
    ) -> int;  def getgroups(size: int, list: int) -> int;  def sysconf(
        name: int
    ) -> int;  def getrusage(who: int, usage: int) -> int;  def isatty(  # RUSAGE_SELF=0
        fd: int
    ) -> int;  def tcgetattr(fd: int, termios_p: int) -> int;  def tcsetattr(
        fd: int, optional_actions: int, termios_p: int
    ) -> int;  def cfmakeraw(termios_p: int) -> None;
    # ── Networking ────────────────────────────────────────────────────────────
    def getaddrinfo(host: str, service: str, hints: int, res: int) -> int;  def freeaddrinfo(
        res: int
    ) -> None;  def getnameinfo(
        sa: int,
        salen: int,
        host: int,
        hostlen: int,
        serv: int,
        servlen: int,
        flags: int
    ) -> int;  def socket(domain: int, sock_type: int, protocol: int) -> int;  def bind(
        fd: int, addr: int, addrlen: int
    ) -> int;  def listen(fd: int, backlog: int) -> int;  def accept(
        fd: int, addr: int, addrlen: int
    ) -> int;  def connect(fd: int, addr: int, addrlen: int) -> int;  def shutdown(
        fd: int, how: int
    ) -> int;  def send(fd: int, buf: str, length: int, flags: int) -> int;  def recv(
        fd: int, buf: int, length: int, flags: int
    ) -> int;  def sendto(
        fd: int, buf: str, length: int, flags: int, dest_addr: int, addrlen: int
    ) -> int;  def recvfrom(
        fd: int, buf: int, length: int, flags: int, src_addr: int, addrlen: int
    ) -> int;  def getsockname(fd: int, addr: int, addrlen: int) -> int;  def getpeername(
        fd: int, addr: int, addrlen: int
    ) -> int;  def close(fd: int) -> int;  def setsockopt(
        fd: int, level: int, optname: int, optval: int, optlen: int
    ) -> int;  def getsockopt(
        fd: int, level: int, optname: int, optval: int, optlen: int
    ) -> int;  def htons(hostshort: int) -> int;  def htonl(hostlong: int) -> int;  def ntohs(
        netshort: int
    ) -> int;  def inet_pton(af: int, src: str, dst: int) -> int;  def inet_ntop(
        af: int, src: int, dst: int, size: int
    ) -> str;  def gai_strerror(errcode: int) -> str;
    # ── File-descriptor control ───────────────────────────────────────────────
    def fcntl(fd: int, cmd: int, arg: int) -> int;  def signal(
        sig: int, handler: int
    ) -> int;
    # ── errno ─────────────────────────────────────────────────────────────────
    def __errno_location -> int;
    # ── Resource limits ───────────────────────────────────────────────────────
    def setrlimit(resource: int, rlim: int) -> int;
}

"""Raise RLIMIT_STACK to unlimited so the recursive-descent parser can handle
deeply nested JS code (e.g. Vite's chunks/node.js) without overflowing the
default 8 MB thread stack.  On Linux the hard limit is typically RLIM_INFINITY
for non-privileged users, so the soft limit can always be raised.

  RLIMIT_STACK = 3
  struct rlimit { rlim_cur: u64, rlim_max: u64 }  (16 bytes)
  RLIM_INFINITY = 0xFFFFFFFFFFFFFFFF
"""
def:pub stack_expand -> None {
    rlim_ptr: int = calloc(1, 16);  # struct rlimit { rlim_cur, rlim_max }
    if rlim_ptr == 0 {
        return;  # allocation failed — keep default stack limit
    }
    memset(rlim_ptr, 0xFF, 16);  # RLIM_INFINITY for both fields
    setrlimit(3, rlim_ptr);  # RLIMIT_STACK = 3
    free(rlim_ptr);
}

"""Ignore SIGPIPE so writes to closed pipes return EPIPE instead of terminating."""
def:pub ignore_sigpipe {
    _SIG_IGN: int = 1;
    _SIGPIPE: int = 13;
    signal(_SIGPIPE, _SIG_IGN);
}

"""Return the current thread-local errno as a signed integer.
On Linux `errno` is a macro for `*__errno_location()`. Reads via the raw
__mem_load_i32 intrinsic — errno's bytes are usually zero, which the old
str-reinterpret read tripped over once string subscripts became
length-checked."""
def:pub get_errno -> int {
    return int(__mem_load_i32(__errno_location()));
}
