import from c { def waitpid(pid: i32, status: bytes, options: i32) -> i32;  }
import from c { def kill(pid: i32, signum: i32) -> i32;  }
import from c { def pipe(fds: bytes) -> i32;  }
import from c { def close(fd: i32) -> i32;  }
import from c { def read(fd: i32, buf: bytes, count: u64) -> i64;  }
import from c { def write(fd: i32, buf: bytes, count: u64) -> i64;  }
import from c { def usleep(usec: u32) -> i32;  }
import from c { def clock_gettime(clk: i32, ts: bytes) -> i32;  }
import from c { def poll(fds: int, nfds: u64, timeout: i32) -> i32;  }
import from c { def strdup(s: str) -> int;  }
import from c { def malloc(size: int) -> int;  }
import from c { def free(p: int);  }
import from c {
    def posix_spawnp(
        pid: bytes, path: str, fa: int, attr: int, argv: int, envp: int
    ) -> i32;
}
import from c { def posix_spawn_file_actions_init(fa: int) -> i32;  }
import from c { def posix_spawn_file_actions_destroy(fa: int) -> i32;  }
import from c {
    def posix_spawn_file_actions_adddup2(fa: int, fd: i32, newfd: i32) -> i32;
}
import from c { def posix_spawn_file_actions_addclose(fa: int, fd: i32) -> i32;  }
import from c {
    def posix_spawn_file_actions_addopen(
        fa: int, fd: i32, path: str, flags: i32, mode: i32
    ) -> i32;
}
import from c { def posix_spawn_file_actions_addchdir_np(fa: int, path: str) -> i32;  }

glob _CLOCK_MONOTONIC: int = 1,
     _EV_READ: int = 1,
     _EV_WRITE: int = 4,
     _OPEN_MODE_0666: int = 438,
     _FA_SIZE: int = 256;

def _lo32(buf: bytes, off: int) -> int {
    return int.from_bytes(buf[off:off + 4], "little");
}

def:pub sp_waitpid(pid: int, options: int) -> list[int] {
    buf = b"\x00" * 8;
    rc = waitpid(i32(pid), buf, i32(options));
    return [int(rc), _lo32(buf, 0)];
}

def:pub sp_kill(pid: int, signum: int) -> int {
    return kill(i32(pid), i32(signum));
}

def:pub sp_pipe -> list[int] {
    buf = b"\x00" * 8;
    rc = pipe(buf);
    return [int(rc), _lo32(buf, 0), _lo32(buf, 4)];
}

def:pub sp_close(fd: int) -> int {
    return close(i32(fd));
}

def:pub sp_read(fd: int, size: int) -> bytes {
    buf = b"\x00" * size;
    n = read(i32(fd), buf, u64(size));
    if n <= 0 {
        return b"";
    }
    return buf[:n];
}

def:pub sp_write(fd: int, data: bytes) -> int {
    return int(write(i32(fd), data, u64(len(data))));
}

def:pub sp_usleep(usec: int) -> int {
    return usleep(u32(usec));
}

def:pub sp_now_ms -> int {
    ts = b"\x00" * 16;
    clock_gettime(i32(_CLOCK_MONOTONIC), ts);
    sec = int.from_bytes(ts[0:8], "little");
    nsec = int.from_bytes(ts[8:16], "little");
    return sec * 1000 + nsec // 1000000;
}

def:pub sp_pollio(rfd1: int, rfd2: int, wfd: int, timeout_ms: int) -> list[int] {
    fds = malloc(24);
    __mem_store_i32(fds + 0, i32(rfd1));
    __mem_store_i32(fds + 4, i32(_EV_READ));
    __mem_store_i32(fds + 8, i32(rfd2));
    __mem_store_i32(fds + 12, i32(_EV_READ));
    __mem_store_i32(fds + 16, i32(wfd));
    __mem_store_i32(fds + 20, i32(_EV_WRITE));
    rc = poll(fds, u64(3), i32(timeout_ms));
    out = [
        int(rc),
        __mem_load_i32(fds + 4) >> 16,
        __mem_load_i32(fds + 12) >> 16,
        __mem_load_i32(fds + 20) >> 16
    ];
    free(fds);
    return out;
}

def:pub sp_strvec(items: list[str]) -> int {
    n = len(items);
    buf = malloc((n + 1) * 8);
    i = 0;
    while i < n {
        __mem_store_i64(buf + i * 8, strdup(items[i]));
        i += 1;
    }
    __mem_store_i64(buf + n * 8, 0);
    return buf;
}

def:pub sp_strvec_free(vec: int, n: int) {
    i = 0;
    while i < n {
        free(__mem_load_i64(vec + i * 8));
        i += 1;
    }
    free(vec);
}

def:pub sp_fa_new -> int {
    fa = malloc(_FA_SIZE);
    posix_spawn_file_actions_init(fa);
    return fa;
}

def:pub sp_fa_dup2(fa: int, oldfd: int, newfd: int) -> int {
    return posix_spawn_file_actions_adddup2(fa, i32(oldfd), i32(newfd));
}

def:pub sp_fa_close(fa: int, fd: int) -> int {
    return posix_spawn_file_actions_addclose(fa, i32(fd));
}

def:pub sp_fa_open(fa: int, fd: int, path: str, flags: int) -> int {
    return posix_spawn_file_actions_addopen(
        fa, i32(fd), path, i32(flags), i32(_OPEN_MODE_0666)
    );
}

def:pub sp_fa_chdir(fa: int, path: str) -> int {
    return posix_spawn_file_actions_addchdir_np(fa, path);
}

def:pub sp_fa_free(fa: int) {
    posix_spawn_file_actions_destroy(fa);
    free(fa);
}

def:pub sp_spawn(path: str, fa: int, argv: int, envp: int) -> list[int] {
    pidb = b"\x00" * 8;
    rc = posix_spawnp(pidb, path, fa, 0, argv, envp);
    return [int(rc), _lo32(pidb, 0)];
}
