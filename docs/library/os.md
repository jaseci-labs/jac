---
description: The native os module and os.path (posixpath, ntpath, genericpath): files, directories, the environment and path names, and where they differ from CPython's.
keywords: os, os.path, posixpath, ntpath, genericpath, os.environ, os.getenv, os.putenv, os.unsetenv, os.getcwd, os.chdir, os.listdir, os.walk, os.mkdir, os.makedirs, os.rmdir, os.removedirs, os.remove, os.unlink, os.rename, os.replace, os.symlink, os.readlink, os.stat, os.lstat, os.stat_result, os.utime, os.chmod, os.access, os.system, os.getpid, os.urandom, os.cpu_count, os.process_cpu_count, os.fspath, os.name, os.sep, os.linesep, os.path.join, os.path.split, os.path.splitext, os.path.basename, os.path.dirname, os.path.exists, os.path.isfile, os.path.isdir, os.path.islink, os.path.getsize, os.path.getmtime, os.path.abspath, os.path.realpath, os.path.relpath, os.path.normpath, os.path.expanduser, os.path.commonpath, ntpath.isreserved, os.open, os.fdopen, os.read, os.write, os.close, os.pipe, os.dup, os.dup2, os.fork, os.execv, os.waitpid, os.kill, os.scandir, os.DirEntry, os.getuid, os.uname, os.strerror, os.get_terminal_size, os.fsencode, os.fsdecode, os.environb, os.PathLike, os.posix_spawn, os.sendfile
---
# os and os.path

`import os` in a native program loads jac's own `os`, written in Jac over the operating
system's interface: it has the names and the behavior of CPython's `os` (all but five of the 507
names of its stub on Linux), and raises the same `OSError` subclasses with the same messages. It is not CPython's module (see [The library](index.md), `jac docs library`).
`os.path` is the path-name module of the target, as in CPython: `posixpath` on Linux, macOS and
WASI, `ntpath` on Windows (exactly when `os.name == "nt"`). Both `posixpath` and `ntpath` can be
imported by name on every target; they are string functions plus file-system queries shared
through `genericpath`.

```jac
import os;
import shutil;

with entry {
    base = os.path.join(os.getcwd(), "os_demo");
    os.makedirs(os.path.join(base, "src", "pkg"), exist_ok=True);
    with open(os.path.join(base, "src", "main.jac"), "w") as f {
        f.write("with entry { }\n");
    }
    with open(os.path.join(base, "src", "pkg", "util.jac"), "w") as f {
        f.write("");
    }
    for (top, dirs, files) in os.walk(base) {
        dirs.sort();
        print(os.path.relpath(top, base), sorted(files));
    }
    print(os.path.getsize(os.path.join(base, "src", "main.jac")));
    print(os.path.splitext("archive.tar.gz"), os.path.basename("/a/b/c.txt"));
    shutil.rmtree(base);
    print(os.path.exists(base));
}
```

```output
. []
src ['main.jac']
src/pkg ['util.jac']
15
('archive.tar', '.gz') c.txt
False
```

## What is there

CPython's interface, by the stub for the target: what CPython has on Linux, macOS or Windows is
what the native module has there, and a name the target lacks (`os.fork` on Windows) does not
compile.

