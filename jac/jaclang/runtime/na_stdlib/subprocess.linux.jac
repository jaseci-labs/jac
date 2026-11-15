import from ._subprocess_native {
    sp_waitpid,
    sp_kill,
    sp_strvec,
    sp_strvec_free,
    sp_fa_new,
    sp_fa_dup2,
    sp_fa_close,
    sp_fa_open,
    sp_fa_chdir,
    sp_fa_free,
    sp_spawn,
    sp_pipe,
    sp_close,
    sp_read,
    sp_write,
    sp_usleep,
    sp_now_ms,
    sp_pollio
}
import from ._errno_native { EINTR, last_errno, raise_errno, raise_os_error }
import from signal { signal, SIG_IGN, SIGPIPE }

glob:pub PIPE: int = -1,
     STDOUT: int = -2,
     DEVNULL: int = -3;

glob _WNOHANG: int = 1,
     _SIGKILL: int = 9,
     _SIGTERM: int = 15,
     _ECHILD: int = 10,
     _O_RDWR: int = 2,
     _POLLIN: int = 1,
     _POLLOUT: int = 4,
     _POLLERR: int = 8,
     _POLLHUP: int = 16,
     _POLLNVAL: int = 32,
     _WRITE_CHUNK: int = 4096,
     _READ_CHUNK: int = 65536,
     _sigpipe_ignored: bool = False;

obj:pub SubprocessError(Exception) {}

obj:pub CalledProcessError(SubprocessError) {
    has returncode: int = 0,
        cmd: any = None,
        output: any = None,
        stderr: any = None,
        stdout: any = None;

    def postinit;
}

obj:pub TimeoutExpired(SubprocessError) {
    has cmd: any = None,
        timeout: any = None,
        output: any = None,
        stderr: any = None,
        stdout: any = None;

    def postinit;
}

obj:pub CompletedProcess {
    has args: any = None,
        returncode: int = 0,
        stdout: any = None,
        stderr: any = None;

    def check_returncode;
}

def _to_bytes(data: any, text: bool) -> bytes;

def _decode_status(st: int) -> int;

def _deadline_ms(timeout: (int | float | None)) -> int;

obj:pub Popen {
    has args: (str | list[str]) = "",
        stdin: (int | None) = None,
        stdout: (int | None) = None,
        stderr: (int | None) = None,
        text: bool = False,
        cwd: (str | None) = None,
        env: (dict[str, str] | None) = None,
        shell: bool = False,
        returncode: (int | None) = None,
        pid: int = -1,
        _stdin_w: int = -1,
        _stdout_r: int = -1,
        _stderr_r: int = -1;

    def postinit;
    def _fa_stdio(
        fa: int, in_pipe: list[int], out_pipe: list[int], err_pipe: list[int]
    ) -> int;

    def _render(data: bytes) -> any;
    def _reap(options: int) -> int;
    def poll -> any;
    def `wait(timeout: (int | float | None) = None) -> int;
    def _raise_timeout(timeout: (int | float | None), out: bytes, err: bytes);
    def communicate(
        input: any = None, timeout: (int | float | None) = None
    ) -> tuple[(any, any)];

    def kill;
    def terminate;
}

def:pub run(
    args: (str | list[str]),
    capture_output: bool = False,
    text: bool = False,
    check: bool = False,
    input: any = None,
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False,
    stdin: (int | None) = None,
    stdout: (int | None) = None,
    stderr: (int | None) = None
) -> CompletedProcess;

def:pub call(
    args: (str | list[str]),
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> int;

def:pub check_call(
    args: (str | list[str]),
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> int;

def:pub check_output(
    args: (str | list[str]),
    text: bool = False,
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> any;
