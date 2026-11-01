"""The Argument Clinic signatures of zlib.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/zlib.jac from them. Taken from
the C sources it replaces (Modules/zlibmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="zlib",
         version="3.14.6",
         sources=["Modules/zlibmodule.c"],
         classes={
             "Compress": "compobject *",
             "Decompress": "compobject *",
             "ZlibDecompressor": "ZlibDecompressor *"
         },
         functions=[
             Function(
                 name="compress",
                 full_name="zlib.compress",
                 c_basename="zlib_compress",
                 docstring="compress($module, data, /, level=Z_DEFAULT_COMPRESSION, wbits=MAX_WBITS)\n"
                 "--\n"
                 "\n"
                 "Returns a bytes object containing compressed data.\n"
                 "\n"
                 "  data\n"
                 "    Binary data to be compressed.\n"
                 "  level\n"
                 "    Compression level, in 0-9 or -1.\n"
                 "  wbits\n"
                 "    The window buffer size and container format.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="level",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="Z_DEFAULT_COMPRESSION"
                     ),
                     Parameter(
                         name="wbits",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="MAX_WBITS"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3,
                 pos_only=1
             ),
             Function(
                 name="decompress",
                 full_name="zlib.decompress",
                 c_basename="zlib_decompress",
                 docstring="decompress($module, data, /, wbits=MAX_WBITS, bufsize=DEF_BUF_SIZE)\n"
                 "--\n"
                 "\n"
                 "Returns a bytes object containing the uncompressed data.\n"
                 "\n"
                 "  data\n"
                 "    Compressed data.\n"
                 "  wbits\n"
                 "    The window buffer size and container format.\n"
                 "  bufsize\n"
                 "    The initial output buffer size.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="wbits",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="MAX_WBITS"
                     ),
                     Parameter(
                         name="bufsize",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="unknown",
                         c_default="DEF_BUF_SIZE"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3,
                 pos_only=1
             ),
             Function(
                 name="compressobj",
                 full_name="zlib.compressobj",
                 c_basename="zlib_compressobj",
                 docstring="compressobj($module, /, level=Z_DEFAULT_COMPRESSION, method=DEFLATED,\n"
                 "            wbits=MAX_WBITS, memLevel=DEF_MEM_LEVEL,\n"
                 "            strategy=Z_DEFAULT_STRATEGY, zdict=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Return a compressor object.\n"
                 "\n"
                 "  level\n"
                 "    The compression level (an integer in the range 0-9 or -1; default is\n"
                 "    currently equivalent to 6).  Higher compression levels are slower,\n"
                 "    but produce smaller results.\n"
                 "  method\n"
                 "    The compression algorithm.  If given, this must be DEFLATED.\n"
                 "  wbits\n"
                 "    +9 to +15: The base-two logarithm of the window size.  Include a zlib\n"
                 "        container.\n"
                 "    -9 to -15: Generate a raw stream.\n"
                 "    +25 to +31: Include a gzip container.\n"
                 "  memLevel\n"
                 "    Controls the amount of memory used for internal compression state.\n"
                 "    Valid values range from 1 to 9.  Higher values result in higher memory\n"
                 "    usage, faster compression, and smaller output.\n"
                 "  strategy\n"
                 "    Used to tune the compression algorithm.  Possible values are\n"
                 "    Z_DEFAULT_STRATEGY, Z_FILTERED, and Z_HUFFMAN_ONLY.\n"
                 "  zdict\n"
                 "    The predefined compression dictionary - a sequence of bytes\n"
                 "    containing subsequences that are likely to occur in the input data.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="level",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="Z_DEFAULT_COMPRESSION"
                     ),
                     Parameter(
                         name="method",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DEFLATED"
                     ),
                     Parameter(
                         name="wbits",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="MAX_WBITS"
                     ),
                     Parameter(
                         name="memLevel",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="DEF_MEM_LEVEL"
                     ),
                     Parameter(
                         name="strategy",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="Z_DEFAULT_STRATEGY"
                     ),
                     Parameter(
                         name="zdict",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         default_kind="NULL",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=6
             ),
             Function(
                 name="decompressobj",
                 full_name="zlib.decompressobj",
                 c_basename="zlib_decompressobj",
                 docstring="decompressobj($module, /, wbits=MAX_WBITS, zdict=b'')\n"
                 "--\n"
                 "\n"
                 "Return a decompressor object.\n"
                 "\n"
                 "  wbits\n"
                 "    The window buffer size and container format.\n"
                 "  zdict\n"
                 "    The predefined compression dictionary.  This must be the same\n"
                 "    dictionary as used by the compressor that produced the input data.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="wbits",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="MAX_WBITS"
                     ),
                     Parameter(
                         name="zdict",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="adler32",
                 full_name="zlib.adler32",
                 c_basename="zlib_adler32",
                 docstring="adler32($module, data, value=1, /)\n"
                 "--\n"
                 "\n"
                 "Compute an Adler-32 checksum of data.\n"
                 "\n"
                 "  value\n"
                 "    Starting value of the checksum.\n"
                 "\n"
                 "The returned checksum is an integer.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="value",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I",
                         default_kind="value",
                         py_default=1,
                         c_default="1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="crc32",
                 full_name="zlib.crc32",
                 c_basename="zlib_crc32",
                 docstring="crc32($module, data, value=0, /)\n"
                 "--\n"
                 "\n"
                 "Compute a CRC-32 checksum of data.\n"
                 "\n"
                 "  value\n"
                 "    Starting value of the checksum.\n"
                 "\n"
                 "The returned checksum is an integer.",
                 returns="unsigned_int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="value",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I",
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
                 name="compress",
                 full_name="zlib.Compress.compress",
                 c_basename="zlib_Compress_compress",
                 cls="Compress",
                 docstring="compress($self, data, /)\n"
                 "--\n"
                 "\n"
                 "Returns a bytes object containing compressed data.\n"
                 "\n"
                 "  data\n"
                 "    Binary data to be compressed.\n"
                 "\n"
                 "After calling this function, some of the input data may still\n"
                 "be stored in internal buffers for later processing.\n"
                 "Call the flush() method to clear these buffers.",
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
                         name="data",
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
                 name="flush",
                 full_name="zlib.Compress.flush",
                 c_basename="zlib_Compress_flush",
                 cls="Compress",
                 docstring="flush($self, mode=zlib.Z_FINISH, /)\n"
                 "--\n"
                 "\n"
                 "Return a bytes object containing any remaining compressed data.\n"
                 "\n"
                 "  mode\n"
                 "    One of the constants Z_SYNC_FLUSH, Z_FULL_FLUSH, Z_FINISH.\n"
                 "    If mode == Z_FINISH, the compressor object can no longer be\n"
                 "    used after calling the flush() method.  Otherwise, more data\n"
                 "    can still be compressed.",
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
                         name="mode",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="Z_FINISH"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="copy",
                 full_name="zlib.Compress.copy",
                 c_basename="zlib_Compress_copy",
                 cls="Compress",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the compression object.",
                 condition="defined(HAVE_ZLIB_COPY)",
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
                 name="__copy__",
                 full_name="zlib.Compress.__copy__",
                 c_basename="zlib_Compress___copy__",
                 cls="Compress",
                 docstring="__copy__($self, /)\n" "--",
                 condition="defined(HAVE_ZLIB_COPY)",
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
                 name="__deepcopy__",
                 full_name="zlib.Compress.__deepcopy__",
                 c_basename="zlib_Compress___deepcopy__",
                 cls="Compress",
                 docstring="__deepcopy__($self, memo, /)\n" "--",
                 condition="defined(HAVE_ZLIB_COPY)",
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
                     Parameter(name="memo", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="decompress",
                 full_name="zlib.Decompress.decompress",
                 c_basename="zlib_Decompress_decompress",
                 cls="Decompress",
                 docstring="decompress($self, data, /, max_length=0)\n"
                 "--\n"
                 "\n"
                 "Return a bytes object containing the decompressed version of the data.\n"
                 "\n"
                 "  data\n"
                 "    The binary data to decompress.\n"
                 "  max_length\n"
                 "    The maximum allowable length of the decompressed data.\n"
                 "    Unconsumed input data will be stored in\n"
                 "    the unconsumed_tail attribute.\n"
                 "\n"
                 "After calling this function, some of the input data may still be\n"
                 "stored in internal buffers for later processing.\n"
                 "Call the flush() method to clear these buffers.",
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
                         name="data",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="max_length",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=1
             ),
             Function(
                 name="copy",
                 full_name="zlib.Decompress.copy",
                 c_basename="zlib_Decompress_copy",
                 cls="Decompress",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the decompression object.",
                 condition="defined(HAVE_ZLIB_COPY)",
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
                 name="__copy__",
                 full_name="zlib.Decompress.__copy__",
                 c_basename="zlib_Decompress___copy__",
                 cls="Decompress",
                 docstring="__copy__($self, /)\n" "--",
                 condition="defined(HAVE_ZLIB_COPY)",
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
                 name="__deepcopy__",
                 full_name="zlib.Decompress.__deepcopy__",
                 c_basename="zlib_Decompress___deepcopy__",
                 cls="Decompress",
                 docstring="__deepcopy__($self, memo, /)\n" "--",
                 condition="defined(HAVE_ZLIB_COPY)",
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
                     Parameter(name="memo", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="flush",
                 full_name="zlib.Decompress.flush",
                 c_basename="zlib_Decompress_flush",
                 cls="Decompress",
                 docstring="flush($self, length=zlib.DEF_BUF_SIZE, /)\n"
                 "--\n"
                 "\n"
                 "Return a bytes object containing any remaining decompressed data.\n"
                 "\n"
                 "  length\n"
                 "    the initial size of the output buffer.",
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
                         name="length",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="unknown",
                         c_default="DEF_BUF_SIZE"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="decompress",
                 full_name="zlib.ZlibDecompressor.decompress",
                 c_basename="zlib_ZlibDecompressor_decompress",
                 cls="ZlibDecompressor",
                 docstring="decompress($self, /, data, max_length=-1)\n"
                 "--\n"
                 "\n"
                 "Decompress *data*, returning uncompressed data as bytes.\n"
                 "\n"
                 "If *max_length* is nonnegative, returns at most *max_length* bytes\n"
                 "of decompressed data.  If this limit is reached and further output\n"
                 "can be produced, *self.needs_input* will be set to ``False``.  In\n"
                 "this case, the next call to *decompress()* may provide *data* as b''\n"
                 "to obtain more of the output.\n"
                 "\n"
                 "If all of the input data was decompressed and returned (either\n"
                 "because this was less than *max_length* bytes, or because\n"
                 "*max_length* was negative), *self.needs_input* will be set to True.\n"
                 "\n"
                 "Attempting to decompress data after the end of stream is reached\n"
                 "raises an EOFError.  Any data found after the end of the stream is\n"
                 "ignored and saved in the unused_data attribute.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="data",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="max_length",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             )
         ],
         docs={
             "ZlibDecompressor__new____doc__": "_ZlibDecompressor(wbits=15, zdict=b'')\n"
             "--\n"
             "\n"
             "Create a decompressor object for decompressing data incrementally.\n"
             "\n"
             "  wbits = 15\n"
             "  zdict\n"
             "     The predefined compression dictionary. This is a sequence of bytes\n"
             "     (such as a bytes object) containing subsequences that are expected\n"
             "     to occur frequently in the data that is to be compressed. Those\n"
             "     subsequences that are expected to be most common should come at the\n"
             "     end of the dictionary. This must be the same dictionary as used by the\n"
             "     compressor that produced the input data.\n"
             "\n",
             "ZlibDecompressor_eof__doc__": "True if the end-of-stream marker has been reached.",
             "ZlibDecompressor_unused_data__doc__": "Data found after the end of the compressed stream.",
             "ZlibDecompressor_needs_input_doc": "True if more input is needed before more decompressed data can be produced.",
             "zlib_module_documentation": "The functions in this module allow compression and decompression using the\n"
             "zlib library, which is based on GNU zip.\n"
             "\n"
             "adler32(string[, start]) -- Compute an Adler-32 checksum.\n"
             "compress(data[, level]) -- Compress data, with compression level 0-9 or -1.\n"
             "compressobj([level[, ...]]) -- Return a compressor object.\n"
             "crc32(string[, start]) -- Compute a CRC-32 checksum.\n"
             "decompress(string,[wbits],[bufsize]) -- Decompresses a compressed string.\n"
             "decompressobj([wbits[, zdict]]) -- Return a decompressor object.\n"
             "\n"
             "'wbits' is window buffer size and container format.\n"
             "Compressor objects support compress() and flush() methods; decompressor\n"
             "objects support decompress() and flush()."
         }
     );