| Group | Names (among others) |
|---|---|
| Constants | `name` (`"posix"` or `"nt"`), `linesep`, `sep`, `altsep`, `curdir`, `pardir`, `extsep`, `pathsep`, `defpath`, `devnull`, `F_OK`, `R_OK`, `W_OK`, `X_OK`, the `O_*`, `SEEK_*`, `W*`, `P_*`, `SCHED_*`, `ST_*` and `XATTR_*` constants of the target |
| Environment | `environ`, `environb`, `getenv`, `getenvb`, `putenv`, `unsetenv`, `get_exec_path` |
| Process | `getpid`, `getppid`, `getuid`, `geteuid`, `getgid`, `getgroups`, `setsid`, `umask`, `nice`, `times`, `uname`, `cpu_count`, `process_cpu_count`, `sched_getaffinity`, `getloadavg`, `urandom`, `getrandom`, `strerror` |
| Children | `system`, `fork`, `forkpty`, `execv`, `execve` and the other `exec*`, `spawn*`, `posix_spawn`, `posix_spawnp`, `kill`, `killpg`, `wait`, `waitpid`, `waitstatus_to_exitcode`, `WIFEXITED`, `WEXITSTATUS` and the other status tests, `_exit`, `abort`, `pidfd_open` |
| File descriptors | `open`, `fdopen`, `read`, `write`, `pread`, `pwrite`, `readv`, `writev`, `close`, `closerange`, `dup`, `dup2`, `pipe`, `pipe2`, `lseek`, `fstat`, `fsync`, `ftruncate`, `isatty`, `ttyname`, `openpty`, `get_blocking`, `set_blocking`, `get_inheritable`, `set_inheritable`, `sendfile`, `copy_file_range`, `get_terminal_size`, `terminal_size` |
| Directories | `listdir`, `scandir`, `DirEntry`, `walk`, `fwalk`, `mkdir`, `makedirs`, `rmdir`, `removedirs`, `getcwd`, `chdir`, `fchdir` |
| Files | `remove`, `unlink`, `rename`, `renames`, `replace`, `link`, `symlink`, `readlink`, `chmod`, `chown`, `lchown`, `utime`, `truncate`, `access`, `mkfifo`, `mknod`, `statvfs`, `getxattr`, `setxattr`, `listxattr`, `fspath`, `fsencode`, `fsdecode`, `PathLike` |
| File status | `stat`, `lstat`, `fstat`, `stat_result` (every `st_*` field of the target), `statvfs_result` |
| `os.path` names | `join`, `split`, `splitext`, `splitdrive`, `splitroot`, `basename`, `dirname`, `normpath`, `normcase`, `isabs`, `abspath`, `realpath`, `relpath`, `expanduser`, `expandvars`, `commonpath`, `commonprefix`, `exists`, `lexists`, `isfile`, `isdir`, `islink`, `ismount`, `isjunction`, `isdevdrive`, `samefile`, `sameopenfile`, `samestat`, `getsize`, `getmtime`, `getatime`, `getctime` |
| `ntpath` only | `isreserved` |

```jac
import os;

with entry {
    fd = os.open("raw.txt", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644);
    os.write(fd, b"abc\n");
    os.close(fd);
    for item in os.scandir(".") {
        if item.name == "raw.txt" {
            print(item.name, item.is_file(), item.stat().st_size);
        }
    }
    (r, w) = os.pipe();
    os.write(w, b"through a pipe");
    print(os.read(r, 100));
    os.close(r);
    os.close(w);
    print(
        os.getpid() > 0, os.getppid() > 0, os.strerror(2), os.path.expandvars("$NO_SUCH_VAR_X/x")
    );
    print(
        os.uname().sysname in ["Linux", "Darwin"], os.cpu_count() > 0, os.getuid() == os.geteuid()
    );
    pid = os.fork();
    if pid == 0 {
        os._exit(7);
    }
    (got, status) = os.waitpid(pid, 0);
    print(got == pid, os.WIFEXITED(status), os.WEXITSTATUS(status));
    os.remove("raw.txt");
}
```

```output
raw.txt True 4
b'through a pipe'
True True No such file or directory $NO_SUCH_VAR_X/x
True True True
True True 7
```

`import os.path`, `import from os.path { join }` and `os.path.join` after `import os` all reach
the same functions.

The string functions of `posixpath` and `ntpath` give CPython's results on every target, which
is how a program handles the other system's paths:

```jac
import posixpath;
import ntpath;

with entry {
    print(posixpath.normpath(""), posixpath.join("a", "/b"), posixpath.split("/a/b/"));
    print(ntpath.join("C:/a", "D:b"), ntpath.normpath("/../x"), ntpath.splitdrive("C:\\a"));
    try {
        ntpath.relpath("C:\\a", "D:\\b");
    } except ValueError as e {
        print(e);
    }
}
```

```output
. /b ('/a/b', '')
D:b \x ('C:', '\\a')
path is on mount 'C:', start on mount 'D:'
```

