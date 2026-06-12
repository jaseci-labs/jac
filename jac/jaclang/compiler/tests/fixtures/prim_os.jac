"""os / os.path cross-backend equivalence fixture (issue #6404, v1).

getcwd/getenv are process-stable (sv and na run in the same process), so they
compare by value. getpid is non-deterministic (checked > 0). Mutating ops use a
backend-distinct temp dir to avoid cross-backend filesystem conflicts and return
a success boolean. os.path string ops compare exact strings. ES/JS opts out.
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
    return {
        "cwd": os.getcwd(),
        "path_env": os.getenv("PATH"),
        "pid_pos": os.getpid() > 0,
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
        return {
            "cwd": os.getcwd(),
            "path_env": os.getenv("PATH"),
            "pid_pos": pid_pos,
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
