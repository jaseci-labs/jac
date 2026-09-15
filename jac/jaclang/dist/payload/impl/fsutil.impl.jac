import hashlib;
import io;
import os;
import platform;
import shutil;
import subprocess;
import sys;
import tarfile;

impl log(msg: str) {
    sys.stderr.write(msg + "\n");
    sys.stderr.flush();
}

impl die(msg: str) -> NoReturn {
    raise PayloadDie(msg);
}

impl file_exists(path: str) -> bool {
    return os.path.isfile(path);
}

impl file_size_or_zero(path: str) -> int {
    try {
        return os.path.getsize(path);
    } except OSError {
        return 0;
    }
}

impl mtime_ns(path: str) -> int | None {
    try {
        return os.stat(path).st_mtime_ns;
    } except OSError {
        return None;
    }
}

impl sha256_hex(data: bytes) -> str {
    return hashlib.sha256(data).hexdigest();
}

impl read_bytes(path: str) -> bytes {
    with open(path, "rb") as f {
        return f.read();
    }
}

impl read_trimmed(path: str) -> str | None {
    try {
        raw = read_bytes(path);
    } except OSError {
        return None;
    }
    t = raw.decode("utf-8", errors="replace").strip(" \t\r\n");
    if not t {
        return None;
    }
    return t;
}

impl write_bytes(path: str, data: bytes) {
    with open(path, "wb") as f {
        f.write(data);
    }
}

impl write_text(path: str, text: str) {
    write_bytes(path, text.encode("utf-8"));
}

impl make_dirs(path: str) {
    os.makedirs(path, exist_ok=True);
}

impl delete_tree(path: str) {
    shutil.rmtree(path, ignore_errors=True);
}

impl delete_file(path: str) {
    try {
        os.unlink(path);
    } except OSError {}
}

impl copy_file(src: str, dst: str) {
    try {
        shutil.copy(src, dst);
    } except OSError as e {
        die(f"copy {src} failed: {type(e).__name__}: {e}");
    }
}

impl copy_into(repo_root: str, name: str, dst: str) {
    copy_file(os.path.join(repo_root, name), os.path.join(dst, name));
}

impl walk_sorted(top: str) -> list[tuple[str, list[str], list[str]]] {
    rows: list[tuple[str, list[str], list[str]]] = [];
    stack: list[str] = [top];
    while stack {
        cur = stack.pop();
        try {
            names = sorted(os.listdir(cur));
        } except OSError {
            continue;
        }
        dirs: list[str] = [];
        files: list[str] = [];
        for n in names {
            if os.path.isdir(os.path.join(cur, n))
                and not os.path.islink(os.path.join(cur, n)) {
                dirs.append(n);
            } else {
                files.append(n);
            }
        }
        rows.append((cur, dirs, files));
        for d in reversed(dirs) {
            stack.append(os.path.join(cur, d));
        }
    }
    return rows;
}

impl copy_tree(src_dir: str, dst_path: str, skip_fn: Callable[[str], bool]) {
    if not os.path.isdir(src_dir) {
        die(f"copy tree {src_dir} failed: not a directory");
    }
    make_dirs(dst_path);
    for (cur, dirnames, filenames) in walk_sorted(src_dir) {
        rel_dir = os.path.relpath(cur, src_dir).replace(os.sep, "/");
        prefix = "" if rel_dir == "." else rel_dir + "/";
        for d in dirnames {
            rel = prefix + d;
            if not skip_fn(rel) {
                make_dirs(os.path.join(dst_path, rel));
            }
        }
        for fname in filenames {
            rel = prefix + fname;
            if skip_fn(rel) {
                continue;
            }
            target = os.path.join(dst_path, rel);
            make_dirs(os.path.dirname(target));
            copy_file(os.path.join(cur, fname), target);
        }
    }
}

impl skip_none(p: str) -> bool {
    return False;
}

impl skip_jaclang(p: str) -> bool {
    return (
        "__pycache__" in p
        or "node_modules" in p
        or "_precompiled" in p
        or "vendor/typeshed/stubs" in p
        or "libjacllvm." in p
        or "client/_bun" in p
        or p.endswith(".pyc")
    );
}

impl skip_site_template(p: str) -> bool {
    if p == ".gitignore" {
        return False;
    }
    base = p.rsplit("/", 1)[-1];
    return (
        p == ".jac"
        or p.startswith(".jac/")
        or "__pycache__" in p
        or "node_modules" in p
        or base.startswith(".")
    );
}

impl skip_stage_site(p: str) -> bool {
    base = p.rsplit("/", 1)[-1];
    if base.startswith("._") or base == ".DS_Store" {
        return True;
    }
    for top in (".cache", "Library", ".local") {
        if p == top or p.startswith(top + "/") {
            return True;
        }
    }
    return False;
}

