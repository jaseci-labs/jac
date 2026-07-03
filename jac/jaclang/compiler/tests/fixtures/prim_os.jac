"""os / os.path cross-backend equivalence fixture (issues #6404 / #6940).

getcwd/getenv are process-stable (sv and na run in the same process), so they
compare by value. getpid is non-deterministic (checked > 0). Mutating ops use a
backend-distinct temp dir to avoid cross-backend filesystem conflicts and return
a success boolean. os.path string ops compare exact strings. ES/JS opts out.

#6940 Phase 1 extras: os.makedirs (recursive over libc mkdir) returns a success
boolean over a backend-distinct nested path; os.path.realpath (libc realpath(3))
compares by value on shared existing paths ("/" and the shared cwd), which
resolve identically on both backends since they run on the same host.
"""

import os;

def os_py() -> dict {
    made_ok: int = 0;
    p: str = "/tmp/jac_eq_py_dir";
    os.mkdir(p);
    if os.path.isdir(p) {
        os.rmdir(p);
        if not os.path.exists(p) {
            made_ok = 1;
        }
    }
    makedirs_ok: int = 0;
    deep: str = "/tmp/jac_eq_py_mk/a/b/c";
    # Tolerate a leftover tree from an aborted run: CPython's default
    # exist_ok=False raises FileExistsError, while the native makedirs (mkdir -p)
    # ignores EEXIST. Guarding on exists keeps the two backends congruent.
    if not os.path.exists(deep) {
        os.makedirs(deep);
    }
    if os.path.isdir(deep) {
        makedirs_ok = 1;
        os.rmdir("/tmp/jac_eq_py_mk/a/b/c");
        os.rmdir("/tmp/jac_eq_py_mk/a/b");
        os.rmdir("/tmp/jac_eq_py_mk/a");
        os.rmdir("/tmp/jac_eq_py_mk");
    }
    return {
        "cwd": os.getcwd(),
        "path_env": os.getenv("PATH"),
        "pid_pos": os.getpid() > 0,
        "makedirs_ok": makedirs_ok,
        "realpath_root": os.path.realpath("/"),
        "realpath_cwd": os.path.realpath(os.getcwd()),
        "join2": os.path.join("a", "b"),
        "join_trail": os.path.join("a/", "b"),
        "join_abs": os.path.join("a", "/b"),
        "join3": os.path.join("x", "y", "z"),
        "basename": os.path.basename("/usr/local/bin"),
        "dirname": os.path.dirname("/usr/local/bin"),
        "basename_noslash": os.path.basename("file.txt"),
        "dirname_noslash": os.path.dirname("file.txt"),
        "exists_tmp": os.path.exists("/tmp"),
        "isdir_tmp": os.path.isdir("/tmp"),
        "isfile_tmp": os.path.isfile("/tmp"),
        "exists_missing": os.path.exists("/no/such/path/xyz123"),
        "mkdir_rmdir_ok": made_ok,

    };
}

cl def os_cl() -> dict {
    return {};
}

na {
    def os_na() -> dict[str, any] {
        made_ok: int = 0;
        p: str = "/tmp/jac_eq_na_dir";
        os.mkdir(p);
        isd: int = os.path.isdir(p);
        if isd == 1 {
            os.rmdir(p);
            ex: int = os.path.exists(p);
            if ex == 0 {
                made_ok = 1;
            }
        }
        pid_pos: int = os.getpid() > 0;
        makedirs_ok: int = 0;
        deep: str = "/tmp/jac_eq_na_mk/a/b/c";
        os.makedirs(deep);
        mkd: int = os.path.isdir(deep);
        if mkd == 1 {
            makedirs_ok = 1;
            os.rmdir("/tmp/jac_eq_na_mk/a/b/c");
            os.rmdir("/tmp/jac_eq_na_mk/a/b");
            os.rmdir("/tmp/jac_eq_na_mk/a");
            os.rmdir("/tmp/jac_eq_na_mk");
        }
        return {
            "cwd": os.getcwd(),
            "path_env": os.getenv("PATH"),
            "pid_pos": pid_pos,
            "makedirs_ok": makedirs_ok,
            "realpath_root": os.path.realpath("/"),
            "realpath_cwd": os.path.realpath(os.getcwd()),
            "join2": os.path.join("a", "b"),
            "join_trail": os.path.join("a/", "b"),
            "join_abs": os.path.join("a", "/b"),
            "join3": os.path.join("x", "y", "z"),
            "basename": os.path.basename("/usr/local/bin"),
            "dirname": os.path.dirname("/usr/local/bin"),
            "basename_noslash": os.path.basename("file.txt"),
            "dirname_noslash": os.path.dirname("file.txt"),
            "exists_tmp": os.path.exists("/tmp"),
            "isdir_tmp": os.path.isdir("/tmp"),
            "isfile_tmp": os.path.isfile("/tmp"),
            "exists_missing": os.path.exists("/no/such/path/xyz123"),
            "mkdir_rmdir_ok": made_ok,

        };
    }
}
