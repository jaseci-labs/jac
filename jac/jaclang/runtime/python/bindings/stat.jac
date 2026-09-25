"""The _stat module: mode predicates and constants, compiled into JacPython."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBool_FromLong,
    PyLong_FromUnsignedLong,
    PyModule_AddIntConstant,
    PyObject,
    PyUnicode_FromString
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition
}
import from jaclang.runtime.python.capi { boundary_failure }
import from jaclang.runtime.python.modules.stat {
    mode_value,
    is_type,
    filemode_text,
    S_IMODE,
    S_IFMT,
    S_IFDIR,
    S_IFCHR,
    S_IFBLK,
    S_IFREG,
    S_IFIFO,
    S_IFLNK,
    S_IFSOCK,
    S_IFDOOR,
    S_IFPORT,
    S_ISUID,
    S_ISGID,
    S_ISVTX,
    S_IRWXU,
    S_IRUSR,
    S_IWUSR,
    S_IXUSR,
    S_IRWXG,
    S_IRGRP,
    S_IWGRP,
    S_IXGRP,
    S_IRWXO,
    S_IROTH,
    S_IWOTH,
    S_IXOTH
}
import from jaclang.runtime.python.modules.stat_platform {
    PLATFORM,
    S_IFWHT,
    UF_SETTABLE,
    UF_NODUMP,
    UF_IMMUTABLE,
    UF_APPEND,
    UF_OPAQUE,
    UF_NOUNLINK,
    UF_COMPRESSED,
    UF_TRACKED,
    UF_DATAVAULT,
    UF_HIDDEN,
    SF_SETTABLE,
    SF_ARCHIVED,
    SF_IMMUTABLE,
    SF_APPEND,
    SF_NOUNLINK,
    SF_SNAPSHOT,
    SF_FIRMLINK,
    SF_DATALESS,
    SF_SUPPORTED,
    SF_SYNTHETIC,
    HAS_SF_SUPPORTED
}

glob:priv METH_O: i64 = 8;

def:priv predicate(value: ptr[PyObject], kind: u64) -> ptr[PyObject] {
    try {
        return PyBool_FromLong(i64(is_type(mode_value(value), kind)));
    } except boundary_failure {
        return NULL;
    }
}

def:priv is_dir(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFDIR);
}

def:priv is_chr(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFCHR);
}

def:priv is_blk(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFBLK);
}

def:priv is_reg(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFREG);
}

def:priv is_fifo(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFIFO);
}

def:priv is_lnk(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFLNK);
}

def:priv is_sock(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFSOCK);
}

def:priv is_door(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFDOOR);
}

def:priv is_port(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFPORT);
}

def:priv is_wht(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return predicate(value, S_IFWHT);
}

def:priv masked(value: ptr[PyObject], mask: u64) -> ptr[PyObject] {
    try {
        return PyLong_FromUnsignedLong(mode_value(value) & mask);
    } except boundary_failure {
        return NULL;
    }
}

def:priv imode(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return masked(value, S_IMODE);
}

def:priv ifmt(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return masked(value, S_IFMT);
}

def:priv filemode(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return PyUnicode_FromString(filemode_text(mode_value(value), S_IFWHT));
    } except boundary_failure {
        return NULL;
    }
}

def:priv constants -> list[tuple[str, u64]] {
    names = [
        ("S_IFDIR", S_IFDIR),
        ("S_IFCHR", S_IFCHR),
        ("S_IFBLK", S_IFBLK),
        ("S_IFREG", S_IFREG),
        ("S_IFIFO", S_IFIFO),
        ("S_IFLNK", S_IFLNK),
        ("S_IFSOCK", S_IFSOCK),
        ("S_IFDOOR", S_IFDOOR),
        ("S_IFPORT", S_IFPORT),
        ("S_IFWHT", S_IFWHT),
        ("S_ISUID", S_ISUID),
        ("S_ISGID", S_ISGID),
        ("S_ISVTX", S_ISVTX),
        ("S_ENFMT", S_ISGID),
        ("S_IREAD", S_IRUSR),
        ("S_IWRITE", S_IWUSR),
        ("S_IEXEC", S_IXUSR),
        ("S_IRWXU", S_IRWXU),
        ("S_IRUSR", S_IRUSR),
        ("S_IWUSR", S_IWUSR),
        ("S_IXUSR", S_IXUSR),
        ("S_IRWXG", S_IRWXG),
        ("S_IRGRP", S_IRGRP),
        ("S_IWGRP", S_IWGRP),
        ("S_IXGRP", S_IXGRP),
        ("S_IRWXO", S_IRWXO),
        ("S_IROTH", S_IROTH),
        ("S_IWOTH", S_IWOTH),
        ("S_IXOTH", S_IXOTH),
        ("UF_SETTABLE", UF_SETTABLE),
        ("UF_NODUMP", UF_NODUMP),
        ("UF_IMMUTABLE", UF_IMMUTABLE),
        ("UF_APPEND", UF_APPEND),
        ("UF_OPAQUE", UF_OPAQUE),
        ("UF_NOUNLINK", UF_NOUNLINK),
        ("UF_COMPRESSED", UF_COMPRESSED),
        ("UF_TRACKED", UF_TRACKED),
        ("UF_DATAVAULT", UF_DATAVAULT),
        ("UF_HIDDEN", UF_HIDDEN),
        ("SF_SETTABLE", SF_SETTABLE),
        ("SF_ARCHIVED", SF_ARCHIVED),
        ("SF_IMMUTABLE", SF_IMMUTABLE),
        ("SF_APPEND", SF_APPEND),
        ("SF_NOUNLINK", SF_NOUNLINK),
        ("SF_SNAPSHOT", SF_SNAPSHOT),
        ("SF_FIRMLINK", SF_FIRMLINK),
        ("SF_DATALESS", SF_DATALESS)
    ];
    if HAS_SF_SUPPORTED {
        names.append(("SF_SUPPORTED", SF_SUPPORTED));
        names.append(("SF_SYNTHETIC", SF_SYNTHETIC));
    }
    fields = [
        "ST_MODE",
        "ST_INO",
        "ST_DEV",
        "ST_NLINK",
        "ST_UID",
        "ST_GID",
        "ST_SIZE",
        "ST_ATIME",
        "ST_MTIME",
        "ST_CTIME"
    ];
    for index in range(len(fields)) {
        names.append((fields[index], u64(index)));
    }
    return names;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            "ImportError",
            "_stat has no stat_platform.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    for (name, value) in constants() {
        if PyModule_AddIntConstant(module, name, i64(value)) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_stat",
         "S_IFMT_: file type bits\nS_IFDIR: directory\nS_IFCHR: character device\nS_IFBLK: block device\nS_IFREG: regular file\nS_IFIFO: fifo (named pipe)\nS_IFLNK: symbolic link\nS_IFSOCK: socket file\nS_IFDOOR: door\nS_IFPORT: event port\nS_IFWHT: whiteout\n\nS_ISUID: set UID bit\nS_ISGID: set GID bit\nS_ENFMT: file locking enforcement\nS_ISVTX: sticky bit\nS_IREAD: Unix V7 synonym for S_IRUSR\nS_IWRITE: Unix V7 synonym for S_IWUSR\nS_IEXEC: Unix V7 synonym for S_IXUSR\nS_IRWXU: mask for owner permissions\nS_IRUSR: read by owner\nS_IWUSR: write by owner\nS_IXUSR: execute by owner\nS_IRWXG: mask for group permissions\nS_IRGRP: read by group\nS_IWGRP: write by group\nS_IXGRP: execute by group\nS_IRWXO: mask for others (not in group) permissions\nS_IROTH: read by others\nS_IWOTH: write by others\nS_IXOTH: execute by others\n\nUF_SETTABLE: mask of owner changeable flags\nUF_NODUMP: do not dump file\nUF_IMMUTABLE: file may not be changed\nUF_APPEND: file may only be appended to\nUF_OPAQUE: directory is opaque when viewed through a union stack\nUF_NOUNLINK: file may not be renamed or deleted\nUF_COMPRESSED: macOS: file is hfs-compressed\nUF_TRACKED: used for dealing with document IDs\nUF_DATAVAULT: entitlement required for reading and writing\nUF_HIDDEN: macOS: file should not be displayed\nSF_SETTABLE: mask of super user changeable flags\nSF_ARCHIVED: file may be archived\nSF_IMMUTABLE: file may not be changed\nSF_APPEND: file may only be appended to\nSF_RESTRICTED: entitlement required for writing\nSF_NOUNLINK: file may not be renamed or deleted\nSF_SNAPSHOT: file is a snapshot file\nSF_FIRMLINK: file is a firmlink\nSF_DATALESS: file is a dataless object\n\nOn macOS:\nSF_SUPPORTED: mask of super user supported flags\nSF_SYNTHETIC: mask of read-only synthetic flags\n\nST_MODE\nST_INO\nST_DEV\nST_NLINK\nST_UID\nST_GID\nST_SIZE\nST_ATIME\nST_MTIME\nST_CTIME\n\nFILE_ATTRIBUTE_*: Windows file attribute constants\n                   (only present on Windows)\n",
         [
             MethodDefinition(
                 "S_ISDIR",
                 MethodCallbacks(positional=is_dir),
                 "S_ISDIR(mode) -> bool\n\nReturn True if mode is from a directory.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISCHR",
                 MethodCallbacks(positional=is_chr),
                 "S_ISCHR(mode) -> bool\n\nReturn True if mode is from a character special device file.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISBLK",
                 MethodCallbacks(positional=is_blk),
                 "S_ISBLK(mode) -> bool\n\nReturn True if mode is from a block special device file.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISREG",
                 MethodCallbacks(positional=is_reg),
                 "S_ISREG(mode) -> bool\n\nReturn True if mode is from a regular file.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISFIFO",
                 MethodCallbacks(positional=is_fifo),
                 "S_ISFIFO(mode) -> bool\n\nReturn True if mode is from a FIFO (named pipe).",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISLNK",
                 MethodCallbacks(positional=is_lnk),
                 "S_ISLNK(mode) -> bool\n\nReturn True if mode is from a symbolic link.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISSOCK",
                 MethodCallbacks(positional=is_sock),
                 "S_ISSOCK(mode) -> bool\n\nReturn True if mode is from a socket.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISDOOR",
                 MethodCallbacks(positional=is_door),
                 "S_ISDOOR(mode) -> bool\n\nReturn True if mode is from a door.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISPORT",
                 MethodCallbacks(positional=is_port),
                 "S_ISPORT(mode) -> bool\n\nReturn True if mode is from an event port.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_ISWHT",
                 MethodCallbacks(positional=is_wht),
                 "S_ISWHT(mode) -> bool\n\nReturn True if mode is from a whiteout.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_IMODE",
                 MethodCallbacks(positional=imode),
                 "Return the portion of the file's mode that can be set by os.chmod().",
                 flags=METH_O
             ),
             MethodDefinition(
                 "S_IFMT",
                 MethodCallbacks(positional=ifmt),
                 "Return the portion of the file's mode that describes the file type.",
                 flags=METH_O
             ),
             MethodDefinition(
                 "filemode",
                 MethodCallbacks(positional=filemode),
                 "Convert a file's mode to a string of the form '-rwxrwxrwx'",
                 flags=METH_O
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__stat -> ptr[PyObject] {
    return definition.initialize();
}
