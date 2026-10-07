import from _subprocess_native {
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
import from _errno_native { EINTR, last_errno, raise_errno, raise_os_error }
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

    def postinit {
        if self.stdout is None {
            self.stdout = self.output;
        }
    }
}

obj:pub TimeoutExpired(SubprocessError) {
    has cmd: any = None,
        timeout: any = None,
        output: any = None,
        stderr: any = None,
        stdout: any = None;

    def postinit {
        if self.stdout is None {
            self.stdout = self.output;
        }
    }
}

obj:pub CompletedProcess {
    has args: any = None,
        returncode: int = 0,
        stdout: any = None,
        stderr: any = None;

    def check_returncode {
        if self.returncode != 0 {
            raise CalledProcessError(
                returncode=self.returncode,
                cmd=self.args,
                output=self.stdout,
                stderr=self.stderr
            );
        }
    }
}

def _to_bytes(data: any, text: bool) -> bytes {
    if isinstance(data, bytes) {
        return data;
    }
    if isinstance(data, bytearray) {
        return bytes(data);
    }
    if isinstance(data, str) and text {
        return data.encode();
    }
    raise TypeError("a bytes-like object is required");
}

def _decode_status(st: int) -> int {
    if (st & 0x7f) == 0 {
        return (st >> 8) & 0xff;
    }
    return -(st & 0x7f);
}

