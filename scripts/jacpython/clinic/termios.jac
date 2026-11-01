"""The Argument Clinic signatures of termios.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/termios.jac from them. Taken from
the C sources it replaces (Modules/termios.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="termios",
         version="3.14.6",
         sources=["Modules/termios.c"],
         functions=[
             Function(
                 name="tcgetattr",
                 full_name="termios.tcgetattr",
                 c_basename="termios_tcgetattr",
                 docstring="tcgetattr($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Get the tty attributes for file descriptor fd.\n"
                 "\n"
                 "Returns a list [iflag, oflag, cflag, lflag, ispeed, ospeed, cc]\n"
                 "where cc is a list of the tty special characters (each a string of\n"
                 "length 1, except the items with indices VMIN and VTIME, which are\n"
                 "integers when these fields are defined).  The interpretation of the\n"
                 "flags and the speeds as well as the indexing in the cc array must be\n"
                 "done using the symbolic constants defined in this module.",
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
                 pos_only=1,
                 limited_capi=True
             ),
             Function(
                 name="tcsetattr",
                 full_name="termios.tcsetattr",
                 c_basename="termios_tcsetattr",
                 docstring="tcsetattr($module, fd, when, attributes, /)\n"
                 "--\n"
                 "\n"
                 "Set the tty attributes for file descriptor fd.\n"
                 "\n"
                 "The attributes to be set are taken from the attributes argument, which\n"
                 "is a list like the one returned by tcgetattr(). The when argument\n"
                 "determines when the attributes are changed: termios.TCSANOW to\n"
                 "change immediately, termios.TCSADRAIN to change after transmitting all\n"
                 "queued output, or termios.TCSAFLUSH to change after transmitting all\n"
                 "queued output and discarding all queued input.",
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
                         name="when",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="attributes", kind="POSITIONAL_ONLY", format_unit="O"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3,
                 limited_capi=True
             ),
             Function(
                 name="tcsendbreak",
                 full_name="termios.tcsendbreak",
                 c_basename="termios_tcsendbreak",
                 docstring="tcsendbreak($module, fd, duration, /)\n"
                 "--\n"
                 "\n"
                 "Send a break on file descriptor fd.\n"
                 "\n"
                 "A zero duration sends a break for 0.25-0.5 seconds; a nonzero duration\n"
                 "has a system dependent meaning.",
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
                         name="duration",
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
                 name="tcdrain",
                 full_name="termios.tcdrain",
                 c_basename="termios_tcdrain",
                 docstring="tcdrain($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Wait until all output written to file descriptor fd has been transmitted.",
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
                 pos_only=1,
                 limited_capi=True
             ),
             Function(
                 name="tcflush",
                 full_name="termios.tcflush",
                 c_basename="termios_tcflush",
                 docstring="tcflush($module, fd, queue, /)\n"
                 "--\n"
                 "\n"
                 "Discard queued data on file descriptor fd.\n"
                 "\n"
                 "The queue selector specifies which queue: termios.TCIFLUSH for the input\n"
                 "queue, termios.TCOFLUSH for the output queue, or termios.TCIOFLUSH for\n"
                 "both queues.",
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
                         name="queue",
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
                 name="tcflow",
                 full_name="termios.tcflow",
                 c_basename="termios_tcflow",
                 docstring="tcflow($module, fd, action, /)\n"
                 "--\n"
                 "\n"
                 "Suspend or resume input or output on file descriptor fd.\n"
                 "\n"
                 "The action argument can be termios.TCOOFF to suspend output,\n"
                 "termios.TCOON to restart output, termios.TCIOFF to suspend input,\n"
                 "or termios.TCION to restart input.",
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
                         name="action",
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
                 name="tcgetwinsize",
                 full_name="termios.tcgetwinsize",
                 c_basename="termios_tcgetwinsize",
                 docstring="tcgetwinsize($module, fd, /)\n"
                 "--\n"
                 "\n"
                 "Get the tty winsize for file descriptor fd.\n"
                 "\n"
                 "Returns a tuple (ws_row, ws_col).",
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
                 pos_only=1,
                 limited_capi=True
             ),
             Function(
                 name="tcsetwinsize",
                 full_name="termios.tcsetwinsize",
                 c_basename="termios_tcsetwinsize",
                 docstring="tcsetwinsize($module, fd, winsize, /)\n"
                 "--\n"
                 "\n"
                 "Set the tty winsize for file descriptor fd.\n"
                 "\n"
                 "The winsize to be set is taken from the winsize argument, which\n"
                 "is a two-item tuple (ws_row, ws_col) like the one returned by\n"
                 "tcgetwinsize().",
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
                     Parameter(name="winsize", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 limited_capi=True
             )
         ],
         docs={
             "termios__doc__": "This module provides an interface to the Posix calls for tty I/O control.\n"
             "For a complete description of these calls, see the Posix or Unix manual\n"
             "pages. It is only available for those Unix versions that support Posix\n"
             "termios style tty I/O control.\n"
             "\n"
             "All functions in this module take a file descriptor fd as their first\n"
             "argument. This can be an integer file descriptor, such as returned by\n"
             "sys.stdin.fileno(), or a file object, such as sys.stdin itself."
         }
     );
