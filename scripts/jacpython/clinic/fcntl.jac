"""The Argument Clinic signatures of fcntl.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/fcntl.jac from them. Taken from
the C sources it replaces (Modules/fcntlmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="fcntl",
         version="3.14.6",
         sources=["Modules/fcntlmodule.c"],
         functions=[
             Function(
                 name="fcntl",
                 full_name="fcntl.fcntl",
                 c_basename="fcntl_fcntl",
                 docstring="fcntl($module, fd, cmd, arg=0, /)\n"
                 "--\n"
                 "\n"
                 "Perform the operation cmd on file descriptor fd.\n"
                 "\n"
                 "The values used for cmd are operating system dependent, and are\n"
                 "available as constants in the fcntl module, using the same names as used\n"
                 "in the relevant C header files.  The argument arg is optional, and\n"
                 "defaults to 0; it may be an integer, a bytes-like object or a string.\n"
                 "If arg is given as a string, it will be encoded to binary using the\n"
                 "UTF-8 encoding.\n"
                 "\n"
                 "If the arg given is an integer or if none is specified, the result value\n"
                 "is an integer corresponding to the return value of the fcntl() call in\n"
                 "the C code.\n"
                 "\n"
                 "If arg is given as a bytes-like object, the return value of fcntl() is a\n"
                 "bytes object of that length, containing the resulting value put in the\n"
                 "arg buffer by the operating system.  The length of the arg buffer is not\n"
                 "allowed to exceed 1024 bytes.",
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
                         name="cmd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="arg",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=3,
                 pos_only=3,
                 limited_capi=True
             ),
             Function(
                 name="ioctl",
                 full_name="fcntl.ioctl",
                 c_basename="fcntl_ioctl",
                 docstring="ioctl($module, fd, request, arg=0, mutate_flag=True, /)\n"
                 "--\n"
                 "\n"
                 "Perform the operation request on file descriptor fd.\n"
                 "\n"
                 "The values used for request are operating system dependent, and are\n"
                 "available as constants in the fcntl or termios library modules, using\n"
                 "the same names as used in the relevant C header files.\n"
                 "\n"
                 "The argument arg is optional, and defaults to 0; it may be an integer, a\n"
                 "bytes-like object or a string.  If arg is given as a string, it will be\n"
                 "encoded to binary using the UTF-8 encoding.\n"
                 "\n"
                 "If the arg given is an integer or if none is specified, the result value\n"
                 "is an integer corresponding to the return value of the ioctl() call in\n"
                 "the C code.\n"
                 "\n"
                 "If the argument is a mutable buffer (such as a bytearray) and the\n"
                 "mutate_flag argument is true (default) then the buffer is (in effect)\n"
                 "passed to the operating system and changes made by the OS will be\n"
                 "reflected in the contents of the buffer after the call has returned.\n"
                 "The return value is the integer returned by the ioctl() system call.\n"
                 "\n"
                 "If the argument is a mutable buffer and the mutable_flag argument is\n"
                 "false, the behavior is as if an immutable buffer had been passed.\n"
                 "\n"
                 "If the argument is an immutable buffer then a copy of the buffer is\n"
                 "passed to the operating system and the return value is a bytes object of\n"
                 "the same length containing whatever the operating system put in the\n"
                 "buffer.  The length of the arg buffer in this case is not allowed to\n"
                 "exceed 1024 bytes.",
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
                         name="request",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="k"
                     ),
                     Parameter(
                         name="arg",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     ),
                     Parameter(
                         name="mutate_flag",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=4,
                 pos_only=4,
                 limited_capi=True
             ),
             Function(
                 name="flock",
                 full_name="fcntl.flock",
                 c_basename="fcntl_flock",
                 docstring="flock($module, fd, operation, /)\n"
                 "--\n"
                 "\n"
                 "Perform the lock operation on file descriptor fd.\n"
                 "\n"
                 "See the Unix manual page for flock(2) for details (On some systems, this\n"
                 "function is emulated using fcntl()).",
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
                         name="operation",
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
                 pos_only=2,
                 limited_capi=True
             ),
             Function(
                 name="lockf",
                 full_name="fcntl.lockf",
                 c_basename="fcntl_lockf",
                 docstring="lockf($module, fd, cmd, len=0, start=0, whence=0, /)\n"
                 "--\n"
                 "\n"
                 "A wrapper around the fcntl() locking calls.\n"
                 "\n"
                 "fd is the file descriptor of the file to lock or unlock, and operation\n"
                 "is one of the following values:\n"
                 "\n"
                 "    LOCK_UN - unlock\n"
                 "    LOCK_SH - acquire a shared lock\n"
                 "    LOCK_EX - acquire an exclusive lock\n"
                 "\n"
                 "When operation is LOCK_SH or LOCK_EX, it can also be bitwise ORed with\n"
                 "LOCK_NB to avoid blocking on lock acquisition.  If LOCK_NB is used and\n"
                 "the lock cannot be acquired, an OSError will be raised and the exception\n"
                 "will have an errno attribute set to EACCES or EAGAIN (depending on the\n"
                 "operating system -- for portability, check for either value).\n"
                 "\n"
                 "len is the number of bytes to lock, with the default meaning to lock to\n"
                 "EOF.  start is the byte offset, relative to whence, to that the lock\n"
                 "starts.  whence is as with fileobj.seek(), specifically:\n"
                 "\n"
                 "    0 - relative to the start of the file (SEEK_SET)\n"
                 "    1 - relative to the current buffer position (SEEK_CUR)\n"
                 "    2 - relative to the end of the file (SEEK_END)",
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
                         name="cmd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="len",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     ),
                     Parameter(
                         name="start",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     ),
                     Parameter(
                         name="whence",
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
                 min_pos=2,
                 max_pos=5,
                 pos_only=5,
                 limited_capi=True
             )
         ],
         docs={
             "module_doc": "This module performs file control and I/O control on file\n"
             "descriptors.  It is an interface to the fcntl() and ioctl() Unix\n"
             "routines.  File descriptors can be obtained with the fileno() method of\n"
             "a file or socket object."
         }
     );
