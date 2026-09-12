"""Bundled native ``shutil`` cross-backend equivalence fixture.

The sv entry uses CPython's shutil; the na entry the bundled
`shutil.jac` (which/copyfile/copy/copy2/move/rmtree over the os
intrinsics plus libc). Both backends drive the same fixed /tmp workspace
sequentially and pin observable facts as ints/strings. The locked-directory
helper is spelled out once per lane, because a plain `def` is a Python symbol
native code could only reach through the JIT interop bridge. ES/JS opts out.
"""

import os;
import shutil;
import from shutil { copy2, move, rmtree, which }


"""Remove a directory holding a file that will not unlink, returning the error."""
def _locked_error_py(path: str) -> str {
    os.makedirs(path);
    h = open(os.path.join(path, "pinned.txt"), "w");
    h.write("pinned");
    h.close();
    os.system("chmod 555 " + path);
    err = "";
    try {
        rmtree(path);
    } except Exception as e {
        err = f"{e}";
    }
    os.system("chmod 755 " + path);
    return err;
}


"""Remove a directory holding a file that will not unlink, returning the error."""
def _locked_error_na(path: str) -> str {
    os.makedirs(path);
    h = open(os.path.join(path, "pinned.txt"), "w");
    h.write("pinned");
    h.close();
    os.system("chmod 555 " + path);
    err = "";
    try {
        rmtree(path);
    } except Exception as e {
        err = f"{e}";
    }
    os.system("chmod 755 " + path);
    return err;
}


def shutil_py -> dict {
    base = "/tmp/jac_prim_shutil_fix";
    if os.path.exists(base) {
        rmtree(base);
    }
    os.makedirs(os.path.join(base, "sub"));
    src = os.path.join(base, "a.txt");
    f = open(src, "w");
    f.write("hello shutil");
    f.close();
    copied = shutil.copy(src, os.path.join(base, "sub"));
    c2 = copy2(src, os.path.join(base, "b.txt"));
    moved = move(os.path.join(base, "b.txt"), os.path.join(base, "sub", "c.txt"));
    g = open(os.path.join(base, "sub", "c.txt"), "r");
    moved_body = g.read();
    g.close();
    sh_path = which("sh");
    ghost = which("definitely_not_a_command_xyz_123");
    locked = os.path.join(base, "locked");
    locked_err = _locked_error_py(locked);
    out = {
        "copied_exists": 1 if os.path.exists(os.path.join(base, "sub", "a.txt")) else 0,
        "copy_ret_base": os.path.basename(copied),
        "copy2_exists_pre_move": 0
            if os.path.exists(os.path.join(base, "b.txt"))
            else 1,
        "moved_body": moved_body,
        "moved_ret_base": os.path.basename(moved),
        "sh_found": 1 if sh_path is not None else 0,
        "sh_base": os.path.basename(sh_path) if sh_path is not None else "",
        "ghost_none": 1 if ghost is None else 0,
        "locked_rmtree_raised": 1 if locked_err != "" else 0,
        "locked_dir_kept": 1 if os.path.exists(locked) else 0,

    };
    rmtree(base);
    out["rmtree_gone"] = 0 if os.path.exists(base) else 1;
    return out;
}

def shutil_cl -> dict {
    return {};
}


def shutil_na -> dict[str, any] {
    base = "/tmp/jac_prim_shutil_fix";
    if os.path.exists(base) {
        rmtree(base);
    }
    os.makedirs(os.path.join(base, "sub"));
    src = os.path.join(base, "a.txt");
    f = open(src, "w");
    f.write("hello shutil");
    f.close();
    copied = shutil.copy(src, os.path.join(base, "sub"));
    c2 = copy2(src, os.path.join(base, "b.txt"));
    moved = move(os.path.join(base, "b.txt"), os.path.join(base, "sub", "c.txt"));
    g = open(os.path.join(base, "sub", "c.txt"), "r");
    moved_body = g.read();
    g.close();
    sh_path = which("sh");
    ghost = which("definitely_not_a_command_xyz_123");
    locked = os.path.join(base, "locked");
    locked_err = _locked_error_na(locked);
    out: dict[str, any] = {
        "copied_exists": 1 if os.path.exists(os.path.join(base, "sub", "a.txt")) else 0,
        "copy_ret_base": os.path.basename(copied),
        "copy2_exists_pre_move": 0
            if os.path.exists(os.path.join(base, "b.txt"))
            else 1,
        "moved_body": moved_body,
        "moved_ret_base": os.path.basename(moved),
        "sh_found": 1 if sh_path is not None else 0,
        "sh_base": os.path.basename(sh_path) if sh_path is not None else "",
        "ghost_none": 1 if ghost is None else 0,
        "locked_rmtree_raised": 1 if locked_err != "" else 0,
        "locked_dir_kept": 1 if os.path.exists(locked) else 0,

    };
    rmtree(base);
    out["rmtree_gone"] = 0 if os.path.exists(base) else 1;
    return out;
}


"""Report whether the native rmtree error names the file it could not unlink."""
def locked_error_names_file_na -> int {
    base = "/tmp/jac_prim_shutil_locked";
    if os.path.exists(base) {
        rmtree(base);
    }
    err = _locked_error_na(base);
    rmtree(base);
    return 1 if "pinned.txt" in err else 0;
}
