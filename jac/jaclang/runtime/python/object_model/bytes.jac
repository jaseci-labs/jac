import from c {
    glob PyType_Type: PyTypeObject,
         PyExc_BytesWarning: ptr[PyObject]; def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def memmove(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def memchr(source: ptr, value: i32, size: u64) -> ptr;  def memcmp(
        left: ptr, right: ptr, size: u64
    ) -> i32;  def strlen(s: ptr[u8]) -> u64;  def strcmp(
        s1: ptr[u8], s2: ptr[u8]
    ) -> i32;  def snprintf(
        target: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def PyObject_Calloc(nelem: u64, elsize: u64) -> ptr;  def PyObject_Realloc(
        p: ptr, size: u64
    ) -> ptr;  def PyObject_InitVar(
        op: ptr[PyObject], tp: ptr[PyObject], size: i64
    ) -> ptr[PyObject];  def _Py_NewReferenceNoTotal(op: ptr[PyObject]);  def _Py_GetConfig -> ptr[
        u8
    ];  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        o: ptr[PyObject],
        buf: ptr,
        len_: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def PyBuffer_ToContiguous(
        buf: ptr, src: ptr[Py_buffer], length: i64, order: i8
    ) -> i32;  def PyByteArray_FromStringAndSize(
        data: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyObject_ASCII(v: ptr[PyObject]) -> ptr[PyObject];  def PyUnicode_AsEncodedString(
        unicode: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject];  def PyUnicode_FromEncodedObject(
        obj_: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
    ) -> ptr[PyObject];  def _PyUnicode_FormatLong(
        val: ptr[PyObject], alt: i32, prec: i32, type: i32
    ) -> ptr[PyObject];  def _PyLong_FormatBytesWriter(
        writer: ptr[BytesWriterHead],
        s: ptr[u8],
        ob: ptr[PyObject],
        base: i32,
        alternate: i32
    ) -> ptr[u8];  def _Py_strhex_with_sep(
        argbuf: ptr, arglen: i64, sep: ptr[PyObject], bytes_per_group: i32
    ) -> ptr[PyObject];  obj BytesWriterHead {
        has buffer: ptr[PyObject],
            allocated: i64,
            min_size: i64,
            use_bytearray: i32,
            overallocate: i32,
            use_small_buffer: i32;
    }  glob:priv bytes_as_number: PyNumberMethods = PyNumberMethods(
             nb_remainder=bytes_mod
         ),
         bytes_as_sequence: PySequenceMethods = PySequenceMethods(
             sq_length=bytes_length,
             sq_concat=bytes_concat,
             sq_repeat=bytes_repeat,
             sq_item=bytes_item,
             sq_contains=bytes_contains
         ),
         bytes_as_mapping: PyMappingMethods = PyMappingMethods(
             mp_length=bytes_length, mp_subscript=bytes_subscript
         ),
         bytes_as_buffer: PyBufferProcs = PyBufferProcs(
             bf_getbuffer=bytes_buffer_getbuffer
         ),
         bytes_methods_table: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__getnewargs__"),
                 ml_meth=ptr(bytes_getnewargs),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__bytes__"),
                 ml_meth=ptr(bytes___bytes__),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "__bytes__($self, /)\n--\n\n"
                     "Convert this value to exact type bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("capitalize"),
                 ml_meth=ptr(bytes_capitalize),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.capitalize() -> copy of B\n\n"
                     "Return a copy of B with only its first character capitalized (ASCII)\n"
                     "and the rest lower-cased."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("center"),
                 ml_meth=ptr(bytes_center),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "center($self, width, fillchar=b' ', /)\n--\n\n"
                     "Return a centered string of length width.\n\n"
                     "Padding is done using the specified fill character."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("count"),
                 ml_meth=ptr(bytes_count),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "count($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the number of non-overlapping occurrences of subsection 'sub' in bytes B[start:end].\n\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("decode"),
                 ml_meth=ptr(bytes_decode),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "decode($self, /, encoding='utf-8', errors='strict')\n--\n\n"
                     "Decode the bytes using the codec registered for encoding.\n\n"
                     "  encoding\n"
                     "    The encoding with which to decode the bytes.\n"
                     "  errors\n"
                     "    The error handling scheme to use for the handling of decoding\n"
                     "    errors.  The default is 'strict' meaning that decoding errors\n"
                     "    raise a UnicodeDecodeError.  Other possible values are 'ignore'\n"
                     "    and 'replace' as well as any other name registered with\n"
                     "    codecs.register_error that can handle UnicodeDecodeErrors."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("endswith"),
                 ml_meth=ptr(bytes_endswith),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "endswith($self, suffix[, start[, end]], /)\n--\n\n"
                     "Return True if the bytes ends with the specified suffix, False otherwise.\n\n"
                     "  suffix\n"
                     "    A bytes or a tuple of bytes to try.\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("expandtabs"),
                 ml_meth=ptr(bytes_expandtabs),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "expandtabs($self, /, tabsize=8)\n--\n\n"
                     "Return a copy where all tab characters are expanded using spaces.\n\n"
                     "If tabsize is not given, a tab size of 8 characters is assumed."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("find"),
                 ml_meth=ptr(bytes_find),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "find($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the lowest index in B where subsection 'sub' is found, such that 'sub' is contained within B[start,end].\n\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes.\n\n"
                     "Return -1 on failure."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("fromhex"),
                 ml_meth=ptr(bytes_fromhex),
                 ml_flags=METH_O | METH_CLASS,
                 ml_doc=ptr[u8](
                     "fromhex($type, string, /)\n--\n\n"
                     "Create a bytes object from a string of hexadecimal numbers.\n\n"
                     "Spaces between two numbers are accepted.\n"
                     "Example: bytes.fromhex('B9 01EF') -> b'\\\\xb9\\\\x01\\\\xef'."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hex"),
                 ml_meth=ptr(bytes_hex),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "hex($self, /, sep=<unrepresentable>, bytes_per_sep=1)\n--\n\n"
                     "Create a string of hexadecimal numbers from a bytes object.\n\n"
                     "  sep\n"
                     "    An optional single character or byte to separate hex bytes.\n"
                     "  bytes_per_sep\n"
                     "    How many bytes between separators.  Positive values count from\n"
                     "    the right, negative values count from the left.\n\n"
                     "Example:\n"
                     ">>> value = b'\\xb9\\x01\\xef'\n"
                     ">>> value.hex()\n"
                     "'b901ef'\n"
                     ">>> value.hex(':')\n"
                     "'b9:01:ef'\n"
                     ">>> value.hex(':', 2)\n"
                     "'b9:01ef'\n"
                     ">>> value.hex(':', -2)\n"
                     "'b901:ef'"
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("index"),
                 ml_meth=ptr(bytes_index),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "index($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the lowest index in B where subsection 'sub' is found, such that 'sub' is contained within B[start,end].\n\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes.\n\n"
                     "Raise ValueError if the subsection is not found."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isalnum"),
                 ml_meth=ptr(bytes_isalnum),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.isalnum() -> bool\n\n"
                     "Return True if all characters in B are alphanumeric\n"
                     "and there is at least one character in B, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isalpha"),
                 ml_meth=ptr(bytes_isalpha),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.isalpha() -> bool\n\n"
                     "Return True if all characters in B are alphabetic\n"
                     "and there is at least one character in B, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isascii"),
                 ml_meth=ptr(bytes_isascii),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.isascii() -> bool\n\n"
                     "Return True if B is empty or all characters in B are ASCII,\n"
                     "False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isdigit"),
                 ml_meth=ptr(bytes_isdigit),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.isdigit() -> bool\n\n"
                     "Return True if all characters in B are digits\n"
                     "and there is at least one character in B, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("islower"),
                 ml_meth=ptr(bytes_islower),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.islower() -> bool\n\n"
                     "Return True if all cased characters in B are lowercase and there is\n"
                     "at least one cased character in B, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isspace"),
                 ml_meth=ptr(bytes_isspace),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.isspace() -> bool\n\n"
                     "Return True if all characters in B are whitespace\n"
                     "and there is at least one character in B, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("istitle"),
                 ml_meth=ptr(bytes_istitle),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.istitle() -> bool\n\n"
                     "Return True if B is a titlecased string and there is at least one\n"
                     "character in B, i.e. uppercase characters may only follow uncased\n"
                     "characters and lowercase characters only cased ones. Return False\n"
                     "otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isupper"),
                 ml_meth=ptr(bytes_isupper),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.isupper() -> bool\n\n"
                     "Return True if all cased characters in B are uppercase and there is\n"
                     "at least one cased character in B, False otherwise."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("join"),
                 ml_meth=ptr(bytes_join),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "join($self, iterable_of_bytes, /)\n--\n\n"
                     "Concatenate any number of bytes objects.\n\n"
                     "The bytes whose method is called is inserted in between each pair.\n\n"
                     "The result is returned as a new bytes object.\n\n"
                     "Example: b'.'.join([b'ab', b'pq', b'rs']) -> b'ab.pq.rs'."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("ljust"),
                 ml_meth=ptr(bytes_ljust),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "ljust($self, width, fillchar=b' ', /)\n--\n\n"
                     "Return a left-justified string of length width.\n\n"
                     "Padding is done using the specified fill character."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("lower"),
                 ml_meth=ptr(bytes_lower),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.lower() -> copy of B\n\n"
                     "Return a copy of B with all ASCII characters converted to lowercase."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("lstrip"),
                 ml_meth=ptr(bytes_lstrip),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "lstrip($self, bytes=None, /)\n--\n\n"
                     "Strip leading bytes contained in the argument.\n\n"
                     "If the argument is omitted or None, strip leading  ASCII whitespace."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("maketrans"),
                 ml_meth=ptr(bytes_maketrans),
                 ml_flags=METH_FASTCALL | METH_STATIC,
                 ml_doc=ptr[u8](
                     "maketrans(frm, to, /)\n--\n\n"
                     "Return a translation table usable for the bytes or bytearray translate method.\n\n"
                     "The returned table will be one where each byte in frm is mapped to\n"
                     "the byte at the same position in to.\n\n"
                     "The bytes objects frm and to must be of the same length."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("partition"),
                 ml_meth=ptr(bytes_partition),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "partition($self, sep, /)\n--\n\n"
                     "Partition the bytes into three parts using the given separator.\n\n"
                     "This will search for the separator sep in the bytes.  If the\n"
                     "separator is found, returns a 3-tuple containing the part before the\n"
                     "separator, the separator itself, and the part after it.\n\n"
                     "If the separator is not found, returns a 3-tuple containing the\n"
                     "original bytes object and two empty bytes objects."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("replace"),
                 ml_meth=ptr(bytes_replace),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "replace($self, old, new, count=-1, /)\n--\n\n"
                     "Return a copy with all occurrences of substring old replaced by new.\n\n"
                     "  count\n"
                     "    Maximum number of occurrences to replace.\n"
                     "    -1 (the default value) means replace all occurrences.\n\n"
                     "If the optional argument count is given, only the first count occurrences are\n"
                     "replaced."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("removeprefix"),
                 ml_meth=ptr(bytes_removeprefix),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "removeprefix($self, prefix, /)\n--\n\n"
                     "Return a bytes object with the given prefix string removed if present.\n\n"
                     "If the bytes starts with the prefix string, return\n"
                     "bytes[len(prefix):].  Otherwise, return a copy of the original\n"
                     "bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("removesuffix"),
                 ml_meth=ptr(bytes_removesuffix),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "removesuffix($self, suffix, /)\n--\n\n"
                     "Return a bytes object with the given suffix string removed if present.\n\n"
                     "If the bytes ends with the suffix string and that suffix is not\n"
                     "empty, return bytes[:-len(prefix)].  Otherwise, return a copy of the\n"
                     "original bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rfind"),
                 ml_meth=ptr(bytes_rfind),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rfind($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the highest index in B where subsection 'sub' is found, such that 'sub' is contained within B[start,end].\n\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes.\n\n"
                     "Return -1 on failure."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rindex"),
                 ml_meth=ptr(bytes_rindex),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rindex($self, sub[, start[, end]], /)\n--\n\n"
                     "Return the highest index in B where subsection 'sub' is found, such that 'sub' is contained within B[start,end].\n\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes.\n\n"
                     "Raise ValueError if the subsection is not found."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rjust"),
                 ml_meth=ptr(bytes_rjust),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rjust($self, width, fillchar=b' ', /)\n--\n\n"
                     "Return a right-justified string of length width.\n\n"
                     "Padding is done using the specified fill character."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rpartition"),
                 ml_meth=ptr(bytes_rpartition),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "rpartition($self, sep, /)\n--\n\n"
                     "Partition the bytes into three parts using the given separator.\n\n"
                     "This will search for the separator sep in the bytes, starting at the\n"
                     "end.  If the separator is found, returns a 3-tuple containing the\n"
                     "part before the separator, the separator itself, and the part after\n"
                     "it.\n\n"
                     "If the separator is not found, returns a 3-tuple containing two\n"
                     "empty bytes objects and the original bytes object."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rsplit"),
                 ml_meth=ptr(bytes_rsplit),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "rsplit($self, /, sep=None, maxsplit=-1)\n--\n\n"
                     "Return a list of the sections in the bytes, using sep as the delimiter.\n\n"
                     "  sep\n"
                     "    The delimiter according which to split the bytes.\n"
                     "    None (the default value) means split on ASCII whitespace\n"
                     "    characters (space, tab, return, newline, formfeed, vertical tab).\n"
                     "  maxsplit\n"
                     "    Maximum number of splits to do.\n"
                     "    -1 (the default value) means no limit.\n\n"
                     "Splitting is done starting at the end of the bytes and working to\n"
                     "the front."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("rstrip"),
                 ml_meth=ptr(bytes_rstrip),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "rstrip($self, bytes=None, /)\n--\n\n"
                     "Strip trailing bytes contained in the argument.\n\n"
                     "If the argument is omitted or None, strip trailing ASCII whitespace."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("split"),
                 ml_meth=ptr(bytes_split),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "split($self, /, sep=None, maxsplit=-1)\n--\n\n"
                     "Return a list of the sections in the bytes, using sep as the delimiter.\n\n"
                     "  sep\n"
                     "    The delimiter according which to split the bytes.\n"
                     "    None (the default value) means split on ASCII whitespace\n"
                     "    characters (space, tab, return, newline, formfeed, vertical tab).\n"
                     "  maxsplit\n"
                     "    Maximum number of splits to do.\n"
                     "    -1 (the default value) means no limit."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("splitlines"),
                 ml_meth=ptr(bytes_splitlines),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "splitlines($self, /, keepends=False)\n--\n\n"
                     "Return a list of the lines in the bytes, breaking at line boundaries.\n\n"
                     "Line breaks are not included in the resulting list unless keepends\n"
                     "is given and true."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("startswith"),
                 ml_meth=ptr(bytes_startswith),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "startswith($self, prefix[, start[, end]], /)\n--\n\n"
                     "Return True if the bytes starts with the specified prefix, False otherwise.\n\n"
                     "  prefix\n"
                     "    A bytes or a tuple of bytes to try.\n"
                     "  start\n"
                     "    Optional start position. Default: start of the bytes.\n"
                     "  end\n"
                     "    Optional stop position. Default: end of the bytes."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("strip"),
                 ml_meth=ptr(bytes_strip),
                 ml_flags=METH_FASTCALL,
                 ml_doc=ptr[u8](
                     "strip($self, bytes=None, /)\n--\n\n"
                     "Strip leading and trailing bytes contained in the argument.\n\n"
                     "If the argument is omitted or None, strip leading and trailing ASCII\n"
                     "whitespace."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("swapcase"),
                 ml_meth=ptr(bytes_swapcase),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.swapcase() -> copy of B\n\n"
                     "Return a copy of B with uppercase ASCII characters converted\n"
                     "to lowercase ASCII and vice versa."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("title"),
                 ml_meth=ptr(bytes_title),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.title() -> copy of B\n\n"
                     "Return a titlecased version of B, i.e. ASCII words start with\n"
                     "uppercase characters, all remaining cased characters have lowercase."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("translate"),
                 ml_meth=ptr(bytes_translate),
                 ml_flags=METH_FASTCALL | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "translate($self, table, /, delete=b'')\n--\n\n"
                     "Return a copy with each character mapped by the given translation table.\n\n"
                     "  table\n"
                     "    Translation table, which must be a bytes object of length 256.\n\n"
                     "All characters occurring in the optional argument delete are\n"
                     "removed.  The remaining characters are mapped through the given\n"
                     "translation table."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("upper"),
                 ml_meth=ptr(bytes_upper),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "B.upper() -> copy of B\n\n"
                     "Return a copy of B with all ASCII characters converted to uppercase."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("zfill"),
                 ml_meth=ptr(bytes_zfill),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8](
                     "zfill($self, width, /)\n--\n\n"
                     "Pad a numeric string with zeros on the left, to fill a field of the given width.\n\n"
                     "The original string is never truncated."
                 )
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         striter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__length_hint__"),
                 ml_meth=ptr(striter_len),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "Private method returning an estimate of len(list(it))."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__reduce__"),
                 ml_meth=ptr(striter_reduce),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("Return state information for pickling.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("__setstate__"),
                 ml_meth=ptr(striter_setstate),
                 ml_flags=METH_O,
                 ml_doc=ptr[u8]("Set state information for unpickling.")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ]; glob PyBytes_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("bytes"),
             tp_basicsize=PyBytesObject_OB_SVAL + 1,
             tp_itemsize=1,
             tp_repr=bytes_repr,
             tp_as_number=addressof(bytes_as_number),
             tp_as_sequence=addressof(bytes_as_sequence),
             tp_as_mapping=addressof(bytes_as_mapping),
             tp_hash=bytes_hash,
             tp_str=bytes_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_as_buffer=addressof(bytes_as_buffer),
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_BYTES_SUBCLASS
                 | _Py_TPFLAGS_MATCH_SELF,
             tp_doc=ptr[u8](
                 "bytes(iterable_of_ints) -> bytes\n"
                 "bytes(string, encoding[, errors]) -> bytes\n"
                 "bytes(bytes_or_buffer) -> immutable copy of bytes_or_buffer\n"
                 "bytes(int) -> bytes object of size given by the parameter initialized with null bytes\n"
                 "bytes() -> empty bytes object\n\n"
                 "Construct an immutable array of bytes from:\n"
                 "  - an iterable yielding integers in range(256)\n"
                 "  - a text string encoded using the specified encoding\n"
                 "  - any object implementing the buffer API.\n"
                 "  - an integer"
             ),
             tp_richcompare=bytes_richcompare,
             tp_iter=bytes_iter,
             tp_methods=addressof(bytes_methods_table),
             tp_alloc=bytes_alloc,
             tp_new=bytes_new,
             tp_free=PyObject_Free,
             tp_version_tag=_Py_TYPE_VERSION_BYTES
         ),
         PyBytesIter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("bytes_iterator"),
             tp_basicsize=striterobject_SIZE,
             tp_dealloc=striter_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_traverse=striter_traverse,
             tp_iter=PyObject_SelfIter,
             tp_iternext=striter_next,
             tp_methods=addressof(striter_methods)
         );
}