impl skip_typeshed_tests(p: str) -> bool {
    return "@tests" in p;
}

impl toml_string(toml: str, key: str) -> str | None {
    for line in toml.split("\n") {
        t = line.lstrip(" \t");
        if not t.startswith(key) {
            continue;
        }
        rest = t[len(key):].lstrip(" \t");
        if not rest.startswith("=") {
            continue;
        }
        q1 = rest.find('"');
        if q1 < 0 {
            continue;
        }
        after = rest[q1 + 1:];
        q2 = after.find('"');
        if q2 < 0 {
            continue;
        }
        return after[:q2];
    }
    return None;
}

impl find_sum_line(sums: str, asset: str) -> str | None {
    for line in sums.split("\n") {
        toks = line.replace("\t", " ").replace("\r", " ").split();
        if len(toks) < 2 {
            continue;
        }
        if toks[1] == asset {
            return toks[0];
        }
    }
    return None;
}

impl clone_env(parent: dict[str, str] | None = None) -> dict[str, str] {
    return dict(os.environ) if parent is None else dict(parent);
}

impl run_child(argv: list[str], env: dict[str, str] | None, allow_fail: bool) -> bool {
    sys.stderr.flush();
    sys.stdout.flush();
    try {
        rc = subprocess.run(argv, env=env).returncode;
    } except OSError as e {
        die(f"spawn {argv[0]} failed: {type(e).__name__}: {e}");
    }
    ok = rc == 0;
    if not ok and not allow_fail {
        die(f"command failed: {argv[0]}");
    }
    return ok;
}

impl strip_best_effort(path: str) {
    before = file_size_or_zero(path);
    if before == 0 {
        return;
    }
    try {
        subprocess.run(
            ["strip", path],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        );
    } except OSError {
        log(f"   strip unavailable; shipping {path} unstripped");
        return;
    }
    after = file_size_or_zero(path);
    if after != 0 and after < before {
        log(f"   stripped {path}: {before >> 20} -> {after >> 20} MiB");
    }
}

impl source_file_mode(path: str) -> int {
    if os.name != "posix" {
        return 0;
    }
    try {
        return os.stat(path).st_mode & 0o7777;
    } except OSError {
        return 0;
    }
}

impl host_os_arch -> str {
    sysname = platform.system();
    os_names = {"Linux": "linux", "Darwin": "macos", "Windows": "windows"};
    os_name = os_names.get(sysname);
    if os_name is None {
        die(f"floor staging: unsupported host OS '{sysname}'");
    }
    machine = platform.machine().lower();
    arch_names = {
        "x86_64": "x86_64",
        "amd64": "x86_64",
        "aarch64": "aarch64",
        "arm64": "aarch64"
    };
    arch_name = arch_names.get(machine);
    if arch_name is None {
        die(f"floor staging: unsupported host arch '{machine}'");
    }
    return f"{os_name}-{arch_name}";
}

impl rd_u16(b: bytes, off: int) -> int {
    return int.from_bytes(b[off:off + 2], "little");
}

impl rd_u32(b: bytes, off: int) -> int {
    return int.from_bytes(b[off:off + 4], "little");
}

def _default_modes -> tuple[int, int] {
    um = os.umask(0);
    os.umask(um);
    return (0o666 & ~um, 0o777 & ~um);
}

def _stripped_name(name: str, strip_components: int) -> str | None {
    parts = [
        part
        for part in name.split("/")
        if part not in ("", ".")
    ];
    if len(parts) <= strip_components {
        return None;
    }
    return "/".join(parts[strip_components:]);
}

impl extract_tar(
    tar_bytes: bytes, dest: str, strip_components: int, exec_bit_only: bool
) {
    (file_default, dir_default) = _default_modes();
    make_dirs(dest);
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as tf {
        for m in tf {
            rel = _stripped_name(m.name, strip_components);
            if rel is None {
                continue;
            }
            target = os.path.join(dest, rel);
            if m.isdir() {
                make_dirs(target);
                continue;
            }
            make_dirs(os.path.dirname(target));
            if m.issym() or m.islnk() {
                delete_file(target);
                link_to = m.linkname
                    if m.issym()
                    else os.path.join(
                        dest, _stripped_name(m.linkname, strip_components) or m.linkname
                    );
                os.symlink(link_to, target);
                continue;
            }
            if not m.isfile() {
                continue;
            }
            src = tf.extractfile(m);
            if src is None {
                continue;
            }
            with open(target, "wb") as out {
                shutil.copyfileobj(src, out);
            }
            mode = file_default;
            if exec_bit_only and (m.mode & 0o100) != 0 {
                mode = file_default | 0o111;
            }
            os.chmod(target, mode);
        }
    }
    os.chmod(dest, dir_default | 0o700);
}
