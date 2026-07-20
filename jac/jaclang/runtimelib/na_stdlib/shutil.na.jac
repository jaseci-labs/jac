"""Python-congruent ``shutil`` for the native pathway.

The census-ranked surface real projects use: which, copyfile, copy, copy2,
move, and rmtree, built on the native os intrinsics (getenv, path.join,
path.isdir, path.isfile, path.basename) plus direct libc (access, unlink,
rmdir, rename, opendir/readdir/closedir). The dirent d_name/d_type offsets
follow the glibc x86-64/aarch64 layout (d_ino 8 + d_off 8 + d_reclen 2 +
d_type 1 = 19), matching the platform scope of the other libc-backed
bundled modules. Documented divergences: copy/copy2 duplicate bytes but do
not yet preserve mode/mtime metadata; rmtree follows the isdir predicate,
so directory symlinks are recursed into rather than unlinked; errors raise
ValueError rather than CPython's OSError subclasses.
"""

import os;
import from c { def access(path: str, mode: i32) -> i32;  }
import from c { def unlink(path: str) -> i32;  }
import from c { def rmdir(path: str) -> i32;  }
import from c { def rename(oldp: str, newp: str) -> i32;  }
import from c { def opendir(path: str) -> int;  }
import from c { def readdir(dirp: int) -> int;  }
import from c { def closedir(dirp: int) -> i32;  }
import from c { def strdup(s: int) -> str;  }


def:pub which(cmd: str) -> (str | None) {
    if "/" in cmd {
        if access(cmd, 1) == 0 and os.path.isfile(cmd) {
            return cmd;
        }
        return None;
    }
    path_env = os.getenv("PATH");
    if path_env is None {
        return None;
    }
    for d in path_env.split(":") {
        if d == "" {
            continue;
        }
        cand = os.path.join(d, cmd);
        if access(cand, 1) == 0 and os.path.isfile(cand) {
            return cand;
        }
    }
    return None;
}

def:pub copyfile(src: str, dst: str) -> str {
    fsrc = open(src, "rb");
    data = fsrc.read();
    fsrc.close();
    fdst = open(dst, "wb");
    fdst.write(data);
    fdst.close();
    return dst;
}

def:pub copy(src: str, dst: str) -> str {
    real_dst = dst;
    if os.path.isdir(dst) {
        real_dst = os.path.join(dst, os.path.basename(src));
    }
    return copyfile(src, real_dst);
}

def:pub copy2(src: str, dst: str) -> str {
    return copy(src, dst);
}

def:pub move(src: str, dst: str) -> str {
    real_dst = dst;
    if os.path.isdir(dst) {
        real_dst = os.path.join(dst, os.path.basename(src));
    }
    if rename(src, real_dst) == 0 {
        return real_dst;
    }
    if os.path.isdir(src) {
        raise ValueError(
            f"move: cannot relocate directory '{src}' across filesystems"
        );
    }
    copyfile(src, real_dst);
    unlink(src);
    return real_dst;
}

def:pub rmtree(path: str) -> None {
    d = opendir(path);
    if d == 0 {
        raise ValueError(f"rmtree: cannot open '{path}'");
    }
    children: list[str] = [];
    while True {
        ent = readdir(d);
        if ent == 0 {
            break;
        }
        nm = strdup(ent + 19);
        if nm == "." or nm == ".." {
            continue;
        }
        children.append(nm);
    }
    closedir(d);
    for nm in children {
        child = os.path.join(path, nm);
        if os.path.isdir(child) {
            rmtree(child);
        } else {
            unlink(child);
        }
    }
    if rmdir(path) != 0 {
        raise ValueError(f"rmtree: could not remove '{path}'");
    }
}
