"""The Argument Clinic signatures of _lzma.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/lzma.jac from them. Taken from
CPython 3.14.6 Modules/_lzmamodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_lzma",
         version="3.14.6",
         sources=["Modules/_lzmamodule.c"],
         classes={
             "LZMACompressor": "Compressor *",
             "LZMADecompressor": "Decompressor *"
         },
         functions=[
             Function(
                 name="is_check_supported",
                 full_name="_lzma.is_check_supported",
                 c_basename="_lzma_is_check_supported",
                 docstring="is_check_supported($module, check_id, /)\n"
                 "--\n"
                 "\n"
                 "Test whether the given integrity check is supported.\n"
                 "\n"
                 "Always returns True for CHECK_NONE and CHECK_CRC32.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="check_id",
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
                 name="_decode_filter_properties",
                 full_name="_lzma._decode_filter_properties",
                 c_basename="_lzma__decode_filter_properties",
                 docstring="_decode_filter_properties($module, filter_id, encoded_props, /)\n"
                 "--\n"
                 "\n"
                 "Return a bytes object encoding the options (properties) of the filter specified by *filter* (a dict).\n"
                 "\n"
                 "The result does not include the filter ID itself, only the options.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="filter_id",
                         kind="POSITIONAL_ONLY",
                         converter="lzma_vli",
                         type="lzma_vli",
                         format_unit="O&",
                         convert_with="lzma_vli_converter"
                     ),
                     Parameter(
                         name="encoded_props",
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
                 name="compress",
                 full_name="_lzma.LZMACompressor.compress",
                 c_basename="_lzma_LZMACompressor_compress",
                 cls="LZMACompressor",
                 docstring="compress($self, data, /)\n"
                 "--\n"
                 "\n"
                 "Provide data to the compressor object.\n"
                 "\n"
                 "Returns a chunk of compressed data if possible, or b'' otherwise.\n"
                 "\n"
                 "When you have finished providing data to the compressor, call the\n"
                 "flush() method to finish the compression process.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
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
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="flush",
                 full_name="_lzma.LZMACompressor.flush",
                 c_basename="_lzma_LZMACompressor_flush",
                 cls="LZMACompressor",
                 docstring="flush($self, /)\n"
                 "--\n"
                 "\n"
                 "Finish the compression process.\n"
                 "\n"
                 "Returns the compressed data left in internal buffers.\n"
                 "\n"
                 "The compressor object may not be used after this method is called.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="decompress",
                 full_name="_lzma.LZMADecompressor.decompress",
                 c_basename="_lzma_LZMADecompressor_decompress",
                 cls="LZMADecompressor",
                 docstring="decompress($self, /, data, max_length=-1)\n"
                 "--\n"
                 "\n"
                 "Decompress *data*, returning uncompressed data as bytes.\n"
                 "\n"
                 "If *max_length* is nonnegative, returns at most *max_length* bytes\n"
                 "of decompressed data. If this limit is reached and further output\n"
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
             ),
             Function(
                 name="__new__",
                 full_name="_lzma.LZMADecompressor.__new__",
                 c_basename="_lzma_LZMADecompressor",
                 kind="METHOD_NEW",
                 cls="LZMADecompressor",
                 docstring="LZMADecompressor(format=FORMAT_AUTO, memlimit=None, filters=None)\n"
                 "--\n"
                 "\n"
                 "Create a decompressor object for decompressing data incrementally.\n"
                 "\n"
                 "  format\n"
                 "    Specifies the container format of the input stream.  If this is\n"
                 "    FORMAT_AUTO (the default), the decompressor will automatically detect\n"
                 "    whether the input is FORMAT_XZ or FORMAT_ALONE.  Streams created with\n"
                 "    FORMAT_RAW cannot be autodetected.\n"
                 "  memlimit\n"
                 "    Limit the amount of memory used by the decompressor.  This will cause\n"
                 "    decompression to fail if the input cannot be decompressed within the\n"
                 "    given limit.\n"
                 "  filters\n"
                 "    A custom filter chain.  This argument is required for FORMAT_RAW, and\n"
                 "    not accepted with any other format.  When provided, this should be a\n"
                 "    sequence of dicts, each indicating the ID and options for a single\n"
                 "    filter.\n"
                 "\n"
                 "For one-shot decompression, use the decompress() function instead.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="format",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="FORMAT_AUTO"
                     ),
                     Parameter(
                         name="memlimit",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="filters",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=3
             )
         ],
         docs={
             "Compressor_doc": "LZMACompressor(format=FORMAT_XZ, check=-1, preset=None, filters=None)\n"
             "\n"
             "Create a compressor object for compressing data incrementally.\n"
             "\n"
             "format specifies the container format to use for the output. This can\n"
             "be FORMAT_XZ (default), FORMAT_ALONE, or FORMAT_RAW.\n"
             "\n"
             "check specifies the integrity check to use. For FORMAT_XZ, the default\n"
             "is CHECK_CRC64. FORMAT_ALONE and FORMAT_RAW do not support integrity\n"
             "checks; for these formats, check must be omitted, or be CHECK_NONE.\n"
             "\n"
             "The settings used by the compressor can be specified either as a\n"
             "preset compression level (with the 'preset' argument), or in detail\n"
             "as a custom filter chain (with the 'filters' argument). For FORMAT_XZ\n"
             "and FORMAT_ALONE, the default is to use the PRESET_DEFAULT preset\n"
             "level. For FORMAT_RAW, the caller must always specify a filter chain;\n"
             "the raw compressor does not support preset compression levels.\n"
             "\n"
             "preset (if provided) should be an integer in the range 0-9, optionally\n"
             "OR-ed with the constant PRESET_EXTREME.\n"
             "\n"
             "filters (if provided) should be a sequence of dicts. Each dict should\n"
             "have an entry for \"id\" indicating the ID of the filter, plus\n"
             "additional entries for options to the filter.\n"
             "\n"
             "For one-shot compression, use the compress() function instead.\n",
             "Decompressor_check_doc": "ID of the integrity check used by the input stream.",
             "Decompressor_eof_doc": "True if the end-of-stream marker has been reached.",
             "Decompressor_needs_input_doc": "True if more input is needed before more decompressed data can be produced.",
             "Decompressor_unused_data_doc": "Data found after the end of the compressed stream.",
             "_lzma__encode_filter_properties__doc__": "_encode_filter_properties($module, filter, /)\n"
             "--\n"
             "\n"
             "Return a bytes object encoding the options (properties) of the filter specified by *filter* (a dict).\n"
             "\n"
             "The result does not include the filter ID itself, only the options."
         }
     );
