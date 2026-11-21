---
description: The native pathlib module, as CPython's - pure and concrete paths of both flavours, their parts, queries, reading and writing, globbing and walking - and where it differs.
keywords: pathlib, pathlib.Path, Path, pathlib.PurePath, PurePath, pathlib.PurePosixPath, pathlib.PureWindowsPath, pathlib.PosixPath, pathlib.WindowsPath, pathlib.UnsupportedOperation, pathlib.types, Path.exists, Path.is_dir, Path.is_file, Path.read_text, Path.read_bytes, Path.write_text, Path.write_bytes, Path.mkdir, Path.unlink, Path.iterdir, Path.glob, Path.rglob, Path.walk, Path.resolve, Path.relative_to, Path.with_suffix, Path.suffix, Path.parts, Path.parents, Path.stat, Path.open, Path.touch, Path.rename, Path.copy, Path.move
---
# pathlib

`pathlib` is CPython's: pure paths (`PurePath`, `PurePosixPath`, `PureWindowsPath`), which parse
and join path text by a flavour's rules with no access to a file system, and concrete paths
(`Path`, `PosixPath`, `WindowsPath`), which also ask the file system about themselves, through
[os](os.md). A path is parsed, normalized, compared and printed as CPython's is, and its
methods raise what CPython's raise. It is native (see [The library](index.md),
`jac docs library`).

```jac
import os;
import shutil;
import from pathlib { Path, PurePosixPath, PureWindowsPath }

with entry {
    p = Path("reports", "2026") / "summary.tar.gz";
    print(p.suffix, p.suffixes, p.stem, p.parts, p.parent.name, p.with_suffix(".zip"));
    print(
        PurePosixPath("/a/b").is_absolute(),
        PureWindowsPath("C:/x/y").drive,
        PureWindowsPath("C:/x/y"),
        p.match("*.gz"),
    );
    top = Path("pathlib_demo");
    (top / "notes").mkdir(parents=True, exist_ok=True);
    f = top / "notes" / "a.txt";
    f.write_text("alpha\n");
    print(f.read_text(), end="");
    print(f.stat().st_size, f.exists(), [x.name for x in (top / "notes").iterdir()]);
    print(sorted(str(q.relative_to(top)) for q in top.rglob("*")), os.path.getsize(f));
    out = f.open("a");
    out.write("more\n");
    out.close();
    print(f.read_bytes(), os.fspath(f), Path(f.parent).is_dir());
    shutil.rmtree(top);
    print(top.exists());
}
```

```output
.gz ['.tar', '.gz'] summary.tar ('reports', '2026', 'summary.tar.gz') 2026 reports/2026/summary.tar.zip
True C: C:\x\y True
alpha
6 True ['a.txt']
['notes', 'notes/a.txt'] 6
b'alpha\nmore\n' pathlib_demo/notes/a.txt True
False
```

## What is there

Every member of CPython's `PurePath` and `Path` but four (below):

| Group | Members |
|---|---|
| Making one | `Path(*segments)`, `p / "name"`, `"name" / p`, `joinpath`, `with_segments`, `str(p)`, `os.fspath(p)`, `as_posix`, `as_uri` |
| Parts | `parts`, `drive`, `root`, `anchor`, `parent`, `parents`, `name`, `suffix`, `suffixes`, `stem`, `with_name`, `with_stem`, `with_suffix`, `relative_to` (`walk_up=`), `is_relative_to`, `is_absolute`, `match`, `full_match` |
| Queries | `exists`, `is_dir`, `is_file`, `is_symlink`, `is_mount`, `is_junction`, `is_socket`, `is_fifo`, `is_block_device`, `is_char_device`, `samefile`, `stat`, `lstat`, `owner`, `group`, `info` |
| Reading and writing | `open`, `read_text`, `read_bytes`, `write_text`, `write_bytes` |
| Directories | `iterdir`, `glob`, `rglob`, `walk`, `mkdir`, `rmdir` |
| Changing | `touch`, `unlink`, `rename`, `replace`, `chmod`, `lchmod`, `symlink_to`, `hardlink_to`, `readlink`, `copy`, `copy_into`, `move`, `move_into` |
| Resolving | `absolute`, `resolve`, `expanduser` |

A `Path` is accepted wherever a path is, as an `os.PathLike`: by the functions of [os](os.md),
`open()` and [shutil](files.md). A file or directory that is not there raises
`FileNotFoundError`, with `errno` 2 and `filename` the path; `mkdir` of an existing directory
without `exist_ok` raises `FileExistsError`.

```jac
import from pathlib { Path }

with entry {
    try {
        Path("pathlib_missing_demo/x.txt").read_text();
    } except FileNotFoundError as e {
        print(e.errno, e);
    }
    try {
        Path("a/b").relative_to("c");
    } except ValueError as e {
        print(e);
    }
}
```

```output
2 [Errno 2] No such file or directory: 'pathlib_missing_demo/x.txt'
'a/b' is not in the subpath of 'c'
```

## Differences from CPython

- **`parent` and the items of `parents` are typed `PurePath`**, as a property cannot yet be
  typed as the class of the path it is read from: `p.parent.is_dir()` is refused (E1030). Make a
  `Path` of it, `Path(p.parent).is_dir()`, as the example does.
- **`Path.open` with a mode gives an `any`**, and an `any` is not a context manager: close the
  file with `close()`, or call the builtin `open(p, "a")`, whose literal mode types it.
- **`PurePath(...)` and `Path(...)` make a path of the host's flavour, of the class named**,
  not of `PurePosixPath` or `WindowsPath` as CPython's do.
- **`glob` and `rglob` give paths in the file system's order**, as CPython; sort where order
  matters.

## Not there yet

`Path.cwd()`, `Path.home()`, `Path.from_uri()` and `PurePath.parser` are not written yet (E1030):
use `Path(os.getcwd())` and `Path(os.path.expanduser("~"))`. `parser` is the flavour's module
(`posixpath` or `ntpath`), which waits for a module to be a value.

## Related

- [os and os.path](os.md): the functions `Path` is built on.
- [Files and directories](files.md): `shutil`, `tempfile`, `glob`.
- Every native module: [Standard-library modules](stdlib.md).