glob:priv PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     INT_MAX: i64 = 2147483647,
     PY_BUFFER_SIZE: i64 = 80,
     SMALL_BUFFER_SIZE: i64 = 512,
     WRITER_SCRATCH: i64 = 32,
     OVERALLOCATE_FACTOR: i64 = 4,
     PYREFTRACER_DESTROY: i32 = 1,
     PY_DTSF_ALT: i32 = 4,
     F_LJUST: i64 = 1,
     F_SIGN: i64 = 2,
     F_BLANK: i64 = 4,
     F_ALT: i64 = 8,
     F_ZERO: i64 = 16,
     LEFTSTRIP: i64 = 0,
     RIGHTSTRIP: i64 = 1,
     BOTHSTRIP: i64 = 2,
     ARG_DECODE_ENCODING: i64 = 0,
     ARG_DECODE_ERRORS: i64 = 1,
     ARG_NEW_ENCODING: i64 = 2,
     ARG_NEW_ERRORS: i64 = 3,
     CH_NUL: i64 = 0,
     CH_BEL: i64 = 7,
     CH_BACKSPACE: i64 = 8,
     CH_TAB: i64 = 9,
     CH_NEWLINE: i64 = 10,
     CH_VTAB: i64 = 11,
     CH_FORMFEED: i64 = 12,
     CH_RETURN: i64 = 13,
     CH_SPACE: i64 = 32,
     CH_DQUOTE: i64 = 34,
     CH_HASH: i64 = 35,
     CH_PERCENT: i64 = 37,
     CH_QUOTE: i64 = 39,
     CH_LPAREN: i64 = 40,
     CH_RPAREN: i64 = 41,
     CH_STAR: i64 = 42,
     CH_PLUS: i64 = 43,
     CH_MINUS: i64 = 45,
     CH_DOT: i64 = 46,
     CH_ZERO: i64 = 48,
     CH_SEVEN: i64 = 55,
     CH_NINE: i64 = 57,
     CH_QUESTION: i64 = 63,
     CH_UPPER_E: i64 = 69,
     CH_UPPER_F: i64 = 70,
     CH_UPPER_G: i64 = 71,
     CH_UPPER_L: i64 = 76,
     CH_UPPER_X: i64 = 88,
     CH_BACKSLASH: i64 = 92,
     CH_LOWER_A: i64 = 97,
     CH_LOWER_B: i64 = 98,
     CH_LOWER_C: i64 = 99,
     CH_LOWER_D: i64 = 100,
     CH_LOWER_E: i64 = 101,
     CH_LOWER_F: i64 = 102,
     CH_LOWER_G: i64 = 103,
     CH_LOWER_H: i64 = 104,
     CH_LOWER_I: i64 = 105,
     CH_LOWER_L: i64 = 108,
     CH_LOWER_N: i64 = 110,
     CH_LOWER_O: i64 = 111,
     CH_LOWER_P: i64 = 112,
     CH_LOWER_R: i64 = 114,
     CH_LOWER_S: i64 = 115,
     CH_LOWER_T: i64 = 116,
     CH_LOWER_U: i64 = 117,
     CH_LOWER_V: i64 = 118,
     CH_LOWER_X: i64 = 120,
     CH_LOWER_Z: i64 = 122,
     CH_DEL: i64 = 127;

