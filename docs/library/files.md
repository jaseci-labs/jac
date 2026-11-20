---
description: The native modules for files and directories, as CPython's - shutil with its archive functions, tempfile, glob, filecmp, fileinput, stat and mmap - and the few names they leave out.
keywords: files and directories, shutil, shutil.copy, shutil.copy2, shutil.copyfile, shutil.copyfileobj, shutil.copytree, shutil.rmtree, shutil.move, shutil.which, shutil.disk_usage, shutil.chown, shutil.get_terminal_size, shutil.ignore_patterns, shutil.make_archive, shutil.unpack_archive, shutil.get_archive_formats, shutil.register_archive_format, shutil.get_unpack_formats, shutil.register_unpack_format, tempfile, tempfile.TemporaryDirectory, tempfile.NamedTemporaryFile, tempfile.TemporaryFile, tempfile.SpooledTemporaryFile, tempfile.mkstemp, tempfile.mkdtemp, tempfile.gettempdir, glob.glob, glob.iglob, glob.escape, glob.translate, glob.has_magic, filecmp, filecmp.cmp, filecmp.cmpfiles, filecmp.dircmp, fileinput, fileinput.input, fileinput.FileInput, fileinput.hook_compressed, stat, stat.S_ISDIR, stat.S_ISREG, stat.S_IMODE, stat.S_IFMT, stat.filemode, mmap, mmap.mmap
---
# Files and directories: shutil, tempfile, glob, filecmp, fileinput, stat, mmap

These modules are CPython's, over [`os`](os.md): copying and removing trees, temporary files and
directories, matching names with wildcards, comparing files and directories, reading many files
as one stream of lines, the bits of a file's mode, and files mapped into memory. Each gives
CPython's results, exceptions and messages. They are native (see [The library](index.md),
`jac docs library`).

```jac
import filecmp;
import fileinput;
import glob;
import os;
import shutil;
import stat;
import tempfile;

with entry {
    with tempfile.TemporaryDirectory() as top {
        os.makedirs(os.path.join(top, "src", "sub"));
        for name in ["a.txt", "b.txt", "sub/c.txt"] {
            with open(os.path.join(top, "src", name), "w") as f {
                f.write(f"{name}\n");
            }
        }
        shutil.copytree(os.path.join(top, "src"), os.path.join(top, "dst"));
        cmp = filecmp.dircmp(os.path.join(top, "src"), os.path.join(top, "dst"));
        print(sorted(cmp.same_files), cmp.left_only, cmp.common_dirs);
        found = `glob.glob("**/*.txt", root_dir=os.path.join(top, "src"), recursive=True);
        print(sorted(found));
        files = [os.path.join(top, "src", n) for n in ["a.txt", "b.txt"]];
        with fileinput.input(files) as lines {
            for line in lines {
                print(fileinput.filelineno(), line.strip());
            }
        }
        mode = os.stat(os.path.join(top, "src")).st_mode;
        print(stat.S_ISDIR(mode), stat.filemode(stat.S_IFREG | 0o644));
        with tempfile.NamedTemporaryFile("w+", suffix=".log", dir=top) as tmp {
            tmp.write("kept\n");
            tmp.seek(0);
            print(tmp.name.endswith(".log"), tmp.read().strip());
        }
        shutil.rmtree(os.path.join(top, "dst"));
        print(sorted(os.listdir(top)));
    }
}
```

```output
['a.txt', 'b.txt'] [] ['sub']
['a.txt', 'b.txt', 'sub/c.txt']
1 a.txt
1 b.txt
True -rw-r--r--
True kept
['src']
```

`glob` is also a Jac keyword: `import glob;` needs no backtick, but a use of the module does
(`` `glob.glob("*.txt") ``).

## The modules