def _deadline_ms(timeout: (int | float | None)) -> int {
    if isinstance(timeout, int) {
        return sp_now_ms() + timeout * 1000;
    }
    if isinstance(timeout, float) {
        return sp_now_ms() + int(timeout * 1000);
    }
    return -1;
}

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

    def postinit {
        if not _sigpipe_ignored {
            signal(SIGPIPE, SIG_IGN);
            _sigpipe_ignored = True;
        }
        argv: list[str] = [];
        if self.shell {
            argv = ["/bin/sh", "-c"];
            if isinstance(self.args, str) {
                argv.append(self.args);
            } else {
                for a in self.args {
                    argv.append(a);
                }
            }
        } elif isinstance(self.args, str) {
            argv = [self.args];
        } else {
            argv = self.args;
        }
        if len(argv) == 0 {
            raise IndexError("list index out of range");
        }
        r_in: list[int] = [0, -1, -1];
        r_out: list[int] = [0, -1, -1];
        r_err: list[int] = [0, -1, -1];
        if self.stdin == PIPE {
            r_in = sp_pipe();
        }
        if self.stdout == PIPE {
            r_out = sp_pipe();
        }
        if self.stderr == PIPE {
            r_err = sp_pipe();
        }
        if r_in[0] != 0 or r_out[0] != 0 or r_err[0] != 0 {
            pipe_err = last_errno();
            for r in [r_in, r_out, r_err] {
                if r[0] == 0 and r[1] >= 0 {
                    sp_close(r[1]);
                    sp_close(r[2]);
                }
            }
            raise_errno(pipe_err, "pipe");
        }
        in_pipe = [r_in[1], r_in[2]];
        out_pipe = [r_out[1], r_out[2]];
        err_pipe = [r_err[1], r_err[2]];
        fa = sp_fa_new();
        fa_rc = self._fa_stdio(fa, in_pipe, out_pipe, err_pipe);
        if fa_rc == 0 and self.cwd is not None {
            fa_rc = sp_fa_chdir(fa, self.cwd);
        }
        envv: list[str] = [];
        e = self.env;
        if e is not None {
            for k in e {
                envv.append(k + "=" + e[k]);
            }
        }
        spawn_rc = 0;
        child_pid = -1;
        argv_v = 0;
        envp = 0;
        if fa_rc == 0 {
            argv_v = sp_strvec(argv);
            if e is not None {
                envp = sp_strvec(envv);
            }
            r = sp_spawn(argv[0], fa, argv_v, envp);
            spawn_rc = r[0];
            child_pid = r[1];
        }
        sp_fa_free(fa);
        if argv_v != 0 {
            sp_strvec_free(argv_v, len(argv));
        }
        if envp != 0 {
            sp_strvec_free(envp, len(envv));
        }
        if fa_rc != 0 or spawn_rc != 0 {
            for pair in [in_pipe, out_pipe, err_pipe] {
                for fd in pair {
                    if fd >= 0 {
                        sp_close(fd);
                    }
                }
            }
            code = fa_rc if fa_rc != 0 else spawn_rc;
            raise_os_error("spawn", argv[0], code);
        }
        self.pid = child_pid;
        if in_pipe[0] >= 0 {
            sp_close(in_pipe[0]);
            self._stdin_w = in_pipe[1];
        }
        if out_pipe[1] >= 0 {
            sp_close(out_pipe[1]);
            self._stdout_r = out_pipe[0];
        }
        if err_pipe[1] >= 0 {
            sp_close(err_pipe[1]);
            self._stderr_r = err_pipe[0];
        }
    }

    def _fa_stdio(
        fa: int, in_pipe: list[int], out_pipe: list[int], err_pipe: list[int]
    ) -> int {
        rc = 0;
        if in_pipe[0] >= 0 {
            rc = sp_fa_dup2(fa, in_pipe[0], 0);
        } elif self.stdin == DEVNULL {
            rc = sp_fa_open(fa, 0, "/dev/null", _O_RDWR);
        } elif isinstance(self.stdin, int) {
            rc = sp_fa_dup2(fa, self.stdin, 0);
        }
        if rc == 0 {
            if out_pipe[1] >= 0 {
                rc = sp_fa_dup2(fa, out_pipe[1], 1);
            } elif self.stdout == DEVNULL {
                rc = sp_fa_open(fa, 1, "/dev/null", _O_RDWR);
            } elif isinstance(self.stdout, int) {
                rc = sp_fa_dup2(fa, self.stdout, 1);
            }
        }
        if rc == 0 {
            if err_pipe[1] >= 0 {
                rc = sp_fa_dup2(fa, err_pipe[1], 2);
            } elif self.stderr == STDOUT {
                rc = sp_fa_dup2(fa, 1, 2);
            } elif self.stderr == DEVNULL {
                rc = sp_fa_open(fa, 2, "/dev/null", _O_RDWR);
            } elif isinstance(self.stderr, int) {
                rc = sp_fa_dup2(fa, self.stderr, 2);
            }
        }
        if rc == 0 {
            for pair in [in_pipe, out_pipe, err_pipe] {
                for fd in pair {
                    if fd >= 0 and rc == 0 {
                        rc = sp_fa_close(fa, fd);
                    }
                }
            }
        }
        return rc;
    }

    def _render(data: bytes) -> any {
        if self.text {
            return data.decode();
        }
        return data;
    }

    def _reap(options: int) -> int {
        while True {
            r = sp_waitpid(self.pid, options);
            if r[0] == self.pid {
                return r[1];
            }
            if r[0] == 0 {
                return -1;
            }
            err = last_errno();
            if err == EINTR {
                continue;
            }
            if err == _ECHILD {
                return -2;
            }
            raise_errno(err, "waitpid");
        }
    }

    def poll -> any {
        if self.returncode is not None {
            return self.returncode;
        }
        if self.pid < 0 {
            return None;
        }
        st = self._reap(_WNOHANG);
        if st >= 0 {
            self.returncode = _decode_status(st);
        } elif st == -2 {
            self.returncode = 0;
        }
        return self.returncode;
    }

    def `wait(timeout: (int | float | None) = None) -> int {
        if self.returncode is not None {
            return self.returncode;
        }
        deadline_ms = _deadline_ms(timeout);
        if deadline_ms < 0 {
            st = self._reap(0);
            self.returncode = _decode_status(st) if st >= 0 else 0;
            return self.returncode;
        }
        while True {
            rc = self.poll();
            if isinstance(rc, int) {
                return rc;
            }
            if sp_now_ms() >= deadline_ms {
                raise TimeoutExpired(cmd=self.args, timeout=timeout);
            }
            sp_usleep(2000);
        }
    }

    def _raise_timeout(timeout: (int | float | None), out: bytes, err: bytes) {
        raise TimeoutExpired(
            cmd=self.args,
            timeout=timeout,
            output=self._render(out),
            stderr=self._render(err)
        );
    }

    def communicate(
        input: any = None, timeout: (int | float | None) = None
    ) -> tuple[(any, any)] {
        deadline_ms = _deadline_ms(timeout);
        has_out = self._stdout_r >= 0;
        has_err = self._stderr_r >= 0;
        out_acc = bytearray();
        err_acc = bytearray();
        in_data: bytes = b"";
        if input is not None and self._stdin_w >= 0 {
            in_data = _to_bytes(input, self.text);
        }
        in_off = 0;
        if self._stdin_w >= 0 and in_off >= len(in_data) {
            sp_close(self._stdin_w);
            self._stdin_w = -1;
        }
        while self._stdout_r >= 0
            or self._stderr_r >= 0
            or (self._stdin_w >= 0 and in_off < len(in_data)) {
            wfd = self._stdin_w if in_off < len(in_data) else -1;
            wait_ms = -1;
            if deadline_ms >= 0 {
                wait_ms = deadline_ms - sp_now_ms();
                if wait_ms < 0 {
                    wait_ms = 0;
                }
            }
            pr = sp_pollio(self._stdout_r, self._stderr_r, wfd, wait_ms);
            if pr[0] == 0 {
                self._raise_timeout(timeout, bytes(out_acc), bytes(err_acc));
            }
            if pr[0] < 0 {
                if last_errno() == EINTR {
                    continue;
                }
                raise_errno(last_errno(), "poll");
            }
            if wfd >= 0 {
                if (pr[3] & (_POLLERR | _POLLHUP | _POLLNVAL)) != 0 {
                    sp_close(self._stdin_w);
                    self._stdin_w = -1;
                } elif (pr[3] & _POLLOUT) != 0 {
                    n = sp_write(self._stdin_w, in_data[in_off:in_off + _WRITE_CHUNK]);
                    if n <= 0 {
                        sp_close(self._stdin_w);
                        self._stdin_w = -1;
                    } else {
                        in_off += n;
                        if in_off >= len(in_data) {
                            sp_close(self._stdin_w);
                            self._stdin_w = -1;
                        }
                    }
                }
            }
            if self._stdout_r >= 0
                and (pr[1] & (_POLLIN | _POLLHUP | _POLLERR | _POLLNVAL)) != 0 {
                chunk = sp_read(self._stdout_r, _READ_CHUNK);
                if len(chunk) == 0 {
                    sp_close(self._stdout_r);
                    self._stdout_r = -1;
                } else {
                    out_acc.extend(chunk);
                }
            }
            if self._stderr_r >= 0
                and (pr[2] & (_POLLIN | _POLLHUP | _POLLERR | _POLLNVAL)) != 0 {
                chunk = sp_read(self._stderr_r, _READ_CHUNK);
                if len(chunk) == 0 {
                    sp_close(self._stderr_r);
                    self._stderr_r = -1;
                } else {
                    err_acc.extend(chunk);
                }
            }
        }
        if self._stdin_w >= 0 {
            sp_close(self._stdin_w);
            self._stdin_w = -1;
        }
        out_v: any = None;
        err_v: any = None;
        if has_out {
            out_v = self._render(bytes(out_acc));
        }
        if has_err {
            err_v = self._render(bytes(err_acc));
        }
        if deadline_ms >= 0 {
            rem = deadline_ms - sp_now_ms();
            if rem <= 0 {
                self._raise_timeout(timeout, bytes(out_acc), bytes(err_acc));
            }
            try {
                self.`wait(rem / 1000.0);
            } except TimeoutExpired {
                self._raise_timeout(timeout, bytes(out_acc), bytes(err_acc));
            }
        } else {
            self.`wait();
        }
        return (out_v, err_v);
    }

    def kill {
        if self.pid >= 0 and self.returncode is None {
            sp_kill(self.pid, _SIGKILL);
        }
    }

    def terminate {
        if self.pid >= 0 and self.returncode is None {
            sp_kill(self.pid, _SIGTERM);
        }
    }
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
) -> CompletedProcess {
    if stdin is not None and input is not None {
        raise ValueError("stdin and input arguments may not both be used.");
    }
    if capture_output and (stdout is not None or stderr is not None) {
        raise ValueError(
            "stdout and stderr arguments may not be used with capture_output."
        );
    }
    if input is not None and stdin is None {
        stdin = PIPE;
    }
    if capture_output {
        if stdout is None {
            stdout = PIPE;
        }
        if stderr is None {
            stderr = PIPE;
        }
    }
    p = Popen(
        args=args,
        stdin=stdin,
        stdout=stdout,
        stderr=stderr,
        text=text,
        cwd=cwd,
        env=env,
        shell=shell
    );
    o: any = None;
    e: any = None;
    try {
        (o, e) = p.communicate(input, timeout);
    } except TimeoutExpired as te {
        p.kill();
        p.`wait();
        raise te;
    }
    prc = p.returncode;
    if not isinstance(prc, int) {
        prc = -1;
    }
    cp = CompletedProcess(args=args, returncode=prc, stdout=o, stderr=e);
    if check {
        cp.check_returncode();
    }
    return cp;
}

def:pub call(
    args: (str | list[str]),
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> int {
    cp = run(args, timeout=timeout, cwd=cwd, env=env, shell=shell);
    return cp.returncode;
}

def:pub check_call(
    args: (str | list[str]),
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> int {
    cp = run(args, timeout=timeout, cwd=cwd, env=env, shell=shell, check=True);
    return cp.returncode;
}

def:pub check_output(
    args: (str | list[str]),
    text: bool = False,
    timeout: (int | float | None) = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> any {
    cp = run(
        args,
        capture_output=True,
        text=text,
        check=True,
        timeout=timeout,
        cwd=cwd,
        env=env,
        shell=shell
    );
    return cp.stdout;
}