glob:priv split_signature = CallSignature(
         "split", ["sep", "maxsplit"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     rsplit_signature = CallSignature(
         "rsplit", ["sep", "maxsplit"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     translate_signature = CallSignature(
         "translate", ["table", "delete"], 1, 2, 1, parser=PARSE_KEYWORDS
     ),
     decode_signature = CallSignature(
         "decode", ["encoding", "errors"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     splitlines_signature = CallSignature(
         "splitlines", ["keepends"], 0, 1, 0, parser=PARSE_KEYWORDS
     ),
     hex_signature = CallSignature(
         "hex", ["sep", "bytes_per_sep"], 0, 2, 0, parser=PARSE_KEYWORDS
     ),
     bytes_new_signature = CallSignature(
         "bytes", ["source", "encoding", "errors"], 0, 3, 0, parser=PARSE_KEYWORDS
     );

def bytes_type -> ptr[PyTypeObject];

def bytes_of(op: ptr[PyObject]) -> ptr[PyBytesObject];

def bytes_sval(op: ptr[PyObject]) -> ptr[u8];

def bytes_header_size -> i64;

def get_shash(op: ptr[PyObject]) -> i64;

def set_shash(op: ptr[PyObject], hash: i64);

def set_size(op: ptr[PyObject], size: i64);

def bytes_check(op: ptr[PyObject]) -> bool;

def bytes_check_exact(op: ptr[PyObject]) -> bool;

def bytearray_check(op: ptr[PyObject]) -> bool;

def unicode_check(op: ptr[PyObject]) -> bool;

def long_check(op: ptr[PyObject]) -> bool;

def long_check_exact(op: ptr[PyObject]) -> bool;

def tuple_check(op: ptr[PyObject]) -> bool;

def tuple_check_exact(op: ptr[PyObject]) -> bool;

def list_check_exact(op: ptr[PyObject]) -> bool;

def slice_check(op: ptr[PyObject]) -> bool;

def bytes_get_empty -> ptr[PyObject];

def bytes_character(ch: u8) -> ptr[PyObject];

def peek(p: ptr[u8]) -> u8;

def poke(p: ptr[u8], c: u8);

def span(start: ptr[u8], stop: ptr[u8]) -> i64;

def signed_char(c: u8) -> i64;

def is_digit(c: i64) -> bool;

def hex_digit_value(c: u8) -> i64;

def hex_char(x: i64) -> u8;

def config_bytes_warning -> i32;

def buffer_slot -> ptr[Py_buffer];

def buffer_free(view: ptr[Py_buffer]);

def lookup_bytes_method(v: ptr[PyObject]) -> ptr[PyObject];

def ssize_arg(value: ptr[PyObject]) -> tuple[bool, i64];

def bytes_from_size(size: i64, use_calloc: bool) -> ptr[PyObject];

def bytes_resize(v: ptr[PyObject], newsize: i64) -> ptr[PyObject];

import from c {
    def PyBytes_FromStringAndSize(data: ptr[u8], size: i64) -> ptr[PyObject] {
        if size < 0 {
            PyErr_SetString(
                PyExc_SystemError, "Negative size passed to PyBytes_FromStringAndSize"
            );
            return NULL;
        }
        if size == 1 and data {
            return bytes_character(peek(data));
        }
        if size == 0 {
            return bytes_get_empty();
        }
        op = bytes_from_size(size, False);
        if not op or not data {
            return op;
        }
        memcpy(ptr(bytes_sval(op)), ptr(data), u64(size));
        return op;
    }  def PyBytes_FromString(data: ptr[u8]) -> ptr[PyObject] {
        size = i64(strlen(data));
        if size > PY_SSIZE_T_MAX - bytes_header_size() {
            PyErr_SetString(PyExc_OverflowError, "byte string is too long");
            return NULL;
        }
        if size == 0 {
            return bytes_get_empty();
        }
        if size == 1 {
            return bytes_character(peek(data));
        }

        raw = PyObject_Malloc(u64(bytes_header_size() + size));
        if not raw {
            return PyErr_NoMemory();
        }
        op = ptr[PyObject](raw);
        PyObject_InitVar(op, ptr[PyObject](bytes_type()), size);
        set_shash(op, -1);
        memcpy(ptr(bytes_sval(op)), ptr(data), u64(size + 1));
        return op;
    }  def _PyBytes_Resize(pv: ptr[ptr[PyObject]], newsize: i64) -> i32 {
        resized = bytes_resize(pv.view(1)[0], newsize);
        pv.view(1)[0] = resized;
        return i32(-1) if not resized else i32(0);
    }  def _PyBytes_Repeat(dest: ptr[u8], len_dest: i64, src: ptr[u8], len_src: i64) {
        if len_dest == 0 {
            return;
        }
        if len_src == 1 {
            memset(ptr(dest), i32(peek(src)), u64(len_dest));
            return;
        }
        if src != dest {
            memcpy(ptr(dest), ptr(src), u64(len_src));
        }

        copied = len_src;
        while copied < len_dest {
            bytes_to_copy = min(copied, len_dest - copied);
            memcpy(ptr(dest + copied), ptr(dest), u64(bytes_to_copy));
            copied += bytes_to_copy;
        }
    }
}

def writer_new -> ptr[BytesWriterHead];

def writer_free(writer: ptr[BytesWriterHead]);

def writer_scratch(writer: ptr[BytesWriterHead]) -> ptr[u8];

def writer_small_buffer(writer: ptr[BytesWriterHead]) -> ptr[u8];

def writer_finish(writer: ptr[BytesWriterHead], data: ptr[u8]) -> ptr[PyObject];

def writer_fail(writer: ptr[BytesWriterHead]) -> ptr[PyObject];

def writer_as_string(writer: ptr[BytesWriterHead]) -> ptr[u8];

import from c {
    def _PyBytesWriter_Init(writer: ptr[BytesWriterHead]) {
        memset(ptr(writer), i32(0), u64(_PyBytesWriter_SMALL_BUFFER));
    }  def _PyBytesWriter_Dealloc(writer: ptr[BytesWriterHead]) {
        buffer = writer.view(1)[0].buffer;
        writer.view(1)[0].buffer = NULL;
        object_xdecref(buffer);
    }  def _PyBytesWriter_Resize(
        writer: ptr[BytesWriterHead], data: ptr, size: i64
    ) -> ptr {
        allocated = size;
        if writer.view(1)[0].overallocate != i32(0)
            and allocated <= PY_SSIZE_T_MAX - allocated // OVERALLOCATE_FACTOR {
            allocated += allocated // OVERALLOCATE_FACTOR;
        }
        pos = span(writer_as_string(writer), ptr[u8](data));
        if writer.view(1)[0].use_small_buffer == i32(0) {
            if writer.view(1)[0].use_bytearray != i32(0) {
                if PyByteArray_Resize(writer.view(1)[0].buffer, allocated) != i32(0) {
                    _PyBytesWriter_Dealloc(writer);
                    return ptr();
                }
            } else {
                resized = bytes_resize(writer.view(1)[0].buffer, allocated);
                writer.view(1)[0].buffer = resized;
                if not resized {
                    _PyBytesWriter_Dealloc(writer);
                    return ptr();
                }
            }
        } else {
            created = NULL;
            if writer.view(1)[0].use_bytearray != i32(0) {
                created = PyByteArray_FromStringAndSize(ptr[u8](), allocated);
            } else {
                created = PyBytes_FromStringAndSize(ptr[u8](), allocated);
            }
            writer.view(1)[0].buffer = created;
            if not created {
                _PyBytesWriter_Dealloc(writer);
                return ptr();
            }
            if pos != 0 {
                dest = ptr[u8]();
                if writer.view(1)[0].use_bytearray != i32(0) {
                    dest = PyByteArray_AsString(created);
                } else {
                    dest = bytes_sval(created);
                }
                memcpy(ptr(dest), ptr(writer_small_buffer(writer)), u64(pos));
            }
            writer.view(1)[0].use_small_buffer = i32(0);
        }
        writer.view(1)[0].allocated = allocated;
        return ptr(writer_as_string(writer) + pos);
    }  def _PyBytesWriter_Prepare(
        writer: ptr[BytesWriterHead], data: ptr, size: i64
    ) -> ptr {
        if size == 0 {
            return data;
        }
        if writer.view(1)[0].min_size > PY_SSIZE_T_MAX - size {
            PyErr_NoMemory();
            _PyBytesWriter_Dealloc(writer);
            return ptr();
        }
        new_min_size = writer.view(1)[0].min_size + size;
        out = data;
        if new_min_size > writer.view(1)[0].allocated {
            out = _PyBytesWriter_Resize(writer, data, new_min_size);
        }
        writer.view(1)[0].min_size = new_min_size;
        return out;
    }  def _PyBytesWriter_Alloc(writer: ptr[BytesWriterHead], size: i64) -> ptr {
        writer.view(1)[0].use_small_buffer = i32(1);
        writer.view(1)[0].allocated = SMALL_BUFFER_SIZE;
        return _PyBytesWriter_Prepare(writer, ptr(writer_small_buffer(writer)), size);
    }  def _PyBytesWriter_Finish(
        writer: ptr[BytesWriterHead], data: ptr
    ) -> ptr[PyObject] {
        size = span(writer_as_string(writer), ptr[u8](data));
        if size == 0 and writer.view(1)[0].use_bytearray == i32(0) {
            buffer = writer.view(1)[0].buffer;
            writer.view(1)[0].buffer = NULL;
            object_xdecref(buffer);

            return bytes_get_empty();
        }
        if writer.view(1)[0].use_small_buffer != i32(0) {
            if writer.view(1)[0].use_bytearray != i32(0) {
                return PyByteArray_FromStringAndSize(writer_small_buffer(writer), size);
            }
            return PyBytes_FromStringAndSize(writer_small_buffer(writer), size);
        }
        result = writer.view(1)[0].buffer;
        writer.view(1)[0].buffer = NULL;
        if size != writer.view(1)[0].allocated {
            if writer.view(1)[0].use_bytearray != i32(0) {
                if PyByteArray_Resize(result, size) != i32(0) {
                    object_decref(result);
                    return NULL;
                }
            } else {
                result = bytes_resize(result, size);
            }
        }
        return result;
    }  def _PyBytesWriter_WriteBytes(
        writer: ptr[BytesWriterHead], data: ptr, source: ptr, size: i64
    ) -> ptr {
        out = ptr[u8](_PyBytesWriter_Prepare(writer, data, size));
        if not out {
            return ptr();
        }
        memcpy(ptr(out), source, u64(size));
        return ptr(out + size);
    }
}

def write_text(writer: ptr[BytesWriterHead], s: ptr[u8], text: ptr[u8]) -> ptr[u8];

import from c {
    def PyBytes_FromFormat(format: ptr[u8], *args: VaList) -> ptr[PyObject] {
        writer = writer_new();
        if not writer {
            return NULL;
        }
        s = ptr[u8](_PyBytesWriter_Alloc(writer, i64(strlen(format))));
        if not s {
            writer_free(writer);
            return NULL;
        }
        writer.view(1)[0].overallocate = i32(1);

        buffer = writer_scratch(writer);
        f = format;
        while peek(f) != u8(0) {
            if i64(peek(f)) != CH_PERCENT {
                poke(s, peek(f));
                s = s + 1;
                f = f + 1;
                continue;
            }
            p = f;
            f = f + 1;

            while py_isdigit(peek(f)) {
                f = f + 1;
            }

            prec: i64 = 0;
            if i64(peek(f)) == CH_DOT {
                f = f + 1;
                while py_isdigit(peek(f)) {
                    prec = prec * 10 + (i64(peek(f)) - CH_ZERO);
                    f = f + 1;
                }
            }
            while peek(f) != u8(0)
                and i64(peek(f)) != CH_PERCENT
                and not py_isalpha(peek(f)) {
                f = f + 1;
            }

            longflag = False;
            if i64(peek(f)) == CH_LOWER_L
                and (
                    i64(peek(f + 1)) == CH_LOWER_D or i64(peek(f + 1)) == CH_LOWER_U
                ) {
                longflag = True;
                f = f + 1;
            }

            size_tflag = False;
            if i64(peek(f)) == CH_LOWER_Z
                and (
                    i64(peek(f + 1)) == CH_LOWER_D or i64(peek(f + 1)) == CH_LOWER_U
                ) {
                size_tflag = True;
                f = f + 1;
            }

            writer.view(1)[0].min_size -= span(p, f) + 1;
            c = i64(peek(f));
            if c == CH_LOWER_C {
                ch = args.arg(i32);
                if ch < i32(0) or ch > i32(255) {
                    PyErr_SetString(
                        PyExc_OverflowError,
                        "PyBytes_FromFormatV(): %c format expects an integer in range [0; 255]"
                    );
                    return writer_fail(writer);
                }
                writer.view(1)[0].min_size += 1;
                poke(s, u8(ch));
                s = s + 1;
            } elif c == CH_LOWER_D {
                if longflag {
                    snprintf(
                        buffer, u64(WRITER_SCRATCH), ptr[u8]("%ld"), args.arg(i64)
                    );
                } elif size_tflag {
                    snprintf(
                        buffer, u64(WRITER_SCRATCH), ptr[u8]("%zd"), args.arg(i64)
                    );
                } else {
                    snprintf(buffer, u64(WRITER_SCRATCH), ptr[u8]("%d"), args.arg(i32));
                }
                s = write_text(writer, s, buffer);
                if not s {
                    return writer_fail(writer);
                }
            } elif c == CH_LOWER_U {
                if longflag {
                    snprintf(
                        buffer, u64(WRITER_SCRATCH), ptr[u8]("%lu"), args.arg(u64)
                    );
                } elif size_tflag {
                    snprintf(
                        buffer, u64(WRITER_SCRATCH), ptr[u8]("%zu"), args.arg(u64)
                    );
                } else {
                    snprintf(buffer, u64(WRITER_SCRATCH), ptr[u8]("%u"), args.arg(u32));
                }
                s = write_text(writer, s, buffer);
                if not s {
                    return writer_fail(writer);
                }
            } elif c == CH_LOWER_I {
                snprintf(buffer, u64(WRITER_SCRATCH), ptr[u8]("%i"), args.arg(i32));
                s = write_text(writer, s, buffer);
                if not s {
                    return writer_fail(writer);
                }
            } elif c == CH_LOWER_X {
                snprintf(buffer, u64(WRITER_SCRATCH), ptr[u8]("%x"), args.arg(i32));
                s = write_text(writer, s, buffer);
                if not s {
                    return writer_fail(writer);
                }
            } elif c == CH_LOWER_S {
                text = args.arg(ptr[u8]);
                n: i64 = 0;
                if prec <= 0 {
                    n = i64(strlen(text));
                } else {
                    while n < prec and peek(text + n) != u8(0) {
                        n += 1;
                    }
                }
                s = ptr[u8](_PyBytesWriter_WriteBytes(writer, ptr(s), ptr(text), n));
                if not s {
                    return writer_fail(writer);
                }
            } elif c == CH_LOWER_P {
                snprintf(buffer, u64(WRITER_SCRATCH), ptr[u8]("%p"), args.arg(ptr));
                if i64(peek(buffer + 1)) == CH_UPPER_X {
                    poke(buffer + 1, u8(CH_LOWER_X));
                } elif i64(peek(buffer + 1)) != CH_LOWER_X {
                    memmove(ptr(buffer + 2), ptr(buffer), strlen(buffer) + u64(1));
                    poke(buffer, u8(CH_ZERO));
                    poke(buffer + 1, u8(CH_LOWER_X));
                }
                s = write_text(writer, s, buffer);
                if not s {
                    return writer_fail(writer);
                }
            } elif c == CH_PERCENT {
                writer.view(1)[0].min_size += 1;
                poke(s, u8(CH_PERCENT));
                s = s + 1;
            } else {
                if c == CH_NUL {
                    writer.view(1)[0].min_size += 1;
                }
                s = write_text(writer, s, p);
                if not s {
                    return writer_fail(writer);
                }
                return writer_finish(writer, s);
            }
            f = f + 1;
        }
        return writer_finish(writer, s);
    }
}

def next_arg(
    args: ptr[PyObject], arglen: i64, argidx: i64
) -> tuple[ptr[PyObject], i64];

def format_float_text(v: ptr[PyObject], flags: i64, prec: i64, type: i64) -> ptr[u8];

def format_float_into(
    v: ptr[PyObject],
    flags: i64,
    prec: i64,
    type: i64,
    writer: ptr[BytesWriterHead],
    s: ptr[u8]
) -> ptr[u8];

def format_float_bytes(
    v: ptr[PyObject], flags: i64, prec: i64, type: i64
) -> ptr[PyObject];

def format_long(v: ptr[PyObject], flags: i64, prec: i64, type: i64) -> ptr[PyObject];

def byte_converter(arg: ptr[PyObject]) -> tuple[bool, u8];

def format_obj(v: ptr[PyObject]) -> tuple[ptr[PyObject], ptr[u8], i64];

def is_int_conversion(c: i64) -> bool;

def is_float_conversion(c: i64) -> bool;

def copy_prefix(res: ptr[u8], pbuf: ptr[u8]);

import from c {
    def _PyBytes_FormatEx(
        format: ptr[u8], format_len: i64, args_in: ptr[PyObject], use_bytearray: i32
    ) -> ptr[PyObject] {
        if not args_in {
            PyErr_BadInternalCall();
            return NULL;
        }
        args = args_in;
        fmt = format;
        fmtcnt = format_len;
        writer = writer_new();
        if not writer {
            return NULL;
        }
        writer.view(1)[0].use_bytearray = use_bytearray;
        res = ptr[u8](_PyBytesWriter_Alloc(writer, fmtcnt));
        if not res {
            writer_free(writer);
            return NULL;
        }
        if use_bytearray == i32(0) {
            writer.view(1)[0].overallocate = i32(1);
        }
        arglen: i64 = -1;
        argidx: i64 = -2;
        if tuple_check(args) {
            arglen = object_size(args);
            argidx = 0;
        }
        dict = NULL;
        mapping = object_type(args).view(1)[0].tp_as_mapping;
        if mapping
            and int(mapping.view(1)[0].mp_subscript) != 0
            and not tuple_check(args)
            and not bytes_check(args)
            and not unicode_check(args)
            and not bytearray_check(args) {
            dict = args;
        }
        args_owned = False;

        onechar = writer_scratch(writer);
        failed = False;
        while True {
            fmtcnt -= 1;
            if fmtcnt < 0 {
                break;
            }
            if i64(peek(fmt)) != CH_PERCENT {
                pos = ptr[u8](memchr(ptr(fmt + 1), i32(CH_PERCENT), u64(fmtcnt)));
                run = fmtcnt + 1;
                if pos {
                    run = span(fmt, pos);
                }
                memcpy(ptr(res), ptr(fmt), u64(run));
                res = res + run;
                fmt = fmt + run;
                fmtcnt -= run - 1;
                continue;
            }

            flags: i64 = 0;
            width: i64 = -1;
            prec: i64 = -1;
            c: i64 = 0;
            fill = CH_SPACE;
            v = NULL;
            temp = NULL;
            pbuf = ptr[u8]();
            sign: i64 = 0;
            length: i64 = 0;
            fmt = fmt + 1;
            if i64(peek(fmt)) == CH_PERCENT {
                poke(res, u8(CH_PERCENT));
                res = res + 1;
                fmt = fmt + 1;
                fmtcnt -= 1;
                continue;
            }
            if i64(peek(fmt)) == CH_LPAREN {
                if not dict {
                    PyErr_SetString(PyExc_TypeError, "format requires a mapping");
                    failed = True;
                    break;
                }
                fmt = fmt + 1;
                fmtcnt -= 1;
                keystart = fmt;
                pcount = 1;

                while pcount > 0 {
                    fmtcnt -= 1;
                    if fmtcnt < 0 {
                        break;
                    }
                    if i64(peek(fmt)) == CH_RPAREN {
                        pcount -= 1;
                    } elif i64(peek(fmt)) == CH_LPAREN {
                        pcount += 1;
                    }
                    fmt = fmt + 1;
                }
                keylen = span(keystart, fmt) - 1;
                if fmtcnt < 0 or pcount > 0 {
                    PyErr_SetString(PyExc_ValueError, "incomplete format key");
                    failed = True;
                    break;
                }
                key = PyBytes_FromStringAndSize(keystart, keylen);
                if not key {
                    failed = True;
                    break;
                }
                if args_owned {
                    object_decref(args);
                    args_owned = False;
                }
                args = PyObject_GetItem(dict, key);
                object_decref(key);
                if not args {
                    failed = True;
                    break;
                }
                args_owned = True;
                arglen = -1;
                argidx = -2;
            }

            while True {
                fmtcnt -= 1;
                if fmtcnt < 0 {
                    break;
                }
                c = signed_char(peek(fmt));
                fmt = fmt + 1;
                if c == CH_MINUS {
                    flags = flags | F_LJUST;
                } elif c == CH_PLUS {
                    flags = flags | F_SIGN;
                } elif c == CH_SPACE {
                    flags = flags | F_BLANK;
                } elif c == CH_HASH {
                    flags = flags | F_ALT;
                } elif c == CH_ZERO {
                    flags = flags | F_ZERO;
                } else {
                    break;
                }
            }

            if c == CH_STAR {
                (v, argidx) = next_arg(args, arglen, argidx);
                if not v {
                    failed = True;
                    break;
                }
                if not long_check(v) {
                    PyErr_SetString(PyExc_TypeError, "* wants int");
                    failed = True;
                    break;
                }
                width = PyLong_AsSsize_t(v);
                if width == -1 and PyErr_Occurred() {
                    failed = True;
                    break;
                }
                if width < 0 {
                    flags = flags | F_LJUST;
                    width = wrapping_sub(i64(0), width);
                }
                fmtcnt -= 1;
                if fmtcnt >= 0 {
                    c = signed_char(peek(fmt));
                    fmt = fmt + 1;
                }
            } elif c >= 0 and is_digit(c) {
                width = c - CH_ZERO;
                while True {
                    fmtcnt -= 1;
                    if fmtcnt < 0 {
                        break;
                    }
                    c = i64(peek(fmt));
                    fmt = fmt + 1;
                    if not is_digit(c) {
                        break;
                    }
                    if width > (PY_SSIZE_T_MAX - (c - CH_ZERO)) // 10 {
                        PyErr_SetString(PyExc_ValueError, "width too big");
                        failed = True;
                        break;
                    }
                    width = width * 10 + (c - CH_ZERO);
                }
                if failed {
                    break;
                }
            }

            if c == CH_DOT {
                prec = 0;
                fmtcnt -= 1;
                if fmtcnt >= 0 {
                    c = signed_char(peek(fmt));
                    fmt = fmt + 1;
                }
                if c == CH_STAR {
                    (v, argidx) = next_arg(args, arglen, argidx);
                    if not v {
                        failed = True;
                        break;
                    }
                    if not long_check(v) {
                        PyErr_SetString(PyExc_TypeError, "* wants int");
                        failed = True;
                        break;
                    }
                    prec = i64(PyLong_AsInt(v));
                    if prec == -1 and PyErr_Occurred() {
                        failed = True;
                        break;
                    }
                    if prec < 0 {
                        prec = 0;
                    }
                    fmtcnt -= 1;
                    if fmtcnt >= 0 {
                        c = signed_char(peek(fmt));
                        fmt = fmt + 1;
                    }
                } elif c >= 0 and is_digit(c) {
                    prec = c - CH_ZERO;
                    while True {
                        fmtcnt -= 1;
                        if fmtcnt < 0 {
                            break;
                        }
                        c = i64(peek(fmt));
                        fmt = fmt + 1;
                        if not is_digit(c) {
                            break;
                        }
                        if prec > (INT_MAX - (c - CH_ZERO)) // 10 {
                            PyErr_SetString(PyExc_ValueError, "prec too big");
                            failed = True;
                            break;
                        }
                        prec = prec * 10 + (c - CH_ZERO);
                    }
                    if failed {
                        break;
                    }
                }
            }
            if fmtcnt >= 0 {
                if c == CH_LOWER_H or c == CH_LOWER_L or c == CH_UPPER_L {
                    fmtcnt -= 1;
                    if fmtcnt >= 0 {
                        c = signed_char(peek(fmt));
                        fmt = fmt + 1;
                    }
                }
            }
            if fmtcnt < 0 {
                PyErr_SetString(PyExc_ValueError, "incomplete format");
                failed = True;
                break;
            }
            (v, argidx) = next_arg(args, arglen, argidx);
            if not v {
                failed = True;
                break;
            }
            if fmtcnt == 0 {
                writer.view(1)[0].overallocate = i32(0);
            }
            sign = 0;
            fill = CH_SPACE;
            if c == CH_LOWER_R or c == CH_LOWER_A {
                temp = PyObject_ASCII(v);
                if not temp {
                    failed = True;
                    break;
                }
                pbuf = ptr[u8](jacpy_unicode_data(temp));
                length = PyUnicode_GetLength(temp);
                if prec >= 0 and length > prec {
                    length = prec;
                }
            } elif c == CH_LOWER_S or c == CH_LOWER_B {
                (temp, pbuf, length) = format_obj(v);
                if not temp {
                    failed = True;
                    break;
                }
                if prec >= 0 and length > prec {
                    length = prec;
                }
            } elif is_int_conversion(c) {
                if long_check_exact(v)
                    and width == -1
                    and prec == -1
                    and (flags & (F_SIGN | F_BLANK)) == 0
                    and c != CH_UPPER_X {
                    base = i32(10);
                    if c == CH_LOWER_O {
                        base = i32(8);
                    } elif c == CH_LOWER_X {
                        base = i32(16);
                    }

                    writer.view(1)[0].min_size -= 2;
                    res = _PyLong_FormatBytesWriter(
                        writer, res, v, base, i32(flags & F_ALT)
                    );
                    if not res {
                        failed = True;
                        break;
                    }
                    continue;
                }
                temp = format_long(v, flags, prec, c);
                if not temp {
                    failed = True;
                    break;
                }
                pbuf = ptr[u8](jacpy_unicode_data(temp));
                length = PyUnicode_GetLength(temp);
                sign = 1;
                if (flags & F_ZERO) != 0 {
                    fill = CH_ZERO;
                }
            } elif is_float_conversion(c) {
                if width == -1 and prec == -1 and (flags & (F_SIGN | F_BLANK)) == 0 {
                    writer.view(1)[0].min_size -= 2;
                    res = format_float_into(v, flags, prec, c, writer, res);
                    if not res {
                        failed = True;
                        break;
                    }
                    continue;
                }
                temp = format_float_bytes(v, flags, prec, c);
                if not temp {
                    failed = True;
                    break;
                }
                pbuf = bytes_sval(temp);
                length = object_size(temp);
                sign = 1;
                if (flags & F_ZERO) != 0 {
                    fill = CH_ZERO;
                }
            } elif c == CH_LOWER_C {
                (converted, onebyte) = byte_converter(v);
                if not converted {
                    failed = True;
                    break;
                }
                poke(onechar, onebyte);
                pbuf = onechar;
                length = 1;
                if width == -1 {
                    poke(res, onebyte);
                    res = res + 1;
                    continue;
                }
            } else {
                PyErr_Format(
                    PyExc_ValueError,
                    "unsupported format character '%c' (0x%x) at index %zd",
                    i32(c),
                    i32(c),
                    span(format, fmt) - 1
                );
                failed = True;
                break;
            }
            if sign != 0 {
                first = i64(peek(pbuf));
                if first == CH_MINUS or first == CH_PLUS {
                    sign = first;
                    pbuf = pbuf + 1;
                    length -= 1;
                } elif (flags & F_SIGN) != 0 {
                    sign = CH_PLUS;
                } elif (flags & F_BLANK) != 0 {
                    sign = CH_SPACE;
                } else {
                    sign = 0;
                }
            }
            if width < length {
                width = length;
            }
            alloc = width;
            if sign != 0 and length == width {
                alloc += 1;
            }

            if alloc > 2 {
                res = ptr[u8](_PyBytesWriter_Prepare(writer, ptr(res), alloc - 2));
                if not res {
                    object_xdecref(temp);
                    failed = True;
                    break;
                }
            }

            if sign != 0 {
                if fill != CH_SPACE {
                    poke(res, u8(sign));
                    res = res + 1;
                }
                if width > length {
                    width -= 1;
                }
            }

            alt_prefix = (flags & F_ALT) != 0
                and (c == CH_LOWER_O or c == CH_LOWER_X or c == CH_UPPER_X);
            if alt_prefix {
                if fill != CH_SPACE {
                    copy_prefix(res, pbuf);
                    res = res + 2;
                    pbuf = pbuf + 2;
                }
                width -= 2;
                if width < 0 {
                    width = 0;
                }
                length -= 2;
            }

            if width > length and (flags & F_LJUST) == 0 {
                memset(ptr(res), i32(fill), u64(width - length));
                res = res + (width - length);
                width = length;
            }

            if fill == CH_SPACE {
                if sign != 0 {
                    poke(res, u8(sign));
                    res = res + 1;
                }
                if alt_prefix {
                    copy_prefix(res, pbuf);
                    res = res + 2;
                    pbuf = pbuf + 2;
                }
            }

            memcpy(ptr(res), ptr(pbuf), u64(length));
            res = res + length;

            if width > length {
                memset(ptr(res), i32(CH_SPACE), u64(width - length));
                res = res + (width - length);
            }
            if dict and argidx < arglen {
                PyErr_SetString(
                    PyExc_TypeError,
                    "not all arguments converted during bytes formatting"
                );
                object_xdecref(temp);
                failed = True;
                break;
            }
            object_xdecref(temp);
        }
        if not failed and argidx < arglen and not dict {
            PyErr_SetString(
                PyExc_TypeError, "not all arguments converted during bytes formatting"
            );
            failed = True;
        }
        if args_owned {
            object_decref(args);
        }
        if failed {
            return writer_fail(writer);
        }
        return writer_finish(writer, res);
    }
}

def decode_escape(
    s_in: ptr[u8], length: i64, errors: ptr[u8]
) -> tuple[ptr[PyObject], i32, ptr[u8]];

import from c {
    def _PyBytes_DecodeEscape2(
        s: ptr[u8],
        length: i64,
        errors: ptr[u8],
        first_invalid_escape_char: ptr[i32],
        first_invalid_escape_ptr: ptr[ptr[u8]]
    ) -> ptr[PyObject] {
        (result, first_char, first_ptr) = decode_escape(s, length, errors);
        first_invalid_escape_char.view(1)[0] = first_char;
        first_invalid_escape_ptr.view(1)[0] = first_ptr;
        return result;
    }  def PyBytes_DecodeEscape(
        s: ptr[u8], length: i64, errors: ptr[u8], unicode: i64, recode_encoding: ptr[u8]
    ) -> ptr[PyObject] {
        (result, first_char, first_ptr) = decode_escape(s, length, errors);
        if not result {
            return NULL;
        }
        if first_char != i32(-1) {
            warned = i32(0);
            if first_char > i32(0xff) {
                warned = PyErr_WarnFormat(
                    PyExc_DeprecationWarning,
                    1,
                    "b\"\\%o\" is an invalid octal escape sequence. Such sequences will not work in the future. ",
                    first_char
                );
            } else {
                warned = PyErr_WarnFormat(
                    PyExc_DeprecationWarning,
                    1,
                    "b\"\\%c\" is an invalid escape sequence. Such sequences will not work in the future. ",
                    first_char
                );
            }
            if warned < i32(0) {
                object_decref(result);
                return NULL;
            }
        }
        return result;
    }
}

def expected_bytes(op: ptr[PyObject]);

import from c {
    def PyBytes_Size(op: ptr[PyObject]) -> i64 {
        if not bytes_check(op) {
            expected_bytes(op);
            return -1;
        }
        return object_size(op);
    }  def PyBytes_AsString(op: ptr[PyObject]) -> ptr[u8] {
        if not bytes_check(op) {
            expected_bytes(op);
            return ptr[u8]();
        }
        return bytes_sval(op);
    }  def PyBytes_AsStringAndSize(
        op: ptr[PyObject], s: ptr[ptr[u8]], length: ptr[i64]
    ) -> i32 {
        if not s {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        if not bytes_check(op) {
            expected_bytes(op);
            return i32(-1);
        }
        s.view(1)[0] = bytes_sval(op);
        if length {
            length.view(1)[0] = object_size(op);
        } elif i64(strlen(bytes_sval(op))) != object_size(op) {
            PyErr_SetString(PyExc_ValueError, "embedded null byte");
            return i32(-1);
        }
        return i32(0);
    }  def _PyBytes_Find(
        haystack: ptr[u8],
        len_haystack: i64,
        needle: ptr[u8],
        len_needle: i64,
        offset: i64
    ) -> i64 {
        if len_needle == 0 {
            return offset;
        }
        if len_needle > len_haystack {
            return -1;
        }
        res = bl_find(haystack, len_haystack - 1, needle, len_needle, offset);
        if res == -1 {
            last_align = len_haystack - len_needle;
            if memcmp(ptr(haystack + last_align), ptr(needle), u64(len_needle))
                == i32(0) {
                return offset + last_align;
            }
        }
        return res;
    }  def _PyBytes_ReverseFind(
        haystack: ptr[u8],
        len_haystack: i64,
        needle: ptr[u8],
        len_needle: i64,
        offset: i64
    ) -> i64 {
        return bl_rfind(haystack, len_haystack, needle, len_needle, offset);
    }  def PyBytes_Repr(op: ptr[PyObject], smartquotes: i32) -> ptr[PyObject] {
        length = object_size(op);
        s = bytes_sval(op);

        squotes: i64 = 0;
        dquotes: i64 = 0;

        newsize: i64 = 3;
        for i in range(length) {
            c = i64(peek(s + i));
            incr: i64 = 1;
            if c == CH_QUOTE {
                squotes += 1;
            } elif c == CH_DQUOTE {
                dquotes += 1;
            } elif c == CH_BACKSLASH
                or c == CH_TAB
                or c == CH_NEWLINE
                or c == CH_RETURN {
                incr = 2;
            } elif c < CH_SPACE or c >= CH_DEL {
                incr = 4;
            }
            if newsize > PY_SSIZE_T_MAX - incr {
                PyErr_SetString(
                    PyExc_OverflowError, "bytes object is too large to make repr"
                );
                return NULL;
            }
            newsize += incr;
        }
        quote = CH_QUOTE;
        if smartquotes != i32(0) and squotes != 0 and dquotes == 0 {
            quote = CH_DQUOTE;
        }
        if squotes != 0 and quote == CH_QUOTE {
            if newsize > PY_SSIZE_T_MAX - squotes {
                PyErr_SetString(
                    PyExc_OverflowError, "bytes object is too large to make repr"
                );
                return NULL;
            }
            newsize += squotes;
        }
        v = PyUnicode_New(newsize, u32(127));
        if not v {
            return NULL;
        }
        p = ptr[u8](jacpy_unicode_data(v));
        poke(p, u8(CH_LOWER_B));
        poke(p + 1, u8(quote));
        p = p + 2;
        for i in range(length) {
            c = i64(peek(s + i));
            if c == quote or c == CH_BACKSLASH {
                poke(p, u8(CH_BACKSLASH));
                poke(p + 1, u8(c));
                p = p + 2;
            } elif c == CH_TAB {
                poke(p, u8(CH_BACKSLASH));
                poke(p + 1, u8(CH_LOWER_T));
                p = p + 2;
            } elif c == CH_NEWLINE {
                poke(p, u8(CH_BACKSLASH));
                poke(p + 1, u8(CH_LOWER_N));
                p = p + 2;
            } elif c == CH_RETURN {
                poke(p, u8(CH_BACKSLASH));
                poke(p + 1, u8(CH_LOWER_R));
                p = p + 2;
            } elif c < CH_SPACE or c >= CH_DEL {
                poke(p, u8(CH_BACKSLASH));
                poke(p + 1, u8(CH_LOWER_X));
                poke(p + 2, hex_char((c & 0xf0) >> 4));
                poke(p + 3, hex_char(c & 0xf));
                p = p + 4;
            } else {
                poke(p, u8(c));
                p = p + 1;
            }
        }
        poke(p, u8(quote));
        return v;
    }  def PyBytes_Join(sep: ptr[PyObject], iterable: ptr[PyObject]) -> ptr[PyObject] {
        if not sep {
            PyErr_BadInternalCall();
            return NULL;
        }
        if not bytes_check(sep) {
            PyErr_Format(PyExc_TypeError, "sep: expected bytes, got %T", sep);
            return NULL;
        }
        return bl_bytes_join(sep, iterable);
    }  def PyBytes_Concat(pv: ptr[ptr[PyObject]], w: ptr[PyObject]) {
        v = pv.view(1)[0];
        if not v {
            return;
        }
        if not w {
            pv.view(1)[0] = NULL;
            object_decref(v);
            return;
        }
        if object_refcount(v) != 1 or not bytes_check_exact(v) {
            pv.view(1)[0] = bytes_concat(v, w);
            object_decref(v);
            return;
        }

        wb = buffer_slot();
        if not wb {
            pv.view(1)[0] = NULL;
            object_decref(v);
            return;
        }
        if PyObject_GetBuffer(w, wb, PyBUF_SIMPLE) != i32(0) {
            PyErr_Format(
                PyExc_TypeError,
                "can't concat %.100s to %.100s",
                object_type(w).view(1)[0].tp_name,
                object_type(v).view(1)[0].tp_name
            );
            buffer_free(wb);
            pv.view(1)[0] = NULL;
            object_decref(v);
            return;
        }
        oldsize = object_size(v);
        addsize = wb.view(1)[0].length;
        if oldsize > PY_SSIZE_T_MAX - addsize {
            PyErr_NoMemory();
            buffer_free(wb);
            pv.view(1)[0] = NULL;
            object_decref(v);
            return;
        }
        resized = bytes_resize(v, oldsize + addsize);
        pv.view(1)[0] = resized;
        if resized {
            memcpy(ptr(bytes_sval(resized) + oldsize), wb.view(1)[0].buf, u64(addsize));
        }
        buffer_free(wb);
    }  def PyBytes_ConcatAndDel(pv: ptr[ptr[PyObject]], w: ptr[PyObject]) {
        PyBytes_Concat(pv, w);
        object_xdecref(w);
    }
}

def bytes_from_buffer(x: ptr[PyObject]) -> ptr[PyObject];

def byte_in_range(value: i64) -> bool;

def bytes_from_list(x: ptr[PyObject]) -> ptr[PyObject];

def bytes_from_tuple(x: ptr[PyObject]) -> ptr[PyObject];

def bytes_from_iterator(it: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject];

def first_non_ascii(text: ptr[PyObject], length: i64) -> i64;

def fromhex_error(invalid_char: i64);

import from c {
    def PyBytes_FromObject(x: ptr[PyObject]) -> ptr[PyObject] {
        if not x {
            PyErr_BadInternalCall();
            return NULL;
        }
        if bytes_check_exact(x) {
            return object_new_ref(x);
        }

        if PyObject_CheckBuffer(x) != i32(0) {
            return bytes_from_buffer(x);
        }
        if list_check_exact(x) {
            return bytes_from_list(x);
        }
        if tuple_check_exact(x) {
            return bytes_from_tuple(x);
        }
        if not unicode_check(x) {
            it = PyObject_GetIter(x);
            if it {
                result = bytes_from_iterator(it, x);
                object_decref(it);
                return result;
            }
            if PyErr_ExceptionMatches(PyExc_TypeError) == i32(0) {
                return NULL;
            }
        }
        PyErr_Format(
            PyExc_TypeError,
            "cannot convert '%.200s' object to bytes",
            object_type(x).view(1)[0].tp_name
        );
        return NULL;
    }  def _PyBytes_FromHex(
        string: ptr[PyObject], use_bytearray: i32
    ) -> ptr[PyObject] {
        view = ptr[Py_buffer]();
        hexlen: i64 = 0;
        data = ptr[u8]();
        if unicode_check(string) {
            hexlen = PyUnicode_GetLength(string);
            invalid = first_non_ascii(string, hexlen);
            if invalid != -1 {
                fromhex_error(invalid);
                return NULL;
            }
            data = ptr[u8](jacpy_unicode_data(string));
        } elif PyObject_CheckBuffer(string) != i32(0) {
            view = buffer_slot();
            if not view {
                return NULL;
            }
            if PyObject_GetBuffer(string, view, PyBUF_SIMPLE) != i32(0) {
                buffer_free(view);
                return NULL;
            }
            hexlen = view.view(1)[0].length;
            data = ptr[u8](view.view(1)[0].buf);
        } else {
            PyErr_Format(
                PyExc_TypeError,
                "fromhex() argument must be str or bytes-like, not %T",
                string
            );
            return NULL;
        }
        writer = writer_new();
        if not writer {
            if view {
                buffer_free(view);
            }
            return NULL;
        }
        writer.view(1)[0].use_bytearray = use_bytearray;

        buf = ptr[u8](_PyBytesWriter_Alloc(writer, hexlen // 2));
        if not buf {
            writer_free(writer);
            if view {
                buffer_free(view);
            }
            return NULL;
        }

        invalid_char: i64 = -2;
        s = data;
        end = data + hexlen;
        while s < end {
            if py_isspace(peek(s)) {
                s = s + 1;
                while s < end and py_isspace(peek(s)) {
                    s = s + 1;
                }
                if s >= end {
                    break;
                }
            }
            top = hex_digit_value(peek(s));
            if top >= 16 {
                invalid_char = span(data, s);
                break;
            }
            s = s + 1;

            if s >= end {
                invalid_char = -1;
                break;
            }
            bot = hex_digit_value(peek(s));
            if bot >= 16 {
                invalid_char = span(data, s);
                break;
            }
            s = s + 1;
            poke(buf, u8((top << 4) + bot));
            buf = buf + 1;
        }
        if invalid_char != -2 {
            fromhex_error(invalid_char);
            _PyBytesWriter_Dealloc(writer);
            writer_free(writer);
            if view {
                buffer_free(view);
            }
            return NULL;
        }
        if view {
            buffer_free(view);
        }
        return writer_finish(writer, buf);
    }
}

def bytes_repr(op: ptr[PyObject]) -> ptr[PyObject];

def bytes_str(op: ptr[PyObject]) -> ptr[PyObject];

def bytes_length(op: ptr[PyObject]) -> i64;

def bytes_concat(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def bytes_repeat(op: ptr[PyObject], count: i64) -> ptr[PyObject];

def bytes_contains(op: ptr[PyObject], arg: ptr[PyObject]) -> i32;

def bytes_item(op: ptr[PyObject], i: i64) -> ptr[PyObject];

def bytes_compare_eq(a: ptr[PyObject], b: ptr[PyObject]) -> bool;

def bytes_richcompare(aa: ptr[PyObject], bb: ptr[PyObject], op: i32) -> ptr[PyObject];

def bytes_hash(op: ptr[PyObject]) -> i64;

def bytes_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def bytes_buffer_getbuffer(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def bytes_mod(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def bytes_alloc(type: ptr[PyTypeObject], nitems: i64) -> ptr[PyObject];

def bytes_subtype_new(type: ptr[PyTypeObject], tmp: ptr[PyObject]) -> ptr[PyObject];

def bytes_getnewargs(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def bytes___bytes__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def bytes_capitalize(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_isalnum(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_isalpha(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_isascii(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_isdigit(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_islower(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_isspace(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_istitle(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_isupper(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_lower(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_upper(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_swapcase(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_title(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def bytes_expandtabs(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bytes_ljust(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_rjust(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_center(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_zfill(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def split_impl(
    op: ptr[PyObject], sep: ptr[PyObject], maxsplit_in: i64, reverse: bool
) -> ptr[PyObject];

def split_with(
    op: ptr[PyObject], sep: ptr[PyObject], maxsplit_obj: ptr[PyObject], reverse: bool
) -> ptr[PyObject];

def bytes_split_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_rsplit_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_split(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bytes_rsplit(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def partition_with(
    op: ptr[PyObject], arg: ptr[PyObject], reverse: bool
) -> ptr[PyObject];

def bytes_partition(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def bytes_rpartition(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def bytes_join(op: ptr[PyObject], iterable_of_bytes: ptr[PyObject]) -> ptr[PyObject];

def slice_bounds(args: ptr[ptr[PyObject]], nargs: i64) -> tuple[bool, i64, i64];

def bytes_find(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_rfind(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_rindex(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_count(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_startswith(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_endswith(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def do_xstrip(
    op: ptr[PyObject], striptype: i64, sepobj: ptr[PyObject]
) -> ptr[PyObject];

def do_strip(op: ptr[PyObject], striptype: i64) -> ptr[PyObject];

def do_argstrip(
    op: ptr[PyObject], striptype: i64, chars: ptr[PyObject]
) -> ptr[PyObject];

def bytes_strip(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_lstrip(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_rstrip(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def translate_with(
    op: ptr[PyObject],
    table: ptr[PyObject],
    deletechars: ptr[PyObject],
    table_view: ptr[Py_buffer],
    del_table_view: ptr[Py_buffer]
) -> ptr[PyObject];

def bytes_translate_impl(
    op: ptr[PyObject], table: ptr[PyObject], deletechars: ptr[PyObject]
) -> ptr[PyObject];

def bytes_translate_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_translate(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bytes_maketrans(
    _null: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytes_replace(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def remove_affix(op: ptr[PyObject], arg: ptr[PyObject], suffix: bool) -> ptr[PyObject];

def bytes_removeprefix(op: ptr[PyObject], prefix: ptr[PyObject]) -> ptr[PyObject];

def bytes_removesuffix(op: ptr[PyObject], suffix: ptr[PyObject]) -> ptr[PyObject];

def text_arg(value: ptr[PyObject], which: i64) -> tuple[bool, ptr[u8]];

def decode_with(
    op: ptr[PyObject], encoding_obj: ptr[PyObject], errors_obj: ptr[PyObject]
) -> ptr[PyObject];

def bytes_decode_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_decode(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def splitlines_with(op: ptr[PyObject], keepends_obj: ptr[PyObject]) -> ptr[PyObject];

def bytes_splitlines_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_splitlines(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bytes_fromhex(type: ptr[PyObject], string: ptr[PyObject]) -> ptr[PyObject];

def hex_with(
    op: ptr[PyObject], sep: ptr[PyObject], per_sep_obj: ptr[PyObject]
) -> ptr[PyObject];

def bytes_hex_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_hex(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bytes_new_impl(
    type: ptr[PyTypeObject], x: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject];

def bytes_new_bound(args: BoundArguments) -> ptr[PyObject];

def bytes_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def striter_of(op: ptr[PyObject]) -> ptr[striterobject];

def striter_seq(op: ptr[PyObject]) -> ptr[PyObject];

def striter_dealloc(op: ptr[PyObject]);

def striter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def striter_next(op: ptr[PyObject]) -> ptr[PyObject];

def striter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def striter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def striter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

def bytes_iter(seq: ptr[PyObject]) -> ptr[PyObject];

impl bytes_type -> ptr[PyTypeObject] {
    return addressof(PyBytes_Type);
}

impl bytes_of(op: ptr[PyObject]) -> ptr[PyBytesObject] {
    return ptr[PyBytesObject](op);
}

impl bytes_sval(op: ptr[PyObject]) -> ptr[u8] {
    return ptr[u8](op) + PyBytesObject_OB_SVAL;
}

impl bytes_header_size -> i64 {
    return PyBytesObject_OB_SVAL + 1;
}

impl get_shash(op: ptr[PyObject]) -> i64 {
    return bytes_of(op).view(1)[0].ob_shash;
}

impl set_shash(op: ptr[PyObject], hash: i64) {
    bytes_of(op).view(1)[0].ob_shash = hash;
}

impl set_size(op: ptr[PyObject], size: i64) {
    ptr[PyVarObject](op).view(1)[0].ob_size = size;
}

impl bytes_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BYTES_SUBCLASS);
}

impl bytes_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, bytes_type());
}

impl bytearray_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyByteArray_Type)));
}

impl unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl long_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_LONG_SUBCLASS);
}

impl long_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyLong_Type)));
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl tuple_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyTuple_Type)));
}

impl list_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PyList_Type)));
}

impl slice_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, ptr[PyTypeObject](addressof(PySlice_Type)));
}

impl bytes_get_empty -> ptr[PyObject] {
    return ptr[PyObject](int(addressof(_PyRuntime)) + _PyRuntimeState_BYTES_EMPTY);
}

impl bytes_character(ch: u8) -> ptr[PyObject] {
    return ptr[PyObject](
        int(addressof(_PyRuntime))
            + _PyRuntimeState_BYTES_CHARACTERS
            + i64(ch) * _PyRuntimeState_BYTES_CHARACTER_SIZE
    );
}

impl peek(p: ptr[u8]) -> u8 {
    return p.view(1)[0];
}

impl poke(p: ptr[u8], c: u8) {
    p.view(1)[0] = c;
}

impl span(start: ptr[u8], stop: ptr[u8]) -> i64 {
    return i64(int(stop) - int(start));
}

impl signed_char(c: u8) -> i64 {
    value = i64(c);
    return value - 256 if value >= 128 else value;
}

impl is_digit(c: i64) -> bool {
    return c >= CH_ZERO and c <= CH_NINE;
}

impl hex_digit_value(c: u8) -> i64 {
    code = i64(c);
    if code >= CH_ZERO and code <= CH_NINE {
        return code - CH_ZERO;
    }
    if code >= CH_LOWER_A and code <= CH_LOWER_F {
        return code - 87;
    }
    if code >= 65 and code <= CH_UPPER_F {
        return code - 55;
    }
    return 37;
}

impl hex_char(x: i64) -> u8 {
    return u8(48 + x) if x < 10 else u8(87 + x);
}

impl config_bytes_warning -> i32 {
    return ptr[i32](_Py_GetConfig() + PyConfig_BYTES_WARNING).view(1)[0];
}

impl buffer_slot -> ptr[Py_buffer] {
    view = ptr[Py_buffer](PyMem_Calloc(1, u64(PY_BUFFER_SIZE)));
    if not view {
        PyErr_NoMemory();
    }
    return view;
}

impl buffer_free(view: ptr[Py_buffer]) {
    PyBuffer_Release(view);
    PyMem_Free(ptr(view));
}

impl lookup_bytes_method(v: ptr[PyObject]) -> ptr[PyObject] {
    name = PyUnicode_InternFromString(ptr[u8]("__bytes__"));
    if not name {
        return NULL;
    }
    func = _PyObject_LookupSpecial(v, name);
    object_decref(name);
    return func;
}

impl ssize_arg(value: ptr[PyObject]) -> tuple[bool, i64] {
    ival: i64 = -1;
    iobj = _PyNumber_Index(value);
    if iobj {
        ival = PyLong_AsSsize_t(iobj);
        object_decref(iobj);
    }
    if ival == -1 and PyErr_Occurred() {
        return (False, ival);
    }
    return (True, ival);
}

impl bytes_from_size(size: i64, use_calloc: bool) -> ptr[PyObject] {
    if size == 0 {
        return bytes_get_empty();
    }
    if size > PY_SSIZE_T_MAX - bytes_header_size() {
        PyErr_SetString(PyExc_OverflowError, "byte string is too large");
        return NULL;
    }

    raw = ptr();
    if use_calloc {
        raw = PyObject_Calloc(u64(1), u64(bytes_header_size() + size));
    } else {
        raw = PyObject_Malloc(u64(bytes_header_size() + size));
    }
    if not raw {
        return PyErr_NoMemory();
    }
    op = ptr[PyObject](raw);
    PyObject_InitVar(op, ptr[PyObject](bytes_type()), size);
    set_shash(op, -1);
    if not use_calloc {
        poke(bytes_sval(op) + size, u8(0));
    }
    return op;
}

impl bytes_resize(v: ptr[PyObject], newsize: i64) -> ptr[PyObject] {
    if not v or not bytes_check(v) or newsize < 0 {
        object_xdecref(v);
        PyErr_BadInternalCall();
        return NULL;
    }
    oldsize = object_size(v);
    if oldsize == newsize {
        return v;
    }
    if oldsize == 0 {
        resized = bytes_from_size(newsize, False);
        object_decref(v);
        return resized;
    }
    if newsize == 0 {
        object_decref(v);
        return bytes_get_empty();
    }
    if object_refcount(v) != 1 {
        copy = NULL;
        if oldsize < newsize {
            copy = bytes_from_size(newsize, False);
            if copy {
                memcpy(ptr(bytes_sval(copy)), ptr(bytes_sval(v)), u64(oldsize));
            }
        } else {
            copy = PyBytes_FromStringAndSize(bytes_sval(v), newsize);
        }
        object_decref(v);
        return copy;
    }
    reftracer_track(v, PYREFTRACER_DESTROY);
    raw = PyObject_Realloc(ptr(v), u64(bytes_header_size()) + u64(newsize));
    if not raw {
        PyObject_Free(ptr(v));
        PyErr_NoMemory();
        return NULL;
    }
    sv = ptr[PyObject](raw);
    _Py_NewReferenceNoTotal(sv);
    set_size(sv, newsize);
    poke(bytes_sval(sv) + newsize, u8(0));

    set_shash(sv, -1);
    return sv;
}

impl writer_new -> ptr[BytesWriterHead] {
    writer = ptr[BytesWriterHead](
        PyMem_Malloc(u64(_PyBytesWriter_SIZE + WRITER_SCRATCH))
    );
    if not writer {
        PyErr_NoMemory();
        return writer;
    }
    _PyBytesWriter_Init(writer);
    return writer;
}

impl writer_free(writer: ptr[BytesWriterHead]) {
    PyMem_Free(ptr(writer));
}

impl writer_scratch(writer: ptr[BytesWriterHead]) -> ptr[u8] {
    return ptr[u8](writer) + _PyBytesWriter_SIZE;
}

impl writer_small_buffer(writer: ptr[BytesWriterHead]) -> ptr[u8] {
    return ptr[u8](writer) + _PyBytesWriter_SMALL_BUFFER;
}

impl writer_finish(writer: ptr[BytesWriterHead], data: ptr[u8]) -> ptr[PyObject] {
    result = _PyBytesWriter_Finish(writer, ptr(data));
    writer_free(writer);
    return result;
}

impl writer_fail(writer: ptr[BytesWriterHead]) -> ptr[PyObject] {
    _PyBytesWriter_Dealloc(writer);
    writer_free(writer);
    return NULL;
}

impl writer_as_string(writer: ptr[BytesWriterHead]) -> ptr[u8] {
    if writer.view(1)[0].use_small_buffer != i32(0) {
        return writer_small_buffer(writer);
    }
    if writer.view(1)[0].use_bytearray != i32(0) {
        return PyByteArray_AsString(writer.view(1)[0].buffer);
    }
    return bytes_sval(writer.view(1)[0].buffer);
}

impl write_text(writer: ptr[BytesWriterHead], s: ptr[u8], text: ptr[u8]) -> ptr[u8] {
    return ptr[u8](
        _PyBytesWriter_WriteBytes(writer, ptr(s), ptr(text), i64(strlen(text)))
    );
}

impl next_arg(
    args: ptr[PyObject], arglen: i64, argidx: i64
) -> tuple[ptr[PyObject], i64] {
    if argidx < arglen {
        if arglen < 0 {
            return (args, argidx + 1);
        }
        return (PyTuple_GetItem(args, argidx), argidx + 1);
    }
    PyErr_SetString(PyExc_TypeError, "not enough arguments for format string");
    return (NULL, argidx);
}

impl format_float_text(v: ptr[PyObject], flags: i64, prec: i64, type: i64) -> ptr[u8] {
    x = PyFloat_AsDouble(v);
    if x == -1.0 and PyErr_Occurred() {
        PyErr_Format(
            PyExc_TypeError,
            "float argument required, not %.200s",
            object_type(v).view(1)[0].tp_name
        );
        return ptr[u8]();
    }
    digits = prec;
    if digits < 0 {
        digits = 6;
    }
    dtoa_flags = i32(0);
    if (flags & F_ALT) != 0 {
        dtoa_flags = PY_DTSF_ALT;
    }
    return PyOS_double_to_string(x, i8(type), i32(digits), dtoa_flags, None);
}

impl format_float_into(
    v: ptr[PyObject],
    flags: i64,
    prec: i64,
    type: i64,
    writer: ptr[BytesWriterHead],
    s: ptr[u8]
) -> ptr[u8] {
    p = format_float_text(v, flags, prec, type);
    if not p {
        return p;
    }
    length = i64(strlen(p));
    out = ptr[u8](_PyBytesWriter_Prepare(writer, ptr(s), length));
    if not out {
        PyMem_Free(ptr(p));
        return out;
    }
    memcpy(ptr(out), ptr(p), u64(length));
    PyMem_Free(ptr(p));
    return out + length;
}

impl format_float_bytes(
    v: ptr[PyObject], flags: i64, prec: i64, type: i64
) -> ptr[PyObject] {
    p = format_float_text(v, flags, prec, type);
    if not p {
        return NULL;
    }
    result = PyBytes_FromStringAndSize(p, i64(strlen(p)));
    PyMem_Free(ptr(p));
    return result;
}

impl format_long(v: ptr[PyObject], flags: i64, prec: i64, type: i64) -> ptr[PyObject] {
    alt = i32(flags & F_ALT);
    integral = type == CH_LOWER_O or type == CH_LOWER_X or type == CH_UPPER_X;
    if long_check(v) {
        return _PyUnicode_FormatLong(v, alt, i32(prec), i32(type));
    }
    if PyNumber_Check(v) != i32(0) {
        iobj = NULL;
        if integral {
            iobj = _PyNumber_Index(v);
        } else {
            iobj = PyNumber_Long(v);
        }
        if iobj {
            result = _PyUnicode_FormatLong(iobj, alt, i32(prec), i32(type));
            object_decref(iobj);
            return result;
        }
        if PyErr_ExceptionMatches(PyExc_TypeError) == i32(0) {
            return NULL;
        }
    }
    required = ptr[u8]("a real number");
    if integral {
        required = ptr[u8]("an integer");
    }
    PyErr_Format(
        PyExc_TypeError,
        "%%%c format: %s is required, not %.200s",
        i32(type),
        required,
        object_type(v).view(1)[0].tp_name
    );
    return NULL;
}

impl byte_converter(arg: ptr[PyObject]) -> tuple[bool, u8] {
    if bytes_check(arg) {
        if object_size(arg) != 1 {
            PyErr_Format(
                PyExc_TypeError,
                "%%c requires an integer in range(256) or a single byte, not a bytes object of length %zd",
                object_size(arg)
            );
            return (False, u8(0));
        }
        return (True, peek(bytes_sval(arg)));
    }
    if bytearray_check(arg) {
        if object_size(arg) != 1 {
            PyErr_Format(
                PyExc_TypeError,
                "%%c requires an integer in range(256) or a single byte, not a bytearray object of length %zd",
                object_size(arg)
            );
            return (False, u8(0));
        }
        return (True, peek(PyByteArray_AsString(arg)));
    }
    if PyIndex_Check(arg) != i32(0) {
        overflow = i32(0);
        ival = PyLong_AsLongAndOverflow(arg, &mut overflow);
        if ival == -1 and PyErr_Occurred() {
            return (False, u8(0));
        }
        if not (0 <= ival and ival <= 255) {
            PyErr_SetString(PyExc_OverflowError, "%c arg not in range(256)");
            return (False, u8(0));
        }
        return (True, u8(ival));
    }
    PyErr_Format(
        PyExc_TypeError,
        "%%c requires an integer in range(256) or a single byte, not %T",
        arg
    );
    return (False, u8(0));
}

impl format_obj(v: ptr[PyObject]) -> tuple[ptr[PyObject], ptr[u8], i64] {
    if bytes_check(v) {
        return (object_new_ref(v), bytes_sval(v), object_size(v));
    }
    if bytearray_check(v) {
        return (object_new_ref(v), PyByteArray_AsString(v), object_size(v));
    }

    func = lookup_bytes_method(v);
    if func {
        result = PyObject_CallNoArgs(func);
        object_decref(func);
        if not result {
            return (NULL, ptr[u8](), 0);
        }
        if not bytes_check(result) {
            PyErr_Format(
                PyExc_TypeError,
                "__bytes__ returned non-bytes (type %.200s)",
                object_type(result).view(1)[0].tp_name
            );
            object_decref(result);
            return (NULL, ptr[u8](), 0);
        }
        return (result, bytes_sval(result), object_size(result));
    }

    if PyObject_CheckBuffer(v) != i32(0) {
        copy = bytes_from_buffer(v);
        if not copy {
            return (NULL, ptr[u8](), 0);
        }
        return (copy, bytes_sval(copy), object_size(copy));
    }
    PyErr_Format(
        PyExc_TypeError,
        "%%b requires a bytes-like object, or an object that implements __bytes__, not '%.100s'",
        object_type(v).view(1)[0].tp_name
    );
    return (NULL, ptr[u8](), 0);
}

impl is_int_conversion(c: i64) -> bool {
    return c == CH_LOWER_I
        or c == CH_LOWER_D
        or c == CH_LOWER_U
        or c == CH_LOWER_O
        or c == CH_LOWER_X
        or c == CH_UPPER_X;
}

impl is_float_conversion(c: i64) -> bool {
    return c == CH_LOWER_E
        or c == CH_UPPER_E
        or c == CH_LOWER_F
        or c == CH_UPPER_F
        or c == CH_LOWER_G
        or c == CH_UPPER_G;
}

impl copy_prefix(res: ptr[u8], pbuf: ptr[u8]) {
    poke(res, peek(pbuf));
    poke(res + 1, peek(pbuf + 1));
}

impl decode_escape(
    s_in: ptr[u8], length: i64, errors: ptr[u8]
) -> tuple[ptr[PyObject], i32, ptr[u8]] {
    first_char = i32(-1);
    first_ptr = ptr[u8]();
    writer = writer_new();
    if not writer {
        return (NULL, first_char, first_ptr);
    }
    p = ptr[u8](_PyBytesWriter_Alloc(writer, length));
    if not p {
        writer_free(writer);
        return (NULL, first_char, first_ptr);
    }
    writer.view(1)[0].overallocate = i32(1);
    s = s_in;
    end = s_in + length;
    while s < end {
        if i64(peek(s)) != CH_BACKSLASH {
            poke(p, peek(s));
            p = p + 1;
            s = s + 1;
            continue;
        }
        s = s + 1;
        if s == end {
            PyErr_SetString(PyExc_ValueError, "Trailing \\ in string");
            return (writer_fail(writer), first_char, first_ptr);
        }
        ch = i64(peek(s));
        s = s + 1;

        if ch == CH_NEWLINE {
            continue;
        }
        if ch == CH_BACKSLASH or ch == CH_QUOTE or ch == CH_DQUOTE {
            poke(p, u8(ch));
            p = p + 1;
        } elif ch == CH_LOWER_B {
            poke(p, u8(CH_BACKSPACE));
            p = p + 1;
        } elif ch == CH_LOWER_F {
            poke(p, u8(CH_FORMFEED));
            p = p + 1;
        } elif ch == CH_LOWER_T {
            poke(p, u8(CH_TAB));
            p = p + 1;
        } elif ch == CH_LOWER_N {
            poke(p, u8(CH_NEWLINE));
            p = p + 1;
        } elif ch == CH_LOWER_R {
            poke(p, u8(CH_RETURN));
            p = p + 1;
        } elif ch == CH_LOWER_V {
            poke(p, u8(CH_VTAB));
            p = p + 1;
        } elif ch == CH_LOWER_A {
            poke(p, u8(CH_BEL));
            p = p + 1;
        } elif ch >= CH_ZERO and ch <= CH_SEVEN {
            c = ch - CH_ZERO;
            if s < end and i64(peek(s)) >= CH_ZERO and i64(peek(s)) <= CH_SEVEN {
                c = (c << 3) + i64(peek(s)) - CH_ZERO;
                s = s + 1;
                if s < end and i64(peek(s)) >= CH_ZERO and i64(peek(s)) <= CH_SEVEN {
                    c = (c << 3) + i64(peek(s)) - CH_ZERO;
                    s = s + 1;
                }
            }
            if c > 255 and first_char == i32(-1) {
                first_char = i32(c);

                first_ptr = s - 3;
            }
            poke(p, u8(c & 0xFF));
            p = p + 1;
        } elif ch == CH_LOWER_X {
            if s + 1 < end {
                digit1 = hex_digit_value(peek(s));
                digit2 = hex_digit_value(peek(s + 1));
                if digit1 < 16 and digit2 < 16 {
                    poke(p, u8((digit1 << 4) + digit2));
                    p = p + 1;
                    s = s + 2;
                    continue;
                }
            }
            if not errors or strcmp(errors, ptr[u8]("strict")) == i32(0) {
                PyErr_Format(
                    PyExc_ValueError,
                    "invalid \\x escape at position %zd",
                    span(s_in, s) - 2
                );
                return (writer_fail(writer), first_char, first_ptr);
            }
            if strcmp(errors, ptr[u8]("replace")) == i32(0) {
                poke(p, u8(CH_QUESTION));
                p = p + 1;
            } elif strcmp(errors, ptr[u8]("ignore")) != i32(0) {
                PyErr_Format(
                    PyExc_ValueError,
                    "decoding error; unknown error handling code: %.400s",
                    errors
                );
                return (writer_fail(writer), first_char, first_ptr);
            }
            if s < end and py_isxdigit(peek(s)) {
                s = s + 1;
            }
        } else {
            if first_char == i32(-1) {
                first_char = i32(ch);

                first_ptr = s - 1;
            }
            poke(p, u8(CH_BACKSLASH));
            p = p + 1;
            s = s - 1;
        }
    }
    return (writer_finish(writer, p), first_char, first_ptr);
}

impl expected_bytes(op: ptr[PyObject]) {
    PyErr_Format(
        PyExc_TypeError,
        "expected bytes, %.200s found",
        object_type(op).view(1)[0].tp_name
    );
}

impl bytes_from_buffer(x: ptr[PyObject]) -> ptr[PyObject] {
    view = buffer_slot();
    if not view {
        return NULL;
    }
    if PyObject_GetBuffer(x, view, PyBUF_FULL_RO) < i32(0) {
        buffer_free(view);
        return NULL;
    }
    result = PyBytes_FromStringAndSize(ptr[u8](), view.view(1)[0].length);
    if result
        and PyBuffer_ToContiguous(
            ptr(bytes_sval(result)), view, view.view(1)[0].length, i8(67)
        )
            < i32(0) {
        object_decref(result);
        result = NULL;
    }
    buffer_free(view);
    return result;
}

impl byte_in_range(value: i64) -> bool {
    if value < 0 or value >= 256 {
        PyErr_SetString(PyExc_ValueError, "bytes must be in range(0, 256)");
        return False;
    }
    return True;
}

impl bytes_from_list(x: ptr[PyObject]) -> ptr[PyObject] {
    writer = writer_new();
    if not writer {
        return NULL;
    }
    s = ptr[u8](_PyBytesWriter_Alloc(writer, object_size(x)));
    if not s {
        writer_free(writer);
        return NULL;
    }
    writer.view(1)[0].overallocate = i32(1);
    size = writer.view(1)[0].allocated;
    i: i64 = 0;

    while i < object_size(x) {
        item = PyList_GetItemRef(x, i);
        if not item {
            return writer_fail(writer);
        }
        value = PyNumber_AsSsize_t(item, NULL);
        object_decref(item);
        if value == -1 and PyErr_Occurred() {
            return writer_fail(writer);
        }
        if not byte_in_range(value) {
            return writer_fail(writer);
        }
        if i >= size {
            s = ptr[u8](_PyBytesWriter_Resize(writer, ptr(s), size + 1));
            if not s {
                writer_free(writer);
                return NULL;
            }
            size = writer.view(1)[0].allocated;
        }
        poke(s, u8(value));
        s = s + 1;
        i += 1;
    }
    return writer_finish(writer, s);
}

impl bytes_from_tuple(x: ptr[PyObject]) -> ptr[PyObject] {
    size = object_size(x);
    result = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not result {
        return NULL;
    }
    s = bytes_sval(result);
    for i in range(size) {
        value = PyNumber_AsSsize_t(tuple_get_item(x, i), NULL);
        if value == -1 and PyErr_Occurred() {
            object_decref(result);
            return NULL;
        }
        if not byte_in_range(value) {
            object_decref(result);
            return NULL;
        }
        poke(s + i, u8(value));
    }
    return result;
}

impl bytes_from_iterator(it: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    size = PyObject_LengthHint(x, 64);
    if size == -1 and PyErr_Occurred() {
        return NULL;
    }
    writer = writer_new();
    if not writer {
        return NULL;
    }
    s = ptr[u8](_PyBytesWriter_Alloc(writer, size));
    if not s {
        writer_free(writer);
        return NULL;
    }
    writer.view(1)[0].overallocate = i32(1);
    size = writer.view(1)[0].allocated;

    i: i64 = 0;
    while True {
        item = PyIter_Next(it);
        if not item {
            if PyErr_Occurred() {
                return writer_fail(writer);
            }
            break;
        }

        value = PyNumber_AsSsize_t(item, NULL);
        object_decref(item);
        if value == -1 and PyErr_Occurred() {
            return writer_fail(writer);
        }
        if not byte_in_range(value) {
            return writer_fail(writer);
        }

        if i >= size {
            s = ptr[u8](_PyBytesWriter_Resize(writer, ptr(s), size + 1));
            if not s {
                writer_free(writer);
                return NULL;
            }
            size = writer.view(1)[0].allocated;
        }
        poke(s, u8(value));
        s = s + 1;
        i += 1;
    }
    return writer_finish(writer, s);
}

impl first_non_ascii(text: ptr[PyObject], length: i64) -> i64 {
    kind = jacpy_unicode_kind(text);
    data = ptr[u8](jacpy_unicode_data(text));
    for i in range(length) {
        ch: i64 = 0;
        if kind == 1 {
            ch = i64(peek(data + i));
        } elif kind == 2 {
            ch = i64(ptr[u16](data + 2 * i).view(1)[0]);
        } else {
            ch = i64(ptr[u32](data + 4 * i).view(1)[0]);
        }
        if ch >= 128 {
            return i;
        }
    }
    return -1;
}

impl fromhex_error(invalid_char: i64) {
    if invalid_char == -1 {
        PyErr_SetString(
            PyExc_ValueError,
            "fromhex() arg must contain an even number of hexadecimal digits"
        );
    } else {
        PyErr_Format(
            PyExc_ValueError,
            "non-hexadecimal number found in fromhex() arg at position %zd",
            invalid_char
        );
    }
}

impl bytes_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyBytes_Repr(op, i32(1));
}

impl bytes_str(op: ptr[PyObject]) -> ptr[PyObject] {
    if config_bytes_warning() != i32(0)
        and PyErr_WarnEx(PyExc_BytesWarning, "str() on a bytes instance", 1)
            != i32(0) {
        return NULL;
    }
    return bytes_repr(op);
}

impl bytes_length(op: ptr[PyObject]) -> i64 {
    return object_size(op);
}

impl bytes_concat(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    va = buffer_slot();
    if not va {
        return NULL;
    }
    vb = buffer_slot();
    if not vb {
        PyMem_Free(ptr(va));
        return NULL;
    }
    result = NULL;
    if PyObject_GetBuffer(a, va, PyBUF_SIMPLE) != i32(0)
        or PyObject_GetBuffer(b, vb, PyBUF_SIMPLE) != i32(0) {
        PyErr_Format(
            PyExc_TypeError,
            "can't concat %.100s to %.100s",
            object_type(b).view(1)[0].tp_name,
            object_type(a).view(1)[0].tp_name
        );
    } elif va.view(1)[0].length == 0 and bytes_check_exact(b) {
        result = object_new_ref(b);
    } elif vb.view(1)[0].length == 0 and bytes_check_exact(a) {
        result = object_new_ref(a);
    } elif va.view(1)[0].length > PY_SSIZE_T_MAX - vb.view(1)[0].length {
        PyErr_NoMemory();
    } else {
        result = PyBytes_FromStringAndSize(
            ptr[u8](), va.view(1)[0].length + vb.view(1)[0].length
        );
        if result {
            memcpy(
                ptr(bytes_sval(result)), va.view(1)[0].buf, u64(va.view(1)[0].length)
            );
            memcpy(
                ptr(bytes_sval(result) + va.view(1)[0].length),
                vb.view(1)[0].buf,
                u64(vb.view(1)[0].length)
            );
        }
    }
    buffer_free(va);
    buffer_free(vb);
    return result;
}

impl bytes_repeat(op: ptr[PyObject], count: i64) -> ptr[PyObject] {
    n = count;
    if n < 0 {
        n = 0;
    }

    if n > 0 and object_size(op) > PY_SSIZE_T_MAX // n {
        PyErr_SetString(PyExc_OverflowError, "repeated bytes are too long");
        return NULL;
    }
    size = object_size(op) * n;
    if size == object_size(op) and bytes_check_exact(op) {
        return object_new_ref(op);
    }
    nbytes = u64(size);
    if nbytes + u64(bytes_header_size()) <= nbytes {
        PyErr_SetString(PyExc_OverflowError, "repeated bytes are too long");
        return NULL;
    }
    raw = PyObject_Malloc(u64(bytes_header_size()) + nbytes);
    if not raw {
        return PyErr_NoMemory();
    }
    result = ptr[PyObject](raw);
    PyObject_InitVar(result, ptr[PyObject](bytes_type()), size);
    set_shash(result, -1);
    poke(bytes_sval(result) + size, u8(0));
    _PyBytes_Repeat(bytes_sval(result), size, bytes_sval(op), object_size(op));
    return result;
}

impl bytes_contains(op: ptr[PyObject], arg: ptr[PyObject]) -> i32 {
    return _Py_bytes_contains(bytes_sval(op), object_size(op), arg);
}

impl bytes_item(op: ptr[PyObject], i: i64) -> ptr[PyObject] {
    if i < 0 or i >= object_size(op) {
        PyErr_SetString(PyExc_IndexError, "index out of range");
        return NULL;
    }
    return get_small_int(i64(peek(bytes_sval(op) + i)));
}

impl bytes_compare_eq(a: ptr[PyObject], b: ptr[PyObject]) -> bool {
    length = object_size(a);
    if object_size(b) != length {
        return False;
    }
    if peek(bytes_sval(a)) != peek(bytes_sval(b)) {
        return False;
    }
    return memcmp(ptr(bytes_sval(a)), ptr(bytes_sval(b)), u64(length)) == i32(0);
}

impl bytes_richcompare(aa: ptr[PyObject], bb: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if not (bytes_check(aa) and bytes_check(bb)) {
        if config_bytes_warning() != i32(0) and (op == Py_EQ or op == Py_NE) {
            if (unicode_check(aa) or unicode_check(bb))
                and PyErr_WarnEx(
                    PyExc_BytesWarning, "Comparison between bytes and string", 1
                )
                    != i32(0) {
                return NULL;
            }
            if (long_check(aa) or long_check(bb))
                and PyErr_WarnEx(
                    PyExc_BytesWarning, "Comparison between bytes and int", 1
                )
                    != i32(0) {
                return NULL;
            }
        }
        return object_new_ref(Py_NotImplemented);
    }
    if aa == bb {
        if op == Py_EQ or op == Py_LE or op == Py_GE {
            return PyBool_FromLong(1);
        }
        if op == Py_NE or op == Py_LT or op == Py_GT {
            return PyBool_FromLong(0);
        }
        PyErr_BadArgument();
        return NULL;
    }
    if op == Py_EQ or op == Py_NE {
        eq = bytes_compare_eq(aa, bb);
        if op == Py_NE {
            eq = not eq;
        }
        return PyBool_FromLong(1 if eq else 0);
    }
    len_a = object_size(aa);
    len_b = object_size(bb);
    min_len = min(len_a, len_b);
    c: i64 = 0;
    if min_len > 0 {
        c = i64(peek(bytes_sval(aa))) - i64(peek(bytes_sval(bb)));
        if c == 0 {
            c = i64(memcmp(ptr(bytes_sval(aa)), ptr(bytes_sval(bb)), u64(min_len)));
        }
    }
    if c != 0 {
        return rich_compare_values(c, 0, op);
    }
    return rich_compare_values(len_a, len_b, op);
}

impl bytes_hash(op: ptr[PyObject]) -> i64 {
    hash = get_shash(op);
    if hash == -1 {
        hash = Py_HashBuffer(ptr(bytes_sval(op)), object_size(op));
        set_shash(op, hash);
    }
    return hash;
}

impl bytes_subscript(op: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    if PyIndex_Check(item) != i32(0) {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if i == -1 and PyErr_Occurred() {
            return NULL;
        }
        if i < 0 {
            i += object_size(op);
        }
        if i < 0 or i >= object_size(op) {
            PyErr_SetString(PyExc_IndexError, "index out of range");
            return NULL;
        }
        return get_small_int(i64(peek(bytes_sval(op) + i)));
    }
    if not slice_check(item) {
        PyErr_Format(
            PyExc_TypeError,
            "byte indices must be integers or slices, not %.200s",
            object_type(item).view(1)[0].tp_name
        );
        return NULL;
    }
    start: i64 = 0;
    stop: i64 = 0;
    step: i64 = 0;
    if PySlice_Unpack(item, &mut start, &mut stop, &mut step) < i32(0) {
        return NULL;
    }
    slicelength = PySlice_AdjustIndices(object_size(op), &mut start, &mut stop, step);
    if slicelength <= 0 {
        return bytes_get_empty();
    }
    if start == 0
        and step == 1
        and slicelength == object_size(op)
        and bytes_check_exact(op) {
        return object_new_ref(op);
    }
    if step == 1 {
        return PyBytes_FromStringAndSize(bytes_sval(op) + start, slicelength);
    }
    source_buf = bytes_sval(op);
    result = PyBytes_FromStringAndSize(ptr[u8](), slicelength);
    if not result {
        return NULL;
    }
    result_buf = bytes_sval(result);
    cur = start;
    for i in range(slicelength) {
        poke(result_buf + i, peek(source_buf + cur));
        cur = wrapping_add(cur, step);
    }
    return result;
}

impl bytes_buffer_getbuffer(
    op: ptr[PyObject], view: ptr[Py_buffer], flags: i32
) -> i32 {
    return PyBuffer_FillInfo(
        view, op, ptr(bytes_sval(op)), object_size(op), i32(1), flags
    );
}

impl bytes_mod(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    if not bytes_check(op) {
        return object_new_ref(Py_NotImplemented);
    }
    return _PyBytes_FormatEx(bytes_sval(op), object_size(op), arg, i32(0));
}

impl bytes_alloc(type: ptr[PyTypeObject], nitems: i64) -> ptr[PyObject] {
    op = PyType_GenericAlloc(ptr[PyObject](type), nitems);
    if not op {
        return NULL;
    }
    set_shash(op, -1);
    return op;
}

impl bytes_subtype_new(type: ptr[PyTypeObject], tmp: ptr[PyObject]) -> ptr[PyObject] {
    n = object_size(tmp);
    pnew = type.view(1)[0].tp_alloc(type, n);
    if pnew {
        memcpy(ptr(bytes_sval(pnew)), ptr(bytes_sval(tmp)), u64(n + 1));
        set_shash(pnew, get_shash(tmp));
    }
    return pnew;
}

impl bytes_getnewargs(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("(y#)", bytes_sval(op), object_size(op));
}

impl bytes___bytes__(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    if bytes_check_exact(op) {
        return object_new_ref(op);
    }
    return PyBytes_FromStringAndSize(bytes_sval(op), object_size(op));
}

impl bytes_capitalize(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_capitalize(op, ignored);
}

impl bytes_isalnum(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_isalnum(op, ignored);
}

impl bytes_isalpha(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_isalpha(op, ignored);
}

impl bytes_isascii(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_isascii(op, ignored);
}

impl bytes_isdigit(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_isdigit(op, ignored);
}

impl bytes_islower(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_islower(op, ignored);
}

impl bytes_isspace(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_isspace(op, ignored);
}

impl bytes_istitle(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_istitle(op, ignored);
}

impl bytes_isupper(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_isupper(op, ignored);
}

impl bytes_lower(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_lower(op, ignored);
}

impl bytes_upper(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_upper(op, ignored);
}

impl bytes_swapcase(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_swapcase(op, ignored);
}

impl bytes_title(op: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return bl_title(op, ignored);
}

impl bytes_expandtabs(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return bl_expandtabs(op, args, nargs, kwnames);
}

impl bytes_ljust(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return bl_ljust(op, args, nargs);
}

impl bytes_rjust(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return bl_rjust(op, args, nargs);
}

impl bytes_center(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return bl_center(op, args, nargs);
}

impl bytes_zfill(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return bl_zfill(op, arg);
}

impl split_impl(
    op: ptr[PyObject], sep: ptr[PyObject], maxsplit_in: i64, reverse: bool
) -> ptr[PyObject] {
    length = object_size(op);
    s = bytes_sval(op);
    maxsplit = maxsplit_in;
    if maxsplit < 0 {
        maxsplit = PY_SSIZE_T_MAX;
    }
    if sep == Py_None {
        if reverse {
            return bl_rsplit_whitespace(op, s, length, maxsplit);
        }
        return bl_split_whitespace(op, s, length, maxsplit);
    }
    vsub = buffer_slot();
    if not vsub {
        return NULL;
    }
    if PyObject_GetBuffer(sep, vsub, PyBUF_SIMPLE) != i32(0) {
        buffer_free(vsub);
        return NULL;
    }
    sub = ptr[u8](vsub.view(1)[0].buf);
    n = vsub.view(1)[0].length;
    result = NULL;
    if reverse {
        result = bl_rsplit(op, s, length, sub, n, maxsplit);
    } else {
        result = bl_split(op, s, length, sub, n, maxsplit);
    }
    buffer_free(vsub);
    return result;
}

impl split_with(
    op: ptr[PyObject], sep: ptr[PyObject], maxsplit_obj: ptr[PyObject], reverse: bool
) -> ptr[PyObject] {
    maxsplit: i64 = -1;
    if maxsplit_obj {
        (ok, maxsplit) = ssize_arg(maxsplit_obj);
        if not ok {
            return NULL;
        }
    }
    return split_impl(op, sep or Py_None, maxsplit, reverse);
}

impl bytes_split_bound(args: BoundArguments) -> ptr[PyObject] {
    return split_with(args.context, args.values[0], args.values[1], False);
}

impl bytes_rsplit_bound(args: BoundArguments) -> ptr[PyObject] {
    return split_with(args.context, args.values[0], args.values[1], True);
}

impl bytes_split(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return split_with(
            op,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL,
            False
        );
    }
    return invoke_vector(split_signature, args, nargs, kwnames, bytes_split_bound, op);
}

impl bytes_rsplit(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return split_with(
            op,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL,
            True
        );
    }
    return invoke_vector(
        rsplit_signature, args, nargs, kwnames, bytes_rsplit_bound, op
    );
}

impl partition_with(
    op: ptr[PyObject], arg: ptr[PyObject], reverse: bool
) -> ptr[PyObject] {
    sep = buffer_slot();
    if not sep {
        return NULL;
    }
    result = NULL;
    if PyObject_GetBuffer(arg, sep, PyBUF_SIMPLE) == i32(0) {
        if reverse {
            result = bl_rpartition(
                op,
                bytes_sval(op),
                object_size(op),
                sep.view(1)[0].owner,
                ptr[u8](sep.view(1)[0].buf),
                sep.view(1)[0].length
            );
        } else {
            result = bl_partition(
                op,
                bytes_sval(op),
                object_size(op),
                sep.view(1)[0].owner,
                ptr[u8](sep.view(1)[0].buf),
                sep.view(1)[0].length
            );
        }
    }
    buffer_free(sep);
    return result;
}

impl bytes_partition(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return partition_with(op, arg, False);
}

impl bytes_rpartition(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    return partition_with(op, arg, True);
}

impl bytes_join(op: ptr[PyObject], iterable_of_bytes: ptr[PyObject]) -> ptr[PyObject] {
    return bl_bytes_join(op, iterable_of_bytes);
}

impl slice_bounds(args: ptr[ptr[PyObject]], nargs: i64) -> tuple[bool, i64, i64] {
    start: i64 = 0;
    end: i64 = PY_SSIZE_T_MAX;
    if nargs >= 2 and _PyEval_SliceIndex((args + 1).view(1)[0], &mut start) == i32(0) {
        return (False, start, end);
    }
    if nargs >= 3 and _PyEval_SliceIndex((args + 2).view(1)[0], &mut end) == i32(0) {
        return (False, start, end);
    }
    return (True, start, end);
}

impl bytes_find(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("find", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_find(bytes_sval(op), object_size(op), args.view(1)[0], start, end);
}

impl bytes_index(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("index", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_index(
        bytes_sval(op), object_size(op), args.view(1)[0], start, end
    );
}

impl bytes_rfind(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("rfind", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_rfind(
        bytes_sval(op), object_size(op), args.view(1)[0], start, end
    );
}

impl bytes_rindex(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("rindex", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_rindex(
        bytes_sval(op), object_size(op), args.view(1)[0], start, end
    );
}

impl bytes_count(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("count", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_count(
        bytes_sval(op), object_size(op), args.view(1)[0], start, end
    );
}

impl bytes_startswith(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("startswith", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_startswith(
        bytes_sval(op), object_size(op), args.view(1)[0], start, end
    );
}

impl bytes_endswith(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 3)
        and _PyArg_CheckPositional("endswith", nargs, 1, 3) == i32(0) {
        return NULL;
    }
    (ok, start, end) = slice_bounds(args, nargs);
    if not ok {
        return NULL;
    }
    return _Py_bytes_endswith(
        bytes_sval(op), object_size(op), args.view(1)[0], start, end
    );
}

impl do_xstrip(
    op: ptr[PyObject], striptype: i64, sepobj: ptr[PyObject]
) -> ptr[PyObject] {
    s = bytes_sval(op);
    length = object_size(op);
    vsep = buffer_slot();
    if not vsep {
        return NULL;
    }
    if PyObject_GetBuffer(sepobj, vsep, PyBUF_SIMPLE) != i32(0) {
        buffer_free(vsep);
        return NULL;
    }
    sep = vsep.view(1)[0].buf;
    seplen = u64(vsep.view(1)[0].length);
    i: i64 = 0;
    if striptype != RIGHTSTRIP {
        while i < length and not memchr(sep, i32(peek(s + i)), seplen).is_null() {
            i += 1;
        }
    }
    j = length;
    if striptype != LEFTSTRIP {
        j -= 1;
        while j >= i and not memchr(sep, i32(peek(s + j)), seplen).is_null() {
            j -= 1;
        }
        j += 1;
    }
    buffer_free(vsep);
    if i == 0 and j == length and bytes_check_exact(op) {
        return object_new_ref(op);
    }
    return PyBytes_FromStringAndSize(s + i, j - i);
}

impl do_strip(op: ptr[PyObject], striptype: i64) -> ptr[PyObject] {
    s = bytes_sval(op);
    length = object_size(op);
    i: i64 = 0;
    if striptype != RIGHTSTRIP {
        while i < length and py_isspace(peek(s + i)) {
            i += 1;
        }
    }
    j = length;
    if striptype != LEFTSTRIP {
        j -= 1;
        while j >= i and py_isspace(peek(s + j)) {
            j -= 1;
        }
        j += 1;
    }
    if i == 0 and j == length and bytes_check_exact(op) {
        return object_new_ref(op);
    }
    return PyBytes_FromStringAndSize(s + i, j - i);
}

impl do_argstrip(
    op: ptr[PyObject], striptype: i64, chars: ptr[PyObject]
) -> ptr[PyObject] {
    if chars != Py_None {
        return do_xstrip(op, striptype, chars);
    }
    return do_strip(op, striptype);
}

impl bytes_strip(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional("strip", nargs, 0, 1) == i32(0) {
        return NULL;
    }
    return do_argstrip(op, BOTHSTRIP, args.view(1)[0] if nargs >= 1 else Py_None);
}

impl bytes_lstrip(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional("lstrip", nargs, 0, 1) == i32(0) {
        return NULL;
    }
    return do_argstrip(op, LEFTSTRIP, args.view(1)[0] if nargs >= 1 else Py_None);
}

impl bytes_rstrip(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs > 1 and _PyArg_CheckPositional("rstrip", nargs, 0, 1) == i32(0) {
        return NULL;
    }
    return do_argstrip(op, RIGHTSTRIP, args.view(1)[0] if nargs >= 1 else Py_None);
}

impl translate_with(
    op: ptr[PyObject],
    table: ptr[PyObject],
    deletechars: ptr[PyObject],
    table_view: ptr[Py_buffer],
    del_table_view: ptr[Py_buffer]
) -> ptr[PyObject] {
    table_chars = ptr[u8]();
    tablen: i64 = 0;
    if bytes_check(table) {
        table_chars = bytes_sval(table);
        tablen = object_size(table);
    } elif table == Py_None {
        tablen = 256;
    } else {
        if PyObject_GetBuffer(table, table_view, PyBUF_SIMPLE) != i32(0) {
            return NULL;
        }
        table_chars = ptr[u8](table_view.view(1)[0].buf);
        tablen = table_view.view(1)[0].length;
    }
    if tablen != 256 {
        PyErr_SetString(
            PyExc_ValueError, "translation table must be 256 characters long"
        );
        PyBuffer_Release(table_view);
        return NULL;
    }
    del_table_chars = ptr[u8]();
    dellen: i64 = 0;
    if deletechars {
        if bytes_check(deletechars) {
            del_table_chars = bytes_sval(deletechars);
            dellen = object_size(deletechars);
        } else {
            if PyObject_GetBuffer(deletechars, del_table_view, PyBUF_SIMPLE)
                != i32(0) {
                PyBuffer_Release(table_view);
                return NULL;
            }
            del_table_chars = ptr[u8](del_table_view.view(1)[0].buf);
            dellen = del_table_view.view(1)[0].length;
        }
    }
    inlen = object_size(op);
    result = PyBytes_FromStringAndSize(ptr[u8](), inlen);
    if not result {
        PyBuffer_Release(del_table_view);
        PyBuffer_Release(table_view);
        return NULL;
    }
    output_start = bytes_sval(result);
    output = output_start;
    input = bytes_sval(op);
    changed = False;
    if dellen == 0 and table_chars {
        for i in range(inlen) {
            c = peek(input + i);
            mapped = peek(table_chars + i64(c));
            poke(output + i, mapped);
            if mapped != c {
                changed = True;
            }
        }
        if not changed and bytes_check_exact(op) {
            object_decref(result);
            result = object_new_ref(op);
        }
        PyBuffer_Release(del_table_view);
        PyBuffer_Release(table_view);
        return result;
    }

    trans_table = ptr[i64](PyMem_Malloc(u64(256 * 8)));
    if not trans_table {
        object_decref(result);
        PyBuffer_Release(del_table_view);
        PyBuffer_Release(table_view);
        return PyErr_NoMemory();
    }
    for i in range(256) {
        if table_chars {
            (trans_table + i).view(1)[0] = i64(peek(table_chars + i));
        } else {
            (trans_table + i).view(1)[0] = i;
        }
    }
    PyBuffer_Release(table_view);
    for i in range(dellen) {
        (trans_table + i64(peek(del_table_chars + i))).view(1)[0] = -1;
    }
    PyBuffer_Release(del_table_view);
    for i in range(inlen) {
        code = i64(peek(input + i));
        translated = (trans_table + code).view(1)[0];
        if translated != -1 {
            poke(output, u8(translated));
            output = output + 1;
            if translated == code {
                continue;
            }
        }
        changed = True;
    }
    PyMem_Free(ptr(trans_table));
    if not changed and bytes_check_exact(op) {
        object_decref(result);
        return object_new_ref(op);
    }

    if inlen > 0 {
        result = bytes_resize(result, span(output_start, output));
    }
    return result;
}

impl bytes_translate_impl(
    op: ptr[PyObject], table: ptr[PyObject], deletechars: ptr[PyObject]
) -> ptr[PyObject] {
    table_view = buffer_slot();
    if not table_view {
        return NULL;
    }
    del_table_view = buffer_slot();
    if not del_table_view {
        PyMem_Free(ptr(table_view));
        return NULL;
    }
    result = translate_with(op, table, deletechars, table_view, del_table_view);
    PyMem_Free(ptr(del_table_view));
    PyMem_Free(ptr(table_view));
    return result;
}

impl bytes_translate_bound(args: BoundArguments) -> ptr[PyObject] {
    return bytes_translate_impl(args.context, args.values[0], args.values[1]);
}

impl bytes_translate(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs >= 1 and nargs <= 2 {
        return bytes_translate_impl(
            op, args.view(1)[0], (args + 1).view(1)[0] if nargs >= 2 else NULL
        );
    }
    return invoke_vector(
        translate_signature, args, nargs, kwnames, bytes_translate_bound, op
    );
}

impl bytes_maketrans(
    _null: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if nargs != 2 and _PyArg_CheckPositional("maketrans", nargs, 2, 2) == i32(0) {
        return NULL;
    }
    frm = buffer_slot();
    if not frm {
        return NULL;
    }
    to = buffer_slot();
    if not to {
        PyMem_Free(ptr(frm));
        return NULL;
    }
    result = NULL;
    if PyObject_GetBuffer(args.view(1)[0], frm, PyBUF_SIMPLE) == i32(0)
        and PyObject_GetBuffer((args + 1).view(1)[0], to, PyBUF_SIMPLE) == i32(0) {
        result = _Py_bytes_maketrans(frm, to);
    }
    buffer_free(frm);
    buffer_free(to);
    return result;
}

impl bytes_replace(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 2 or nargs > 3)
        and _PyArg_CheckPositional("replace", nargs, 2, 3) == i32(0) {
        return NULL;
    }
    old = buffer_slot();
    if not old {
        return NULL;
    }
    repl = buffer_slot();
    if not repl {
        PyMem_Free(ptr(old));
        return NULL;
    }
    result = NULL;
    if PyObject_GetBuffer(args.view(1)[0], old, PyBUF_SIMPLE) == i32(0)
        and PyObject_GetBuffer((args + 1).view(1)[0], repl, PyBUF_SIMPLE) == i32(0) {
        ok = True;
        count: i64 = -1;
        if nargs >= 3 {
            (ok, count) = ssize_arg((args + 2).view(1)[0]);
        }
        if ok {
            result = bl_replace(
                op,
                ptr[u8](old.view(1)[0].buf),
                old.view(1)[0].length,
                ptr[u8](repl.view(1)[0].buf),
                repl.view(1)[0].length,
                count
            );
        }
    }
    buffer_free(old);
    buffer_free(repl);
    return result;
}

impl remove_affix(
    op: ptr[PyObject], arg: ptr[PyObject], suffix: bool
) -> ptr[PyObject] {
    affix = buffer_slot();
    if not affix {
        return NULL;
    }
    if PyObject_GetBuffer(arg, affix, PyBUF_SIMPLE) != i32(0) {
        buffer_free(affix);
        return NULL;
    }
    self_start = bytes_sval(op);
    self_len = object_size(op);
    affix_start = affix.view(1)[0].buf;
    affix_len = affix.view(1)[0].length;
    matched = False;
    if self_len >= affix_len and affix_len > 0 {
        at = self_start + self_len - affix_len if suffix else self_start;
        matched = memcmp(ptr(at), affix_start, u64(affix_len)) == i32(0);
    }
    buffer_free(affix);
    if matched {
        if suffix {
            return PyBytes_FromStringAndSize(self_start, self_len - affix_len);
        }
        return PyBytes_FromStringAndSize(self_start + affix_len, self_len - affix_len);
    }
    if bytes_check_exact(op) {
        return object_new_ref(op);
    }
    return PyBytes_FromStringAndSize(self_start, self_len);
}

impl bytes_removeprefix(op: ptr[PyObject], prefix: ptr[PyObject]) -> ptr[PyObject] {
    return remove_affix(op, prefix, False);
}

impl bytes_removesuffix(op: ptr[PyObject], suffix: ptr[PyObject]) -> ptr[PyObject] {
    return remove_affix(op, suffix, True);
}

impl text_arg(value: ptr[PyObject], which: i64) -> tuple[bool, ptr[u8]] {
    if not unicode_check(value) {
        if which == ARG_DECODE_ENCODING {
            _PyArg_BadArgument("decode", "argument 'encoding'", "str", value);
        } elif which == ARG_DECODE_ERRORS {
            _PyArg_BadArgument("decode", "argument 'errors'", "str", value);
        } elif which == ARG_NEW_ENCODING {
            _PyArg_BadArgument("bytes", "argument 'encoding'", "str", value);
        } else {
            _PyArg_BadArgument("bytes", "argument 'errors'", "str", value);
        }
        return (False, ptr[u8]());
    }
    length: i64 = 0;
    text = PyUnicode_AsUTF8AndSize(value, &mut length);
    if not text {
        return (False, text);
    }
    if i64(strlen(text)) != length {
        PyErr_SetString(PyExc_ValueError, "embedded null character");
        return (False, ptr[u8]());
    }
    return (True, text);
}

impl decode_with(
    op: ptr[PyObject], encoding_obj: ptr[PyObject], errors_obj: ptr[PyObject]
) -> ptr[PyObject] {
    encoding = ptr[u8]();
    errors = ptr[u8]();
    if encoding_obj {
        (ok, encoding) = text_arg(encoding_obj, ARG_DECODE_ENCODING);
        if not ok {
            return NULL;
        }
    }
    if errors_obj {
        (ok2, errors) = text_arg(errors_obj, ARG_DECODE_ERRORS);
        if not ok2 {
            return NULL;
        }
    }
    return PyUnicode_FromEncodedObject(op, encoding, errors);
}

impl bytes_decode_bound(args: BoundArguments) -> ptr[PyObject] {
    return decode_with(args.context, args.values[0], args.values[1]);
}

impl bytes_decode(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return decode_with(
            op,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL
        );
    }
    return invoke_vector(
        decode_signature, args, nargs, kwnames, bytes_decode_bound, op
    );
}

impl splitlines_with(op: ptr[PyObject], keepends_obj: ptr[PyObject]) -> ptr[PyObject] {
    keepends = i32(0);
    if keepends_obj {
        keepends = PyObject_IsTrue(keepends_obj);
        if keepends < i32(0) {
            return NULL;
        }
    }
    return bl_splitlines(op, bytes_sval(op), object_size(op), keepends);
}

impl bytes_splitlines_bound(args: BoundArguments) -> ptr[PyObject] {
    return splitlines_with(args.context, args.values[0]);
}

impl bytes_splitlines(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 1 {
        return splitlines_with(op, args.view(1)[0] if nargs >= 1 else NULL);
    }
    return invoke_vector(
        splitlines_signature, args, nargs, kwnames, bytes_splitlines_bound, op
    );
}

impl bytes_fromhex(type: ptr[PyObject], string: ptr[PyObject]) -> ptr[PyObject] {
    result = _PyBytes_FromHex(string, i32(0));
    if type != ptr[PyObject](bytes_type()) and result {
        converted = PyObject_CallOneArg(type, result);
        object_decref(result);
        result = converted;
    }
    return result;
}

impl hex_with(
    op: ptr[PyObject], sep: ptr[PyObject], per_sep_obj: ptr[PyObject]
) -> ptr[PyObject] {
    bytes_per_sep = i32(1);
    if per_sep_obj {
        bytes_per_sep = PyLong_AsInt(per_sep_obj);
        if bytes_per_sep == i32(-1) and PyErr_Occurred() {
            return NULL;
        }
    }
    return _Py_strhex_with_sep(
        ptr(bytes_sval(op)), object_size(op), sep, bytes_per_sep
    );
}

impl bytes_hex_bound(args: BoundArguments) -> ptr[PyObject] {
    return hex_with(args.context, args.values[0], args.values[1]);
}

impl bytes_hex(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwnames and nargs <= 2 {
        return hex_with(
            op,
            args.view(1)[0] if nargs >= 1 else NULL,
            (args + 1).view(1)[0] if nargs >= 2 else NULL
        );
    }
    return invoke_vector(hex_signature, args, nargs, kwnames, bytes_hex_bound, op);
}

impl bytes_new_impl(
    type: ptr[PyTypeObject], x: ptr[PyObject], encoding: ptr[u8], errors: ptr[u8]
) -> ptr[PyObject] {
    result = NULL;
    if not x {
        if encoding {
            PyErr_SetString(PyExc_TypeError, "encoding without a string argument");
            return NULL;
        }
        if errors {
            PyErr_SetString(PyExc_TypeError, "errors without a string argument");
            return NULL;
        }
        result = bytes_get_empty();
    } elif encoding {
        if not unicode_check(x) {
            PyErr_SetString(PyExc_TypeError, "encoding without a string argument");
            return NULL;
        }
        result = PyUnicode_AsEncodedString(x, encoding, errors);
    } elif errors {
        if unicode_check(x) {
            PyErr_SetString(PyExc_TypeError, "string argument without an encoding");
        } else {
            PyErr_SetString(PyExc_TypeError, "errors without a string argument");
        }
        return NULL;
    } else {
        func = lookup_bytes_method(x);
        if func {
            result = PyObject_CallNoArgs(func);
            object_decref(func);
            if not result {
                return NULL;
            }
            if not bytes_check(result) {
                PyErr_Format(
                    PyExc_TypeError,
                    "__bytes__ returned non-bytes (type %.200s)",
                    object_type(result).view(1)[0].tp_name
                );
                object_decref(result);
                return NULL;
            }
        } elif PyErr_Occurred() {
            return NULL;
        } elif unicode_check(x) {
            PyErr_SetString(PyExc_TypeError, "string argument without an encoding");
            return NULL;
        } elif PyIndex_Check(x) != i32(0) {
            size = PyNumber_AsSsize_t(x, PyExc_OverflowError);
            if size == -1 and PyErr_Occurred() {
                if PyErr_ExceptionMatches(PyExc_TypeError) == i32(0) {
                    return NULL;
                }

                PyErr_Clear();
                result = PyBytes_FromObject(x);
            } else {
                if size < 0 {
                    PyErr_SetString(PyExc_ValueError, "negative count");
                    return NULL;
                }
                result = bytes_from_size(size, True);
            }
        } else {
            result = PyBytes_FromObject(x);
        }
    }
    if result and type != bytes_type() {
        subtyped = bytes_subtype_new(type, result);
        object_decref(result);
        result = subtyped;
    }
    return result;
}

impl bytes_new_bound(args: BoundArguments) -> ptr[PyObject] {
    encoding = ptr[u8]();
    errors = ptr[u8]();
    if args.values[1] {
        (ok, encoding) = text_arg(args.values[1], ARG_NEW_ENCODING);
        if not ok {
            return NULL;
        }
    }
    if args.values[2] {
        (ok2, errors) = text_arg(args.values[2], ARG_NEW_ERRORS);
        if not ok2 {
            return NULL;
        }
    }
    return bytes_new_impl(
        ptr[PyTypeObject](args.context), args.values[0], encoding, errors
    );
}

impl bytes_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if not kwargs and object_size(args) <= 1 {
        return bytes_new_impl(
            type,
            tuple_get_item(args, 0) if object_size(args) == 1 else NULL,
            ptr[u8](),
            ptr[u8]()
        );
    }
    return invoke(
        bytes_new_signature, args, kwargs, bytes_new_bound, ptr[PyObject](type)
    );
}

impl striter_of(op: ptr[PyObject]) -> ptr[striterobject] {
    return ptr[striterobject](op);
}

impl striter_seq(op: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyObject](striter_of(op).view(1)[0].it_seq);
}

impl striter_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(striter_seq(op));
    PyObject_GC_Del(ptr(op));
}

impl striter_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(striter_seq(op), visitor, arg);
}

impl striter_next(op: ptr[PyObject]) -> ptr[PyObject] {
    it = striter_of(op);
    seq = striter_seq(op);
    if not seq {
        return NULL;
    }
    index = it.view(1)[0].it_index;
    if index < object_size(seq) {
        it.view(1)[0].it_index = index + 1;
        return get_small_int(i64(peek(bytes_sval(seq) + index)));
    }
    it.view(1)[0].it_seq = ptr[PyBytesObject]();
    object_decref(seq);
    return NULL;
}

impl striter_len(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    length: i64 = 0;
    seq = striter_seq(op);
    if seq {
        length = object_size(seq) - striter_of(op).view(1)[0].it_index;
    }
    return PyLong_FromSsize_t(length);
}

impl striter_reduce(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    iter_builtin = eval_builtin("iter");
    seq = striter_seq(op);
    if seq {
        return Py_BuildValue(
            "N(O)n", iter_builtin, seq, striter_of(op).view(1)[0].it_index
        );
    }
    return Py_BuildValue("N(())", iter_builtin);
}

impl striter_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    index = PyLong_AsSsize_t(state);
    if index == -1 and PyErr_Occurred() {
        return NULL;
    }
    seq = striter_seq(op);
    if seq {
        if index < 0 {
            index = 0;
        } elif index > object_size(seq) {
            index = object_size(seq);
        }
        striter_of(op).view(1)[0].it_index = index;
    }
    return object_new_ref(Py_None);
}

impl bytes_iter(seq: ptr[PyObject]) -> ptr[PyObject] {
    if not bytes_check(seq) {
        PyErr_BadInternalCall();
        return NULL;
    }
    op = _PyObject_GC_New(ptr[PyObject](addressof(PyBytesIter_Type)));
    if not op {
        return NULL;
    }
    it = striter_of(op);
    it.view(1)[0].it_index = 0;
    it.view(1)[0].it_seq = ptr[PyBytesObject](object_new_ref(seq));
    object_gc_track(op);
    return op;
}
