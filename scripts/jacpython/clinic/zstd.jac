"""The Argument Clinic signatures of _zstd.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/zstd.jac from them. Taken from
the C sources it replaces (Modules/_zstd/_zstdmodule.c, Modules/_zstd/zstddict.c, Modules/_zstd/compressor.c, Modules/_zstd/decompressor.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_zstd",
         version="3.14.6",
         sources=[
             "Modules/_zstd/_zstdmodule.c",
             "Modules/_zstd/zstddict.c",
             "Modules/_zstd/compressor.c",
             "Modules/_zstd/decompressor.c"
         ],
         classes={
             "ZstdDict": "ZstdDict *",
             "ZstdCompressor": "ZstdCompressor *",
             "ZstdDecompressor": "ZstdDecompressor *"
         },
         functions=[
             Function(
                 name="train_dict",
                 full_name="_zstd.train_dict",
                 c_basename="_zstd_train_dict",
                 docstring="train_dict($module, samples_bytes, samples_sizes, dict_size, /)\n"
                 "--\n"
                 "\n"
                 "Train a Zstandard dictionary on sample data.\n"
                 "\n"
                 "  samples_bytes\n"
                 "    Concatenation of samples.\n"
                 "  samples_sizes\n"
                 "    Tuple of samples' sizes.\n"
                 "  dict_size\n"
                 "    The size of the dictionary.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="samples_bytes",
                         kind="POSITIONAL_ONLY",
                         converter="PyBytesObject",
                         type="PyBytesObject *",
                         format_unit="S"
                     ),
                     Parameter(
                         name="samples_sizes",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyTuple_Type"
                     ),
                     Parameter(
                         name="dict_size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="finalize_dict",
                 full_name="_zstd.finalize_dict",
                 c_basename="_zstd_finalize_dict",
                 docstring="finalize_dict($module, custom_dict_bytes, samples_bytes, samples_sizes,\n"
                 "              dict_size, compression_level, /)\n"
                 "--\n"
                 "\n"
                 "Finalize a Zstandard dictionary.\n"
                 "\n"
                 "  custom_dict_bytes\n"
                 "    Custom dictionary content.\n"
                 "  samples_bytes\n"
                 "    Concatenation of samples.\n"
                 "  samples_sizes\n"
                 "    Tuple of samples' sizes.\n"
                 "  dict_size\n"
                 "    The size of the dictionary.\n"
                 "  compression_level\n"
                 "    Optimize for a specific Zstandard compression level, 0 means default.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="custom_dict_bytes",
                         kind="POSITIONAL_ONLY",
                         converter="PyBytesObject",
                         type="PyBytesObject *",
                         format_unit="S"
                     ),
                     Parameter(
                         name="samples_bytes",
                         kind="POSITIONAL_ONLY",
                         converter="PyBytesObject",
                         type="PyBytesObject *",
                         format_unit="S"
                     ),
                     Parameter(
                         name="samples_sizes",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyTuple_Type"
                     ),
                     Parameter(
                         name="dict_size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="compression_level",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=5,
                 max_pos=5,
                 pos_only=5
             ),
             Function(
                 name="get_param_bounds",
                 full_name="_zstd.get_param_bounds",
                 c_basename="_zstd_get_param_bounds",
                 docstring="get_param_bounds($module, /, parameter, is_compress)\n"
                 "--\n"
                 "\n"
                 "Get CompressionParameter/DecompressionParameter bounds.\n"
                 "\n"
                 "  parameter\n"
                 "    The parameter to get bounds.\n"
                 "  is_compress\n"
                 "    True for CompressionParameter, False for DecompressionParameter.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="parameter", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="is_compress",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="get_frame_size",
                 full_name="_zstd.get_frame_size",
                 c_basename="_zstd_get_frame_size",
                 docstring="get_frame_size($module, /, frame_buffer)\n"
                 "--\n"
                 "\n"
                 "Get the size of a Zstandard frame, including the header and optional checksum.\n"
                 "\n"
                 "  frame_buffer\n"
                 "    A bytes-like object, it should start from the beginning of a frame,\n"
                 "    and contains at least one complete frame.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="frame_buffer",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="get_frame_info",
                 full_name="_zstd.get_frame_info",
                 c_basename="_zstd_get_frame_info",
                 docstring="get_frame_info($module, /, frame_buffer)\n"
                 "--\n"
                 "\n"
                 "Get Zstandard frame infomation from a frame header.\n"
                 "\n"
                 "  frame_buffer\n"
                 "    A bytes-like object, containing the header of a Zstandard frame.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="frame_buffer",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="set_parameter_types",
                 full_name="_zstd.set_parameter_types",
                 c_basename="_zstd_set_parameter_types",
                 docstring="set_parameter_types($module, /, c_parameter_type, d_parameter_type)\n"
                 "--\n"
                 "\n"
                 "Set CompressionParameter and DecompressionParameter types for validity check.\n"
                 "\n"
                 "  c_parameter_type\n"
                 "    CompressionParameter IntEnum type object\n"
                 "  d_parameter_type\n"
                 "    DecompressionParameter IntEnum type object",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="c_parameter_type",
                         format_unit="O!",
                         subclass_of="&PyType_Type"
                     ),
                     Parameter(
                         name="d_parameter_type",
                         format_unit="O!",
                         subclass_of="&PyType_Type"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="_zstd.ZstdDict.__new__",
                 c_basename="_zstd_ZstdDict_new",
                 kind="METHOD_NEW",
                 cls="ZstdDict",
                 docstring="ZstdDict(dict_content, /, *, is_raw=False)\n"
                 "--\n"
                 "\n"
                 "Represents a Zstandard dictionary.\n"
                 "\n"
                 "  dict_content\n"
                 "    The content of a Zstandard dictionary as a bytes-like object.\n"
                 "  is_raw\n"
                 "    If true, perform no checks on *dict_content*, useful for some\n"
                 "    advanced cases. Otherwise, check that the content represents\n"
                 "    a Zstandard dictionary created by the zstd library or CLI.\n"
                 "\n"
                 "The dictionary can be used for compression or decompression, and can be\n"
                 "shared by multiple ZstdCompressor or ZstdDecompressor objects.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="dict_content",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="is_raw",
                         kind="KEYWORD_ONLY",
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
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="dict_content",
                 full_name="_zstd.ZstdDict.dict_content",
                 c_basename="_zstd_ZstdDict_dict_content",
                 kind="GETTER",
                 cls="ZstdDict",
                 docstring="The content of a Zstandard dictionary, as a bytes object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="as_digested_dict",
                 full_name="_zstd.ZstdDict.as_digested_dict",
                 c_basename="_zstd_ZstdDict_as_digested_dict",
                 kind="GETTER",
                 cls="ZstdDict",
                 docstring="Load as a digested dictionary to compressor.\n"
                 "\n"
                 "Pass this attribute as zstd_dict argument:\n"
                 "compress(dat, zstd_dict=zd.as_digested_dict)\n"
                 "\n"
                 "1. Some advanced compression parameters of compressor may be\n"
                 "   overridden by parameters of digested dictionary.\n"
                 "2. ZstdDict has a digested dictionaries cache for each compression\n"
                 "   level.  It's faster when loading again a digested dictionary with\n"
                 "   the same compression level.\n"
                 "3. No need to use this for decompression.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="as_undigested_dict",
                 full_name="_zstd.ZstdDict.as_undigested_dict",
                 c_basename="_zstd_ZstdDict_as_undigested_dict",
                 kind="GETTER",
                 cls="ZstdDict",
                 docstring="Load as an undigested dictionary to compressor.\n"
                 "\n"
                 "Pass this attribute as zstd_dict argument:\n"
                 "compress(dat, zstd_dict=zd.as_undigested_dict)\n"
                 "\n"
                 "1. The advanced compression parameters of compressor will not be\n"
                 "   overridden.\n"
                 "2. Loading an undigested dictionary is costly. If load an undigested\n"
                 "   dictionary multiple times, consider reusing a compressor object.\n"
                 "3. No need to use this for decompression.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="as_prefix",
                 full_name="_zstd.ZstdDict.as_prefix",
                 c_basename="_zstd_ZstdDict_as_prefix",
                 kind="GETTER",
                 cls="ZstdDict",
                 docstring="Load as a prefix to compressor/decompressor.\n"
                 "\n"
                 "Pass this attribute as zstd_dict argument:\n"
                 "compress(dat, zstd_dict=zd.as_prefix)\n"
                 "\n"
                 "1. Prefix is compatible with long distance matching, while\n"
                 "   dictionary is not.\n"
                 "2. It only works for the first frame, then the\n"
                 "   compressor/decompressor will return to no prefix state.\n"
                 "3. When decompressing, must use the same prefix as when compressing.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="__new__",
                 full_name="_zstd.ZstdCompressor.__new__",
                 c_basename="_zstd_ZstdCompressor_new",
                 kind="METHOD_NEW",
                 cls="ZstdCompressor",
                 docstring="ZstdCompressor(level=None, options=None, zstd_dict=None)\n"
                 "--\n"
                 "\n"
                 "Create a compressor object for compressing data incrementally.\n"
                 "\n"
                 "  level\n"
                 "    The compression level to use. Defaults to COMPRESSION_LEVEL_DEFAULT.\n"
                 "  options\n"
                 "    A dict object that contains advanced compression parameters.\n"
                 "  zstd_dict\n"
                 "    A ZstdDict object, a pre-trained Zstandard dictionary.\n"
                 "\n"
                 "Thread-safe at method level.  For one-shot compression, use the\n"
                 "compress() function instead.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="level",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="options",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="zstd_dict",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=3
             ),
             Function(
                 name="compress",
                 full_name="_zstd.ZstdCompressor.compress",
                 c_basename="_zstd_ZstdCompressor_compress",
                 cls="ZstdCompressor",
                 docstring="compress($self, /, data, mode=ZstdCompressor.CONTINUE)\n"
                 "--\n"
                 "\n"
                 "Provide data to the compressor object.\n"
                 "\n"
                 "  mode\n"
                 "    Can be these 3 values ZstdCompressor.CONTINUE,\n"
                 "    ZstdCompressor.FLUSH_BLOCK, ZstdCompressor.FLUSH_FRAME\n"
                 "\n"
                 "Return a chunk of compressed data if possible, or b'' otherwise.\n"
                 "When you have finished providing data to the compressor, call the\n"
                 "flush() method to finish the compression process.",
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
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="ZSTD_e_continue"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="flush",
                 full_name="_zstd.ZstdCompressor.flush",
                 c_basename="_zstd_ZstdCompressor_flush",
                 cls="ZstdCompressor",
                 docstring="flush($self, /, mode=ZstdCompressor.FLUSH_FRAME)\n"
                 "--\n"
                 "\n"
                 "Finish the compression process.\n"
                 "\n"
                 "  mode\n"
                 "    Can be these 2 values ZstdCompressor.FLUSH_FRAME,\n"
                 "    ZstdCompressor.FLUSH_BLOCK\n"
                 "\n"
                 "Flush any remaining data left in internal buffers.  Since Zstandard\n"
                 "data consists of one or more independent frames, the compressor\n"
                 "object can still be used after this method is called.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="ZSTD_e_end"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="set_pledged_input_size",
                 full_name="_zstd.ZstdCompressor.set_pledged_input_size",
                 c_basename="_zstd_ZstdCompressor_set_pledged_input_size",
                 cls="ZstdCompressor",
                 docstring="set_pledged_input_size($self, size, /)\n"
                 "--\n"
                 "\n"
                 "Set the uncompressed content size to be written into the frame header.\n"
                 "\n"
                 "  size\n"
                 "    The size of the uncompressed data to be provided to the compressor.\n"
                 "\n"
                 "This method can be used to ensure the header of the frame about to\n"
                 "be written includes the size of the data, unless the\n"
                 "CompressionParameter.content_size_flag is set to False.\n"
                 "If last_mode != FLUSH_FRAME, then a RuntimeError is raised.\n"
                 "\n"
                 "It is important to ensure that the pledged data size matches the\n"
                 "actual data size.  If they do not match the compressed output data\n"
                 "may be corrupted and the final chunk written may be lost.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="zstd_contentsize",
                         type="unsigned long long",
                         format_unit="O&",
                         convert_with="zstd_contentsize_converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__new__",
                 full_name="_zstd.ZstdDecompressor.__new__",
                 c_basename="_zstd_ZstdDecompressor_new",
                 kind="METHOD_NEW",
                 cls="ZstdDecompressor",
                 docstring="ZstdDecompressor(zstd_dict=None, options=None)\n"
                 "--\n"
                 "\n"
                 "Create a decompressor object for decompressing data incrementally.\n"
                 "\n"
                 "  zstd_dict\n"
                 "    A ZstdDict object, a pre-trained Zstandard dictionary.\n"
                 "  options\n"
                 "    A dict object that contains advanced decompression parameters.\n"
                 "\n"
                 "Thread-safe at method level.  For one-shot decompression, use the\n"
                 "decompress() function instead.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="zstd_dict",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="options",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="unused_data",
                 full_name="_zstd.ZstdDecompressor.unused_data",
                 c_basename="_zstd_ZstdDecompressor_unused_data",
                 kind="GETTER",
                 cls="ZstdDecompressor",
                 docstring="A bytes object of un-consumed input data.\n"
                 "\n"
                 "When ZstdDecompressor object stops after a frame is\n"
                 "decompressed, unused input data after the frame.  Otherwise this\n"
                 "will be b''.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="decompress",
                 full_name="_zstd.ZstdDecompressor.decompress",
                 c_basename="_zstd_ZstdDecompressor_decompress",
                 cls="ZstdDecompressor",
                 docstring="decompress($self, /, data, max_length=-1)\n"
                 "--\n"
                 "\n"
                 "Decompress *data*, returning uncompressed bytes if possible, or b'' otherwise.\n"
                 "\n"
                 "  data\n"
                 "    A bytes-like object, Zstandard data to be decompressed.\n"
                 "  max_length\n"
                 "    Maximum size of returned data. When it is negative, the size of\n"
                 "    output buffer is unlimited. When it is nonnegative, returns at\n"
                 "    most max_length bytes of decompressed data.\n"
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
                 "Attempting to decompress data after the end of a frame is reached\n"
                 "raises an EOFError.  Any data found after the end of the frame is\n"
                 "ignored and saved in the self.unused_data attribute.",
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
             "ZstdDict_dictid_doc": "The Zstandard dictionary, an int between 0 and 2**32.\n"
             "\n"
             "A non-zero value represents an ordinary Zstandard dictionary,\n"
             "conforming to the standardised format.\n"
             "\n"
             "A value of zero indicates a 'raw content' dictionary,\n"
             "without any restrictions on format or content.",
             "ZstdCompressor_last_mode_doc": "The last mode used to this compressor object, its value can be .CONTINUE,\n"
             ".FLUSH_BLOCK, .FLUSH_FRAME. Initialized to .FLUSH_FRAME.\n"
             "\n"
             "It can be used to get the current state of a compressor, such as, data\n"
             "flushed, or a frame ended.",
             "ZstdDecompressor_eof_doc": "True means the end of the first frame has been reached. If decompress data\n"
             "after that, an EOFError exception will be raised.",
             "ZstdDecompressor_needs_input_doc": "If the max_length output limit in .decompress() method has been reached,\n"
             "and the decompressor has (or may has) unconsumed input data, it will be set\n"
             "to False. In this case, passing b'' to the .decompress() method may output\n"
             "further data."
         }
     );
