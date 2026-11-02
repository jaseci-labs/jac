"""Benchmark: raw FFI floor calls vs bundled surface calls (native-only).

`jac run -b native` only -- the `_glob_native`/`_platform_native` floors are
Jac modules with clib externs and cannot load on the sv pathway. Decomposes
each operation into bare-loop overhead, the raw FFI floor call, and the
bundled-module surface call so the per-layer cost is visible.
"""

import time;
import sys;
import os;
import errno;
import from errno { EPERM, errorcode }
import from stat { S_IMODE, S_ISREG, filemode }
import from glob { `glob }
import platform;
import from _glob_native { glob_lexists }
import from _platform_native { plat_sysname }
import from c {
    def glob64(pattern: str, flags: i32, errfunc: int, pglob: int) -> i32;
}
import from c { def globfree64(pglob: int);  }
import from c { def strdup(s: int) -> str;  }
import from c { def malloc(size: int) -> int;  }

glob BASE: str = "/tmp/jac_na_stdlib_bench_tree",
     LIT: str = "/tmp/jac_na_stdlib_bench_tree/a.txt",
     _GT: int = malloc(256);


def _w(s: str) {
    sys.stdout.write(s + "\n");
}


def timed(name: str, n: int, acc: int, ns: int) {
    _w(
        name
            + " n="
            + str(n)
            + " acc="
            + str(acc)
            + " total_ms="
            + str(ns / 1000000.0)
            + " ns_per_op="
            + str(ns / n)
    );
}


with entry {
    if not os.path.exists(BASE) {
        os.makedirs(BASE);
        f = open(BASE + "/a.txt", "w");
        f.write("x");
        f.close();
    }
}

glob names: list[str] = [
         "bare_loop",
         "ffi_lstat",
         "surf_glob_literal",
         "osp_exists",
         "ffi_uname_sysname",
         "surf_platform_system",
         "surf_stat_imode",
         "surf_stat_filemode",
         "surf_errno_lookup",
         "ffi_libc_glob_call",
         "ffi_libc_glob_marshal",
         "surf_glob_pattern"
     ],
     ns_list: list[int] = [
         1000000,
         100000,
         100000,
         100000,
         100000,
         200000,
         1000000,
         200000,
         1000000,
         50000,
         50000,
         50000
     ];

with entry {
    phase: int = 0;
    while phase < 12 {
        n = ns_list[phase];
        best: int = 0;
        best_acc: int = 0;
        r: int = -1;
        while r < 3 {
            t0 = time.perf_counter_ns();
            acc: int = 0;
            i: int = 0;
            while i < n {
                if phase == 0 {
                    acc += 1;
                } elif phase == 1 {
                    if glob_lexists(LIT) {
                        acc += 1;
                    }
                } elif phase == 2 {
                    acc += len(`glob(LIT));
                } elif phase == 3 {
                    if os.path.exists(LIT) {
                        acc += 1;
                    }
                } elif phase == 4 {
                    acc += len(plat_sysname());
                } elif phase == 5 {
                    acc += len(platform.system());
                } elif phase == 6 {
                    acc += S_IMODE(0o100644 + (i % 0o777))
                        + (1 if S_ISREG(0o100644 + (i % 0o777)) else 0);
                } elif phase == 7 {
                    acc += len(filemode(0o100000 + (i % 0o17777)));
                } elif phase == 8 {
                    acc += errno.EPERM + len(errorcode[EPERM]);
                } elif phase == 9 {
                    rc = glob64(BASE + "/d?/*.log", 0, 0, _GT);
                    acc += rc + int(__mem_load_i64(_GT));
                    globfree64(_GT);
                } elif phase == 10 {
                    rc = glob64(BASE + "/d?/*.log", 0, 0, _GT);
                    cnt = int(__mem_load_i64(_GT));
                    pv = __mem_load_i64(_GT + 8);
                    acc += rc + cnt;
                    j: int = 0;
                    while j < cnt {
                        acc += len(strdup(__mem_load_i64(pv + j * 8)));
                        j += 1;
                    }
                    globfree64(_GT);
                } else {
                    acc += len(`glob(BASE + "/d?/*.log"));
                }
                i += 1;
            }
            el = time.perf_counter_ns() - t0;
            if r >= 0 and (best == 0 or el < best) {
                best = el;
                best_acc = acc;
            }
            r += 1;
        }
        timed(names[phase], n, best_acc, best);
        phase += 1;
    }
}
