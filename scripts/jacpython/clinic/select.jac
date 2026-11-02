"""The Argument Clinic signatures of select.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/select.jac from them. Taken from
CPython 3.14.6 Modules/selectmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="select",
         version="3.14.6",
         sources=["Modules/selectmodule.c"],
         classes={
             "poll": "pollObject *",
             "devpoll": "devpollObject *",
             "epoll": "pyEpoll_Object *",
             "kqueue": "kqueue_queue_Object *"
         },
         functions=[
             Function(
                 name="select",
                 full_name="select.select",
                 c_basename="select_select",
                 docstring="select($module, rlist, wlist, xlist, timeout=None, /)\n"
                 "--\n"
                 "\n"
                 "Wait until one or more file descriptors are ready for some kind of I/O.\n"
                 "\n"
                 "The first three arguments are iterables of file descriptors to be waited\n"
                 "for:\n"
                 "rlist -- wait until ready for reading\n"
                 "wlist -- wait until ready for writing\n"
                 "xlist -- wait for an \"exceptional condition\"\n"
                 "If only one kind of condition is required, pass [] for the other lists.\n"
                 "\n"
                 "A file descriptor is either a socket or file object, or a small integer\n"
                 "gotten from a fileno() method call on one of those.\n"
                 "\n"
                 "The optional 4th argument specifies a timeout in seconds; it may be\n"
                 "a floating-point number to specify fractions of seconds.  If it is absent\n"
                 "or None, the call will never time out.\n"
                 "\n"
                 "The return value is a tuple of three lists corresponding to the first\n"
                 "three arguments; each contains the subset of the corresponding file\n"
                 "descriptors that are ready.\n"
                 "\n"
                 "*** IMPORTANT NOTICE ***\n"
                 "On Windows, only sockets are supported; on Unix, all file\n"
                 "descriptors can be used.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="rlist", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="wlist", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="xlist", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="timeout",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=4,
                 pos_only=4
             ),
             Function(
                 name="poll",
                 full_name="select.poll",
                 c_basename="select_poll",
                 docstring="poll($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns a polling object.\n"
                 "\n"
                 "This object supports registering and unregistering file descriptors, and\n"
                 "then polling them for I/O events.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL))",
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
                 name="devpoll",
                 full_name="select.devpoll",
                 c_basename="select_devpoll",
                 docstring="devpoll($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns a polling object.\n"
                 "\n"
                 "This object supports registering and unregistering file descriptors, and\n"
                 "then polling them for I/O events.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
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
                 name="register",
                 full_name="select.poll.register",
                 c_basename="select_poll_register",
                 cls="poll",
                 docstring="register($self, fd,\n"
                 "         eventmask=select.POLLIN | select.POLLPRI | select.POLLOUT, /)\n"
                 "--\n"
                 "\n"
                 "Register a file descriptor with the polling object.\n"
                 "\n"
                 "  fd\n"
                 "    either an integer, or an object with a fileno() method returning an int\n"
                 "  eventmask\n"
                 "    an optional bitmask describing the type of events to check for",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL))",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                         name="eventmask",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_short",
                         type="unsigned short",
                         format_unit="O&",
                         default_kind="unknown",
                         c_default="POLLIN | POLLPRI | POLLOUT",
                         convert_with="_PyLong_UnsignedShort_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="modify",
                 full_name="select.poll.modify",
                 c_basename="select_poll_modify",
                 cls="poll",
                 docstring="modify($self, fd, eventmask, /)\n"
                 "--\n"
                 "\n"
                 "Modify an already registered file descriptor.\n"
                 "\n"
                 "  fd\n"
                 "    either an integer, or an object with a fileno() method returning\n"
                 "    an int\n"
                 "  eventmask\n"
                 "    a bitmask describing the type of events to check for",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL))",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                         name="eventmask",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_short",
                         type="unsigned short",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedShort_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="unregister",
                 full_name="select.poll.unregister",
                 c_basename="select_poll_unregister",
                 cls="poll",
                 docstring="unregister($self, fd, /)\n"
                 "--\n"
                 "\n"
                 "Remove a file descriptor being tracked by the polling object.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL))",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 name="poll",
                 full_name="select.poll.poll",
                 c_basename="select_poll_poll",
                 cls="poll",
                 docstring="poll($self, timeout=None, /)\n"
                 "--\n"
                 "\n"
                 "Polls the set of registered file descriptors.\n"
                 "\n"
                 "  timeout\n"
                 "    The maximum time to wait in milliseconds, or else None (or a negative\n"
                 "    value) to wait indefinitely.\n"
                 "\n"
                 "Returns a list containing any descriptors that have events or errors\n"
                 "to report, as a list of (fd, event) 2-tuples.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL))",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="timeout",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="register",
                 full_name="select.devpoll.register",
                 c_basename="select_devpoll_register",
                 cls="devpoll",
                 docstring="register($self, fd,\n"
                 "         eventmask=select.POLLIN | select.POLLPRI | select.POLLOUT, /)\n"
                 "--\n"
                 "\n"
                 "Register a file descriptor with the polling object.\n"
                 "\n"
                 "  fd\n"
                 "    either an integer, or an object with a fileno() method returning\n"
                 "    an int\n"
                 "  eventmask\n"
                 "    an optional bitmask describing the type of events to check for",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                         name="eventmask",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_short",
                         type="unsigned short",
                         format_unit="O&",
                         default_kind="unknown",
                         c_default="POLLIN | POLLPRI | POLLOUT",
                         convert_with="_PyLong_UnsignedShort_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="modify",
                 full_name="select.devpoll.modify",
                 c_basename="select_devpoll_modify",
                 cls="devpoll",
                 docstring="modify($self, fd,\n"
                 "       eventmask=select.POLLIN | select.POLLPRI | select.POLLOUT, /)\n"
                 "--\n"
                 "\n"
                 "Modify a possible already registered file descriptor.\n"
                 "\n"
                 "  fd\n"
                 "    either an integer, or an object with a fileno() method returning\n"
                 "    an int\n"
                 "  eventmask\n"
                 "    an optional bitmask describing the type of events to check for",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                         name="eventmask",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_short",
                         type="unsigned short",
                         format_unit="O&",
                         default_kind="unknown",
                         c_default="POLLIN | POLLPRI | POLLOUT",
                         convert_with="_PyLong_UnsignedShort_Converter"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="unregister",
                 full_name="select.devpoll.unregister",
                 c_basename="select_devpoll_unregister",
                 cls="devpoll",
                 docstring="unregister($self, fd, /)\n"
                 "--\n"
                 "\n"
                 "Remove a file descriptor being tracked by the polling object.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 name="poll",
                 full_name="select.devpoll.poll",
                 c_basename="select_devpoll_poll",
                 cls="devpoll",
                 docstring="poll($self, timeout=None, /)\n"
                 "--\n"
                 "\n"
                 "Polls the set of registered file descriptors.\n"
                 "\n"
                 "  timeout\n"
                 "    The maximum time to wait in milliseconds, or else None (or\n"
                 "    a negative value) to wait indefinitely.\n"
                 "\n"
                 "Returns a list containing any descriptors that have events or errors\n"
                 "to report, as a list of (fd, event) 2-tuples.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="timeout",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="close",
                 full_name="select.devpoll.close",
                 c_basename="select_devpoll_close",
                 cls="devpoll",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Close the devpoll file descriptor.\n"
                 "\n"
                 "Further operations on the devpoll object will raise an exception.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fileno",
                 full_name="select.devpoll.fileno",
                 c_basename="select_devpoll_fileno",
                 cls="devpoll",
                 docstring="fileno($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the file descriptor.",
                 condition="(defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)) && defined(HAVE_SYS_DEVPOLL_H)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__new__",
                 full_name="select.epoll.__new__",
                 c_basename="select_epoll",
                 kind="METHOD_NEW",
                 cls="epoll",
                 docstring="epoll(sizehint=-1, flags=0)\n"
                 "--\n"
                 "\n"
                 "Returns an epolling object.\n"
                 "\n"
                 "  sizehint\n"
                 "    The expected number of events to be registered.  It must be positive,\n"
                 "    or -1 to use the default.  It is only used on older systems where\n"
                 "    epoll_create1() is not available; otherwise it has no effect (though its\n"
                 "    value is still checked).\n"
                 "  flags\n"
                 "    Deprecated and completely ignored.  However, when supplied, its value\n"
                 "    must be 0 or select.EPOLL_CLOEXEC, otherwise OSError is raised.",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sizehint",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
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
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="close",
                 full_name="select.epoll.close",
                 c_basename="select_epoll_close",
                 cls="epoll",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Close the epoll control file descriptor.\n"
                 "\n"
                 "Further operations on the epoll object will raise an exception.",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fileno",
                 full_name="select.epoll.fileno",
                 c_basename="select_epoll_fileno",
                 cls="epoll",
                 docstring="fileno($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the epoll control file descriptor.",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fromfd",
                 full_name="select.epoll.fromfd",
                 c_basename="select_epoll_fromfd",
                 kind="CLASS_METHOD",
                 cls="epoll",
                 docstring="fromfd($type, fd, /)\n"
                 "--\n"
                 "\n"
                 "Create an epoll object from a given control fd.",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O|METH_CLASS",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="register",
                 full_name="select.epoll.register",
                 c_basename="select_epoll_register",
                 cls="epoll",
                 docstring="register($self, /, fd,\n"
                 "         eventmask=select.EPOLLIN | select.EPOLLPRI | select.EPOLLOUT)\n"
                 "--\n"
                 "\n"
                 "Registers a new fd or raises an OSError if the fd is already registered.\n"
                 "\n"
                 "  fd\n"
                 "    the target file descriptor of the operation\n"
                 "  eventmask\n"
                 "    a bit set composed of the various EPOLL constants\n"
                 "\n"
                 "The epoll interface supports all file descriptors that support poll.",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="eventmask",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I",
                         default_kind="unknown",
                         c_default="EPOLLIN | EPOLLPRI | EPOLLOUT"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="modify",
                 full_name="select.epoll.modify",
                 c_basename="select_epoll_modify",
                 cls="epoll",
                 docstring="modify($self, /, fd, eventmask)\n"
                 "--\n"
                 "\n"
                 "Modify event mask for a registered file descriptor.\n"
                 "\n"
                 "  fd\n"
                 "    the target file descriptor of the operation\n"
                 "  eventmask\n"
                 "    a bit set composed of the various EPOLL constants",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="fd",
                         converter="fildes",
                         type="int",
                         format_unit="O&",
                         convert_with="_PyLong_FileDescriptor_Converter"
                     ),
                     Parameter(
                         name="eventmask",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="unregister",
                 full_name="select.epoll.unregister",
                 c_basename="select_epoll_unregister",
                 cls="epoll",
                 docstring="unregister($self, /, fd)\n"
                 "--\n"
                 "\n"
                 "Remove a registered file descriptor from the epoll object.\n"
                 "\n"
                 "  fd\n"
                 "    the target file descriptor of the operation",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 name="poll",
                 full_name="select.epoll.poll",
                 c_basename="select_epoll_poll",
                 cls="epoll",
                 docstring="poll($self, /, timeout=None, maxevents=-1)\n"
                 "--\n"
                 "\n"
                 "Wait for events on the epoll file descriptor.\n"
                 "\n"
                 "  timeout\n"
                 "    the maximum time to wait in seconds (as float);\n"
                 "    a timeout of None or -1 makes poll wait indefinitely\n"
                 "  maxevents\n"
                 "    the maximum number of events returned; -1 means no limit\n"
                 "\n"
                 "Returns a list containing any descriptors that have events to\n"
                 "report, as a list of (fd, events) 2-tuples.",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="timeout",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="maxevents",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="__enter__",
                 full_name="select.epoll.__enter__",
                 c_basename="select_epoll___enter__",
                 cls="epoll",
                 docstring="__enter__($self, /)\n" "--",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__exit__",
                 full_name="select.epoll.__exit__",
                 c_basename="select_epoll___exit__",
                 cls="epoll",
                 docstring="__exit__($self, exc_type=None, exc_value=None, exc_tb=None, /)\n"
                 "--",
                 condition="defined(HAVE_EPOLL)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="exc_type",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="exc_value",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="exc_tb",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="__new__",
                 full_name="select.kqueue.__new__",
                 c_basename="select_kqueue",
                 kind="METHOD_NEW",
                 cls="kqueue",
                 docstring="kqueue()\n"
                 "--\n"
                 "\n"
                 "Kqueue syscall wrapper.\n"
                 "\n"
                 "For example, to start watching a socket for input:\n"
                 ">>> kq = kqueue()\n"
                 ">>> sock = socket()\n"
                 ">>> sock.connect((host, port))\n"
                 ">>> kq.control([kevent(sock, KQ_FILTER_WRITE, KQ_EV_ADD)], 0)\n"
                 "\n"
                 "To wait one second for it to become writeable:\n"
                 ">>> kq.control(None, 1, 1000)\n"
                 "\n"
                 "To stop listening:\n"
                 ">>> kq.control([kevent(sock, KQ_FILTER_WRITE, KQ_EV_DELETE)], 0)",
                 condition="defined(HAVE_KQUEUE)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_NOTHING",
                 self_type_check=True
             ),
             Function(
                 name="close",
                 full_name="select.kqueue.close",
                 c_basename="select_kqueue_close",
                 cls="kqueue",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Close the kqueue control file descriptor.\n"
                 "\n"
                 "Further operations on the kqueue object will raise an exception.",
                 condition="defined(HAVE_KQUEUE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fileno",
                 full_name="select.kqueue.fileno",
                 c_basename="select_kqueue_fileno",
                 cls="kqueue",
                 docstring="fileno($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the kqueue control file descriptor.",
                 condition="defined(HAVE_KQUEUE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="fromfd",
                 full_name="select.kqueue.fromfd",
                 c_basename="select_kqueue_fromfd",
                 kind="CLASS_METHOD",
                 cls="kqueue",
                 docstring="fromfd($type, fd, /)\n"
                 "--\n"
                 "\n"
                 "Create a kqueue object from a given control fd.",
                 condition="defined(HAVE_KQUEUE)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="fd",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_O|METH_CLASS",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="control",
                 full_name="select.kqueue.control",
                 c_basename="select_kqueue_control",
                 cls="kqueue",
                 docstring="control($self, changelist, maxevents, timeout=None, /)\n"
                 "--\n"
                 "\n"
                 "Calls the kernel kevent function.\n"
                 "\n"
                 "  changelist\n"
                 "    Must be an iterable of kevent objects describing the changes to be made\n"
                 "    to the kernel's watch list or None.\n"
                 "  maxevents\n"
                 "    The maximum number of events that the kernel will return.\n"
                 "  timeout\n"
                 "    The maximum time to wait in seconds, or else None to wait forever.\n"
                 "    This accepts floats for smaller timeouts, too.",
                 condition="defined(HAVE_KQUEUE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="changelist", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="maxevents",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="timeout",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=3,
                 pos_only=3
             )
         ],
         docs={
             "pyepoll_doc": "select.epoll(sizehint=-1, flags=0)\n"
             "\n"
             "Returns an epolling object\n"
             "\n"
             "sizehint must be a positive integer or -1 for the default size. The\n"
             "sizehint is used to optimize internal data structures. It doesn't limit\n"
             "the maximum number of monitored events.",
             "kqueue_event_doc": "kevent(ident, filter=KQ_FILTER_READ, flags=KQ_EV_ADD, fflags=0, data=0, udata=0)\n"
             "\n"
             "This object is the equivalent of the struct kevent for the C API.\n"
             "\n"
             "See the kqueue manpage for more detailed information about the meaning\n"
             "of the arguments.\n"
             "\n"
             "One minor note: while you might hope that udata could store a\n"
             "reference to a python object, it cannot, because it is impossible to\n"
             "keep a proper reference count of the object once it's passed into the\n"
             "kernel. Therefore, I have restricted it to only storing an integer.  I\n"
             "recommend ignoring it and simply using the 'ident' field to key off\n"
             "of. You could also set up a dictionary on the python side to store a\n"
             "udata->object mapping.",
             "module_doc": "This module supports asynchronous I/O on multiple file descriptors.\n"
             "\n"
             "*** IMPORTANT NOTICE ***\n"
             "On Windows, only sockets are supported; on Unix, all file descriptors.",
             "devpoll_getsetlist_closed_doc": "True if the devpoll object is closed",
             "pyepoll_getsetlist_closed_doc": "True if the epoll handler is closed",
             "kqueue_queue_getsetlist_closed_doc": "True if the kqueue handler is closed"
         }
     );
