import os;
import from c { def access(path: str, mode: i32) -> i32;  }
import from c { def unlink(path: str) -> i32;  }
import from c { def rmdir(path: str) -> i32;  }
import from c { def rename(oldp: str, newp: str) -> i32;  }
import from _directory_native { try_directory_names }


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
        raise ValueError(f"move: cannot relocate directory '{src}' across filesystems");
    }
    copyfile(src, real_dst);
    if unlink(src) != 0 {
        raise ValueError(f"move: could not remove '{src}'");
    }
    return real_dst;
}

def:pub rmtree(path: str, ignore_errors: bool = False) {
    _rmtree_walk(path, ignore_errors);
}

def _rmtree_children(path: str, ignore_errors: bool) -> bool {
    ok = True;
    for nm in try_directory_names(path) {
        child = os.path.join(path, nm);
        if unlink(child) == 0 {
            continue;
        }
        if os.path.isdir(child) {
            if not _rmtree_walk(child, ignore_errors) {
                ok = False;
            }
            continue;
        }
        if not ignore_errors {
            raise ValueError(f"rmtree: could not remove '{child}'");
        }
        ok = False;
    }
    return ok;
}

def _rmtree_walk(path: str, ignore_errors: bool) -> bool {
    ok = _rmtree_children(path, ignore_errors);
    if rmdir(path) != 0 {
        if not _rmtree_children(path, ignore_errors) {
            ok = False;
        }
        if rmdir(path) != 0 {
            if not ignore_errors {
                raise ValueError(f"rmtree: could not remove '{path}'");
            }
            return False;
        }
    }
    return ok;
}
