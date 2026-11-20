"""Benchmark: bundled na_stdlib stat/glob/platform/errno vs sv bridge.

Lanes: `jac run -b native` (na bundled module), `jac run -b python`
(Jac over CPython), and `python3 scripts/bench_na_stdlib.py` (CPython
oracle). Identical loops and checksums across lanes. The ffi lane calls the
module's C-floor wrapper directly where one exists.
"""

import time;
import sys;
import os;
import errno;
import from errno { EPERM, ENOENT, EAGAIN, errorcode }
import from stat { S_IMODE, S_IFMT, S_ISDIR, S_ISREG, S_ISLNK, filemode }
import from glob { `glob, iglob, has_magic }
import platform;

glob BASE: str = "/tmp/jac_na_stdlib_bench_tree";


def _w(s: str) {
    sys.stdout.write(s + "\n");
}


def _setup_tree {
    if os.path.exists(BASE) {
        return;
    }
    os.makedirs(BASE + "/da/sub");
    os.makedirs(BASE + "/db/sub");
    names: list[str] = [];
    names.append("a.txt");
    names.append("b.txt");
    names.append("c.log");
    for n in names {
        f = open(BASE + "/" + n, "w");
        f.write("x");
        f.close();
    }
    for n in names {
        f = open(BASE + "/da/" + n, "w");
        f.write("x");
        f.close();
        f = open(BASE + "/db/" + n, "w");
        f.write("x");
        f.close();
    }
    f = open(BASE + "/da/sub/deep.txt", "w");
    f.write("x");
    f.close();
}


def bench_stat(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        m: int = 0o100000 + (i % 0o17777);
        acc += S_IMODE(m) + S_IFMT(m);
        if S_ISREG(m) {
            acc += 1;
        }
        if S_ISDIR(m) {
            acc += 2;
        }
        if S_ISLNK(m) {
            acc += 4;
        }
        acc += len(filemode(m));
        i += 1;
    }
    return acc;
}


def bench_glob(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(`glob(BASE + "/**/*.txt", recursive=True));
        acc += len(`glob(BASE + "/d?/*.log"));
        acc += len(`glob(BASE + "/*"));
        if has_magic(BASE + "/*") {
            acc += 1;
        }
        i += 1;
    }
    return acc;
}


def bench_platform(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(platform.system());
        acc += len(platform.release());
        acc += len(platform.machine());
        acc += len(platform.platform());
        u = platform.uname();
        acc += len(u.system) + len(u.machine);
        i += 1;
    }
    return acc;
}


def bench_errno(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += errno.EPERM + errno.EINVAL;
        acc += len(errorcode[EPERM]) + len(errorcode[ENOENT]) + len(errorcode[EAGAIN]);
        i += 1;
    }
    return acc;
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
    _setup_tree();
}

glob rounds: int = 3;
with entry {
    phase: int = 0;
}
glob names: list[str] = ["stat", "glob", "platform", "errno"],
     ns_list: list[int] = [200000, 2000, 20000, 200000];

with entry {
    while phase < 4 {
        n = ns_list[phase];
        best: int = 0;
        best_acc: int = 0;
        r: int = -1;
        while r < rounds {
            t0 = time.perf_counter_ns();
            acc = 0;
            if phase == 0 {
                acc = bench_stat(n);
            } elif phase == 1 {
                acc = bench_glob(n);
            } elif phase == 2 {
                acc = bench_platform(n);
            } else {
                acc = bench_errno(n);
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