| Module | What it has |
|---|---|
| `shutil` | `copyfileobj`, `copyfile`, `copymode`, `copystat`, `copy`, `copy2`, `copytree` (with `ignore`, `ignore_patterns`, `dirs_exist_ok`, `copy_function`), `rmtree` (with `onexc`), `move`, `which`, `disk_usage`, `chown`, `get_terminal_size`, `make_archive`, `unpack_archive` and the two registries of formats ([Archives](#archives)), and the error classes |
| `tempfile` | `TemporaryDirectory`, `NamedTemporaryFile`, `TemporaryFile`, `SpooledTemporaryFile`, `mkstemp`, `mkdtemp`, `mktemp`, `gettempdir`, `gettempprefix` and their `bytes` forms, `tempdir`, `template` |
| `glob` | `glob`, `iglob` (with `root_dir`, `dir_fd`, `recursive`, `include_hidden`), `escape`, `has_magic`, `translate` |
| `filecmp` | `cmp`, `cmpfiles`, `dircmp` (every attribute and `report`, `report_full_closure`), `clear_cache`, `DEFAULT_IGNORES` |
| `fileinput` | `input`, `FileInput` (with `inplace` and `backup`, `openhook`, `encoding`), `hook_encoded`, `hook_compressed`, and the module's state functions (`filename`, `lineno`, `filelineno`, `isfirstline`, `nextfile`, ...) |
| `stat` | Every `S_*`, `ST_*`, `UF_*`, `SF_*` and `FILE_ATTRIBUTE_*` constant, the `S_IS*` tests, `S_IMODE`, `S_IFMT`, `filemode` |
| `mmap` | `mmap` over a file or anonymous memory: indexing and slices, `read`, `write`, `find`, `rfind`, `seek`, `readline`, `flush`, `resize`, `move`, `madvise`, `with`; the target's `MAP_*`, `PROT_*` and `MADV_*` constants |

As in CPython: `glob` leaves out names that start with `.` unless `include_hidden=True`, and
`**` matches directories at any depth only with `recursive=True`. `shutil.copy` keeps the
permission bits and `copy2` the modification time too; `copytree` onto a directory that exists
raises `FileExistsError` unless `dirs_exist_ok=True`; `which` returns `None` for a command it
cannot find. A `TemporaryDirectory` and a `NamedTemporaryFile` remove what they made when their
`with` ends, and what is left at the program's end is removed then.

```jac
import mmap;

with entry {
    with open("data.bin", "wb") as f {
        f.write(b"hello mapped world");
    }
    with open("data.bin", "r+b") as both {
        with mmap.mmap(both.fileno(), 0) as m {
            print(len(m), m[:5], m.find(b"world"));
            m[0:5] = b"HELLO";
            m.seek(6);
            print(m.read(6), m.readline());
            m.flush();
        }
    }
    with open("data.bin", "rb") as back {
        print(back.read());
    }
    anon = mmap.mmap(-1, 16);
    anon.write(b"scratch");
    print(anon[:7], mmap.PAGESIZE > 0);
    anon.close();
}
```

```output
18 b'hello' 13
b'mapped' b' world'
b'HELLO mapped world'
b'scratch' True
```

On Windows, `shutil.disk_usage` and `shutil.chown` are not written yet (E1145), and `rmtree`
walks the tree by its paths, as CPython's does there.

## Archives

`shutil.make_archive` writes a tree as one archive file and `unpack_archive` unpacks one, over
the native `zipfile` and `tarfile` ([Compression and archives](compression.md)).

| Name | What it does |
|---|---|
| `make_archive(base_name, format, root_dir=None, base_dir=None, verbose=False, dry_run=False, owner=None, group=None, logger=None)` | Archives `base_dir`, a path relative to `root_dir`, or all of `root_dir`, as `base_name` plus the format's extension, and returns that name. `format` is `"zip"`, `"tar"`, `"gztar"`, `"bztar"`, `"xztar"`, `"zstdtar"` or one the program registered; `owner` and `group` name the owner of a tar archive's members |
| `unpack_archive(filename, extract_dir=None, format=None, *, filter=None)` | Unpacks into `extract_dir` (the current directory by default), as `format` or as the format of the file's extension. `filter` is `tarfile`'s extraction filter. A file of no known format raises `ReadError` |
| `get_archive_formats()`, `register_archive_format(name, function, extra_args=None, description="")`, `unregister_archive_format(name)` | The formats `make_archive` writes: `function(base_name, base_dir, **keywords)` makes the archive and returns its name |
| `get_unpack_formats()`, `register_unpack_format(name, extensions, function, extra_args=None, description="")`, `unregister_unpack_format(name)` | The formats `unpack_archive` reads, each with the extensions of its files: `function(filename, extract_dir, **keywords)` unpacks one |
| `fileinput.hook_compressed(filename, mode, *, encoding=None, errors=None)` | An `openhook` that reads a `.gz` file through `gzip` and a `.bz2` file through `bz2`, and opens any other file as `open` does |

```jac
import fileinput;
import gzip;
import os;
import shutil;
import tempfile;
import zipfile;

with entry {
    with tempfile.TemporaryDirectory() as top {
        os.makedirs(os.path.join(top, "site", "css"));
        for name in ["index.html", "css/main.css"] {
            with open(os.path.join(top, "site", name), "w") as f {
                f.write(f"{name}\n");
            }
        }
        made = shutil.make_archive(
            os.path.join(top, "backup"), "zip", root_dir=top, base_dir="site"
        );
        with zipfile.ZipFile(made) as z {
            print(os.path.basename(made), sorted(z.namelist()));
        }
        packed = shutil.make_archive(
            os.path.join(top, "backup"), "gztar", os.path.join(top, "site")
        );
        print(os.path.basename(packed));
        shutil.unpack_archive(packed, os.path.join(top, "restored"));
        print(sorted(os.listdir(os.path.join(top, "restored"))));
        print([name for (name, what) in shutil.get_archive_formats()]);
        print([extensions for (name, extensions, what) in shutil.get_unpack_formats()][:2]);
        try {
            shutil.unpack_archive(os.path.join(top, "site", "index.html"));
        } except shutil.ReadError as e {
            print("ReadError:", str(e).startswith("Unknown archive format"));
        }
        log = os.path.join(top, "old.log.gz");
        with gzip.open(log, "wt") as packed_log {
            packed_log.write("first\nsecond\n");
        }
        with fileinput.input(log, openhook=fileinput.hook_compressed, encoding="utf-8") as lines {
            print([line.strip() for line in lines]);
        }
    }
}
```

```output
backup.zip ['site/', 'site/css/', 'site/css/main.css', 'site/index.html']
backup.tar.gz
['css', 'index.html']
['bztar', 'gztar', 'tar', 'xztar', 'zip', 'zstdtar']
[['.tar.bz2', '.tbz2'], ['.tar.gz', '.tgz']]
ReadError: True
['first', 'second']
```

## What is left out

- **`filecmp.dircmp.methodmap`** (E5142): a native `dircmp` computes each attribute as a
  property, so there is no such map; read the attribute.
- **`shutil.rmtree.avoids_symlink_attacks`** (E5142): a Jac function has no attributes.
  `rmtree` removes through directory descriptors on Linux and macOS, where CPython's is true.

```jac
# expect: E5142
import shutil;

with entry {
    print(shutil.rmtree.avoids_symlink_attacks);
}
```
