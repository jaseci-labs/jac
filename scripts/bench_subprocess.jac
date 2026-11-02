"""FFI-floor bench for the subprocess spawn path.

Splits per-spawn cost into the raw `_subprocess_native` floor (spawn file
actions + argv vector + posix_spawnp + waitpid) and the layers above it
(Popen glue, pipe plumbing, communicate, CompletedProcess).

    jac run -b native scripts/bench_subprocess.jac
"""

import time;
import from _subprocess_native {
    sp_fa_new,
    sp_fa_dup2,
    sp_fa_close,
    sp_fa_free,
    sp_strvec,
    sp_strvec_free,
    sp_spawn,
    sp_waitpid,
    sp_pipe,
    sp_close,
    sp_read
}
import from subprocess { Popen, run }

glob _ITERS: int = 300,
     _WARMUP: int = 20,
     _READ_CHUNK: int = 65536,
     _LANES: list[str] = ["floor spawn", "floor capture", "Popen+wait", "run capture"];

# spawn + reap, no pipes: fa + argv vector + posix_spawnp + waitpid
def floor_spawn -> int {
    fa = sp_fa_new();
    argv = sp_strvec(["true"]);
    r = sp_spawn("true", fa, argv, 0);
    sp_fa_free(fa);
    sp_strvec_free(argv, 1);
    if r[0] != 0 {
        return r[0];
    }
    sp_waitpid(r[1], 0);
    return 0;
}

# the capture_output floor: two pipes, dup2/close actions, drain, reap
def floor_capture -> int {
    r_out = sp_pipe();
    r_err = sp_pipe();
    if r_out[0] != 0 or r_err[0] != 0 {
        return -1;
    }
    fa = sp_fa_new();
    sp_fa_dup2(fa, r_out[2], 1);
    sp_fa_dup2(fa, r_err[2], 2);
    for fd in [r_out[1], r_out[2], r_err[1], r_err[2]] {
        sp_fa_close(fa, fd);
    }
    argv = sp_strvec(["true"]);
    r = sp_spawn("true", fa, argv, 0);
    sp_fa_free(fa);
    sp_strvec_free(argv, 1);
    sp_close(r_out[2]);
    sp_close(r_err[2]);
    if r[0] != 0 {
        sp_close(r_out[1]);
        sp_close(r_err[1]);
        return r[0];
    }
    while len(sp_read(r_out[1], _READ_CHUNK)) > 0 {}
    while len(sp_read(r_err[1], _READ_CHUNK)) > 0 {}
    sp_close(r_out[1]);
    sp_close(r_err[1]);
    sp_waitpid(r[1], 0);
    return 0;
}

def popen_wait -> int {
    p = Popen(args=["true"]);
    return p.`wait();
}

def run_capture -> int {
    cp = run(["true"], capture_output=True);
    return cp.returncode;
}

def bench(which: int, iters: int) -> float {
    t0 = time.monotonic();
    for _ in range(iters) {
        if which == 0 {
            floor_spawn();
        } elif which == 1 {
            floor_capture();
        } elif which == 2 {
            popen_wait();
        } else {
            run_capture();
        }
    }
    return time.monotonic() - t0;
}

with entry {
    for _ in range(_WARMUP) {
        floor_spawn();
        popen_wait();
        run_capture();
    }
    print(f"subprocess spawn floor vs layers ({_ITERS} iters, native lane)");
    i = 0;
    while i < len(_LANES) {
        el = bench(i, _ITERS);
        print(f"{_LANES[i]:<14} {el:8.3f}s total  {el / _ITERS * 1000:8.3f} ms/spawn");
        i += 1;
    }
}
