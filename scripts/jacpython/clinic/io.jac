"""The Argument Clinic signatures of _io.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/io.jac from them. Taken from
the C sources it replaces (Modules/_io/_iomodule.c, Modules/_io/iobase.c, Modules/_io/fileio.c, Modules/_io/bytesio.c, Modules/_io/bufferedio.c, Modules/_io/textio.c, Modules/_io/stringio.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_io",
         version="3.14.6",
         sources=[
             "Modules/_io/_iomodule.c",
             "Modules/_io/iobase.c",
             "Modules/_io/fileio.c",
             "Modules/_io/bytesio.c",
             "Modules/_io/bufferedio.c",
             "Modules/_io/textio.c",
             "Modules/_io/stringio.c"
         ],
         classes={
             "_IOBase": "PyObject *",
             "_RawIOBase": "PyObject *",
             "FileIO": "fileio *",
             "BytesIO": "bytesio *",
             "_BufferedIOBase": "PyObject *",
             "_Buffered": "buffered *",
             "BufferedReader": "buffered *",
             "BufferedWriter": "buffered *",
             "BufferedRWPair": "rwpair *",
             "BufferedRandom": "buffered *",
             "IncrementalNewlineDecoder": "nldecoder_object *",
             "TextIOWrapper": "textio *",
             "_TextIOBase": "PyObject *",
             "StringIO": "stringio *"
         },
         functions=[
             Function(
                 name="open",
                 full_name="_io.open",
                 c_basename="_io_open",
                 docstring="open($module, /, file, mode='r', buffering=-1, encoding=None,\n"
                 "     errors=None, newline=None, closefd=True, opener=None)\n"
                 "--\n"
                 "\n"
                 "Open file and return a stream.  Raise OSError upon failure.\n"
                 "\n"
                 "file is either a text or byte string giving the name (and the path\n"
                 "if the file isn't in the current working directory) of the file to\n"
                 "be opened or an integer file descriptor of the file to be\n"
                 "wrapped.  (If a file descriptor is given, it is closed when the\n"
                 "returned I/O object is closed, unless closefd is set to False.)\n"
                 "\n"
                 "mode is an optional string that specifies the mode in which the file\n"
                 "is opened.  It defaults to 'r' which means open for reading in text\n"
                 "mode.  Other common values are 'w' for writing (truncating the file if\n"
                 "it already exists), 'x' for creating and writing to a new file, and\n"
                 "'a' for appending (which on some Unix systems, means that all writes\n"
                 "append to the end of the file regardless of the current seek position).\n"
                 "In text mode, if encoding is not specified the encoding used is platform\n"
                 "dependent: locale.getencoding() is called to get the current locale\n"
                 "encoding.  (For reading and writing raw bytes use binary mode and leave\n"
                 "encoding unspecified.)  The available modes are:\n"
                 "\n"
                 "========= ==========================================================\n"
                 "Character Meaning\n"
                 "--------- ----------------------------------------------------------\n"
                 "'r'       open for reading (default)\n"
                 "'w'       open for writing, truncating the file first\n"
                 "'x'       create a new file and open it for writing\n"
                 "'a'       open for writing, appending to the end of the file if it\n"
                 "          exists\n"
                 "'b'       binary mode\n"
                 "'t'       text mode (default)\n"
                 "'+'       open a disk file for updating (reading and writing)\n"
                 "========= ==========================================================\n"
                 "\n"
                 "The default mode is 'rt' (open for reading text).  For binary random\n"
                 "access, the mode 'w+b' opens and truncates the file to 0 bytes, while\n"
                 "'r+b' opens the file without truncation.  The 'x' mode implies 'w' and\n"
                 "raises an `FileExistsError` if the file already exists.\n"
                 "\n"
                 "Python distinguishes between files opened in binary and text modes,\n"
                 "even when the underlying operating system doesn't.  Files opened in\n"
                 "binary mode (appending 'b' to the mode argument) return contents as\n"
                 "bytes objects without any decoding.  In text mode (the default, or when\n"
                 "'t' is appended to the mode argument), the contents of the file are\n"
                 "returned as strings, the bytes having been first decoded using a\n"
                 "platform-dependent encoding or using the specified encoding if given.\n"
                 "\n"
                 "buffering is an optional integer used to set the buffering policy.\n"
                 "Pass 0 to switch buffering off (only allowed in binary mode), 1 to\n"
                 "select line buffering (only usable in text mode), and an integer > 1 to\n"
                 "indicate the size of a fixed-size chunk buffer.   When no buffering\n"
                 "argument is given, the default buffering policy works as follows:\n"
                 "\n"
                 "* Binary files are buffered in fixed-size chunks; the size of the buffer\n"
                 "  is max(min(blocksize, 8 MiB), DEFAULT_BUFFER_SIZE) when the device\n"
                 "  block size is available.\n"
                 "  On most systems, the buffer will typically be 128 kilobytes long.\n"
                 "\n"
                 "* \"Interactive\" text files (files for which isatty() returns True)\n"
                 "  use line buffering.  Other text files use the policy described above\n"
                 "  for binary files.\n"
                 "\n"
                 "encoding is the name of the encoding used to decode or encode the\n"
                 "file.  This should only be used in text mode.  The default encoding is\n"
                 "platform dependent, but any encoding supported by Python can be\n"
                 "passed.  See the codecs module for the list of supported encodings.\n"
                 "\n"
                 "errors is an optional string that specifies how encoding errors are to\n"
                 "be handled---this argument should not be used in binary mode.  Pass\n"
                 "'strict' to raise a ValueError exception if there is an encoding error\n"
                 "(the default of None has the same effect), or pass 'ignore' to ignore\n"
                 "errors.  (Note that ignoring encoding errors can lead to data loss.)\n"
                 "See the documentation for codecs.register or run 'help(codecs.Codec)'\n"
                 "for a list of the permitted encoding error strings.\n"
                 "\n"
                 "newline controls how universal newlines works (it only applies to text\n"
                 "mode).  It can be None, '', '\\n', '\\r', and '\\r\\n'.  It works as\n"
                 "follows:\n"
                 "\n"
                 "* On input, if newline is None, universal newlines mode is enabled.\n"
                 "  Lines in the input can end in '\\n', '\\r', or '\\r\\n', and these are\n"
                 "  translated into '\\n' before being returned to the caller.  If it is\n"
                 "  '', universal newline mode is enabled, but line endings are returned\n"
                 "  to the caller untranslated.  If it has any of the other legal values,\n"
                 "  input lines are only terminated by the given string, and the line\n"
                 "  ending is returned to the caller untranslated.\n"
                 "\n"
                 "* On output, if newline is None, any '\\n' characters written are\n"
                 "  translated to the system default line separator, os.linesep.  If\n"
                 "  newline is '' or '\\n', no translation takes place.  If newline is any\n"
                 "  of the other legal values, any '\\n' characters written are translated\n"
                 "  to the given string.\n"
                 "\n"
                 "If closefd is False, the underlying file descriptor will be kept open\n"
                 "when the file is closed.  This does not work when a file name is given\n"
                 "and must be True in that case.\n"
                 "\n"
                 "A custom opener can be used by passing a callable as *opener*.  The\n"
                 "underlying file descriptor for the file object is then obtained by\n"
                 "calling *opener* with (*file*, *flags*).  *opener* must return an open\n"
                 "file descriptor (passing os.open as *opener* results in functionality\n"
                 "similar to passing None).\n"
                 "\n"
                 "open() returns a file object whose type depends on the mode, and\n"
                 "through which the standard file operations such as reading and writing\n"
                 "are performed.  When open() is used to open a file in a text mode ('w',\n"
                 "'r', 'wt', 'rt', etc.), it returns a TextIOWrapper.  When used to open\n"
                 "a file in a binary mode, the returned class varies: in read binary\n"
                 "mode, it returns a BufferedReader; in write binary and append binary\n"
                 "modes, it returns a BufferedWriter, and in read/write mode, it returns\n"
                 "a BufferedRandom.\n"
                 "\n"
                 "It is also possible to use a string or bytearray as a file for both\n"
                 "reading and writing.  For strings StringIO can be used like a file\n"
                 "opened in a text mode, and for bytes a BytesIO can be used like a file\n"
                 "opened in a binary mode.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="file", format_unit="O"),
                     Parameter(
                         name="mode",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="r",
                         c_default="\"r\""
                     ),
                     Parameter(
                         name="buffering",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     ),
                     Parameter(
                         name="encoding",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="errors",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="newline",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="closefd",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="opener",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=8
             ),
             Function(
                 name="text_encoding",
                 full_name="_io.text_encoding",
                 c_basename="_io_text_encoding",
                 docstring="text_encoding($module, encoding, stacklevel=2, /)\n"
                 "--\n"
                 "\n"
                 "A helper function to choose the text encoding.\n"
                 "\n"
                 "When encoding is not None, this function returns it.\n"
                 "Otherwise, this function returns the default text encoding\n"
                 "(i.e. \"locale\" or \"utf-8\" depends on UTF-8 mode).\n"
                 "\n"
                 "This function emits an EncodingWarning if encoding is None and\n"
                 "sys.flags.warn_default_encoding is true.\n"
                 "\n"
                 "This can be used in APIs with an encoding=None parameter.\n"
                 "However, please consider using encoding=\"utf-8\" for new APIs.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="encoding", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="stacklevel",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=2,
                         c_default="2"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="open_code",
                 full_name="_io.open_code",
                 c_basename="_io_open_code",
                 docstring="open_code($module, /, path)\n"
                 "--\n"
                 "\n"
                 "Opens the provided file with the intent to import the contents.\n"
                 "\n"
                 "This may perform extra validation beyond open(), but is otherwise\n"
                 "interchangeable with calling open(path, 'rb').",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="path", converter="unicode", format_unit="U")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="seek",
                 full_name="_io._IOBase.seek",
                 c_basename="_io__IOBase_seek",
                 cls="_IOBase",
                 docstring="seek($self, offset, whence=os.SEEK_SET, /)\n"
                 "--\n"
                 "\n"
                 "Change the stream position to the given byte offset.\n"
                 "\n"
                 "  offset\n"
                 "    The stream position, relative to 'whence'.\n"
                 "  whence\n"
                 "    The relative position to seek from.\n"
                 "\n"
                 "The offset is interpreted relative to the position indicated by\n"
                 "whence.  Values for whence are:\n"
                 "\n"
                 "* os.SEEK_SET or 0 -- start of stream (the default); offset should\n"
                 "  be zero or positive\n"
                 "* os.SEEK_CUR or 1 -- current stream position; offset may be\n"
                 "  negative\n"
                 "* os.SEEK_END or 2 -- end of stream; offset is usually negative\n"
                 "\n"
                 "Return the new absolute position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="offset",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="whence",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="tell",
                 full_name="_io._IOBase.tell",
                 c_basename="_io__IOBase_tell",
                 cls="_IOBase",
                 docstring="tell($self, /)\n"
                 "--\n"
                 "\n"
                 "Return current stream position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="truncate",
                 full_name="_io._IOBase.truncate",
                 c_basename="_io__IOBase_truncate",
                 cls="_IOBase",
                 docstring="truncate($self, size=None, /)\n"
                 "--\n"
                 "\n"
                 "Truncate file to size bytes.\n"
                 "\n"
                 "File pointer is left unchanged.  Size defaults to the current IO\n"
                 "position as reported by tell().  Return the new size.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="flush",
                 full_name="_io._IOBase.flush",
                 c_basename="_io__IOBase_flush",
                 cls="_IOBase",
                 docstring="flush($self, /)\n"
                 "--\n"
                 "\n"
                 "Flush write buffers, if applicable.\n"
                 "\n"
                 "This is not implemented for read-only and non-blocking streams.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="close",
                 full_name="_io._IOBase.close",
                 c_basename="_io__IOBase_close",
                 cls="_IOBase",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Flush and close the IO object.\n"
                 "\n"
                 "This method has no effect if the file is already closed.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seekable",
                 full_name="_io._IOBase.seekable",
                 c_basename="_io__IOBase_seekable",
                 cls="_IOBase",
                 docstring="seekable($self, /)\n"
                 "--\n"
                 "\n"
                 "Return whether object supports random access.\n"
                 "\n"
                 "If False, seek(), tell() and truncate() will raise OSError.\n"
                 "This method may need to do a test seek().",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readable",
                 full_name="_io._IOBase.readable",
                 c_basename="_io__IOBase_readable",
                 cls="_IOBase",
                 docstring="readable($self, /)\n"
                 "--\n"
                 "\n"
                 "Return whether object was opened for reading.\n"
                 "\n"
                 "If False, read() will raise OSError.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="writable",
                 full_name="_io._IOBase.writable",
                 c_basename="_io__IOBase_writable",
                 cls="_IOBase",
                 docstring="writable($self, /)\n"
                 "--\n"
                 "\n"
                 "Return whether object was opened for writing.\n"
                 "\n"
                 "If False, write() will raise OSError.",
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
                 full_name="_io._IOBase.fileno",
                 c_basename="_io__IOBase_fileno",
                 cls="_IOBase",
                 docstring="fileno($self, /)\n"
                 "--\n"
                 "\n"
                 "Return underlying file descriptor if one exists.\n"
                 "\n"
                 "Raise OSError if the IO object does not use a file descriptor.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="isatty",
                 full_name="_io._IOBase.isatty",
                 c_basename="_io__IOBase_isatty",
                 cls="_IOBase",
                 docstring="isatty($self, /)\n"
                 "--\n"
                 "\n"
                 "Return whether this is an 'interactive' stream.\n"
                 "\n"
                 "Return False if it can't be determined.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readline",
                 full_name="_io._IOBase.readline",
                 c_basename="_io__IOBase_readline",
                 cls="_IOBase",
                 docstring="readline($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read and return a line from the stream.\n"
                 "\n"
                 "If size is specified, at most size bytes will be read.\n"
                 "\n"
                 "The line terminator is always b'\\n' for binary files; for text\n"
                 "files, the newlines argument to open can be used to select the line\n"
                 "terminator(s) recognized.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readlines",
                 full_name="_io._IOBase.readlines",
                 c_basename="_io__IOBase_readlines",
                 cls="_IOBase",
                 docstring="readlines($self, hint=-1, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of lines from the stream.\n"
                 "\n"
                 "hint can be specified to control the number of lines read: no more\n"
                 "lines will be read if the total size (in bytes/characters) of all\n"
                 "lines so far exceeds hint.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="hint",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="writelines",
                 full_name="_io._IOBase.writelines",
                 c_basename="_io__IOBase_writelines",
                 cls="_IOBase",
                 docstring="writelines($self, lines, /)\n"
                 "--\n"
                 "\n"
                 "Write a list of lines to stream.\n"
                 "\n"
                 "Line separators are not added, so it is usual for each of the\n"
                 "lines provided to have a line separator at the end.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="lines", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="read",
                 full_name="_io._RawIOBase.read",
                 c_basename="_io__RawIOBase_read",
                 cls="_RawIOBase",
                 docstring="read($self, size=-1, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readall",
                 full_name="_io._RawIOBase.readall",
                 c_basename="_io__RawIOBase_readall",
                 cls="_RawIOBase",
                 docstring="readall($self, /)\n"
                 "--\n"
                 "\n"
                 "Read until EOF, using multiple read() call.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="close",
                 full_name="_io.FileIO.close",
                 c_basename="_io_FileIO_close",
                 cls="FileIO",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Close the file.\n"
                 "\n"
                 "A closed file cannot be used for further I/O operations.  close()\n"
                 "may be called more than once without error.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="__init__",
                 full_name="_io.FileIO.__init__",
                 c_basename="_io_FileIO___init__",
                 kind="METHOD_INIT",
                 cls="FileIO",
                 docstring="FileIO(file, mode='r', closefd=True, opener=None)\n"
                 "--\n"
                 "\n"
                 "Open a file.\n"
                 "\n"
                 "The mode can be 'r' (default), 'w', 'x' or 'a' for reading,\n"
                 "writing, exclusive creation or appending.  The file will be created\n"
                 "if it doesn't exist when opened for writing or appending; it will be\n"
                 "truncated when opened for writing.  A FileExistsError will be raised\n"
                 "if it already exists when opened for creating.  Opening a file for\n"
                 "creating implies writing so this mode behaves in a similar way to\n"
                 "'w'.  Add a '+' to the mode to allow simultaneous reading and\n"
                 "writing.\n"
                 "\n"
                 "A custom opener can be used by passing a callable as *opener*.\n"
                 "The underlying file descriptor for the file object is then obtained\n"
                 "by calling opener with (*name*, *flags*).  *opener* must return\n"
                 "an open file descriptor (passing os.open as *opener* results in\n"
                 "functionality similar to passing None).",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="file", format_unit="O"),
                     Parameter(
                         name="mode",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="r",
                         c_default="\"r\""
                     ),
                     Parameter(
                         name="closefd",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="opener",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=4
             ),
             Function(
                 name="fileno",
                 full_name="_io.FileIO.fileno",
                 c_basename="_io_FileIO_fileno",
                 cls="FileIO",
                 docstring="fileno($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the underlying file descriptor (an integer).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readable",
                 full_name="_io.FileIO.readable",
                 c_basename="_io_FileIO_readable",
                 cls="FileIO",
                 docstring="readable($self, /)\n"
                 "--\n"
                 "\n"
                 "True if file was opened in a read mode.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="writable",
                 full_name="_io.FileIO.writable",
                 c_basename="_io_FileIO_writable",
                 cls="FileIO",
                 docstring="writable($self, /)\n"
                 "--\n"
                 "\n"
                 "True if file was opened in a write mode.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seekable",
                 full_name="_io.FileIO.seekable",
                 c_basename="_io_FileIO_seekable",
                 cls="FileIO",
                 docstring="seekable($self, /)\n"
                 "--\n"
                 "\n"
                 "True if file supports random-access.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readinto",
                 full_name="_io.FileIO.readinto",
                 c_basename="_io_FileIO_readinto",
                 cls="FileIO",
                 docstring="readinto($self, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Same as RawIOBase.readinto().",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
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
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readall",
                 full_name="_io.FileIO.readall",
                 c_basename="_io_FileIO_readall",
                 cls="FileIO",
                 docstring="readall($self, /)\n"
                 "--\n"
                 "\n"
                 "Read all data from the file, returned as bytes.\n"
                 "\n"
                 "Reads until either there is an error or read() returns size 0\n"
                 "(indicates EOF).  If the file is already at EOF, returns an empty\n"
                 "bytes object.\n"
                 "\n"
                 "In non-blocking mode, returns as much data as could be read before\n"
                 "EAGAIN.  If no data is available (EAGAIN is returned before bytes\n"
                 "are read) returns None.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="read",
                 full_name="_io.FileIO.read",
                 c_basename="_io_FileIO_read",
                 cls="FileIO",
                 docstring="read($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read at most size bytes, returned as bytes.\n"
                 "\n"
                 "If size is less than 0, read all bytes in the file making multiple\n"
                 "read calls.  See ``FileIO.readall``.\n"
                 "\n"
                 "Attempts to make only one system call, retrying only per PEP 475\n"
                 "(EINTR).  This means less data may be returned than requested.\n"
                 "\n"
                 "In non-blocking mode, returns None if no data is available.  Return\n"
                 "an empty bytes object at EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="write",
                 full_name="_io.FileIO.write",
                 c_basename="_io_FileIO_write",
                 cls="FileIO",
                 docstring="write($self, b, /)\n"
                 "--\n"
                 "\n"
                 "Write buffer b to file, return number of bytes written.\n"
                 "\n"
                 "Only makes one system call, so not all of the data may be written.\n"
                 "The number of bytes actually written is returned.  In non-blocking\n"
                 "mode, returns None if the write would block.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="b",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="seek",
                 full_name="_io.FileIO.seek",
                 c_basename="_io_FileIO_seek",
                 cls="FileIO",
                 docstring="seek($self, pos, whence=0, /)\n"
                 "--\n"
                 "\n"
                 "Move to new file position and return the file position.\n"
                 "\n"
                 "Argument offset is a byte count.  Optional argument whence defaults\n"
                 "to SEEK_SET or 0 (offset from start of file, offset should be >= 0);\n"
                 "other values are SEEK_CUR or 1 (move relative to current position,\n"
                 "positive or negative), and SEEK_END or 2 (move relative to end of\n"
                 "file, usually negative, although many platforms allow seeking beyond\n"
                 "the end of a file).\n"
                 "\n"
                 "Note that not all file objects are seekable.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="pos", kind="POSITIONAL_ONLY", format_unit="O"),
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
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="tell",
                 full_name="_io.FileIO.tell",
                 c_basename="_io_FileIO_tell",
                 cls="FileIO",
                 docstring="tell($self, /)\n"
                 "--\n"
                 "\n"
                 "Current file position.\n"
                 "\n"
                 "Can raise OSError for non seekable files.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="truncate",
                 full_name="_io.FileIO.truncate",
                 c_basename="_io_FileIO_truncate",
                 cls="FileIO",
                 docstring="truncate($self, size=None, /)\n"
                 "--\n"
                 "\n"
                 "Truncate the file to at most size bytes and return the truncated size.\n"
                 "\n"
                 "Size defaults to the current file position, as returned by tell().\n"
                 "The current file position is changed to the value of size.",
                 condition="defined(HAVE_FTRUNCATE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="isatty",
                 full_name="_io.FileIO.isatty",
                 c_basename="_io_FileIO_isatty",
                 cls="FileIO",
                 docstring="isatty($self, /)\n"
                 "--\n"
                 "\n"
                 "True if the file is connected to a TTY device.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readable",
                 full_name="_io.BytesIO.readable",
                 c_basename="_io_BytesIO_readable",
                 cls="BytesIO",
                 docstring="readable($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the IO object can be read.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="writable",
                 full_name="_io.BytesIO.writable",
                 c_basename="_io_BytesIO_writable",
                 cls="BytesIO",
                 docstring="writable($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the IO object can be written.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seekable",
                 full_name="_io.BytesIO.seekable",
                 c_basename="_io_BytesIO_seekable",
                 cls="BytesIO",
                 docstring="seekable($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the IO object can be seeked.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="flush",
                 full_name="_io.BytesIO.flush",
                 c_basename="_io_BytesIO_flush",
                 cls="BytesIO",
                 docstring="flush($self, /)\n" "--\n" "\n" "Does nothing.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getbuffer",
                 full_name="_io.BytesIO.getbuffer",
                 c_basename="_io_BytesIO_getbuffer",
                 cls="BytesIO",
                 docstring="getbuffer($self, /)\n"
                 "--\n"
                 "\n"
                 "Get a read-write view over the contents of the BytesIO object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="getvalue",
                 full_name="_io.BytesIO.getvalue",
                 c_basename="_io_BytesIO_getvalue",
                 cls="BytesIO",
                 docstring="getvalue($self, /)\n"
                 "--\n"
                 "\n"
                 "Retrieve the entire contents of the BytesIO object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="isatty",
                 full_name="_io.BytesIO.isatty",
                 c_basename="_io_BytesIO_isatty",
                 cls="BytesIO",
                 docstring="isatty($self, /)\n"
                 "--\n"
                 "\n"
                 "Always returns False.\n"
                 "\n"
                 "BytesIO objects are not connected to a TTY-like device.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="tell",
                 full_name="_io.BytesIO.tell",
                 c_basename="_io_BytesIO_tell",
                 cls="BytesIO",
                 docstring="tell($self, /)\n"
                 "--\n"
                 "\n"
                 "Current file position, an integer.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="read",
                 full_name="_io.BytesIO.read",
                 c_basename="_io_BytesIO_read",
                 cls="BytesIO",
                 docstring="read($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read at most size bytes, returned as a bytes object.\n"
                 "\n"
                 "If the size argument is negative, read until EOF is reached.\n"
                 "Return an empty bytes object at EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="read1",
                 full_name="_io.BytesIO.read1",
                 c_basename="_io_BytesIO_read1",
                 cls="BytesIO",
                 docstring="read1($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read at most size bytes, returned as a bytes object.\n"
                 "\n"
                 "If the size argument is negative or omitted, read until EOF is\n"
                 "reached.  Return an empty bytes object at EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readline",
                 full_name="_io.BytesIO.readline",
                 c_basename="_io_BytesIO_readline",
                 cls="BytesIO",
                 docstring="readline($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Next line from the file, as a bytes object.\n"
                 "\n"
                 "Retain newline.  A non-negative size argument limits the maximum\n"
                 "number of bytes to return (an incomplete line may be returned then).\n"
                 "Return an empty bytes object at EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readlines",
                 full_name="_io.BytesIO.readlines",
                 c_basename="_io_BytesIO_readlines",
                 cls="BytesIO",
                 docstring="readlines($self, size=None, /)\n"
                 "--\n"
                 "\n"
                 "List of bytes objects, each a line from the file.\n"
                 "\n"
                 "Call readline() repeatedly and return a list of the lines so read.\n"
                 "The optional size argument, if given, is an approximate bound on the\n"
                 "total number of bytes in the lines returned.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
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
                 name="readinto",
                 full_name="_io.BytesIO.readinto",
                 c_basename="_io_BytesIO_readinto",
                 cls="BytesIO",
                 docstring="readinto($self, buffer, /)\n"
                 "--\n"
                 "\n"
                 "Read bytes into buffer.\n"
                 "\n"
                 "Returns number of bytes read (0 for EOF), or None if the object\n"
                 "is set not to block and has no data to read.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="truncate",
                 full_name="_io.BytesIO.truncate",
                 c_basename="_io_BytesIO_truncate",
                 cls="BytesIO",
                 docstring="truncate($self, size=None, /)\n"
                 "--\n"
                 "\n"
                 "Truncate the file to at most size bytes.\n"
                 "\n"
                 "Size defaults to the current file position, as returned by tell().\n"
                 "The current file position is unchanged.  Returns the new size.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
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
                 name="seek",
                 full_name="_io.BytesIO.seek",
                 c_basename="_io_BytesIO_seek",
                 cls="BytesIO",
                 docstring="seek($self, pos, whence=0, /)\n"
                 "--\n"
                 "\n"
                 "Change stream position.\n"
                 "\n"
                 "Seek to byte offset pos relative to position indicated by whence:\n"
                 "     0  Start of stream (the default).  pos should be >= 0;\n"
                 "     1  Current position - pos may be negative;\n"
                 "     2  End of stream - pos usually negative.\n"
                 "Returns the new absolute position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="pos",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
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
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="write",
                 full_name="_io.BytesIO.write",
                 c_basename="_io_BytesIO_write",
                 cls="BytesIO",
                 docstring="write($self, b, /)\n"
                 "--\n"
                 "\n"
                 "Write bytes to file.\n"
                 "\n"
                 "Return the number of bytes written.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="writelines",
                 full_name="_io.BytesIO.writelines",
                 c_basename="_io_BytesIO_writelines",
                 cls="BytesIO",
                 docstring="writelines($self, lines, /)\n"
                 "--\n"
                 "\n"
                 "Write lines to the file.\n"
                 "\n"
                 "Note that newlines are not added.  lines can be any iterable object\n"
                 "producing bytes-like objects.  This is equivalent to calling write()\n"
                 "for each element.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="lines", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="close",
                 full_name="_io.BytesIO.close",
                 c_basename="_io_BytesIO_close",
                 cls="BytesIO",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Disable all I/O operations.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__init__",
                 full_name="_io.BytesIO.__init__",
                 c_basename="_io_BytesIO___init__",
                 kind="METHOD_INIT",
                 cls="BytesIO",
                 docstring="BytesIO(initial_bytes=b'')\n"
                 "--\n"
                 "\n"
                 "Buffered I/O implementation using an in-memory bytes buffer.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="initial_bytes",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="readinto",
                 full_name="_io._BufferedIOBase.readinto",
                 c_basename="_io__BufferedIOBase_readinto",
                 cls="_BufferedIOBase",
                 docstring="readinto($self, buffer, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readinto1",
                 full_name="_io._BufferedIOBase.readinto1",
                 c_basename="_io__BufferedIOBase_readinto1",
                 cls="_BufferedIOBase",
                 docstring="readinto1($self, buffer, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="detach",
                 full_name="_io._BufferedIOBase.detach",
                 c_basename="_io__BufferedIOBase_detach",
                 cls="_BufferedIOBase",
                 docstring="detach($self, /)\n"
                 "--\n"
                 "\n"
                 "Disconnect this buffer from its underlying raw stream and return it.\n"
                 "\n"
                 "After the raw stream has been detached, the buffer is in an unusable\n"
                 "state.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="read",
                 full_name="_io._BufferedIOBase.read",
                 c_basename="_io__BufferedIOBase_read",
                 cls="_BufferedIOBase",
                 docstring="read($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read and return up to n bytes.\n"
                 "\n"
                 "If the size argument is omitted, None, or negative, read and\n"
                 "return all data until EOF.\n"
                 "\n"
                 "If the size argument is positive, and the underlying raw stream is\n"
                 "not 'interactive', multiple raw reads may be issued to satisfy\n"
                 "the byte count (unless EOF is reached first).\n"
                 "However, for interactive raw streams (as well as sockets and pipes),\n"
                 "at most one raw read will be issued, and a short result does not\n"
                 "imply that EOF is imminent.\n"
                 "\n"
                 "Return an empty bytes object on EOF.\n"
                 "\n"
                 "Return None if the underlying raw stream was open in non-blocking\n"
                 "mode and no data is available at the moment.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="read1",
                 full_name="_io._BufferedIOBase.read1",
                 c_basename="_io__BufferedIOBase_read1",
                 cls="_BufferedIOBase",
                 docstring="read1($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read and return up to size bytes, with at most one read() call to the underlying raw stream.\n"
                 "\n"
                 "Return an empty bytes object on EOF.\n"
                 "A short result does not imply that EOF is imminent.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="write",
                 full_name="_io._BufferedIOBase.write",
                 c_basename="_io__BufferedIOBase_write",
                 cls="_BufferedIOBase",
                 docstring="write($self, b, /)\n"
                 "--\n"
                 "\n"
                 "Write buffer b to the IO stream.\n"
                 "\n"
                 "Return the number of bytes written, which is always\n"
                 "the length of b in bytes.\n"
                 "\n"
                 "Raise BlockingIOError if the buffer is full and the\n"
                 "underlying raw stream cannot accept more data at the moment.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__sizeof__",
                 full_name="_io._Buffered.__sizeof__",
                 c_basename="_io__Buffered___sizeof__",
                 cls="_Buffered",
                 docstring="__sizeof__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_dealloc_warn",
                 full_name="_io._Buffered._dealloc_warn",
                 c_basename="_io__Buffered__dealloc_warn",
                 cls="_Buffered",
                 docstring="_dealloc_warn($self, source, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="source", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="flush",
                 full_name="_io._Buffered.flush",
                 c_basename="_io__Buffered_simple_flush",
                 cls="_Buffered",
                 docstring="flush($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="closed",
                 full_name="_io._Buffered.closed",
                 c_basename="_io__Buffered_closed",
                 kind="GETTER",
                 cls="_Buffered",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="close",
                 full_name="_io._Buffered.close",
                 c_basename="_io__Buffered_close",
                 cls="_Buffered",
                 docstring="close($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="detach",
                 full_name="_io._Buffered.detach",
                 c_basename="_io__Buffered_detach",
                 cls="_Buffered",
                 docstring="detach($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seekable",
                 full_name="_io._Buffered.seekable",
                 c_basename="_io__Buffered_seekable",
                 cls="_Buffered",
                 docstring="seekable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readable",
                 full_name="_io._Buffered.readable",
                 c_basename="_io__Buffered_readable",
                 cls="_Buffered",
                 docstring="readable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="writable",
                 full_name="_io._Buffered.writable",
                 c_basename="_io__Buffered_writable",
                 cls="_Buffered",
                 docstring="writable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="name",
                 full_name="_io._Buffered.name",
                 c_basename="_io__Buffered_name",
                 kind="GETTER",
                 cls="_Buffered",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="mode",
                 full_name="_io._Buffered.mode",
                 c_basename="_io__Buffered_mode",
                 kind="GETTER",
                 cls="_Buffered",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="fileno",
                 full_name="_io._Buffered.fileno",
                 c_basename="_io__Buffered_fileno",
                 cls="_Buffered",
                 docstring="fileno($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="isatty",
                 full_name="_io._Buffered.isatty",
                 c_basename="_io__Buffered_isatty",
                 cls="_Buffered",
                 docstring="isatty($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="flush",
                 full_name="_io._Buffered.flush",
                 c_basename="_io__Buffered_flush",
                 cls="_Buffered",
                 docstring="flush($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="peek",
                 full_name="_io._Buffered.peek",
                 c_basename="_io__Buffered_peek",
                 cls="_Buffered",
                 docstring="peek($self, size=0, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="read",
                 full_name="_io._Buffered.read",
                 c_basename="_io__Buffered_read",
                 cls="_Buffered",
                 docstring="read($self, size=-1, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="read1",
                 full_name="_io._Buffered.read1",
                 c_basename="_io__Buffered_read1",
                 cls="_Buffered",
                 docstring="read1($self, size=-1, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readinto",
                 full_name="_io._Buffered.readinto",
                 c_basename="_io__Buffered_readinto",
                 cls="_Buffered",
                 docstring="readinto($self, buffer, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readinto1",
                 full_name="_io._Buffered.readinto1",
                 c_basename="_io__Buffered_readinto1",
                 cls="_Buffered",
                 docstring="readinto1($self, buffer, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readline",
                 full_name="_io._Buffered.readline",
                 c_basename="_io__Buffered_readline",
                 cls="_Buffered",
                 docstring="readline($self, size=-1, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="tell",
                 full_name="_io._Buffered.tell",
                 c_basename="_io__Buffered_tell",
                 cls="_Buffered",
                 docstring="tell($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seek",
                 full_name="_io._Buffered.seek",
                 c_basename="_io__Buffered_seek",
                 cls="_Buffered",
                 docstring="seek($self, target, whence=0, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="target", kind="POSITIONAL_ONLY", format_unit="O"),
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
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="truncate",
                 full_name="_io._Buffered.truncate",
                 c_basename="_io__Buffered_truncate",
                 cls="_Buffered",
                 docstring="truncate($self, pos=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="pos",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__init__",
                 full_name="_io.BufferedReader.__init__",
                 c_basename="_io_BufferedReader___init__",
                 kind="METHOD_INIT",
                 cls="BufferedReader",
                 docstring="BufferedReader(raw, buffer_size=DEFAULT_BUFFER_SIZE)\n"
                 "--\n"
                 "\n"
                 "Create a new buffered reader using the given readable raw IO object.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="raw", format_unit="O"),
                     Parameter(
                         name="buffer_size",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="unknown",
                         c_default="DEFAULT_BUFFER_SIZE"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="__init__",
                 full_name="_io.BufferedWriter.__init__",
                 c_basename="_io_BufferedWriter___init__",
                 kind="METHOD_INIT",
                 cls="BufferedWriter",
                 docstring="BufferedWriter(raw, buffer_size=DEFAULT_BUFFER_SIZE)\n"
                 "--\n"
                 "\n"
                 "A buffer for a writeable sequential RawIO object.\n"
                 "\n"
                 "The constructor creates a BufferedWriter for the given writeable raw\n"
                 "stream. If the buffer_size is not given, it defaults to\n"
                 "DEFAULT_BUFFER_SIZE.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="raw", format_unit="O"),
                     Parameter(
                         name="buffer_size",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="unknown",
                         c_default="DEFAULT_BUFFER_SIZE"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="write",
                 full_name="_io.BufferedWriter.write",
                 c_basename="_io_BufferedWriter_write",
                 cls="BufferedWriter",
                 docstring="write($self, buffer, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
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
                 name="__init__",
                 full_name="_io.BufferedRWPair.__init__",
                 c_basename="_io_BufferedRWPair___init__",
                 kind="METHOD_INIT",
                 cls="BufferedRWPair",
                 docstring="BufferedRWPair(reader, writer, buffer_size=DEFAULT_BUFFER_SIZE, /)\n"
                 "--\n"
                 "\n"
                 "A buffered reader and writer object together.\n"
                 "\n"
                 "A buffered reader object and buffered writer object put together to\n"
                 "form a sequential IO object that can read and write. This is typically\n"
                 "used with a socket or two-way pipe.\n"
                 "\n"
                 "reader and writer are RawIOBase objects that are readable and\n"
                 "writeable respectively. If the buffer_size is omitted it defaults to\n"
                 "DEFAULT_BUFFER_SIZE.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="reader", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="writer", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="buffer_size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="unknown",
                         c_default="DEFAULT_BUFFER_SIZE"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=3,
                 pos_only=3,
                 self_type_check=True
             ),
             Function(
                 name="__init__",
                 full_name="_io.BufferedRandom.__init__",
                 c_basename="_io_BufferedRandom___init__",
                 kind="METHOD_INIT",
                 cls="BufferedRandom",
                 docstring="BufferedRandom(raw, buffer_size=DEFAULT_BUFFER_SIZE)\n"
                 "--\n"
                 "\n"
                 "A buffered interface to random access streams.\n"
                 "\n"
                 "The constructor creates a reader and writer for a seekable stream,\n"
                 "raw, given in the first argument. If the buffer_size is omitted it\n"
                 "defaults to DEFAULT_BUFFER_SIZE.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="raw", format_unit="O"),
                     Parameter(
                         name="buffer_size",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="unknown",
                         c_default="DEFAULT_BUFFER_SIZE"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="__init__",
                 full_name="_io.IncrementalNewlineDecoder.__init__",
                 c_basename="_io_IncrementalNewlineDecoder___init__",
                 kind="METHOD_INIT",
                 cls="IncrementalNewlineDecoder",
                 docstring="IncrementalNewlineDecoder(decoder, translate, errors='strict')\n"
                 "--\n"
                 "\n"
                 "Codec used when reading a file in universal newlines mode.\n"
                 "\n"
                 "It wraps another incremental decoder, translating \\r\\n and \\r into \\n.\n"
                 "It also records the types of newlines encountered.  When used with\n"
                 "translate=False, it ensures that the newline sequence is returned in\n"
                 "one piece. When used with decoder=None, it expects unicode strings as\n"
                 "decode input and translates newlines without first invoking an external\n"
                 "decoder.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="decoder", format_unit="O"),
                     Parameter(
                         name="translate", converter="bool", type="int", format_unit="p"
                     ),
                     Parameter(
                         name="errors",
                         format_unit="O",
                         default_kind="value",
                         py_default="strict",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="decode",
                 full_name="_io.IncrementalNewlineDecoder.decode",
                 c_basename="_io_IncrementalNewlineDecoder_decode",
                 cls="IncrementalNewlineDecoder",
                 docstring="decode($self, /, input, final=False)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="input", format_unit="O"),
                     Parameter(
                         name="final",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="getstate",
                 full_name="_io.IncrementalNewlineDecoder.getstate",
                 c_basename="_io_IncrementalNewlineDecoder_getstate",
                 cls="IncrementalNewlineDecoder",
                 docstring="getstate($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="setstate",
                 full_name="_io.IncrementalNewlineDecoder.setstate",
                 c_basename="_io_IncrementalNewlineDecoder_setstate",
                 cls="IncrementalNewlineDecoder",
                 docstring="setstate($self, state, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="state", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="reset",
                 full_name="_io.IncrementalNewlineDecoder.reset",
                 c_basename="_io_IncrementalNewlineDecoder_reset",
                 cls="IncrementalNewlineDecoder",
                 docstring="reset($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__init__",
                 full_name="_io.TextIOWrapper.__init__",
                 c_basename="_io_TextIOWrapper___init__",
                 kind="METHOD_INIT",
                 cls="TextIOWrapper",
                 docstring="TextIOWrapper(buffer, encoding=None, errors=None, newline=None,\n"
                 "              line_buffering=False, write_through=False)\n"
                 "--\n"
                 "\n"
                 "Character and line based layer over a BufferedIOBase object, buffer.\n"
                 "\n"
                 "encoding gives the name of the encoding that the stream will be\n"
                 "decoded or encoded with. It defaults to locale.getencoding().\n"
                 "\n"
                 "errors determines the strictness of encoding and decoding (see\n"
                 "help(codecs.Codec) or the documentation for codecs.register) and\n"
                 "defaults to \"strict\".\n"
                 "\n"
                 "newline controls how line endings are handled. It can be None, '',\n"
                 "'\\n', '\\r', and '\\r\\n'.  It works as follows:\n"
                 "\n"
                 "* On input, if newline is None, universal newlines mode is\n"
                 "  enabled. Lines in the input can end in '\\n', '\\r', or '\\r\\n', and\n"
                 "  these are translated into '\\n' before being returned to the\n"
                 "  caller. If it is '', universal newline mode is enabled, but line\n"
                 "  endings are returned to the caller untranslated. If it has any of\n"
                 "  the other legal values, input lines are only terminated by the given\n"
                 "  string, and the line ending is returned to the caller untranslated.\n"
                 "\n"
                 "* On output, if newline is None, any '\\n' characters written are\n"
                 "  translated to the system default line separator, os.linesep. If\n"
                 "  newline is '' or '\\n', no translation takes place. If newline is any\n"
                 "  of the other legal values, any '\\n' characters written are translated\n"
                 "  to the given string.\n"
                 "\n"
                 "If line_buffering is True, a call to flush is implied when a call to\n"
                 "write contains a newline character.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="buffer", format_unit="O"),
                     Parameter(
                         name="encoding",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="errors",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="newline",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="line_buffering",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="write_through",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=6
             ),
             Function(
                 name="reconfigure",
                 full_name="_io.TextIOWrapper.reconfigure",
                 c_basename="_io_TextIOWrapper_reconfigure",
                 cls="TextIOWrapper",
                 docstring="reconfigure($self, /, *, encoding=None, errors=None, newline=None,\n"
                 "            line_buffering=None, write_through=None)\n"
                 "--\n"
                 "\n"
                 "Reconfigure the text stream with new parameters.\n"
                 "\n"
                 "This also does an implicit stream flush.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="encoding",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="errors",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="newline",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="line_buffering",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="write_through",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS"
             ),
             Function(
                 name="detach",
                 full_name="_io.TextIOWrapper.detach",
                 c_basename="_io_TextIOWrapper_detach",
                 cls="TextIOWrapper",
                 docstring="detach($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="write",
                 full_name="_io.TextIOWrapper.write",
                 c_basename="_io_TextIOWrapper_write",
                 cls="TextIOWrapper",
                 docstring="write($self, text, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="text",
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
                 name="read",
                 full_name="_io.TextIOWrapper.read",
                 c_basename="_io_TextIOWrapper_read",
                 cls="TextIOWrapper",
                 docstring="read($self, size=-1, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readline",
                 full_name="_io.TextIOWrapper.readline",
                 c_basename="_io_TextIOWrapper_readline",
                 cls="TextIOWrapper",
                 docstring="readline($self, size=-1, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="seek",
                 full_name="_io.TextIOWrapper.seek",
                 c_basename="_io_TextIOWrapper_seek",
                 cls="TextIOWrapper",
                 docstring="seek($self, cookie, whence=os.SEEK_SET, /)\n"
                 "--\n"
                 "\n"
                 "Set the stream position, and return the new stream position.\n"
                 "\n"
                 "  cookie\n"
                 "    Zero or an opaque number returned by tell().\n"
                 "  whence\n"
                 "    The relative position to seek from.\n"
                 "\n"
                 "Four operations are supported, given by the following argument\n"
                 "combinations:\n"
                 "\n"
                 "- seek(0, SEEK_SET): Rewind to the start of the stream.\n"
                 "- seek(cookie, SEEK_SET): Restore a previous position;\n"
                 "  'cookie' must be a number returned by tell().\n"
                 "- seek(0, SEEK_END): Fast-forward to the end of the stream.\n"
                 "- seek(0, SEEK_CUR): Leave the current stream position unchanged.\n"
                 "\n"
                 "Any other argument combinations are invalid,\n"
                 "and may raise exceptions.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="cookie", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="whence",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="tell",
                 full_name="_io.TextIOWrapper.tell",
                 c_basename="_io_TextIOWrapper_tell",
                 cls="TextIOWrapper",
                 docstring="tell($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the stream position as an opaque number.\n"
                 "\n"
                 "The return value of tell() can be given as input to seek(), to\n"
                 "restore a previous stream position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="truncate",
                 full_name="_io.TextIOWrapper.truncate",
                 c_basename="_io_TextIOWrapper_truncate",
                 cls="TextIOWrapper",
                 docstring="truncate($self, pos=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="pos",
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
                 name="fileno",
                 full_name="_io.TextIOWrapper.fileno",
                 c_basename="_io_TextIOWrapper_fileno",
                 cls="TextIOWrapper",
                 docstring="fileno($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seekable",
                 full_name="_io.TextIOWrapper.seekable",
                 c_basename="_io_TextIOWrapper_seekable",
                 cls="TextIOWrapper",
                 docstring="seekable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="readable",
                 full_name="_io.TextIOWrapper.readable",
                 c_basename="_io_TextIOWrapper_readable",
                 cls="TextIOWrapper",
                 docstring="readable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="writable",
                 full_name="_io.TextIOWrapper.writable",
                 c_basename="_io_TextIOWrapper_writable",
                 cls="TextIOWrapper",
                 docstring="writable($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="isatty",
                 full_name="_io.TextIOWrapper.isatty",
                 c_basename="_io_TextIOWrapper_isatty",
                 cls="TextIOWrapper",
                 docstring="isatty($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="flush",
                 full_name="_io.TextIOWrapper.flush",
                 c_basename="_io_TextIOWrapper_flush",
                 cls="TextIOWrapper",
                 docstring="flush($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="close",
                 full_name="_io.TextIOWrapper.close",
                 c_basename="_io_TextIOWrapper_close",
                 cls="TextIOWrapper",
                 docstring="close($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="name",
                 full_name="_io.TextIOWrapper.name",
                 c_basename="_io_TextIOWrapper_name",
                 kind="GETTER",
                 cls="TextIOWrapper",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="closed",
                 full_name="_io.TextIOWrapper.closed",
                 c_basename="_io_TextIOWrapper_closed",
                 kind="GETTER",
                 cls="TextIOWrapper",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="newlines",
                 full_name="_io.TextIOWrapper.newlines",
                 c_basename="_io_TextIOWrapper_newlines",
                 kind="GETTER",
                 cls="TextIOWrapper",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="errors",
                 full_name="_io.TextIOWrapper.errors",
                 c_basename="_io_TextIOWrapper_errors",
                 kind="GETTER",
                 cls="TextIOWrapper",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_CHUNK_SIZE",
                 full_name="_io.TextIOWrapper._CHUNK_SIZE",
                 c_basename="_io_TextIOWrapper__CHUNK_SIZE",
                 kind="GETTER",
                 cls="TextIOWrapper",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_CHUNK_SIZE",
                 full_name="_io.TextIOWrapper._CHUNK_SIZE",
                 c_basename="_io_TextIOWrapper__CHUNK_SIZE",
                 kind="SETTER",
                 cls="TextIOWrapper",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="detach",
                 full_name="_io._TextIOBase.detach",
                 c_basename="_io__TextIOBase_detach",
                 cls="_TextIOBase",
                 docstring="detach($self, /)\n"
                 "--\n"
                 "\n"
                 "Separate the underlying buffer from the TextIOBase and return it.\n"
                 "\n"
                 "After the underlying buffer has been detached, the TextIO is in\n"
                 "an unusable state.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_NO_ARGUMENTS"
             ),
             Function(
                 name="read",
                 full_name="_io._TextIOBase.read",
                 c_basename="_io__TextIOBase_read",
                 cls="_TextIOBase",
                 docstring="read($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read at most size characters from stream.\n"
                 "\n"
                 "Read from underlying buffer until we have size characters or we hit\n"
                 "EOF.  If size is negative or omitted, read until EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readline",
                 full_name="_io._TextIOBase.readline",
                 c_basename="_io__TextIOBase_readline",
                 cls="_TextIOBase",
                 docstring="readline($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read until newline or EOF.\n"
                 "\n"
                 "Return an empty string if EOF is hit immediately.\n"
                 "If size is specified, at most size characters will be read.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="write",
                 full_name="_io._TextIOBase.write",
                 c_basename="_io__TextIOBase_write",
                 cls="_TextIOBase",
                 docstring="write($self, s, /)\n"
                 "--\n"
                 "\n"
                 "Write string s to stream.\n"
                 "\n"
                 "Return the number of characters written\n"
                 "(which is always equal to the length of the string).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cls",
                         kind="POSITIONAL_ONLY",
                         converter="defining_class",
                         type="PyTypeObject *"
                     ),
                     Parameter(
                         name="s",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="encoding",
                 full_name="_io._TextIOBase.encoding",
                 c_basename="_io__TextIOBase_encoding",
                 kind="GETTER",
                 cls="_TextIOBase",
                 docstring="Encoding of the text stream.\n"
                 "\n"
                 "Subclasses should override.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="newlines",
                 full_name="_io._TextIOBase.newlines",
                 c_basename="_io__TextIOBase_newlines",
                 kind="GETTER",
                 cls="_TextIOBase",
                 docstring="Line endings translated so far.\n"
                 "\n"
                 "Only line endings translated during reading are considered.\n"
                 "\n"
                 "Subclasses should override.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="errors",
                 full_name="_io._TextIOBase.errors",
                 c_basename="_io__TextIOBase_errors",
                 kind="GETTER",
                 cls="_TextIOBase",
                 docstring="The error setting of the decoder or encoder.\n"
                 "\n"
                 "Subclasses should override.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="getvalue",
                 full_name="_io.StringIO.getvalue",
                 c_basename="_io_StringIO_getvalue",
                 cls="StringIO",
                 docstring="getvalue($self, /)\n"
                 "--\n"
                 "\n"
                 "Retrieve the entire contents of the object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="tell",
                 full_name="_io.StringIO.tell",
                 c_basename="_io_StringIO_tell",
                 cls="StringIO",
                 docstring="tell($self, /)\n"
                 "--\n"
                 "\n"
                 "Tell the current file position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="read",
                 full_name="_io.StringIO.read",
                 c_basename="_io_StringIO_read",
                 cls="StringIO",
                 docstring="read($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read at most size characters, returned as a string.\n"
                 "\n"
                 "If the argument is negative or omitted, read until EOF\n"
                 "is reached. Return an empty string at EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="readline",
                 full_name="_io.StringIO.readline",
                 c_basename="_io_StringIO_readline",
                 cls="StringIO",
                 docstring="readline($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read until newline or EOF.\n"
                 "\n"
                 "Returns an empty string if EOF is hit immediately.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="truncate",
                 full_name="_io.StringIO.truncate",
                 c_basename="_io_StringIO_truncate",
                 cls="StringIO",
                 docstring="truncate($self, pos=None, /)\n"
                 "--\n"
                 "\n"
                 "Truncate size to pos.\n"
                 "\n"
                 "The pos argument defaults to the current file position, as\n"
                 "returned by tell().  The current file position is unchanged.\n"
                 "Returns the new absolute position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="pos",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="O&",
                         default_kind="value",
                         c_default="((stringio *)self)->pos",
                         convert_with="_Py_convert_optional_to_ssize_t"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="seek",
                 full_name="_io.StringIO.seek",
                 c_basename="_io_StringIO_seek",
                 cls="StringIO",
                 docstring="seek($self, pos, whence=0, /)\n"
                 "--\n"
                 "\n"
                 "Change stream position.\n"
                 "\n"
                 "Seek to character offset pos relative to position indicated by\n"
                 "whence:\n"
                 "    0  Start of stream (the default).  pos should be >= 0;\n"
                 "    1  Current position - pos must be 0;\n"
                 "    2  End of stream - pos must be 0.\n"
                 "Returns the new absolute position.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="pos",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
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
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="write",
                 full_name="_io.StringIO.write",
                 c_basename="_io_StringIO_write",
                 cls="StringIO",
                 docstring="write($self, s, /)\n"
                 "--\n"
                 "\n"
                 "Write string to file.\n"
                 "\n"
                 "Returns the number of characters written, which is always equal to\n"
                 "the length of the string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="s", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="close",
                 full_name="_io.StringIO.close",
                 c_basename="_io_StringIO_close",
                 cls="StringIO",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "Close the IO object.\n"
                 "\n"
                 "Attempting any further operation after the object is closed\n"
                 "will raise a ValueError.\n"
                 "\n"
                 "This method has no effect if the file is already closed.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__init__",
                 full_name="_io.StringIO.__init__",
                 c_basename="_io_StringIO___init__",
                 kind="METHOD_INIT",
                 cls="StringIO",
                 docstring="StringIO(initial_value='', newline='\\n')\n"
                 "--\n"
                 "\n"
                 "Text I/O implementation using an in-memory buffer.\n"
                 "\n"
                 "The initial_value argument sets the value of object.  The newline\n"
                 "argument is like the one of TextIOWrapper's constructor.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="initial_value",
                         format_unit="O",
                         default_kind="value",
                         py_default="",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="newline",
                         format_unit="O",
                         default_kind="value",
                         py_default="\n",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="readable",
                 full_name="_io.StringIO.readable",
                 c_basename="_io_StringIO_readable",
                 cls="StringIO",
                 docstring="readable($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the IO object can be read.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="writable",
                 full_name="_io.StringIO.writable",
                 c_basename="_io_StringIO_writable",
                 cls="StringIO",
                 docstring="writable($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the IO object can be written.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seekable",
                 full_name="_io.StringIO.seekable",
                 c_basename="_io_StringIO_seekable",
                 cls="StringIO",
                 docstring="seekable($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the IO object can be seeked.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__getstate__",
                 full_name="_io.StringIO.__getstate__",
                 c_basename="_io_StringIO___getstate__",
                 cls="StringIO",
                 docstring="__getstate__($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__setstate__",
                 full_name="_io.StringIO.__setstate__",
                 c_basename="_io_StringIO___setstate__",
                 cls="StringIO",
                 docstring="__setstate__($self, state, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="state", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="closed",
                 full_name="_io.StringIO.closed",
                 c_basename="_io_StringIO_closed",
                 kind="GETTER",
                 cls="StringIO",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="line_buffering",
                 full_name="_io.StringIO.line_buffering",
                 c_basename="_io_StringIO_line_buffering",
                 kind="GETTER",
                 cls="StringIO",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="newlines",
                 full_name="_io.StringIO.newlines",
                 c_basename="_io_StringIO_newlines",
                 kind="GETTER",
                 cls="StringIO",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             )
         ],
         docs={
             "module_doc": "The io module provides the Python interfaces to stream handling. The\n"
             "builtin open function is defined in this module.\n"
             "\n"
             "At the top of the I/O hierarchy is the abstract base class IOBase. It\n"
             "defines the basic interface to a stream. Note, however, that there is no\n"
             "separation between reading and writing to streams; implementations are\n"
             "allowed to raise an OSError if they do not support a given operation.\n"
             "\n"
             "Extending IOBase is RawIOBase which deals simply with the reading and\n"
             "writing of raw bytes to a stream. FileIO subclasses RawIOBase to provide\n"
             "an interface to OS files.\n"
             "\n"
             "BufferedIOBase deals with buffering on a raw byte stream (RawIOBase). Its\n"
             "subclasses, BufferedWriter, BufferedReader, and BufferedRWPair buffer\n"
             "streams that are readable, writable, and both respectively.\n"
             "BufferedRandom provides a buffered interface to random access\n"
             "streams. BytesIO is a simple stream of in-memory bytes.\n"
             "\n"
             "Another IOBase subclass, TextIOBase, deals with the encoding and decoding\n"
             "of streams into text. TextIOWrapper, which extends it, is a buffered text\n"
             "interface to a buffered raw stream (`BufferedIOBase`). Finally, StringIO\n"
             "is an in-memory stream for text.\n"
             "\n"
             "Argument names are not part of the specification, and only the arguments\n"
             "of open() are intended to be used as keyword arguments.\n"
             "\n"
             "data:\n"
             "\n"
             "DEFAULT_BUFFER_SIZE\n"
             "\n"
             "   An int containing the default buffer size used by the module's buffered\n"
             "   I/O classes.\n",
             "iobase_doc": "The abstract base class for all I/O classes.\n"
             "\n"
             "This class provides dummy implementations for many methods that\n"
             "derived classes can override selectively; the default implementations\n"
             "represent a file that cannot be read, written or seeked.\n"
             "\n"
             "Even though IOBase does not declare read, readinto, or write because\n"
             "their signatures will vary, implementations and clients should\n"
             "consider those methods part of the interface. Also, implementations\n"
             "may raise UnsupportedOperation when operations they do not support are\n"
             "called.\n"
             "\n"
             "The basic type used for binary data read from or written to a file is\n"
             "bytes. Other bytes-like objects are accepted as method arguments too.\n"
             "In some cases (such as readinto), a writable object is required. Text\n"
             "I/O classes work with str data.\n"
             "\n"
             "Note that calling any method (except additional calls to close(),\n"
             "which are ignored) on a closed stream should raise a ValueError.\n"
             "\n"
             "IOBase (and its subclasses) support the iterator protocol, meaning\n"
             "that an IOBase object can be iterated over yielding the lines in a\n"
             "stream.\n"
             "\n"
             "IOBase also supports the :keyword:`with` statement. In this example,\n"
             "fp is closed after the suite of the with statement is complete:\n"
             "\n"
             "with open('spam.txt', 'r') as fp:\n"
             "    fp.write('Spam and eggs!')\n",
             "rawiobase_doc": "Base class for raw binary I/O.",
             "bufferediobase_doc": "Base class for buffered IO objects.\n"
             "\n"
             "The main difference with RawIOBase is that the read() method\n"
             "supports omitting the size argument, and does not have a default\n"
             "implementation that defers to readinto().\n"
             "\n"
             "In addition, read(), readinto() and write() may raise\n"
             "BlockingIOError if the underlying raw stream is in non-blocking\n"
             "mode and not ready; unlike their raw counterparts, they will never\n"
             "return None.\n"
             "\n"
             "A typical implementation should not inherit from a RawIOBase\n"
             "implementation, but wrap one.\n",
             "textiobase_doc": "Base class for text I/O.\n"
             "\n"
             "This class provides a character and line based interface to stream\n"
             "I/O. There is no readinto method because Python's character strings\n"
             "are immutable.\n",
             "fileio_getsetlist_closed_doc": "True if the file is closed",
             "fileio_getsetlist_closefd_doc": "True if the file descriptor will be closed by close().",
             "fileio_getsetlist_mode_doc": "String giving the file mode",
             "fileio_getsetlist__blksize_doc": "Stat st_blksize if available",
             "bytesio_getsetlist_closed_doc": "True if the file is closed."
         }
     );
