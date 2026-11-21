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

def _lo32(buf: bytes, off: int) -> int;

def:pub sp_waitpid(pid: int, options: int) -> list[int];

def:pub sp_kill(pid: int, signum: int) -> int;

def:pub sp_pipe -> list[int];

def:pub sp_close(fd: int) -> int;

def:pub sp_read(fd: int, size: int) -> bytes;

def:pub sp_write(fd: int, data: bytes) -> int;

def:pub sp_usleep(usec: int) -> int;

def:pub sp_now_ms -> int;

def:pub sp_pollio(rfd1: int, rfd2: int, wfd: int, timeout_ms: int) -> list[int];

def:pub sp_strvec(items: list[str]) -> int;

def:pub sp_strvec_free(vec: int, n: int);

def:pub sp_fa_new -> int;

def:pub sp_fa_dup2(fa: int, oldfd: int, newfd: int) -> int;

def:pub sp_fa_close(fa: int, fd: int) -> int;

def:pub sp_fa_open(fa: int, fd: int, path: str, flags: int) -> int;

def:pub sp_fa_chdir(fa: int, path: str) -> int;

def:pub sp_fa_free(fa: int);

def:pub sp_spawn(path: str, fa: int, argv: int, envp: int) -> list[int];