`os.environ` is a mapping of str to str: indexing, `in`, `len`, iteration, `get`, `keys`,
`values`, `items`, `copy` (a plain `dict[str, str]`), `setdefault` and `pop`. Setting or deleting
a name changes the environment of the process, so child processes see it. `putenv` changes the
process's environment without changing `os.environ`, as in CPython.

```jac
import os;
import subprocess;

with entry {
    os.environ["DEMO_NAME"] = "a";
    os.putenv("DEMO_OTHER", "b");
    print(os.environ["DEMO_NAME"], os.getenv("DEMO_OTHER"), os.getenv("DEMO_MISSING", "none"));
    cp = subprocess.run(
        ["sh", "-c", "echo $DEMO_NAME $DEMO_OTHER"], capture_output=True, text=True
    );
    out: str = cp.stdout;
    print(out.strip());
    del os.environ["DEMO_NAME"];
    print("DEMO_NAME" in os.environ);
}
```

```output
a None none
a b
False
```

## Errors

A failing call raises the `OSError` subclass CPython raises, with its `errno`, its `filename`
and the message `[Errno N] text: 'path'` (see [Builtin exceptions](exceptions.md)).

```jac
import os;
import shutil;

with entry {
    d = "os_errors_demo";
    os.makedirs(d, exist_ok=True);
    try {
        os.remove(os.path.join(d, "missing.txt"));
    } except FileNotFoundError as e {
        print(e.errno, e.filename);
    }
    try {
        os.mkdir(d);
    } except FileExistsError as e {
        print(e);
    }
    shutil.rmtree(d);
}
```

```output
2 os_errors_demo/missing.txt
[Errno 17] File exists: 'os_errors_demo'
```

The `os.path` queries `exists`, `isfile`, `isdir`, `islink` and `lexists` answer `False` where
the file cannot be reached; `getsize` and the time queries raise.

## Differences from CPython

- **Paths are `str` or an `os.PathLike`** (a [pathlib](pathlib.md) `Path`). A `bytes` path is
  refused (E1053); `os.fsencode` and `os.fsdecode` convert between the two.
- **`os.environ` is not a `dict`.** Where a `dict[str, str]` is declared, such as
  `subprocess.run(env=...)`, pass `os.environ.copy()`; passing `os.environ` is refused (E1053).
- **A module is not a value.** `m = os;` and `os.path is ...` are refused (E5090); name what
  you use: `os.path.join(...)`.
- **`os.listdir` order is the file system's**, as in CPython; sort it where order matters.
- **`ntpath.isabs("\\x")` is `False`**: a path with a root and no drive is not absolute, as
  since Python 3.13.
- **A name that is not UTF-8 is not yet decoded with `surrogateescape`**, as CPython's are.

## fdopen

`os.fdopen(fd, mode, ...)` is the builtin `open` given a descriptor, and takes nothing else: a
path is E1001. As with `open`, a call whose mode is written out has that mode's stream's type
(`os.fdopen(fd, "rb")` is a `BufferedReader`), and one whose mode is known only as the program
runs gives an `any`.

## Not there yet

`popen`, `wait3` and `wait4` are not written yet (E1145 when named);
`POSIX_SPAWN_CLOSEFROM` is left out on purpose (E5142: it needs glibc 2.34, and a jac program
runs on glibc 2.29 and later). On Windows, the `l` and `p` forms of `exec` and `spawn`
(`execlp`, `spawnlp`, ...) are not written yet.

## Platforms

- **Linux, macOS, WASI:** `os.name` is `"posix"`, `os.sep` is `/`, `os.path` is `posixpath`.
- **Windows:** `os.name` is `"nt"`, `os.sep` is `\` and `os.altsep` is `/`; `getcwd`,
  `listdir` and `walk` give `\`-separated paths and take either separator. `chmod` sets or
  clears the read-only attribute, as CPython's does, and `symlink`'s `target_is_directory` makes
  a directory link.

## Related

- [pathlib](pathlib.md) for the object form of paths, [subprocess](subprocess.md) for child
  processes, [sys](sys.md) for the command line and the standard streams.
- `open()` is a builtin: [Builtin functions](builtins.md).
- Every native module: [Standard-library modules](stdlib.md).
