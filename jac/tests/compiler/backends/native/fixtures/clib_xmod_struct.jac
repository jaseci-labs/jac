"""A foreign struct field whose type is a foreign struct from another module."""

import from clib_xmod_struct_base { timeval, total_micros }

import from c {
    obj rusage_like {
        has ru_utime: timeval,
            ru_stime: timeval,
            ru_maxrss: i64;
    }  def memset(dst: &mut rusage_like, byte: i32, n: i64) -> ptr;
}

def build -> rusage_like {
    return rusage_like(
        ru_utime=timeval(tv_sec=3, tv_usec=4),
        ru_stime=timeval(tv_sec=5, tv_usec=6),
        ru_maxrss=77
    );
}

with entry {
    r = build();
    print(
        "read", r.ru_utime.tv_sec, r.ru_utime.tv_usec, r.ru_stime.tv_sec, r.ru_maxrss
    );
    r.ru_stime.tv_usec = 250;
    print("write", r.ru_stime.tv_usec, total_micros(&r.ru_stime));
    u = r.ru_utime;
    u.tv_sec = 40;
    print("copy", u.tv_sec, r.ru_utime.tv_sec);
    memset(&mut r, 0, 40);
    print("cleared", r.ru_utime.tv_sec, r.ru_stime.tv_usec, r.ru_maxrss);
}
