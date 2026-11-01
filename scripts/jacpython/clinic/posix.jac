"""The Argument Clinic signatures of posix.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/posix.jac from them. Taken from
the C sources it replaces (Modules/posixmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="posix",
         version="3.14.6",
         sources=["Modules/posixmodule.c"],
         classes={"sched_param": "PyObject *", "DirEntry": "DirEntry *"},
         functions=[
             Function(
                 name="stat",
                 full_name="os.stat",
                 c_basename="os_stat",
                 docstring="stat($module, /, path, *, dir_fd=None, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Perform a stat system call on the given path.\n"
                 "\n"
                 "  path\n"
                 "    Path to be examined; can be string, bytes, a path-like object or\n"
                 "    open-file-descriptor int.\n"
                 "  dir_fd\n"
                 "    If not None, it should be a file descriptor open to a directory,\n"
                 "    and path should be a relative string; path will then be relative to\n"
                 "    that directory.\n"
                 "  follow_symlinks\n"
                 "    If False, and the last element of the path is a symbolic link,\n"
                 "    stat will examine the symbolic link itself instead of the file\n"
                 "    the link points to.\n"
                 "\n"
                 "dir_fd and follow_symlinks may not be implemented\n"
                 "  on your platform.  If they are unavailable, using them will raise a\n"
                 "  NotImplementedError.\n"
                 "\n"
                 "It's an error to use dir_fd or follow_symlinks when specifying path as\n"
                 "  an open file descriptor.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"stat\", \"path\", 0, 0, 0, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="FSTATAT_DIR_FD_CONVERTER"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="lstat",
                 full_name="os.lstat",
                 c_basename="os_lstat",
                 docstring="lstat($module, /, path, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Perform a stat system call on the given path, without following symbolic links.\n"
                 "\n"
                 "Like stat(), but do not follow symbolic links.\n"
                 "Equivalent to stat(path, follow_symlinks=False).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"lstat\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="FSTATAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="access",
                 full_name="os.access",
                 c_basename="os_access",
                 docstring="access($module, /, path, mode, *, dir_fd=None, effective_ids=False,\n"
                 "       follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Use the real uid/gid to test for access to a path.\n"
                 "\n"
                 "  path\n"
                 "    Path to be tested; can be string, bytes, or a path-like object.\n"
                 "  mode\n"
                 "    Operating-system mode bitfield.  Can be F_OK to test existence,\n"
                 "    or the inclusive-OR of R_OK, W_OK, and X_OK.\n"
                 "  dir_fd\n"
                 "    If not None, it should be a file descriptor open to a directory,\n"
                 "    and path should be relative; path will then be relative to that\n"
                 "    directory.\n"
                 "  effective_ids\n"
                 "    If True, access will use the effective uid/gid instead of\n"
                 "    the real uid/gid.\n"
                 "  follow_symlinks\n"
                 "    If False, and the last element of the path is a symbolic link,\n"
                 "    access will examine the symbolic link itself instead of the file\n"
                 "    the link points to.\n"
                 "\n"
                 "dir_fd, effective_ids, and follow_symlinks may not be implemented\n"
                 "  on your platform.  If they are unavailable, using them will raise a\n"
                 "  NotImplementedError.\n"
                 "\n"
                 "Note that most operations will use the effective uid/gid, therefore this\n"
                 "  routine can be used in a suid/sgid environment to test if the invoking user\n"
                 "  has the specified access to the path.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"access\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="mode", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="FACCESSAT_DIR_FD_CONVERTER"
                     ),
                     Parameter(
                         name="effective_ids",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="ttyname",
                 full_name="os.ttyname",
                 c_basename="os_ttyname",
                 docstring="ttyname($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return the name of the terminal device connected to 'fd'.\n"
                 "\n"
                 "  fd\n"
                 "    Integer file descriptor handle.",
                 condition="defined(HAVE_TTYNAME_R)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="ctermid",
                 full_name="os.ctermid",
                 c_basename="os_ctermid",
                 docstring="ctermid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the name of the controlling terminal for this process.",
                 condition="defined(HAVE_CTERMID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="chdir",
                 full_name="os.chdir",
                 c_basename="os_chdir",
                 docstring="chdir($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Change the current working directory to the specified path.\n"
                 "\n"
                 "path may always be specified as a string.  On some platforms, path may\n"
                 "also be specified as an open file descriptor.  If this functionality is\n"
                 "unavailable, using it raises an exception.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"chdir\", \"path\", 0, 0, 0, PATH_HAVE_FCHDIR)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FCHDIR"]
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="fchdir",
                 full_name="os.fchdir",
                 c_basename="os_fchdir",
                 docstring="fchdir($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Change to the directory of the given file descriptor.\n"
                 "\n"
                 "fd must be opened on a directory, not a file.\n"
                 "Equivalent to os.chdir(fd).",
                 condition="defined(HAVE_FCHDIR)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="chmod",
                 full_name="os.chmod",
                 c_basename="os_chmod",
                 docstring="chmod($module, /, path, mode, *, dir_fd=None,\n"
                 "      follow_symlinks=(os.name != 'nt'))\n"
                 "--\n"
                 "\n"
                 "Change the access permissions of a file.\n"
                 "\n"
                 "  path\n"
                 "    Path to be modified.  May always be specified as a str, bytes, or\n"
                 "    a path-like object.  On some platforms, path may also be specified\n"
                 "    as an open file descriptor.  If this functionality is unavailable,\n"
                 "    using it raises an exception.\n"
                 "  mode\n"
                 "    Operating-system mode bitfield.\n"
                 "    Be careful when using number literals for *mode*. The conventional\n"
                 "    UNIX notation for numeric modes uses an octal base, which needs to\n"
                 "    be indicated with a ``0o`` prefix in Python.\n"
                 "  dir_fd\n"
                 "    If not None, it should be a file descriptor open to a directory,\n"
                 "    and path should be relative; path will then be relative to that\n"
                 "    directory.\n"
                 "  follow_symlinks\n"
                 "    If False, and the last element of the path is a symbolic link,\n"
                 "    chmod will modify the symbolic link itself instead of the file\n"
                 "    the link points to.\n"
                 "\n"
                 "It is an error to use dir_fd or follow_symlinks when specifying path as\n"
                 "  an open file descriptor.\n"
                 "dir_fd and follow_symlinks may not be implemented on your platform.\n"
                 "  If they are unavailable, using them will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"chmod\", \"path\", 0, 0, 0, PATH_HAVE_FCHMOD)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FCHMOD"]
                     ),
                     Parameter(
                         name="mode", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="FCHMODAT_DIR_FD_CONVERTER"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="unknown",
                         c_default="CHMOD_DEFAULT_FOLLOW_SYMLINKS"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="fchmod",
                 full_name="os.fchmod",
                 c_basename="os_fchmod",
                 docstring="fchmod($module, /, fd, mode)\n"
                 "--\n"
                 "\n"
                 "Change the access permissions of the file given by file descriptor fd.\n"
                 "\n"
                 "  fd\n"
                 "    The file descriptor of the file to be modified.\n"
                 "  mode\n"
                 "    Operating-system mode bitfield.\n"
                 "    Be careful when using number literals for *mode*.  The conventional\n"
                 "    UNIX notation for numeric modes uses an octal base, which needs to\n"
                 "    be indicated with a ``0o`` prefix in Python.\n"
                 "\n"
                 "Equivalent to os.chmod(fd, mode).",
                 condition="(defined(HAVE_FCHMOD) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", converter="int", type="int", format_unit="i"),
                     Parameter(
                         name="mode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="lchmod",
                 full_name="os.lchmod",
                 c_basename="os_lchmod",
                 docstring="lchmod($module, /, path, mode)\n"
                 "--\n"
                 "\n"
                 "Change the access permissions of a file, without following symbolic links.\n"
                 "\n"
                 "If path is a symlink, this affects the link itself rather than the\n"
                 "target.  Equivalent to chmod(path, mode, follow_symlinks=False).",
                 condition="(defined(HAVE_LCHMOD) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"lchmod\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="mode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="chflags",
                 full_name="os.chflags",
                 c_basename="os_chflags",
                 docstring="chflags($module, /, path, flags, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Set file flags.\n"
                 "\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, chflags() will change flags on the symbolic link itself\n"
                 "instead of the file the link points to.\n"
                 "follow_symlinks may not be implemented on your platform.  If it is\n"
                 "unavailable, using it will raise a NotImplementedError.",
                 condition="defined(HAVE_CHFLAGS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"chflags\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="flags",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="k"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="lchflags",
                 full_name="os.lchflags",
                 c_basename="os_lchflags",
                 docstring="lchflags($module, /, path, flags)\n"
                 "--\n"
                 "\n"
                 "Set file flags.\n"
                 "\n"
                 "This function will not follow symbolic links.\n"
                 "Equivalent to chflags(path, flags, follow_symlinks=False).",
                 condition="defined(HAVE_LCHFLAGS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"lchflags\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="flags",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="k"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="chroot",
                 full_name="os.chroot",
                 c_basename="os_chroot",
                 docstring="chroot($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Change root directory to path.",
                 condition="defined(HAVE_CHROOT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"chroot\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="fsync",
                 full_name="os.fsync",
                 c_basename="os_fsync",
                 docstring="fsync($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Force write of fd to disk.",
                 condition="defined(HAVE_FSYNC)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="sync",
                 full_name="os.sync",
                 c_basename="os_sync",
                 docstring="sync($module, /)\n"
                 "--\n"
                 "\n"
                 "Force write of everything to disk.",
                 condition="defined(HAVE_SYNC)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fdatasync",
                 full_name="os.fdatasync",
                 c_basename="os_fdatasync",
                 docstring="fdatasync($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Force write of fd to disk without forcing update of metadata.",
                 condition="defined(HAVE_FDATASYNC)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="chown",
                 full_name="os.chown",
                 c_basename="os_chown",
                 docstring="chown($module, /, path, uid, gid, *, dir_fd=None, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Change the owner and group id of path to the numeric uid and gid.\n"
                 "\n"
                 "  path\n"
                 "    Path to be examined; can be string, bytes, a path-like object, or\n"
                 "    open-file-descriptor int.\n"
                 "  dir_fd\n"
                 "    If not None, it should be a file descriptor open to a directory,\n"
                 "    and path should be relative; path will then be relative to that\n"
                 "    directory.\n"
                 "  follow_symlinks\n"
                 "    If False, and the last element of the path is a symbolic link,\n"
                 "    stat will examine the symbolic link itself instead of the file\n"
                 "    the link points to.\n"
                 "\n"
                 "path may always be specified as a string.  On some platforms, path may\n"
                 "also be specified as an open file descriptor.  If this functionality is\n"
                 "unavailable, using it raises an exception.\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, chown will modify the symbolic link itself instead of\n"
                 "the file the link points to.\n"
                 "It is an error to use dir_fd or follow_symlinks when specifying path as\n"
                 "an open file descriptor.\n"
                 "dir_fd and follow_symlinks may not be implemented on your platform.  If\n"
                 "they are unavailable, using them will raise a NotImplementedError.",
                 condition="defined(HAVE_CHOWN)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"chown\", \"path\", 0, 0, 0, PATH_HAVE_FCHOWN)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FCHOWN"]
                     ),
                     Parameter(
                         name="uid",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     ),
                     Parameter(
                         name="gid",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="FCHOWNAT_DIR_FD_CONVERTER"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="fchown",
                 full_name="os.fchown",
                 c_basename="os_fchown",
                 docstring="fchown($module, /, fd, uid, gid)\n"
                 "--\n"
                 "\n"
                 "Change the owner and group id of the file specified by file descriptor.\n"
                 "\n"
                 "Equivalent to os.chown(fd, uid, gid).",
                 condition="defined(HAVE_FCHOWN)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", converter="int", type="int", format_unit="i"),
                     Parameter(
                         name="uid",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     ),
                     Parameter(
                         name="gid",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="lchown",
                 full_name="os.lchown",
                 c_basename="os_lchown",
                 docstring="lchown($module, /, path, uid, gid)\n"
                 "--\n"
                 "\n"
                 "Change the owner and group id of path to the numeric uid and gid.\n"
                 "\n"
                 "This function will not follow symbolic links.\n"
                 "Equivalent to os.chown(path, uid, gid, follow_symlinks=False).",
                 condition="defined(HAVE_LCHOWN)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"lchown\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="uid",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     ),
                     Parameter(
                         name="gid",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="getcwd",
                 full_name="os.getcwd",
                 c_basename="os_getcwd",
                 docstring="getcwd($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a unicode string representing the current working directory.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getcwdb",
                 full_name="os.getcwdb",
                 c_basename="os_getcwdb",
                 docstring="getcwdb($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a bytes string representing the current working directory.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="link",
                 full_name="os.link",
                 c_basename="os_link",
                 docstring="link($module, /, src, dst, *, src_dir_fd=None, dst_dir_fd=None,\n"
                 "     follow_symlinks=(os.name != 'nt'))\n"
                 "--\n"
                 "\n"
                 "Create a hard link to a file.\n"
                 "\n"
                 "If either src_dir_fd or dst_dir_fd is not None, it should be a file\n"
                 "descriptor open to a directory, and the respective path string (src or\n"
                 "dst) should be relative; the path will then be relative to that\n"
                 "directory.\n"
                 "If follow_symlinks is False, and the last element of src is a symbolic\n"
                 "link, link will create a link to the symbolic link itself instead of the\n"
                 "file the link points to.\n"
                 "src_dir_fd, dst_dir_fd, and follow_symlinks may not be implemented on\n"
                 "your platform.  If they are unavailable, using them will raise\n"
                 "a NotImplementedError.",
                 condition="defined(HAVE_LINK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="src",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"link\", \"src\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dst",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"link\", \"dst\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="src_dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="dir_fd_converter"
                     ),
                     Parameter(
                         name="dst_dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="dir_fd_converter"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="unknown",
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="listdir",
                 full_name="os.listdir",
                 c_basename="os_listdir",
                 docstring="listdir($module, /, path=None)\n"
                 "--\n"
                 "\n"
                 "Return a list containing the names of the files in the directory.\n"
                 "\n"
                 "path can be specified as either str, bytes, or a path-like object.  If\n"
                 "path is bytes, the filenames returned will also be bytes; in all other\n"
                 "circumstances the filenames returned will be str.\n"
                 "If path is None, uses the path='.'.\n"
                 "On some platforms, path may also be specified as an open file\n"
                 "descriptor; the file descriptor must refer to a directory.  If this\n"
                 "functionality is unavailable, using it raises NotImplementedError.\n"
                 "\n"
                 "The list is in arbitrary order.  It does not include the special\n"
                 "entries '.' and '..' even if they are present in the directory.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="PATH_T_INITIALIZE_P(\"listdir\", \"path\", 1, 0, 0, PATH_HAVE_FDOPENDIR)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FDOPENDIR"]
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="listdrives",
                 full_name="os.listdrives",
                 c_basename="os_listdrives",
                 docstring="listdrives($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list containing the names of drives in the system.\n"
                 "\n"
                 "A drive name typically looks like 'C:\\\\'.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="listvolumes",
                 full_name="os.listvolumes",
                 c_basename="os_listvolumes",
                 docstring="listvolumes($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list containing the volumes in the system.\n"
                 "\n"
                 "Volumes are typically represented as a GUID path.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="listmounts",
                 full_name="os.listmounts",
                 c_basename="os_listmounts",
                 docstring="listmounts($module, /, volume)\n"
                 "--\n"
                 "\n"
                 "Return a list containing mount points for a particular volume.\n"
                 "\n"
                 "'volume' should be a GUID path as returned from os.listvolumes.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="volume",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"listmounts\", \"volume\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_isdevdrive",
                 full_name="os._path_isdevdrive",
                 c_basename="os__path_isdevdrive",
                 docstring="_path_isdevdrive($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Determines whether the specified path is on a Windows Dev Drive.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_isdevdrive\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_getfullpathname",
                 full_name="os._getfullpathname",
                 c_basename="os__getfullpathname",
                 docstring="_getfullpathname($module, path, /)\n" "--",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_getfullpathname\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_getfinalpathname",
                 full_name="os._getfinalpathname",
                 c_basename="os__getfinalpathname",
                 docstring="_getfinalpathname($module, path, /)\n"
                 "--\n"
                 "\n"
                 "A helper function for samepath on windows.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_getfinalpathname\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_findfirstfile",
                 full_name="os._findfirstfile",
                 c_basename="os__findfirstfile",
                 docstring="_findfirstfile($module, path, /)\n"
                 "--\n"
                 "\n"
                 "A function to get the real file name without accessing the file in Windows.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_findfirstfile\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_getvolumepathname",
                 full_name="os._getvolumepathname",
                 c_basename="os__getvolumepathname",
                 docstring="_getvolumepathname($module, /, path)\n"
                 "--\n"
                 "\n"
                 "A helper function for ismount on Win32.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_getvolumepathname\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_splitroot",
                 full_name="os._path_splitroot",
                 c_basename="os__path_splitroot",
                 docstring="_path_splitroot($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Removes everything after the root on Win32.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_splitroot\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_exists",
                 full_name="os._path_exists",
                 c_basename="os__path_exists",
                 docstring="_path_exists($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Test whether a path exists.  Returns False for broken symbolic links.",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_exists\", \"path\", 0, 0, 1, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_lexists",
                 full_name="os._path_lexists",
                 c_basename="os__path_lexists",
                 docstring="_path_lexists($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Test whether a path exists.  Returns True for broken symbolic links.",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_lexists\", \"path\", 0, 0, 1, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_isdir",
                 full_name="os._path_isdir",
                 c_basename="os__path_isdir",
                 docstring="_path_isdir($module, /, s)\n"
                 "--\n"
                 "\n"
                 "Return true if the pathname refers to an existing directory.",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="s",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_isdir\", \"path\", 0, 0, 1, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_isfile",
                 full_name="os._path_isfile",
                 c_basename="os__path_isfile",
                 docstring="_path_isfile($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Test whether a path is a regular file",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_isfile\", \"path\", 0, 0, 1, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_islink",
                 full_name="os._path_islink",
                 c_basename="os__path_islink",
                 docstring="_path_islink($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Test whether a path is a symbolic link",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_islink\", \"path\", 0, 0, 1, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_isjunction",
                 full_name="os._path_isjunction",
                 c_basename="os__path_isjunction",
                 docstring="_path_isjunction($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Test whether a path is a junction",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_path_isjunction\", \"path\", 0, 0, 1, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_splitroot_ex",
                 full_name="os._path_splitroot_ex",
                 c_basename="os__path_splitroot_ex",
                 docstring="_path_splitroot_ex($module, /, p)\n"
                 "--\n"
                 "\n"
                 "Split a pathname into drive, root and tail.\n"
                 "\n"
                 "The tail contains anything after the root.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="p",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE(\"_path_splitroot_ex\", \"path\", 0, 1, 1, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_path_normpath",
                 full_name="os._path_normpath",
                 c_basename="os__path_normpath",
                 docstring="_path_normpath($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Normalize path, eliminating double slashes, etc.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE(\"_path_normpath\", \"path\", 0, 1, 1, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="mkdir",
                 full_name="os.mkdir",
                 c_basename="os_mkdir",
                 docstring="mkdir($module, /, path, mode=511, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Create a directory.\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "dir_fd may not be implemented on your platform.  If it is unavailable,\n"
                 "using it will raise a NotImplementedError.\n"
                 "\n"
                 "The mode argument is ignored on Windows.  Where it is used, the current\n"
                 "umask value is first masked out.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"mkdir\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=511,
                         c_default="511"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="MKDIRAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="nice",
                 full_name="os.nice",
                 c_basename="os_nice",
                 docstring="nice($module, increment, /)\n"
                 "--\n"
                 "\n"
                 "Add increment to the priority of process and return the new priority.",
                 condition="defined(HAVE_NICE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="increment",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="getpriority",
                 full_name="os.getpriority",
                 c_basename="os_getpriority",
                 docstring="getpriority($module, /, which, who)\n"
                 "--\n"
                 "\n"
                 "Return program scheduling priority.",
                 condition="defined(HAVE_GETPRIORITY)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="which", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(name="who", converter="int", type="int", format_unit="i")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="setpriority",
                 full_name="os.setpriority",
                 c_basename="os_setpriority",
                 docstring="setpriority($module, /, which, who, priority)\n"
                 "--\n"
                 "\n"
                 "Set program scheduling priority.",
                 condition="defined(HAVE_SETPRIORITY)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="which", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="who", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="priority", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="rename",
                 full_name="os.rename",
                 c_basename="os_rename",
                 docstring="rename($module, /, src, dst, *, src_dir_fd=None, dst_dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Rename a file or directory.\n"
                 "\n"
                 "If either src_dir_fd or dst_dir_fd is not None, it should be a file\n"
                 "descriptor open to a directory, and the respective path string (src or\n"
                 "dst) should be relative; the path will then be relative to that\n"
                 "directory.\n"
                 "src_dir_fd and dst_dir_fd, may not be implemented on your platform.\n"
                 "If they are unavailable, using them will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="src",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"rename\", \"src\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dst",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"rename\", \"dst\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="src_dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="dir_fd_converter"
                     ),
                     Parameter(
                         name="dst_dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="dir_fd_converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="replace",
                 full_name="os.replace",
                 c_basename="os_replace",
                 docstring="replace($module, /, src, dst, *, src_dir_fd=None, dst_dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Rename a file or directory, overwriting the destination.\n"
                 "\n"
                 "If either src_dir_fd or dst_dir_fd is not None, it should be a file\n"
                 "descriptor open to a directory, and the respective path string (src or\n"
                 "dst) should be relative; the path will then be relative to that\n"
                 "directory.\n"
                 "src_dir_fd and dst_dir_fd, may not be implemented on your platform.\n"
                 "If they are unavailable, using them will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="src",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"replace\", \"src\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dst",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"replace\", \"dst\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="src_dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="dir_fd_converter"
                     ),
                     Parameter(
                         name="dst_dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="dir_fd_converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="rmdir",
                 full_name="os.rmdir",
                 c_basename="os_rmdir",
                 docstring="rmdir($module, /, path, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Remove a directory.\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative\n"
                 "to that directory.\n"
                 "dir_fd may not be implemented on your platform.\n"
                 "If it is unavailable, using it will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"rmdir\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="UNLINKAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="system",
                 full_name="os.system",
                 c_basename="os_system",
                 docstring="system($module, /, command)\n"
                 "--\n"
                 "\n"
                 "Execute the command in a subshell.",
                 condition="defined(HAVE_SYSTEM) && defined(MS_WINDOWS)",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="command",
                         converter="Py_UNICODE",
                         type="const wchar_t *",
                         format_unit="O&",
                         c_default="NULL",
                         accept=["str"],
                         convert_with="_PyUnicode_WideCharString_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="system",
                 full_name="os.system",
                 c_basename="os_system",
                 docstring="system($module, /, command)\n"
                 "--\n"
                 "\n"
                 "Execute the command in a subshell.",
                 condition="defined(HAVE_SYSTEM) && !defined(MS_WINDOWS)",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="command",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="umask",
                 full_name="os.umask",
                 c_basename="os_umask",
                 docstring="umask($module, mask, /)\n"
                 "--\n"
                 "\n"
                 "Set the current numeric umask and return the previous umask.",
                 condition="defined(HAVE_UMASK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="mask",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unlink",
                 full_name="os.unlink",
                 c_basename="os_unlink",
                 docstring="unlink($module, /, path, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Remove a file (same as remove()).\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "dir_fd may not be implemented on your platform.\n"
                 "If it is unavailable, using it will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"unlink\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="UNLINKAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="remove",
                 full_name="os.remove",
                 c_basename="os_remove",
                 docstring="remove($module, /, path, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Remove a file (same as unlink()).\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative\n"
                 "to that directory.\n"
                 "dir_fd may not be implemented on your platform.\n"
                 "If it is unavailable, using it will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"remove\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="UNLINKAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="uname",
                 full_name="os.uname",
                 c_basename="os_uname",
                 docstring="uname($module, /)\n"
                 "--\n"
                 "\n"
                 "Return an object identifying the current operating system.\n"
                 "\n"
                 "The object behaves like a named tuple with the following fields:\n"
                 "  (sysname, nodename, release, version, machine)",
                 condition="defined(HAVE_UNAME)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="utime",
                 full_name="os.utime",
                 c_basename="os_utime",
                 docstring="utime($module, /, path, times=None, *, ns=<unrepresentable>,\n"
                 "      dir_fd=None, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Set the access and modified time of path.\n"
                 "\n"
                 "path may always be specified as a string.  On some platforms, path may\n"
                 "also be specified as an open file descriptor.  If this functionality is\n"
                 "unavailable, using it raises an exception.\n"
                 "\n"
                 "If times is not None, it must be a tuple (atime, mtime);\n"
                 "atime and mtime should be expressed as float seconds since the epoch.\n"
                 "If ns is specified, it must be a tuple (atime_ns, mtime_ns);\n"
                 "atime_ns and mtime_ns should be expressed as integer nanoseconds\n"
                 "since the epoch.\n"
                 "If times is None and ns is unspecified, utime uses the current time.\n"
                 "Specifying tuples for both times and ns is an error.\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, utime will modify the symbolic link itself instead of\n"
                 "the file the link points to.\n"
                 "It is an error to use dir_fd or follow_symlinks when specifying path as\n"
                 "an open file descriptor.\n"
                 "dir_fd and follow_symlinks may not be available on your platform.\n"
                 "If they are unavailable, using them will raise a NotImplementedError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"utime\", \"path\", 0, 0, 0, PATH_UTIME_HAVE_FD)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_UTIME_HAVE_FD"]
                     ),
                     Parameter(
                         name="times",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="ns",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="FUTIMENSAT_DIR_FD_CONVERTER"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="_exit",
                 full_name="os._exit",
                 c_basename="os__exit",
                 docstring="_exit($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Exit to the system with specified status, without normal exit processing.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="execv",
                 full_name="os.execv",
                 c_basename="os_execv",
                 docstring="execv($module, path, argv, /)\n"
                 "--\n"
                 "\n"
                 "Execute an executable path with arguments, replacing current process.\n"
                 "\n"
                 "  path\n"
                 "    Path of executable file.\n"
                 "  argv\n"
                 "    Tuple or list of strings.",
                 condition="defined(HAVE_EXECV)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"execv\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(name="argv", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="execve",
                 full_name="os.execve",
                 c_basename="os_execve",
                 docstring="execve($module, /, path, argv, env)\n"
                 "--\n"
                 "\n"
                 "Execute an executable path with arguments, replacing current process.\n"
                 "\n"
                 "  path\n"
                 "    Path of executable file.\n"
                 "  argv\n"
                 "    Tuple or list of strings.\n"
                 "  env\n"
                 "    Dictionary of strings mapping to strings.",
                 condition="defined(HAVE_EXECV)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"execve\", \"path\", 0, 0, 0, PATH_HAVE_FEXECVE)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FEXECVE"]
                     ),
                     Parameter(name="argv", format_unit="O"),
                     Parameter(name="env", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="posix_spawn",
                 full_name="os.posix_spawn",
                 c_basename="os_posix_spawn",
                 docstring="posix_spawn($module, path, argv, env, /, *, file_actions=(),\n"
                 "            setpgroup=None, resetids=False, setsid=False,\n"
                 "            setsigmask=(), setsigdef=(), scheduler=None)\n"
                 "--\n"
                 "\n"
                 "Execute the program specified by path in a new process.\n"
                 "\n"
                 "  path\n"
                 "    Path of executable file.\n"
                 "  argv\n"
                 "    Tuple or list of strings.\n"
                 "  env\n"
                 "    Dictionary of strings mapping to strings.\n"
                 "  file_actions\n"
                 "    A sequence of file action tuples.\n"
                 "  setpgroup\n"
                 "    The pgroup to use with the POSIX_SPAWN_SETPGROUP flag.\n"
                 "  resetids\n"
                 "    If the value is `true` the POSIX_SPAWN_RESETIDS will be activated.\n"
                 "  setsid\n"
                 "    If the value is `true` the POSIX_SPAWN_SETSID or POSIX_SPAWN_SETSID_NP\n"
                 "    will be activated.\n"
                 "  setsigmask\n"
                 "    The sigmask to use with the POSIX_SPAWN_SETSIGMASK flag.\n"
                 "  setsigdef\n"
                 "    The sigmask to use with the POSIX_SPAWN_SETSIGDEF flag.\n"
                 "  scheduler\n"
                 "    A tuple with the scheduler policy (optional) and parameters.",
                 condition="defined(HAVE_POSIX_SPAWN)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"posix_spawn\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(name="argv", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="env", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="file_actions",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="setpgroup",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="resetids",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="setsid",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="setsigmask",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="setsigdef",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="scheduler",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="posix_spawnp",
                 full_name="os.posix_spawnp",
                 c_basename="os_posix_spawnp",
                 docstring="posix_spawnp($module, path, argv, env, /, *, file_actions=(),\n"
                 "             setpgroup=None, resetids=False, setsid=False,\n"
                 "             setsigmask=(), setsigdef=(), scheduler=None)\n"
                 "--\n"
                 "\n"
                 "Execute the program specified by path in a new process.\n"
                 "\n"
                 "  path\n"
                 "    Path of executable file.\n"
                 "  argv\n"
                 "    Tuple or list of strings.\n"
                 "  env\n"
                 "    Dictionary of strings mapping to strings.\n"
                 "  file_actions\n"
                 "    A sequence of file action tuples.\n"
                 "  setpgroup\n"
                 "    The pgroup to use with the POSIX_SPAWN_SETPGROUP flag.\n"
                 "  resetids\n"
                 "    If the value is `True` the POSIX_SPAWN_RESETIDS will be activated.\n"
                 "  setsid\n"
                 "    If the value is `True` the POSIX_SPAWN_SETSID or POSIX_SPAWN_SETSID_NP\n"
                 "    will be activated.\n"
                 "  setsigmask\n"
                 "    The sigmask to use with the POSIX_SPAWN_SETSIGMASK flag.\n"
                 "  setsigdef\n"
                 "    The sigmask to use with the POSIX_SPAWN_SETSIGDEF flag.\n"
                 "  scheduler\n"
                 "    A tuple with the scheduler policy (optional) and parameters.",
                 condition="defined(HAVE_POSIX_SPAWNP)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"posix_spawnp\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(name="argv", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="env", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="file_actions",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="setpgroup",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="resetids",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="setsid",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="setsigmask",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="setsigdef",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="scheduler",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="spawnv",
                 full_name="os.spawnv",
                 c_basename="os_spawnv",
                 docstring="spawnv($module, mode, path, argv, /)\n"
                 "--\n"
                 "\n"
                 "Execute the program specified by path in a new process.\n"
                 "\n"
                 "  mode\n"
                 "    Mode of process creation.\n"
                 "  path\n"
                 "    Path of executable file.\n"
                 "  argv\n"
                 "    Tuple or list of strings.",
                 condition="(defined(HAVE_SPAWNV) || defined(HAVE_WSPAWNV) || defined(HAVE_RTPSPAWN))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="mode",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"spawnv\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(name="argv", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="spawnve",
                 full_name="os.spawnve",
                 c_basename="os_spawnve",
                 docstring="spawnve($module, mode, path, argv, env, /)\n"
                 "--\n"
                 "\n"
                 "Execute the program specified by path in a new process.\n"
                 "\n"
                 "  mode\n"
                 "    Mode of process creation.\n"
                 "  path\n"
                 "    Path of executable file.\n"
                 "  argv\n"
                 "    Tuple or list of strings.\n"
                 "  env\n"
                 "    Dictionary of strings mapping to strings.",
                 condition="(defined(HAVE_SPAWNV) || defined(HAVE_WSPAWNV) || defined(HAVE_RTPSPAWN))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="mode",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"spawnve\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(name="argv", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="env", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=4,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="register_at_fork",
                 full_name="os.register_at_fork",
                 c_basename="os_register_at_fork",
                 docstring="register_at_fork($module, /, *, before=<unrepresentable>,\n"
                 "                 after_in_child=<unrepresentable>,\n"
                 "                 after_in_parent=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Register callables to be called when forking a new process.\n"
                 "\n"
                 "  before\n"
                 "    A callable to be called in the parent before the fork() syscall.\n"
                 "  after_in_child\n"
                 "    A callable to be called in the child after fork().\n"
                 "  after_in_parent\n"
                 "    A callable to be called in the parent after fork().\n"
                 "\n"
                 "'before' callbacks are called in reverse order.\n"
                 "'after_in_child' and 'after_in_parent' callbacks are called in order.",
                 condition="defined(HAVE_FORK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="before",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="after_in_child",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="after_in_parent",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="fork1",
                 full_name="os.fork1",
                 c_basename="os_fork1",
                 docstring="fork1($module, /)\n"
                 "--\n"
                 "\n"
                 "Fork a child process with a single multiplexed (i.e., not bound) thread.\n"
                 "\n"
                 "Return 0 to child process and PID of child to parent process.",
                 condition="defined(HAVE_FORK1)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fork",
                 full_name="os.fork",
                 c_basename="os_fork",
                 docstring="fork($module, /)\n"
                 "--\n"
                 "\n"
                 "Fork a child process.\n"
                 "\n"
                 "Return 0 to child process and PID of child to parent process.",
                 condition="defined(HAVE_FORK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="sched_get_priority_max",
                 full_name="os.sched_get_priority_max",
                 c_basename="os_sched_get_priority_max",
                 docstring="sched_get_priority_max($module, /, policy)\n"
                 "--\n"
                 "\n"
                 "Get the maximum scheduling priority for policy.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_GET_PRIORITY_MAX)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="policy", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="sched_get_priority_min",
                 full_name="os.sched_get_priority_min",
                 c_basename="os_sched_get_priority_min",
                 docstring="sched_get_priority_min($module, /, policy)\n"
                 "--\n"
                 "\n"
                 "Get the minimum scheduling priority for policy.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_GET_PRIORITY_MAX)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="policy", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="sched_getscheduler",
                 full_name="os.sched_getscheduler",
                 c_basename="os_sched_getscheduler",
                 docstring="sched_getscheduler($module, pid, /)\n"
                 "--\n"
                 "\n"
                 "Get the scheduling policy for the process identified by pid.\n"
                 "\n"
                 "Passing 0 for pid returns the scheduling policy for the calling process.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_SETSCHEDULER)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="sched_setscheduler",
                 full_name="os.sched_setscheduler",
                 c_basename="os_sched_setscheduler",
                 docstring="sched_setscheduler($module, pid, policy, param, /)\n"
                 "--\n"
                 "\n"
                 "Set the scheduling policy for the process identified by pid.\n"
                 "\n"
                 "If pid is 0, the calling process is changed.\n"
                 "param is an instance of sched_param.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_SETSCHEDULER)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="policy",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="param", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="sched_getparam",
                 full_name="os.sched_getparam",
                 c_basename="os_sched_getparam",
                 docstring="sched_getparam($module, pid, /)\n"
                 "--\n"
                 "\n"
                 "Returns scheduling parameters for the process identified by pid.\n"
                 "\n"
                 "If pid is 0, returns parameters for the calling process.\n"
                 "Return value is an instance of sched_param.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_SETPARAM)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="sched_setparam",
                 full_name="os.sched_setparam",
                 c_basename="os_sched_setparam",
                 docstring="sched_setparam($module, pid, param, /)\n"
                 "--\n"
                 "\n"
                 "Set scheduling parameters for the process identified by pid.\n"
                 "\n"
                 "If pid is 0, sets parameters for the calling process.\n"
                 "param should be an instance of sched_param.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_SETPARAM)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(name="param", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="sched_rr_get_interval",
                 full_name="os.sched_rr_get_interval",
                 c_basename="os_sched_rr_get_interval",
                 docstring="sched_rr_get_interval($module, pid, /)\n"
                 "--\n"
                 "\n"
                 "Return the round-robin quantum for the process identified by pid, in seconds.\n"
                 "\n"
                 "Value returned is a float.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_RR_GET_INTERVAL)",
                 returns="double",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="sched_yield",
                 full_name="os.sched_yield",
                 c_basename="os_sched_yield",
                 docstring="sched_yield($module, /)\n"
                 "--\n"
                 "\n"
                 "Voluntarily relinquish the CPU.",
                 condition="defined(HAVE_SCHED_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="sched_setaffinity",
                 full_name="os.sched_setaffinity",
                 c_basename="os_sched_setaffinity",
                 docstring="sched_setaffinity($module, pid, mask, /)\n"
                 "--\n"
                 "\n"
                 "Set the CPU affinity of the process identified by pid to mask.\n"
                 "\n"
                 "mask should be an iterable of integers identifying CPUs.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_SETAFFINITY)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(name="mask", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="sched_getaffinity",
                 full_name="os.sched_getaffinity",
                 c_basename="os_sched_getaffinity",
                 docstring="sched_getaffinity($module, pid, /)\n"
                 "--\n"
                 "\n"
                 "Return the affinity of the process identified by pid (or the current process if zero).\n"
                 "\n"
                 "The affinity is returned as a set of CPU identifiers.",
                 condition="defined(HAVE_SCHED_H) && defined(HAVE_SCHED_SETAFFINITY)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="posix_openpt",
                 full_name="os.posix_openpt",
                 c_basename="os_posix_openpt",
                 docstring="posix_openpt($module, oflag, /)\n"
                 "--\n"
                 "\n"
                 "Open and return a file descriptor for a master pseudo-terminal device.\n"
                 "\n"
                 "Performs a posix_openpt() C function call. The oflag argument is used to\n"
                 "set file status flags and file access modes as specified in the manual\n"
                 "page of posix_openpt() of your system.",
                 condition="defined(HAVE_POSIX_OPENPT)",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="oflag",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="grantpt",
                 full_name="os.grantpt",
                 c_basename="os_grantpt",
                 docstring="grantpt($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Grant access to the slave pseudo-terminal device.\n"
                 "\n"
                 "  fd\n"
                 "    File descriptor of a master pseudo-terminal device.\n"
                 "\n"
                 "Performs a grantpt() C function call.",
                 condition="defined(HAVE_GRANTPT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unlockpt",
                 full_name="os.unlockpt",
                 c_basename="os_unlockpt",
                 docstring="unlockpt($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Unlock a pseudo-terminal master/slave pair.\n"
                 "\n"
                 "  fd\n"
                 "    File descriptor of a master pseudo-terminal device.\n"
                 "\n"
                 "Performs an unlockpt() C function call.",
                 condition="defined(HAVE_UNLOCKPT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="ptsname",
                 full_name="os.ptsname",
                 c_basename="os_ptsname",
                 docstring="ptsname($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return the name of the slave pseudo-terminal device.\n"
                 "\n"
                 "  fd\n"
                 "    File descriptor of a master pseudo-terminal device.\n"
                 "\n"
                 "If the ptsname_r() C function is available, it is called;\n"
                 "otherwise, performs a ptsname() C function call.",
                 condition="(defined(HAVE_PTSNAME) || defined(HAVE_PTSNAME_R))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="openpty",
                 full_name="os.openpty",
                 c_basename="os_openpty",
                 docstring="openpty($module, /)\n"
                 "--\n"
                 "\n"
                 "Open a pseudo-terminal.\n"
                 "\n"
                 "Return a tuple of (master_fd, slave_fd) containing open file descriptors\n"
                 "for both the master and slave ends.",
                 condition="(defined(HAVE_OPENPTY) || defined(HAVE__GETPTY) || defined(HAVE_DEV_PTMX))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="login_tty",
                 full_name="os.login_tty",
                 c_basename="os_login_tty",
                 docstring="login_tty($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Prepare the tty of which fd is a file descriptor for a new login session.\n"
                 "\n"
                 "Make the calling process a session leader; make the tty the\n"
                 "controlling tty, the stdin, the stdout, and the stderr of the\n"
                 "calling process; close fd.",
                 condition="(defined(HAVE_LOGIN_TTY) || defined(HAVE_FALLBACK_LOGIN_TTY))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="forkpty",
                 full_name="os.forkpty",
                 c_basename="os_forkpty",
                 docstring="forkpty($module, /)\n"
                 "--\n"
                 "\n"
                 "Fork a new process with a new pseudo-terminal as controlling tty.\n"
                 "\n"
                 "Returns a tuple of (pid, master_fd).\n"
                 "Like fork(), return pid of 0 to the child process,\n"
                 "and pid of child to the parent process.\n"
                 "To both, return fd of newly opened pseudo-terminal.",
                 condition="defined(HAVE_FORKPTY)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getegid",
                 full_name="os.getegid",
                 c_basename="os_getegid",
                 docstring="getegid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the current process's effective group id.",
                 condition="defined(HAVE_GETEGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="geteuid",
                 full_name="os.geteuid",
                 c_basename="os_geteuid",
                 docstring="geteuid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the current process's effective user id.",
                 condition="defined(HAVE_GETEUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getgid",
                 full_name="os.getgid",
                 c_basename="os_getgid",
                 docstring="getgid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the current process's group id.",
                 condition="defined(HAVE_GETGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getpid",
                 full_name="os.getpid",
                 c_basename="os_getpid",
                 docstring="getpid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the current process id.",
                 condition="defined(HAVE_GETPID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getgrouplist",
                 full_name="os.getgrouplist",
                 c_basename="os_getgrouplist",
                 docstring="getgrouplist($module, user, group, /)\n"
                 "--\n"
                 "\n"
                 "Returns a list of groups to which a user belongs.\n"
                 "\n"
                 "  user\n"
                 "    username to lookup\n"
                 "  group\n"
                 "    base group id of the user",
                 condition="defined(HAVE_GETGROUPLIST) && defined(__APPLE__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="user",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="group",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getgrouplist",
                 full_name="os.getgrouplist",
                 c_basename="os_getgrouplist",
                 docstring="getgrouplist($module, user, group, /)\n"
                 "--\n"
                 "\n"
                 "Returns a list of groups to which a user belongs.\n"
                 "\n"
                 "  user\n"
                 "    username to lookup\n"
                 "  group\n"
                 "    base group id of the user",
                 condition="defined(HAVE_GETGROUPLIST) && !defined(__APPLE__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="user",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="group",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getgroups",
                 full_name="os.getgroups",
                 c_basename="os_getgroups",
                 docstring="getgroups($module, /)\n"
                 "--\n"
                 "\n"
                 "Return list of supplemental group IDs for the process.",
                 condition="defined(HAVE_GETGROUPS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="initgroups",
                 full_name="os.initgroups",
                 c_basename="os_initgroups",
                 docstring="initgroups($module, username, gid, /)\n"
                 "--\n"
                 "\n"
                 "Initialize the group access list.\n"
                 "\n"
                 "Call the system initgroups() to initialize the group access list with\n"
                 "all of the groups of which the specified username is a member, plus the\n"
                 "specified group id.",
                 condition="defined(HAVE_INITGROUPS) && defined(__APPLE__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="username",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     ),
                     Parameter(
                         name="gid",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="initgroups",
                 full_name="os.initgroups",
                 c_basename="os_initgroups",
                 docstring="initgroups($module, username, gid, /)\n"
                 "--\n"
                 "\n"
                 "Initialize the group access list.\n"
                 "\n"
                 "Call the system initgroups() to initialize the group access list with\n"
                 "all of the groups of which the specified username is a member, plus the\n"
                 "specified group id.",
                 condition="defined(HAVE_INITGROUPS) && !defined(__APPLE__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="username",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     ),
                     Parameter(
                         name="gid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getpgid",
                 full_name="os.getpgid",
                 c_basename="os_getpgid",
                 docstring="getpgid($module, /, pid)\n"
                 "--\n"
                 "\n"
                 "Call the system call getpgid(), and return the result.",
                 condition="defined(HAVE_GETPGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="getpgrp",
                 full_name="os.getpgrp",
                 c_basename="os_getpgrp",
                 docstring="getpgrp($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the current process group id.",
                 condition="defined(HAVE_GETPGRP)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="setpgrp",
                 full_name="os.setpgrp",
                 c_basename="os_setpgrp",
                 docstring="setpgrp($module, /)\n"
                 "--\n"
                 "\n"
                 "Make the current process the leader of its process group.",
                 condition="defined(HAVE_SETPGRP)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getppid",
                 full_name="os.getppid",
                 c_basename="os_getppid",
                 docstring="getppid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the parent's process id.\n"
                 "\n"
                 "If the parent process has already exited, Windows machines will still\n"
                 "return its id; others systems will return the id of the 'init' proces\n"
                 "(1).",
                 condition="defined(HAVE_GETPPID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getlogin",
                 full_name="os.getlogin",
                 c_basename="os_getlogin",
                 docstring="getlogin($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the actual login name.",
                 condition="defined(HAVE_GETLOGIN)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getuid",
                 full_name="os.getuid",
                 c_basename="os_getuid",
                 docstring="getuid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the current process's user id.",
                 condition="defined(HAVE_GETUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="kill",
                 full_name="os.kill",
                 c_basename="os_kill",
                 docstring="kill($module, pid, signal, /)\n"
                 "--\n"
                 "\n"
                 "Kill a process with a signal.",
                 condition="defined(HAVE_KILL)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="signal",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="killpg",
                 full_name="os.killpg",
                 c_basename="os_killpg",
                 docstring="killpg($module, pgid, signal, /)\n"
                 "--\n"
                 "\n"
                 "Kill a process group with a signal.",
                 condition="defined(HAVE_KILLPG)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pgid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="signal",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="plock",
                 full_name="os.plock",
                 c_basename="os_plock",
                 docstring="plock($module, op, /)\n"
                 "--\n"
                 "\n"
                 "Lock program segments into memory.\");",
                 condition="defined(HAVE_PLOCK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="op",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setuid",
                 full_name="os.setuid",
                 c_basename="os_setuid",
                 docstring="setuid($module, uid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's user id.",
                 condition="defined(HAVE_SETUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="uid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="seteuid",
                 full_name="os.seteuid",
                 c_basename="os_seteuid",
                 docstring="seteuid($module, euid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's effective user id.",
                 condition="defined(HAVE_SETEUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="euid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setegid",
                 full_name="os.setegid",
                 c_basename="os_setegid",
                 docstring="setegid($module, egid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's effective group id.",
                 condition="defined(HAVE_SETEGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="egid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setreuid",
                 full_name="os.setreuid",
                 c_basename="os_setreuid",
                 docstring="setreuid($module, ruid, euid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's real and effective user ids.",
                 condition="defined(HAVE_SETREUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="ruid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     ),
                     Parameter(
                         name="euid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="setregid",
                 full_name="os.setregid",
                 c_basename="os_setregid",
                 docstring="setregid($module, rgid, egid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's real and effective group ids.",
                 condition="defined(HAVE_SETREGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="rgid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     ),
                     Parameter(
                         name="egid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="setgid",
                 full_name="os.setgid",
                 c_basename="os_setgid",
                 docstring="setgid($module, gid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's group id.",
                 condition="defined(HAVE_SETGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="gid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setgroups",
                 full_name="os.setgroups",
                 c_basename="os_setgroups",
                 docstring="setgroups($module, groups, /)\n"
                 "--\n"
                 "\n"
                 "Set the groups of the current process to list.",
                 condition="defined(HAVE_SETGROUPS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="groups", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="wait3",
                 full_name="os.wait3",
                 c_basename="os_wait3",
                 docstring="wait3($module, /, options)\n"
                 "--\n"
                 "\n"
                 "Wait for completion of a child process.\n"
                 "\n"
                 "Returns a tuple of information about the child process:\n"
                 "  (pid, status, rusage)",
                 condition="defined(HAVE_WAIT3)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="options", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="wait4",
                 full_name="os.wait4",
                 c_basename="os_wait4",
                 docstring="wait4($module, /, pid, options)\n"
                 "--\n"
                 "\n"
                 "Wait for completion of a specific child process.\n"
                 "\n"
                 "Returns a tuple of information about the child process:\n"
                 "  (pid, status, rusage)",
                 condition="defined(HAVE_WAIT4)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="options", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="waitid",
                 full_name="os.waitid",
                 c_basename="os_waitid",
                 docstring="waitid($module, idtype, id, options, /)\n"
                 "--\n"
                 "\n"
                 "Returns the result of waiting for a process or processes.\n"
                 "\n"
                 "  idtype\n"
                 "    Must be one of be P_PID, P_PGID or P_ALL.\n"
                 "  id\n"
                 "    The id to wait on.\n"
                 "  options\n"
                 "    Constructed from the ORing of one or more of WEXITED, WSTOPPED\n"
                 "    or WCONTINUED and additionally may be ORed with WNOHANG or WNOWAIT.\n"
                 "\n"
                 "Returns either waitid_result or None if WNOHANG is specified and there\n"
                 "are no children in a waitable state.",
                 condition="defined(HAVE_WAITID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="idtype",
                         kind="POSITIONAL_ONLY",
                         converter="idtype_t",
                         type="idtype_t",
                         format_unit="O&",
                         convert_with="idtype_t_converter"
                     ),
                     Parameter(
                         name="id",
                         kind="POSITIONAL_ONLY",
                         converter="id_t",
                         type="id_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="options",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="waitpid",
                 full_name="os.waitpid",
                 c_basename="os_waitpid",
                 docstring="waitpid($module, pid, options, /)\n"
                 "--\n"
                 "\n"
                 "Wait for completion of a given child process.\n"
                 "\n"
                 "Returns a tuple of information regarding the child process:\n"
                 "    (pid, status)\n"
                 "\n"
                 "The options argument is ignored on Windows.",
                 condition="defined(HAVE_WAITPID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="options",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="waitpid",
                 full_name="os.waitpid",
                 c_basename="os_waitpid",
                 docstring="waitpid($module, pid, options, /)\n"
                 "--\n"
                 "\n"
                 "Wait for completion of a given process.\n"
                 "\n"
                 "Returns a tuple of information regarding the process:\n"
                 "    (pid, status << 8)\n"
                 "\n"
                 "The options argument is ignored on Windows.",
                 condition="!defined(HAVE_WAITPID) && defined(HAVE_CWAIT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="intptr_t",
                         type="intptr_t",
                         format_unit="\" _Py_PARSE_INTPTR \""
                     ),
                     Parameter(
                         name="options",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="wait",
                 full_name="os.wait",
                 c_basename="os_wait",
                 docstring="wait($module, /)\n"
                 "--\n"
                 "\n"
                 "Wait for completion of a child process.\n"
                 "\n"
                 "Returns a tuple of information about the child process:\n"
                 "    (pid, status)",
                 condition="defined(HAVE_WAIT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="pidfd_open",
                 full_name="os.pidfd_open",
                 c_basename="os_pidfd_open",
                 docstring="pidfd_open($module, /, pid, flags=0)\n"
                 "--\n"
                 "\n"
                 "Return a file descriptor referring to the process *pid*.\n"
                 "\n"
                 "The descriptor can be used to perform process management without races\n"
                 "and signals.",
                 condition="(defined(__linux__) && defined(__NR_pidfd_open) && !(defined(__ANDROID__) && __ANDROID_API__ < 31))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="flags",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyLong_UnsignedInt_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="setns",
                 full_name="os.setns",
                 c_basename="os_setns",
                 docstring="setns($module, /, fd, nstype=0)\n"
                 "--\n"
                 "\n"
                 "Move the calling thread into different namespaces.\n"
                 "\n"
                 "  fd\n"
                 "    A file descriptor to a namespace.\n"
                 "  nstype\n"
                 "    Type of namespace.",
                 condition="defined(HAVE_SETNS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="nstype",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="unshare",
                 full_name="os.unshare",
                 c_basename="os_unshare",
                 docstring="unshare($module, /, flags)\n"
                 "--\n"
                 "\n"
                 "Disassociate parts of a process (or thread) execution context.\n"
                 "\n"
                 "  flags\n"
                 "    Namespaces to be unshared.",
                 condition="defined(HAVE_UNSHARE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="flags", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="readlink",
                 full_name="os.readlink",
                 c_basename="os_readlink",
                 docstring="readlink($module, /, path, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Return a string representing the path to which the symbolic link points.\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "\n"
                 "dir_fd may not be implemented on your platform.  If it is unavailable,\n"
                 "using it will raise a NotImplementedError.",
                 condition="(defined(HAVE_READLINK) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"readlink\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="READLINKAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="symlink",
                 full_name="os.symlink",
                 c_basename="os_symlink",
                 docstring="symlink($module, /, src, dst, target_is_directory=False, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Create a symbolic link pointing to src named dst.\n"
                 "\n"
                 "target_is_directory is required on Windows if the target is to be\n"
                 "interpreted as a directory.  (On Windows, symlink requires Windows 6.0\n"
                 "or greater, and raises a NotImplementedError otherwise.)\n"
                 "target_is_directory is ignored on non-Windows platforms.\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative\n"
                 "to that directory.\n"
                 "dir_fd may not be implemented on your platform.  If it is unavailable,\n"
                 "using it will raise a NotImplementedError.",
                 condition="defined(HAVE_SYMLINK)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="src",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"symlink\", \"src\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="dst",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"symlink\", \"dst\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="target_is_directory",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="SYMLINKAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="times",
                 full_name="os.times",
                 c_basename="os_times",
                 docstring="times($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a collection containing process timing information.\n"
                 "\n"
                 "The object returned behaves like a named tuple with these fields:\n"
                 "  (utime, stime, cutime, cstime, elapsed_time)\n"
                 "All fields are floating-point numbers.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="timerfd_create",
                 full_name="os.timerfd_create",
                 c_basename="os_timerfd_create",
                 docstring="timerfd_create($module, clockid, /, *, flags=0)\n"
                 "--\n"
                 "\n"
                 "Create and return a timer file descriptor.\n"
                 "\n"
                 "  clockid\n"
                 "    A valid clock ID constant as timer file descriptor.\n"
                 "\n"
                 "    time.CLOCK_REALTIME\n"
                 "    time.CLOCK_MONOTONIC\n"
                 "    time.CLOCK_BOOTTIME\n"
                 "  flags\n"
                 "    0 or a bit mask of os.TFD_NONBLOCK or os.TFD_CLOEXEC.\n"
                 "\n"
                 "    os.TFD_NONBLOCK\n"
                 "        If *TFD_NONBLOCK* is set as a flag, read doesn't blocks.\n"
                 "        If *TFD_NONBLOCK* is not set as a flag, read block until the timer fires.\n"
                 "\n"
                 "    os.TFD_CLOEXEC\n"
                 "        If *TFD_CLOEXEC* is set as a flag, enable the close-on-exec flag",
                 condition="defined(HAVE_TIMERFD_CREATE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="clockid",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="flags",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="timerfd_settime",
                 full_name="os.timerfd_settime",
                 c_basename="os_timerfd_settime",
                 docstring="timerfd_settime($module, fd, /, *, flags=0, initial=0.0, interval=0.0)\n"
                 "--\n"
                 "\n"
                 "Alter a timer file descriptor's internal timer in seconds.\n"
                 "\n"
                 "  fd\n"
                 "    A timer file descriptor.\n"
                 "  flags\n"
                 "    0 or a bit mask of TFD_TIMER_ABSTIME or TFD_TIMER_CANCEL_ON_SET.\n"
                 "  initial\n"
                 "    The initial expiration time, in seconds.\n"
                 "  interval\n"
                 "    The timer's interval, in seconds.",
                 condition="defined(HAVE_TIMERFD_CREATE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="flags",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="initial",
                         kind="KEYWORD_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=0.0,
                         c_default="0.0"
                     ),
                     Parameter(
                         name="interval",
                         kind="KEYWORD_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=0.0,
                         c_default="0.0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="timerfd_settime_ns",
                 full_name="os.timerfd_settime_ns",
                 c_basename="os_timerfd_settime_ns",
                 docstring="timerfd_settime_ns($module, fd, /, *, flags=0, initial=0, interval=0)\n"
                 "--\n"
                 "\n"
                 "Alter a timer file descriptor's internal timer in nanoseconds.\n"
                 "\n"
                 "  fd\n"
                 "    A timer file descriptor.\n"
                 "  flags\n"
                 "    0 or a bit mask of TFD_TIMER_ABSTIME or TFD_TIMER_CANCEL_ON_SET.\n"
                 "  initial\n"
                 "    initial expiration timing in seconds.\n"
                 "  interval\n"
                 "    interval for the timer in seconds.",
                 condition="defined(HAVE_TIMERFD_CREATE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="flags",
                         kind="KEYWORD_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="initial",
                         kind="KEYWORD_ONLY",
                         converter="long_long",
                         type="long long",
                         format_unit="L",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="interval",
                         kind="KEYWORD_ONLY",
                         converter="long_long",
                         type="long long",
                         format_unit="L",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="timerfd_gettime",
                 full_name="os.timerfd_gettime",
                 c_basename="os_timerfd_gettime",
                 docstring="timerfd_gettime($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple of a timer file descriptor's (interval, next expiration) in float seconds.\n"
                 "\n"
                 "  fd\n"
                 "    A timer file descriptor.",
                 condition="defined(HAVE_TIMERFD_CREATE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="timerfd_gettime_ns",
                 full_name="os.timerfd_gettime_ns",
                 c_basename="os_timerfd_gettime_ns",
                 docstring="timerfd_gettime_ns($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple of a timer file descriptor's (interval, next expiration) in nanoseconds.\n"
                 "\n"
                 "  fd\n"
                 "    A timer file descriptor.",
                 condition="defined(HAVE_TIMERFD_CREATE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="getsid",
                 full_name="os.getsid",
                 c_basename="os_getsid",
                 docstring="getsid($module, pid, /)\n"
                 "--\n"
                 "\n"
                 "Call the system call getsid(pid) and return the result.",
                 condition="defined(HAVE_GETSID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="setsid",
                 full_name="os.setsid",
                 c_basename="os_setsid",
                 docstring="setsid($module, /)\n"
                 "--\n"
                 "\n"
                 "Call the system call setsid().",
                 condition="defined(HAVE_SETSID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="setpgid",
                 full_name="os.setpgid",
                 c_basename="os_setpgid",
                 docstring="setpgid($module, pid, pgrp, /)\n"
                 "--\n"
                 "\n"
                 "Call the system call setpgid(pid, pgrp).",
                 condition="defined(HAVE_SETPGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     ),
                     Parameter(
                         name="pgrp",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="tcgetpgrp",
                 full_name="os.tcgetpgrp",
                 c_basename="os_tcgetpgrp",
                 docstring="tcgetpgrp($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return the process group associated with the terminal specified by fd.",
                 condition="defined(HAVE_TCGETPGRP)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tcsetpgrp",
                 full_name="os.tcsetpgrp",
                 c_basename="os_tcsetpgrp",
                 docstring="tcsetpgrp($module, fd, pgid, /)\n"
                 "--\n"
                 "\n"
                 "Set the process group associated with the terminal specified by fd.",
                 condition="defined(HAVE_TCSETPGRP)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="pgid",
                         kind="POSITIONAL_ONLY",
                         converter="pid_t",
                         type="pid_t",
                         format_unit="\" _Py_PARSE_PID \""
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="open",
                 full_name="os.open",
                 c_basename="os_open",
                 docstring="open($module, /, path, flags, mode=511, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Open a file for low level IO.  Returns a file descriptor (integer).\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "dir_fd may not be implemented on your platform.  If it is unavailable,\n"
                 "using it will raise a NotImplementedError.",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"open\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="flags", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=511,
                         c_default="511"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="OPENAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="close",
                 full_name="os.close",
                 c_basename="os_close",
                 docstring="close($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Close a file descriptor.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", converter="int", type="int", format_unit="i")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="closerange",
                 full_name="os.closerange",
                 c_basename="os_closerange",
                 docstring="closerange($module, fd_low, fd_high, /)\n"
                 "--\n"
                 "\n"
                 "Closes all file descriptors in [fd_low, fd_high), ignoring errors.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd_low",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="fd_high",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="dup",
                 full_name="os.dup",
                 c_basename="os_dup",
                 docstring="dup($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return a duplicate of a file descriptor.",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="dup2",
                 full_name="os.dup2",
                 c_basename="os_dup2",
                 docstring="dup2($module, /, fd, fd2, inheritable=True)\n"
                 "--\n"
                 "\n"
                 "Duplicate file descriptor.",
                 condition="((defined(HAVE_DUP3) || defined(F_DUPFD) || defined(MS_WINDOWS)))",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", converter="int", type="int", format_unit="i"),
                     Parameter(
                         name="fd2", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="inheritable",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="lockf",
                 full_name="os.lockf",
                 c_basename="os_lockf",
                 docstring="lockf($module, fd, command, length, /)\n"
                 "--\n"
                 "\n"
                 "Apply, test or remove a POSIX lock on an open file descriptor.\n"
                 "\n"
                 "  fd\n"
                 "    An open file descriptor.\n"
                 "  command\n"
                 "    One of F_LOCK, F_TLOCK, F_ULOCK or F_TEST.\n"
                 "  length\n"
                 "    The number of bytes to lock, starting at the current position.",
                 condition="defined(HAVE_LOCKF)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="command",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="lseek",
                 full_name="os.lseek",
                 c_basename="os_lseek",
                 docstring="lseek($module, fd, position, whence, /)\n"
                 "--\n"
                 "\n"
                 "Set the position of a file descriptor.  Return the new position.\n"
                 "\n"
                 "  fd\n"
                 "    An open file descriptor, as returned by os.open().\n"
                 "  position\n"
                 "    Position, interpreted relative to 'whence'.\n"
                 "  whence\n"
                 "    The relative position to seek from. Valid values are:\n"
                 "    - SEEK_SET: seek from the start of the file.\n"
                 "    - SEEK_CUR: seek from the current file position.\n"
                 "    - SEEK_END: seek from the end of the file.\n"
                 "\n"
                 "The return value is the number of bytes relative to the beginning of\n"
                 "the file.",
                 returns="Py_off_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="position",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="whence",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="read",
                 full_name="os.read",
                 c_basename="os_read",
                 docstring="read($module, fd, length, /)\n"
                 "--\n"
                 "\n"
                 "Read from a file descriptor.  Returns a bytes object.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="readinto",
                 full_name="os.readinto",
                 c_basename="os_readinto",
                 docstring="readinto($module, fd, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Read into a buffer object from a file descriptor.\n"
                 "\n"
                 "The buffer should be mutable and bytes-like.  On success, returns the\n"
                 "number of bytes read.  Less bytes may be read than the size of the\n"
                 "buffer.  The underlying system call will be retried when interrupted by\n"
                 "a signal, unless the signal handler raises an exception.  Other errors\n"
                 "will not be retried and an error will be raised.\n"
                 "\n"
                 "Returns 0 if *fd* is at end of file or if the provided *buffer* has\n"
                 "length 0 (which can be used to check for errors without reading data).\n"
                 "Never returns negative.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="w*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="readv",
                 full_name="os.readv",
                 c_basename="os_readv",
                 docstring="readv($module, fd, buffers, /)\n"
                 "--\n"
                 "\n"
                 "Read from a file descriptor fd into an iterable of buffers.\n"
                 "\n"
                 "The buffers should be mutable buffers accepting bytes.\n"
                 "readv will transfer data into each buffer until it is full\n"
                 "and then move on to the next buffer in the sequence to hold\n"
                 "the rest of the data.\n"
                 "\n"
                 "readv returns the total number of bytes read,\n"
                 "which may be less than the total capacity of all the buffers.",
                 condition="defined(HAVE_READV)",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="buffers", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pread",
                 full_name="os.pread",
                 c_basename="os_pread",
                 docstring="pread($module, fd, length, offset, /)\n"
                 "--\n"
                 "\n"
                 "Read a number of bytes from a file descriptor starting at a particular offset.\n"
                 "\n"
                 "Read length bytes from file descriptor fd, starting at offset bytes from\n"
                 "the beginning of the file.  The file offset remains unchanged.",
                 condition="defined(HAVE_PREAD)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="preadv",
                 full_name="os.preadv",
                 c_basename="os_preadv",
                 docstring="preadv($module, fd, buffers, offset, flags=0, /)\n"
                 "--\n"
                 "\n"
                 "Reads from a file descriptor into a number of mutable bytes-like objects.\n"
                 "\n"
                 "Combines the functionality of readv() and pread().  As readv(), it will\n"
                 "transfer data into each buffer until it is full and then move on to the\n"
                 "next buffer in the sequence to hold the rest of the data.  Its fourth\n"
                 "argument, specifies the file offset at which the input operation is to\n"
                 "be performed.  It will return the total number of bytes read (which can\n"
                 "be less than the total capacity of all the objects).\n"
                 "\n"
                 "The flags argument contains a bitwise OR of zero or more of the\n"
                 "following flags:\n"
                 "\n"
                 "- RWF_HIPRI\n"
                 "- RWF_NOWAIT\n"
                 "\n"
                 "Using non-zero flags requires Linux 4.6 or newer.",
                 condition="(defined(HAVE_PREADV) || defined (HAVE_PREADV2))",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="buffers", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="flags",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="write",
                 full_name="os.write",
                 c_basename="os_write",
                 docstring="write($module, fd, data, /)\n"
                 "--\n"
                 "\n"
                 "Write a bytes object to a file descriptor.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="sendfile",
                 full_name="os.sendfile",
                 c_basename="os_sendfile",
                 docstring="sendfile($module, /, out_fd, in_fd, offset, count, headers=(),\n"
                 "         trailers=(), flags=0)\n"
                 "--\n"
                 "\n"
                 "Copy count bytes from file descriptor in_fd to file descriptor out_fd.",
                 condition="defined(HAVE_SENDFILE) && defined(__APPLE__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="out_fd", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="in_fd", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="offset",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="count",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="headers",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="trailers",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="flags",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=4,
                 max_pos=7
             ),
             Function(
                 name="sendfile",
                 full_name="os.sendfile",
                 c_basename="os_sendfile",
                 docstring="sendfile($module, /, out_fd, in_fd, offset, count, headers=(),\n"
                 "         trailers=(), flags=0)\n"
                 "--\n"
                 "\n"
                 "Copy count bytes from file descriptor in_fd to file descriptor out_fd.",
                 condition="defined(HAVE_SENDFILE) && !defined(__APPLE__) && (defined(__FreeBSD__) || defined(__DragonFly__))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="out_fd", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="in_fd", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="offset",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="count",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="headers",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="trailers",
                         format_unit="O",
                         default_kind="value",
                         py_default=(),
                         c_default="NULL"
                     ),
                     Parameter(
                         name="flags",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=4,
                 max_pos=7
             ),
             Function(
                 name="sendfile",
                 full_name="os.sendfile",
                 c_basename="os_sendfile",
                 docstring="sendfile($module, /, out_fd, in_fd, offset, count)\n"
                 "--\n"
                 "\n"
                 "Copy count bytes from file descriptor in_fd to file descriptor out_fd.",
                 condition="defined(HAVE_SENDFILE) && !defined(__APPLE__) && !(defined(__FreeBSD__) || defined(__DragonFly__))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="out_fd", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="in_fd", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(name="offset", format_unit="O"),
                     Parameter(
                         name="count",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=4,
                 max_pos=4
             ),
             Function(
                 name="_fcopyfile",
                 full_name="os._fcopyfile",
                 c_basename="os__fcopyfile",
                 docstring="_fcopyfile($module, in_fd, out_fd, flags, /)\n"
                 "--\n"
                 "\n"
                 "Efficiently copy content or metadata of 2 regular file descriptors (macOS).",
                 condition="defined(__APPLE__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="in_fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="out_fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="flags",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="fstat",
                 full_name="os.fstat",
                 c_basename="os_fstat",
                 docstring="fstat($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Perform a stat system call on the given file descriptor.\n"
                 "\n"
                 "Like stat(), but for an open file descriptor.\n"
                 "Equivalent to os.stat(fd).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", converter="int", type="int", format_unit="i")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="isatty",
                 full_name="os.isatty",
                 c_basename="os_isatty",
                 docstring="isatty($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the fd is connected to a terminal.\n"
                 "\n"
                 "Return True if the file descriptor is an open file descriptor\n"
                 "connected to the slave end of a terminal.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="pipe",
                 full_name="os.pipe",
                 c_basename="os_pipe",
                 docstring="pipe($module, /)\n"
                 "--\n"
                 "\n"
                 "Create a pipe.\n"
                 "\n"
                 "Returns a tuple of two file descriptors:\n"
                 "  (read_fd, write_fd)",
                 condition="defined(HAVE_PIPE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="pipe2",
                 full_name="os.pipe2",
                 c_basename="os_pipe2",
                 docstring="pipe2($module, flags, /)\n"
                 "--\n"
                 "\n"
                 "Create a pipe with flags set atomically.\n"
                 "\n"
                 "Returns a tuple of two file descriptors:\n"
                 "  (read_fd, write_fd)\n"
                 "\n"
                 "flags can be constructed by ORing together one or more of these values:\n"
                 "O_NONBLOCK, O_CLOEXEC.",
                 condition="defined(HAVE_PIPE2)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="flags",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="writev",
                 full_name="os.writev",
                 c_basename="os_writev",
                 docstring="writev($module, fd, buffers, /)\n"
                 "--\n"
                 "\n"
                 "Iterate over buffers, and write the contents of each to a file descriptor.\n"
                 "\n"
                 "Returns the total number of bytes written.\n"
                 "buffers must be a sequence of bytes-like objects.",
                 condition="defined(HAVE_WRITEV)",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="buffers", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pwrite",
                 full_name="os.pwrite",
                 c_basename="os_pwrite",
                 docstring="pwrite($module, fd, buffer, offset, /)\n"
                 "--\n"
                 "\n"
                 "Write bytes to a file descriptor starting at a particular offset.\n"
                 "\n"
                 "Write buffer to fd, starting at offset bytes from the beginning of\n"
                 "the file.  Returns the number of bytes written.  Does not change the\n"
                 "current file offset.",
                 condition="defined(HAVE_PWRITE)",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="pwritev",
                 full_name="os.pwritev",
                 c_basename="os_pwritev",
                 docstring="pwritev($module, fd, buffers, offset, flags=0, /)\n"
                 "--\n"
                 "\n"
                 "Writes the contents of bytes-like objects to a file descriptor at a given offset.\n"
                 "\n"
                 "Combines the functionality of writev() and pwrite(). All buffers must be\n"
                 "a sequence of bytes-like objects.  Buffers are processed in array order.\n"
                 "Entire contents of first buffer is written before proceeding to second,\n"
                 "and so on. The operating system may set a limit (sysconf() value\n"
                 "SC_IOV_MAX) on the number of buffers that can be used.\n"
                 "This function writes the contents of each object to the file descriptor\n"
                 "and returns the total number of bytes written.\n"
                 "\n"
                 "The flags argument contains a bitwise OR of zero or more of the\n"
                 "following flags:\n"
                 "\n"
                 "- RWF_DSYNC\n"
                 "- RWF_SYNC\n"
                 "- RWF_APPEND\n"
                 "\n"
                 "Using non-zero flags requires Linux 4.7 or newer.",
                 condition="(defined(HAVE_PWRITEV) || defined (HAVE_PWRITEV2))",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(name="buffers", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="flags",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="copy_file_range",
                 full_name="os.copy_file_range",
                 c_basename="os_copy_file_range",
                 docstring="copy_file_range($module, /, src, dst, count, offset_src=None,\n"
                 "                offset_dst=None)\n"
                 "--\n"
                 "\n"
                 "Copy count bytes from one file descriptor to another.\n"
                 "\n"
                 "  src\n"
                 "    Source file descriptor.\n"
                 "  dst\n"
                 "    Destination file descriptor.\n"
                 "  count\n"
                 "    Number of bytes to copy.\n"
                 "  offset_src\n"
                 "    Starting offset in src.\n"
                 "  offset_dst\n"
                 "    Starting offset in dst.\n"
                 "\n"
                 "If offset_src is None, then src is read from the current position;\n"
                 "respectively for offset_dst.",
                 condition="defined(HAVE_COPY_FILE_RANGE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="src", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="dst", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="count",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="offset_src",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="offset_dst",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=5
             ),
             Function(
                 name="splice",
                 full_name="os.splice",
                 c_basename="os_splice",
                 docstring="splice($module, /, src, dst, count, offset_src=None, offset_dst=None,\n"
                 "       flags=0)\n"
                 "--\n"
                 "\n"
                 "Transfer count bytes from one pipe to a descriptor or vice versa.\n"
                 "\n"
                 "  src\n"
                 "    Source file descriptor.\n"
                 "  dst\n"
                 "    Destination file descriptor.\n"
                 "  count\n"
                 "    Number of bytes to copy.\n"
                 "  offset_src\n"
                 "    Starting offset in src.\n"
                 "  offset_dst\n"
                 "    Starting offset in dst.\n"
                 "  flags\n"
                 "    Flags to modify the semantics of the call.\n"
                 "\n"
                 "If offset_src is None, then src is read from the current position;\n"
                 "respectively for offset_dst. The offset associated to the file\n"
                 "descriptor that refers to a pipe must be None.",
                 condition="((defined(HAVE_SPLICE) && !defined(_AIX)))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="src", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="dst", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="count",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="offset_src",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="offset_dst",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="flags",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_PyLong_UnsignedInt_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=6
             ),
             Function(
                 name="mkfifo",
                 full_name="os.mkfifo",
                 c_basename="os_mkfifo",
                 docstring="mkfifo($module, /, path, mode=438, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Create a \"fifo\" (a POSIX named pipe).\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative to\n"
                 "that directory.\n"
                 "dir_fd may not be implemented on your platform.  If it is unavailable,\n"
                 "using it will raise a NotImplementedError.",
                 condition="defined(HAVE_MKFIFO)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"mkfifo\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=438,
                         c_default="438"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="MKFIFOAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="mknod",
                 full_name="os.mknod",
                 c_basename="os_mknod",
                 docstring="mknod($module, /, path, mode=384, device=0, *, dir_fd=None)\n"
                 "--\n"
                 "\n"
                 "Create a node in the file system.\n"
                 "\n"
                 "Create a node in the file system (file, device special file or named\n"
                 "pipe) at path.  mode specifies both the permissions to use and the\n"
                 "type of node to be created, being combined (bitwise OR) with one of\n"
                 "S_IFREG, S_IFCHR, S_IFBLK, and S_IFIFO.  If S_IFCHR or S_IFBLK is set\n"
                 "on mode, device defines the newly created device special file (probably\n"
                 "using os.makedev()).  Otherwise device is ignored.\n"
                 "\n"
                 "If dir_fd is not None, it should be a file descriptor open to\n"
                 "a directory, and path should be relative; path will then be relative\n"
                 "to that directory.\n"
                 "dir_fd may not be implemented on your platform.  If it is unavailable,\n"
                 "using it will raise a NotImplementedError.",
                 condition="(defined(HAVE_MKNOD) && defined(HAVE_MAKEDEV))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"mknod\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=384,
                         c_default="384"
                     ),
                     Parameter(
                         name="device",
                         converter="dev_t",
                         type="dev_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=0,
                         c_default="0",
                         convert_with="_Py_Dev_Converter"
                     ),
                     Parameter(
                         name="dir_fd",
                         kind="KEYWORD_ONLY",
                         converter="dir_fd",
                         type="int",
                         format_unit="O&",
                         default_kind="value",
                         c_default="DEFAULT_DIR_FD",
                         convert_with="MKNODAT_DIR_FD_CONVERTER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="major",
                 full_name="os.major",
                 c_basename="os_major",
                 docstring="major($module, device, /)\n"
                 "--\n"
                 "\n"
                 "Extracts a device major number from a raw device number.",
                 condition="defined(HAVE_DEVICE_MACROS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="device",
                         kind="POSITIONAL_ONLY",
                         converter="dev_t",
                         type="dev_t",
                         format_unit="O&",
                         convert_with="_Py_Dev_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="minor",
                 full_name="os.minor",
                 c_basename="os_minor",
                 docstring="minor($module, device, /)\n"
                 "--\n"
                 "\n"
                 "Extracts a device minor number from a raw device number.",
                 condition="defined(HAVE_DEVICE_MACROS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="device",
                         kind="POSITIONAL_ONLY",
                         converter="dev_t",
                         type="dev_t",
                         format_unit="O&",
                         convert_with="_Py_Dev_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="makedev",
                 full_name="os.makedev",
                 c_basename="os_makedev",
                 docstring="makedev($module, major, minor, /)\n"
                 "--\n"
                 "\n"
                 "Composes a raw device number from the major and minor device numbers.",
                 condition="defined(HAVE_DEVICE_MACROS)",
                 returns="dev_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="major",
                         kind="POSITIONAL_ONLY",
                         converter="dev_t",
                         type="dev_t",
                         format_unit="O&",
                         convert_with="_Py_Dev_Converter"
                     ),
                     Parameter(
                         name="minor",
                         kind="POSITIONAL_ONLY",
                         converter="dev_t",
                         type="dev_t",
                         format_unit="O&",
                         convert_with="_Py_Dev_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ftruncate",
                 full_name="os.ftruncate",
                 c_basename="os_ftruncate",
                 docstring="ftruncate($module, fd, length, /)\n"
                 "--\n"
                 "\n"
                 "Truncate a file, specified by file descriptor, to a specific length.",
                 condition="(defined HAVE_FTRUNCATE || defined MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="truncate",
                 full_name="os.truncate",
                 c_basename="os_truncate",
                 docstring="truncate($module, /, path, length)\n"
                 "--\n"
                 "\n"
                 "Truncate a file, specified by path, to a specific length.\n"
                 "\n"
                 "On some platforms, path may also be specified as an open file\n"
                 "descriptor.  If this functionality is unavailable, using it raises\n"
                 "an exception.",
                 condition="(defined HAVE_TRUNCATE || defined MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"truncate\", \"path\", 0, 0, 0, PATH_HAVE_FTRUNCATE)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FTRUNCATE"]
                     ),
                     Parameter(
                         name="length",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="posix_fallocate",
                 full_name="os.posix_fallocate",
                 c_basename="os_posix_fallocate",
                 docstring="posix_fallocate($module, fd, offset, length, /)\n"
                 "--\n"
                 "\n"
                 "Ensure a file has allocated at least a particular number of bytes on disk.\n"
                 "\n"
                 "Ensure that the file specified by fd encompasses a range of bytes\n"
                 "starting at offset bytes from the beginning and continuing for length\n"
                 "bytes.",
                 condition="(defined(HAVE_POSIX_FALLOCATE) && !defined(POSIX_FADVISE_AIX_BUG) && !defined(__wasi__))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="posix_fadvise",
                 full_name="os.posix_fadvise",
                 c_basename="os_posix_fadvise",
                 docstring="posix_fadvise($module, fd, offset, length, advice, /)\n"
                 "--\n"
                 "\n"
                 "Announce an intention to access data in a specific pattern.\n"
                 "\n"
                 "Announce an intention to access data in a specific pattern, thus\n"
                 "allowing the kernel to make optimizations.\n"
                 "The advice applies to the region of the file specified by fd starting at\n"
                 "offset and continuing for length bytes.\n"
                 "advice is one of POSIX_FADV_NORMAL, POSIX_FADV_SEQUENTIAL,\n"
                 "POSIX_FADV_RANDOM, POSIX_FADV_NOREUSE, POSIX_FADV_WILLNEED, or\n"
                 "POSIX_FADV_DONTNEED.",
                 condition="(defined(HAVE_POSIX_FADVISE) && !defined(POSIX_FADVISE_AIX_BUG))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_off_t",
                         type="Py_off_t",
                         format_unit="O&",
                         convert_with="Py_off_t_converter"
                     ),
                     Parameter(
                         name="advice",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=4,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="putenv",
                 full_name="os.putenv",
                 c_basename="os_putenv",
                 docstring="putenv($module, name, value, /)\n"
                 "--\n"
                 "\n"
                 "Change or add an environment variable.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="value",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="putenv",
                 full_name="os.putenv",
                 c_basename="os_putenv",
                 docstring="putenv($module, name, value, /)\n"
                 "--\n"
                 "\n"
                 "Change or add an environment variable.",
                 condition="!defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     ),
                     Parameter(
                         name="value",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="unsetenv",
                 full_name="os.unsetenv",
                 c_basename="os_unsetenv",
                 docstring="unsetenv($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Delete an environment variable.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="unsetenv",
                 full_name="os.unsetenv",
                 c_basename="os_unsetenv",
                 docstring="unsetenv($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Delete an environment variable.",
                 condition="!defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="strerror",
                 full_name="os.strerror",
                 c_basename="os_strerror",
                 docstring="strerror($module, code, /)\n"
                 "--\n"
                 "\n"
                 "Translate an error code to a message string.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="code",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="WCOREDUMP",
                 full_name="os.WCOREDUMP",
                 c_basename="os_WCOREDUMP",
                 docstring="WCOREDUMP($module, status, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the process returning status was dumped to a core file.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WCOREDUMP)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="WIFCONTINUED",
                 full_name="os.WIFCONTINUED",
                 c_basename="os_WIFCONTINUED",
                 docstring="WIFCONTINUED($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return True if a particular process was continued from a job control stop.\n"
                 "\n"
                 "Return True if the process returning status was continued from a\n"
                 "job control stop.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WIFCONTINUED)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="WIFSTOPPED",
                 full_name="os.WIFSTOPPED",
                 c_basename="os_WIFSTOPPED",
                 docstring="WIFSTOPPED($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return True if the process returning status was stopped.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WIFSTOPPED)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="WIFSIGNALED",
                 full_name="os.WIFSIGNALED",
                 c_basename="os_WIFSIGNALED",
                 docstring="WIFSIGNALED($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return True if the process returning status was terminated by a signal.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WIFSIGNALED)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="WIFEXITED",
                 full_name="os.WIFEXITED",
                 c_basename="os_WIFEXITED",
                 docstring="WIFEXITED($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return True if the process returning status exited via the exit() system call.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WIFEXITED)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="WEXITSTATUS",
                 full_name="os.WEXITSTATUS",
                 c_basename="os_WEXITSTATUS",
                 docstring="WEXITSTATUS($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return the process return code from status.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WEXITSTATUS)",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="WTERMSIG",
                 full_name="os.WTERMSIG",
                 c_basename="os_WTERMSIG",
                 docstring="WTERMSIG($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return the signal that terminated the process that provided the status value.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WTERMSIG)",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="WSTOPSIG",
                 full_name="os.WSTOPSIG",
                 c_basename="os_WSTOPSIG",
                 docstring="WSTOPSIG($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Return the signal that stopped the process that provided the status value.",
                 condition="defined(HAVE_SYS_WAIT_H) && defined(WSTOPSIG)",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="status", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="fstatvfs",
                 full_name="os.fstatvfs",
                 c_basename="os_fstatvfs",
                 docstring="fstatvfs($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Perform an fstatvfs system call on the given fd.\n"
                 "\n"
                 "Equivalent to statvfs(fd).",
                 condition="(defined(HAVE_FSTATVFS) && defined(HAVE_SYS_STATVFS_H))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="statvfs",
                 full_name="os.statvfs",
                 c_basename="os_statvfs",
                 docstring="statvfs($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Perform a statvfs system call on the given path.\n"
                 "\n"
                 "path may always be specified as a string.\n"
                 "On some platforms, path may also be specified as an open file\n"
                 "descriptor.  If this functionality is unavailable, using it raises\n"
                 "an exception.",
                 condition="(defined(HAVE_STATVFS) && defined(HAVE_SYS_STATVFS_H))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"statvfs\", \"path\", 0, 0, 0, PATH_HAVE_FSTATVFS)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FSTATVFS"]
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_getdiskusage",
                 full_name="os._getdiskusage",
                 c_basename="os__getdiskusage",
                 docstring="_getdiskusage($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Return disk usage statistics about the given path as a (total, free) tuple.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_getdiskusage\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="fpathconf",
                 full_name="os.fpathconf",
                 c_basename="os_fpathconf",
                 docstring="fpathconf($module, fd, name, /)\n"
                 "--\n"
                 "\n"
                 "Return the configuration limit name for the file descriptor fd.\n"
                 "\n"
                 "If there is no limit, return -1.",
                 condition="defined(HAVE_FPATHCONF)",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="confname",
                         type="int",
                         format_unit="O&",
                         convert_with="conv_confname",
                         options=["\"pathconf_names\""],
                         takes_module=True
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pathconf",
                 full_name="os.pathconf",
                 c_basename="os_pathconf",
                 docstring="pathconf($module, /, path, name)\n"
                 "--\n"
                 "\n"
                 "Return the configuration limit name for the file or directory path.\n"
                 "\n"
                 "If there is no limit, return -1.\n"
                 "On some platforms, path may also be specified as an open file\n"
                 "descriptor.  If this functionality is unavailable, using it raises\n"
                 "an exception.",
                 condition="defined(HAVE_PATHCONF)",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"pathconf\", \"path\", 0, 0, 0, PATH_HAVE_FPATHCONF)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FPATHCONF"]
                     ),
                     Parameter(
                         name="name",
                         converter="confname",
                         type="int",
                         format_unit="O&",
                         convert_with="conv_confname",
                         options=["\"pathconf_names\""],
                         takes_module=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="confstr",
                 full_name="os.confstr",
                 c_basename="os_confstr",
                 docstring="confstr($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Return a string-valued system configuration variable.",
                 condition="defined(HAVE_CONFSTR)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="confname",
                         type="int",
                         format_unit="O&",
                         convert_with="conv_confname",
                         options=["\"confstr_names\""],
                         takes_module=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="sysconf",
                 full_name="os.sysconf",
                 c_basename="os_sysconf",
                 docstring="sysconf($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Return an integer-valued system configuration variable.",
                 condition="defined(HAVE_SYSCONF)",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="confname",
                         type="int",
                         format_unit="O&",
                         convert_with="conv_confname",
                         options=["\"sysconf_names\""],
                         takes_module=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="abort",
                 full_name="os.abort",
                 c_basename="os_abort",
                 docstring="abort($module, /)\n"
                 "--\n"
                 "\n"
                 "Abort the interpreter immediately.\n"
                 "\n"
                 "This function 'dumps core' or otherwise fails in the hardest way\n"
                 "possible on the hosting operating system.  This function never returns.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="startfile",
                 full_name="os.startfile",
                 c_basename="os_startfile",
                 docstring="startfile($module, /, filepath, operation=<unrepresentable>,\n"
                 "          arguments=<unrepresentable>, cwd=None, show_cmd=1)\n"
                 "--\n"
                 "\n"
                 "Start a file with its associated application.\n"
                 "\n"
                 "When \"operation\" is not specified or \"open\", this acts like\n"
                 "double-clicking the file in Explorer, or giving the file name as an\n"
                 "argument to the DOS \"start\" command: the file is opened with whatever\n"
                 "application (if any) its extension is associated.\n"
                 "When another \"operation\" is given, it specifies what should be done with\n"
                 "the file.  A typical operation is \"print\".\n"
                 "\n"
                 "\"arguments\" is passed to the application, but should be omitted if the\n"
                 "file is a document.\n"
                 "\n"
                 "\"cwd\" is the working directory for the operation. If \"filepath\" is\n"
                 "relative, it will be resolved against this directory. This argument\n"
                 "should usually be an absolute path.\n"
                 "\n"
                 "\"show_cmd\" can be used to override the recommended visibility option.\n"
                 "See the Windows ShellExecute documentation for values.\n"
                 "\n"
                 "startfile returns as soon as the associated application is launched.\n"
                 "There is no option to wait for the application to close, and no way\n"
                 "to retrieve the application's exit status.\n"
                 "\n"
                 "The filepath is relative to the current directory.  If you want to use\n"
                 "an absolute path, make sure the first character is not a slash (\"/\");\n"
                 "the underlying Win32 ShellExecute function doesn't work if it is.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="filepath",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"startfile\", \"filepath\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="operation",
                         converter="Py_UNICODE",
                         type="const wchar_t *",
                         format_unit="O&",
                         default_kind="NULL",
                         c_default="NULL",
                         accept=["str"],
                         convert_with="_PyUnicode_WideCharString_Converter"
                     ),
                     Parameter(
                         name="arguments",
                         converter="Py_UNICODE",
                         type="const wchar_t *",
                         format_unit="O&",
                         default_kind="NULL",
                         c_default="NULL",
                         accept=["str"],
                         convert_with="_PyUnicode_WideCharString_Converter"
                     ),
                     Parameter(
                         name="cwd",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="PATH_T_INITIALIZE_P(\"startfile\", \"cwd\", 1, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="show_cmd",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=5
             ),
             Function(
                 name="getloadavg",
                 full_name="os.getloadavg",
                 c_basename="os_getloadavg",
                 docstring="getloadavg($module, /)\n"
                 "--\n"
                 "\n"
                 "Return average recent system load information.\n"
                 "\n"
                 "Return the number of processes in the system run queue averaged over\n"
                 "the last 1, 5, and 15 minutes as a tuple of three floats.\n"
                 "Raises OSError if the load average was unobtainable.",
                 condition="defined(HAVE_GETLOADAVG)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="device_encoding",
                 full_name="os.device_encoding",
                 c_basename="os_device_encoding",
                 docstring="device_encoding($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Return a string describing the encoding of a terminal's file descriptor.\n"
                 "\n"
                 "The file descriptor must be attached to a terminal.\n"
                 "If the device is not a terminal, return None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="fd", converter="int", type="int", format_unit="i")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="setresuid",
                 full_name="os.setresuid",
                 c_basename="os_setresuid",
                 docstring="setresuid($module, ruid, euid, suid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's real, effective, and saved user ids.",
                 condition="defined(HAVE_SETRESUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="ruid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     ),
                     Parameter(
                         name="euid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     ),
                     Parameter(
                         name="suid",
                         kind="POSITIONAL_ONLY",
                         converter="uid_t",
                         type="uid_t",
                         format_unit="O&",
                         convert_with="_Py_Uid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="setresgid",
                 full_name="os.setresgid",
                 c_basename="os_setresgid",
                 docstring="setresgid($module, rgid, egid, sgid, /)\n"
                 "--\n"
                 "\n"
                 "Set the current process's real, effective, and saved group ids.",
                 condition="defined(HAVE_SETRESGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="rgid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     ),
                     Parameter(
                         name="egid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     ),
                     Parameter(
                         name="sgid",
                         kind="POSITIONAL_ONLY",
                         converter="gid_t",
                         type="gid_t",
                         format_unit="O&",
                         convert_with="_Py_Gid_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="getresuid",
                 full_name="os.getresuid",
                 c_basename="os_getresuid",
                 docstring="getresuid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple of the current process's real, effective, and saved user ids.",
                 condition="defined(HAVE_GETRESUID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getresgid",
                 full_name="os.getresgid",
                 c_basename="os_getresgid",
                 docstring="getresgid($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a tuple of the current process's real, effective, and saved group ids.",
                 condition="defined(HAVE_GETRESGID)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getxattr",
                 full_name="os.getxattr",
                 c_basename="os_getxattr",
                 docstring="getxattr($module, /, path, attribute, *, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Return the value of extended attribute attribute on path.\n"
                 "\n"
                 "path may be either a string, a path-like object, or an open file\n"
                 "descriptor.\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, getxattr will examine the symbolic link itself\n"
                 "instead of the file the link points to.",
                 condition="defined(USE_XATTRS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"getxattr\", \"path\", 0, 0, 0, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="attribute",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"getxattr\", \"attribute\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="setxattr",
                 full_name="os.setxattr",
                 c_basename="os_setxattr",
                 docstring="setxattr($module, /, path, attribute, value, flags=0, *,\n"
                 "         follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Set extended attribute attribute on path to value.\n"
                 "\n"
                 "path may be either a string, a path-like object,  or an open file\n"
                 "descriptor.\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, setxattr will modify the symbolic link itself instead\n"
                 "of the file the link points to.",
                 condition="defined(USE_XATTRS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"setxattr\", \"path\", 0, 0, 0, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="attribute",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"setxattr\", \"attribute\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="value",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="flags",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=4
             ),
             Function(
                 name="removexattr",
                 full_name="os.removexattr",
                 c_basename="os_removexattr",
                 docstring="removexattr($module, /, path, attribute, *, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Remove extended attribute attribute on path.\n"
                 "\n"
                 "path may be either a string, a path-like object, or an open file\n"
                 "descriptor.\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, removexattr will modify the symbolic link itself\n"
                 "instead of the file the link points to.",
                 condition="defined(USE_XATTRS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"removexattr\", \"path\", 0, 0, 0, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="attribute",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"removexattr\", \"attribute\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="listxattr",
                 full_name="os.listxattr",
                 c_basename="os_listxattr",
                 docstring="listxattr($module, /, path=None, *, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Return a list of extended attributes on path.\n"
                 "\n"
                 "path may be either None, a string, a path-like object, or an open file\n"
                 "descriptor.  If path is None, listxattr will examine the current\n"
                 "directory.\n"
                 "If follow_symlinks is False, and the last element of the path is\n"
                 "a symbolic link, listxattr will examine the symbolic link itself instead\n"
                 "of the file the link points to.",
                 condition="defined(USE_XATTRS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="PATH_T_INITIALIZE_P(\"listxattr\", \"path\", 1, 0, 0, 1)",
                         convert_with="path_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="urandom",
                 full_name="os.urandom",
                 c_basename="os_urandom",
                 docstring="urandom($module, size, /)\n"
                 "--\n"
                 "\n"
                 "Return a bytes object containing random bytes suitable for cryptographic use.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="memfd_create",
                 full_name="os.memfd_create",
                 c_basename="os_memfd_create",
                 docstring="memfd_create($module, /, name, flags=MFD_CLOEXEC)\n" "--",
                 condition="defined(HAVE_MEMFD_CREATE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     ),
                     Parameter(
                         name="flags",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I",
                         default_kind="unknown",
                         c_default="MFD_CLOEXEC"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="eventfd",
                 full_name="os.eventfd",
                 c_basename="os_eventfd",
                 docstring="eventfd($module, /, initval, flags=EFD_CLOEXEC)\n"
                 "--\n"
                 "\n"
                 "Creates and returns an event notification file descriptor.",
                 condition="(defined(HAVE_EVENTFD) && defined(EFD_CLOEXEC))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="initval",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedInt_Converter"
                     ),
                     Parameter(
                         name="flags",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="EFD_CLOEXEC"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="eventfd_read",
                 full_name="os.eventfd_read",
                 c_basename="os_eventfd_read",
                 docstring="eventfd_read($module, /, fd)\n"
                 "--\n"
                 "\n"
                 "Read eventfd value",
                 condition="(defined(HAVE_EVENTFD) && defined(EFD_CLOEXEC))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="eventfd_write",
                 full_name="os.eventfd_write",
                 c_basename="os_eventfd_write",
                 docstring="eventfd_write($module, /, fd, value)\n"
                 "--\n"
                 "\n"
                 "Write eventfd value.",
                 condition="(defined(HAVE_EVENTFD) && defined(EFD_CLOEXEC))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="value",
                         converter="unsigned_long_long",
                         type="unsigned long long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLongLong_Converter"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="get_terminal_size",
                 full_name="os.get_terminal_size",
                 c_basename="os_get_terminal_size",
                 docstring="get_terminal_size($module, fd=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Return the size of the terminal window as (columns, lines).\n"
                 "\n"
                 "The optional argument fd (default standard output) specifies\n"
                 "which file descriptor should be queried.\n"
                 "\n"
                 "If the file descriptor is not connected to a terminal, an OSError\n"
                 "is thrown.\n"
                 "\n"
                 "This function will only be defined if an implementation is\n"
                 "available for this system.\n"
                 "\n"
                 "shutil.get_terminal_size is the high-level function which should\n"
                 "normally be used, os.get_terminal_size is the low-level implementation.",
                 condition="(defined(TERMSIZE_USE_CONIO) || defined(TERMSIZE_USE_IOCTL))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="fileno(stdout)"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="cpu_count",
                 full_name="os.cpu_count",
                 c_basename="os_cpu_count",
                 docstring="cpu_count($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the number of logical CPUs in the system.\n"
                 "\n"
                 "Return None if indeterminable.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_inheritable",
                 full_name="os.get_inheritable",
                 c_basename="os_get_inheritable",
                 docstring="get_inheritable($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Get the close-on-exe flag of the specified file descriptor.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set_inheritable",
                 full_name="os.set_inheritable",
                 c_basename="os_set_inheritable",
                 docstring="set_inheritable($module, fd, inheritable, /)\n"
                 "--\n"
                 "\n"
                 "Set the inheritable flag of the specified file descriptor.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="inheritable",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="get_handle_inheritable",
                 full_name="os.get_handle_inheritable",
                 c_basename="os_get_handle_inheritable",
                 docstring="get_handle_inheritable($module, handle, /)\n"
                 "--\n"
                 "\n"
                 "Get the close-on-exe flag of the specified file descriptor.",
                 condition="defined(MS_WINDOWS)",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="handle",
                         kind="POSITIONAL_ONLY",
                         converter="intptr_t",
                         type="intptr_t",
                         format_unit="\" _Py_PARSE_INTPTR \""
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set_handle_inheritable",
                 full_name="os.set_handle_inheritable",
                 c_basename="os_set_handle_inheritable",
                 docstring="set_handle_inheritable($module, handle, inheritable, /)\n"
                 "--\n"
                 "\n"
                 "Set the inheritable flag of the specified handle.",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="handle",
                         kind="POSITIONAL_ONLY",
                         converter="intptr_t",
                         type="intptr_t",
                         format_unit="\" _Py_PARSE_INTPTR \""
                     ),
                     Parameter(
                         name="inheritable",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="get_blocking",
                 full_name="os.get_blocking",
                 c_basename="os_get_blocking",
                 docstring="get_blocking($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Get the blocking mode of the file descriptor.\n"
                 "\n"
                 "Return False if the O_NONBLOCK flag is set, True if the flag is cleared.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="set_blocking",
                 full_name="os.set_blocking",
                 c_basename="os_set_blocking",
                 docstring="set_blocking($module, fd, blocking, /)\n"
                 "--\n"
                 "\n"
                 "Set the blocking mode of the specified file descriptor.\n"
                 "\n"
                 "Set the O_NONBLOCK flag if blocking is False,\n"
                 "clear the O_NONBLOCK flag otherwise.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="blocking",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="scandir",
                 full_name="os.scandir",
                 c_basename="os_scandir",
                 docstring="scandir($module, /, path=None)\n"
                 "--\n"
                 "\n"
                 "Return an iterator of DirEntry objects for given path.\n"
                 "\n"
                 "path can be specified as either str, bytes, or a path-like object.  If\n"
                 "path is bytes, the names of yielded DirEntry objects will also be bytes;\n"
                 "in all other circumstances they will be str.\n"
                 "\n"
                 "If path is None, uses the path='.'.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="PATH_T_INITIALIZE_P(\"scandir\", \"path\", 1, 0, 0, PATH_HAVE_FDOPENDIR)",
                         convert_with="path_converter",
                         by_reference=True,
                         options=["PATH_HAVE_FDOPENDIR"]
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="fspath",
                 full_name="os.fspath",
                 c_basename="os_fspath",
                 docstring="fspath($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Return the file system path representation of the object.\n"
                 "\n"
                 "If the object is str or bytes, then allow it to pass through as-is.  If\n"
                 "the object defines __fspath__(), then return the result of that method.\n"
                 "All other types raise a TypeError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="path", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="getrandom",
                 full_name="os.getrandom",
                 c_basename="os_getrandom",
                 docstring="getrandom($module, /, size, flags=0)\n"
                 "--\n"
                 "\n"
                 "Obtain a series of random bytes.",
                 condition="defined(HAVE_GETRANDOM_SYSCALL)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="size",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="flags",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="_add_dll_directory",
                 full_name="os._add_dll_directory",
                 c_basename="os__add_dll_directory",
                 docstring="_add_dll_directory($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Add a path to the DLL search path.\n"
                 "\n"
                 "This search path is used when resolving dependencies for imported\n"
                 "extension modules (the module itself is resolved through sys.path),\n"
                 "and also by ctypes.\n"
                 "\n"
                 "Returns an opaque value that may be passed to os.remove_dll_directory\n"
                 "to remove this directory from the search path.",
                 condition="(defined(MS_WINDOWS_DESKTOP) || defined(MS_WINDOWS_APP) || defined(MS_WINDOWS_SYSTEM))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         converter="path_t",
                         type="path_t",
                         format_unit="O&",
                         c_default="PATH_T_INITIALIZE_P(\"_add_dll_directory\", \"path\", 0, 0, 0, 0)",
                         convert_with="path_converter",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_remove_dll_directory",
                 full_name="os._remove_dll_directory",
                 c_basename="os__remove_dll_directory",
                 docstring="_remove_dll_directory($module, /, cookie)\n"
                 "--\n"
                 "\n"
                 "Removes a path from the DLL search path.\n"
                 "\n"
                 "The parameter is an opaque value that was returned from\n"
                 "os.add_dll_directory. You can only remove directories that you added\n"
                 "yourself.",
                 condition="(defined(MS_WINDOWS_DESKTOP) || defined(MS_WINDOWS_APP) || defined(MS_WINDOWS_SYSTEM))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="cookie", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="waitstatus_to_exitcode",
                 full_name="os.waitstatus_to_exitcode",
                 c_basename="os_waitstatus_to_exitcode",
                 docstring="waitstatus_to_exitcode($module, /, status)\n"
                 "--\n"
                 "\n"
                 "Convert a wait status to an exit code.\n"
                 "\n"
                 "On Unix:\n"
                 "\n"
                 "* If WIFEXITED(status) is true, return WEXITSTATUS(status).\n"
                 "* If WIFSIGNALED(status) is true, return -WTERMSIG(status).\n"
                 "* Otherwise, raise a ValueError.\n"
                 "\n"
                 "On Windows, return status shifted right by 8 bits.\n"
                 "\n"
                 "On Unix, if the process is being traced or if waitpid() was called with\n"
                 "WUNTRACED option, the caller must first check if WIFSTOPPED(status) is\n"
                 "true.  This function must not be called if WIFSTOPPED(status) is true.",
                 condition="(defined(WIFEXITED) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="status", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="_supports_virtual_terminal",
                 full_name="os._supports_virtual_terminal",
                 c_basename="os__supports_virtual_terminal",
                 docstring="_supports_virtual_terminal($module, /)\n"
                 "--\n"
                 "\n"
                 "Checks if virtual terminal is supported in windows",
                 condition="defined(MS_WINDOWS)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_inputhook",
                 full_name="os._inputhook",
                 c_basename="os__inputhook",
                 docstring="_inputhook($module, /)\n"
                 "--\n"
                 "\n"
                 "Calls PyOS_CallInputHook droppong the GIL first",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_is_inputhook_installed",
                 full_name="os._is_inputhook_installed",
                 c_basename="os__is_inputhook_installed",
                 docstring="_is_inputhook_installed($module, /)\n"
                 "--\n"
                 "\n"
                 "Checks if PyOS_CallInputHook is set",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_create_environ",
                 full_name="os._create_environ",
                 c_basename="os__create_environ",
                 docstring="_create_environ($module, /)\n"
                 "--\n"
                 "\n"
                 "Create the environment dictionary.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_emscripten_debugger",
                 full_name="os._emscripten_debugger",
                 c_basename="os__emscripten_debugger",
                 docstring="_emscripten_debugger($module, /)\n"
                 "--\n"
                 "\n"
                 "Create a breakpoint for the JavaScript debugger. Emscripten only.",
                 condition="defined(__EMSCRIPTEN__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_emscripten_log",
                 full_name="os._emscripten_log",
                 c_basename="os__emscripten_log",
                 docstring="_emscripten_log($module, /, arg)\n"
                 "--\n"
                 "\n"
                 "Log something to the JS console. Emscripten only.",
                 condition="defined(__EMSCRIPTEN__)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="arg",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="__new__",
                 full_name="os.sched_param.__new__",
                 c_basename="os_sched_param",
                 kind="METHOD_NEW",
                 cls="sched_param",
                 docstring="sched_param(sched_priority)\n"
                 "--\n"
                 "\n"
                 "Currently has only one field: sched_priority\n"
                 "\n"
                 "  sched_priority\n"
                 "    A scheduling parameter.",
                 condition="defined(HAVE_SCHED_H) && (defined(HAVE_SCHED_SETPARAM) || defined(HAVE_SCHED_SETSCHEDULER) || defined(POSIX_SPAWN_SETSCHEDULER) || defined(POSIX_SPAWN_SETSCHEDPARAM))",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="sched_priority", format_unit="O")
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="is_symlink",
                 full_name="os.DirEntry.is_symlink",
                 c_basename="os_DirEntry_is_symlink",
                 cls="DirEntry",
                 docstring="is_symlink($self, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the entry is a symbolic link; cached per entry.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="defining_class",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="is_junction",
                 full_name="os.DirEntry.is_junction",
                 c_basename="os_DirEntry_is_junction",
                 cls="DirEntry",
                 docstring="is_junction($self, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the entry is a junction; cached per entry.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="stat",
                 full_name="os.DirEntry.stat",
                 c_basename="os_DirEntry_stat",
                 cls="DirEntry",
                 docstring="stat($self, /, *, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Return stat_result object for the entry; cached per entry.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="defining_class",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="is_dir",
                 full_name="os.DirEntry.is_dir",
                 c_basename="os_DirEntry_is_dir",
                 cls="DirEntry",
                 docstring="is_dir($self, /, *, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Return True if the entry is a directory; cached per entry.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="defining_class",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="is_file",
                 full_name="os.DirEntry.is_file",
                 c_basename="os_DirEntry_is_file",
                 cls="DirEntry",
                 docstring="is_file($self, /, *, follow_symlinks=True)\n"
                 "--\n"
                 "\n"
                 "Return True if the entry is a file; cached per entry.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="defining_class",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="follow_symlinks",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="inode",
                 full_name="os.DirEntry.inode",
                 c_basename="os_DirEntry_inode",
                 cls="DirEntry",
                 docstring="inode($self, /)\n"
                 "--\n"
                 "\n"
                 "Return inode of the entry; cached per entry.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__fspath__",
                 full_name="os.DirEntry.__fspath__",
                 c_basename="os_DirEntry___fspath__",
                 cls="DirEntry",
                 docstring="__fspath__($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns the path for the entry.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             )
         ],
         docs={
             "posix__doc__": "This module provides access to operating system functionality that is\n"
             "standardized by the C Standard and the POSIX standard (a thinly\n"
             "disguised Unix interface).  Refer to the library manual and\n"
             "corresponding Unix manual entries for more information on calls.",
             "stat_result__doc__": "stat_result: Result from stat, fstat, or lstat.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime)\n"
             "or via the attributes st_mode, st_ino, st_dev, st_nlink, and so on.\n"
             "\n"
             "Posix/windows: If your platform supports st_blksize, st_blocks, st_rdev,\n"
             "or st_flags, they are available as attributes only.\n"
             "\n"
             "See os.stat for more information.",
             "statvfs_result__doc__": "statvfs_result: Result from statvfs or fstatvfs.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (bsize, frsize, blocks, bfree, bavail, files, ffree, favail, flag, namemax),\n"
             "or via the attributes f_bsize, f_frsize, f_blocks, f_bfree, and so on.\n"
             "\n"
             "See os.statvfs for more information.",
             "waitid_result__doc__": "waitid_result: Result from waitid.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (si_pid, si_uid, si_signo, si_status, si_code),\n"
             "or via the attributes si_pid, si_uid, and so on.\n"
             "\n"
             "See os.waitid for more information.",
             "uname_result__doc__": "uname_result: Result from os.uname().\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (sysname, nodename, release, version, machine),\n"
             "or via the attributes sysname, nodename, release, version, and machine.\n"
             "\n"
             "See os.uname for more information.",
             "times_result__doc__": "times_result: Result from os.times().\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (user, system, children_user, children_system, elapsed),\n"
             "or via the attributes user, system, children_user, children_system,\n"
             "and elapsed.\n"
             "\n"
             "See os.times for more information.",
             "TerminalSize_docstring": "A tuple of (columns, lines) for holding terminal window size",
             "DirEntry_members_name_doc": "the entry's base filename, relative to scandir() \"path\" argument",
             "DirEntry_members_path_doc": "the entry's full path name; equivalent to\n"
             "os.path.join(scandir_path, entry.name)",
             "DirEntry_methods___class_getitem___doc": "DirEntry is generic over the type of the path (str or bytes)"
         }
     );
