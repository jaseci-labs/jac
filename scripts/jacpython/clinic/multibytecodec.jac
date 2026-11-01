"""The Argument Clinic signatures of _multibytecodec.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/multibytecodec.jac from them. Taken from
the C sources it replaces (Modules/cjkcodecs/multibytecodec.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_multibytecodec",
         version="3.14.6",
         sources=["Modules/cjkcodecs/multibytecodec.c"],
         classes={
             "MultibyteCodec": "MultibyteCodecObject *",
             "MultibyteIncrementalEncoder": "MultibyteIncrementalEncoderObject *",
             "MultibyteIncrementalDecoder": "MultibyteIncrementalDecoderObject *",
             "MultibyteStreamReader": "MultibyteStreamReaderObject *",
             "MultibyteStreamWriter": "MultibyteStreamWriterObject *"
         },
         functions=[
             Function(
                 name="__create_codec",
                 full_name="_multibytecodec.__create_codec",
                 c_basename="_multibytecodec___create_codec",
                 docstring="__create_codec($module, arg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="arg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="encode",
                 full_name="_multibytecodec.MultibyteCodec.encode",
                 c_basename="_multibytecodec_MultibyteCodec_encode",
                 cls="MultibyteCodec",
                 docstring="encode($self, /, input, errors=None)\n"
                 "--\n"
                 "\n"
                 "Return an encoded string version of 'input'.\n"
                 "\n"
                 "'errors' may be given to set a different error handling scheme.\n"
                 "Default is 'strict' meaning that encoding errors raise\n"
                 "a UnicodeEncodeError.  Other possible values are 'ignore', 'replace'\n"
                 "and 'xmlcharrefreplace' as well as any other name registered with\n"
                 "codecs.register_error that can handle UnicodeEncodeErrors.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="input", format_unit="O"),
                     Parameter(
                         name="errors",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="decode",
                 full_name="_multibytecodec.MultibyteCodec.decode",
                 c_basename="_multibytecodec_MultibyteCodec_decode",
                 cls="MultibyteCodec",
                 docstring="decode($self, /, input, errors=None)\n"
                 "--\n"
                 "\n"
                 "Decodes 'input'.\n"
                 "\n"
                 "'errors' may be given to set a different error handling scheme.\n"
                 "Default is 'strict' meaning that encoding errors raise\n"
                 "a UnicodeDecodeError.  Other possible values are 'ignore' and\n"
                 "'replace' as well as any other name registered with\n"
                 "codecs.register_error that is able to handle UnicodeDecodeErrors.\"",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="input",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="errors",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="encode",
                 full_name="_multibytecodec.MultibyteIncrementalEncoder.encode",
                 c_basename="_multibytecodec_MultibyteIncrementalEncoder_encode",
                 cls="MultibyteIncrementalEncoder",
                 docstring="encode($self, /, input, final=False)\n" "--",
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
                 full_name="_multibytecodec.MultibyteIncrementalEncoder.getstate",
                 c_basename="_multibytecodec_MultibyteIncrementalEncoder_getstate",
                 cls="MultibyteIncrementalEncoder",
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
                 full_name="_multibytecodec.MultibyteIncrementalEncoder.setstate",
                 c_basename="_multibytecodec_MultibyteIncrementalEncoder_setstate",
                 cls="MultibyteIncrementalEncoder",
                 docstring="setstate($self, state, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="state",
                         kind="POSITIONAL_ONLY",
                         type="PyLongObject *",
                         format_unit="O!",
                         subclass_of="&PyLong_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="reset",
                 full_name="_multibytecodec.MultibyteIncrementalEncoder.reset",
                 c_basename="_multibytecodec_MultibyteIncrementalEncoder_reset",
                 cls="MultibyteIncrementalEncoder",
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
                 name="decode",
                 full_name="_multibytecodec.MultibyteIncrementalDecoder.decode",
                 c_basename="_multibytecodec_MultibyteIncrementalDecoder_decode",
                 cls="MultibyteIncrementalDecoder",
                 docstring="decode($self, /, input, final=False)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="input",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
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
                 full_name="_multibytecodec.MultibyteIncrementalDecoder.getstate",
                 c_basename="_multibytecodec_MultibyteIncrementalDecoder_getstate",
                 cls="MultibyteIncrementalDecoder",
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
                 full_name="_multibytecodec.MultibyteIncrementalDecoder.setstate",
                 c_basename="_multibytecodec_MultibyteIncrementalDecoder_setstate",
                 cls="MultibyteIncrementalDecoder",
                 docstring="setstate($self, state, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="state",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyTuple_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="reset",
                 full_name="_multibytecodec.MultibyteIncrementalDecoder.reset",
                 c_basename="_multibytecodec_MultibyteIncrementalDecoder_reset",
                 cls="MultibyteIncrementalDecoder",
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
                 name="read",
                 full_name="_multibytecodec.MultibyteStreamReader.read",
                 c_basename="_multibytecodec_MultibyteStreamReader_read",
                 cls="MultibyteStreamReader",
                 docstring="read($self, sizeobj=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sizeobj",
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
                 name="readline",
                 full_name="_multibytecodec.MultibyteStreamReader.readline",
                 c_basename="_multibytecodec_MultibyteStreamReader_readline",
                 cls="MultibyteStreamReader",
                 docstring="readline($self, sizeobj=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sizeobj",
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
                 name="readlines",
                 full_name="_multibytecodec.MultibyteStreamReader.readlines",
                 c_basename="_multibytecodec_MultibyteStreamReader_readlines",
                 cls="MultibyteStreamReader",
                 docstring="readlines($self, sizehintobj=None, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sizehintobj",
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
                 name="reset",
                 full_name="_multibytecodec.MultibyteStreamReader.reset",
                 c_basename="_multibytecodec_MultibyteStreamReader_reset",
                 cls="MultibyteStreamReader",
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
                 name="write",
                 full_name="_multibytecodec.MultibyteStreamWriter.write",
                 c_basename="_multibytecodec_MultibyteStreamWriter_write",
                 cls="MultibyteStreamWriter",
                 docstring="write($self, strobj, /)\n" "--",
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
                     Parameter(name="strobj", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="writelines",
                 full_name="_multibytecodec.MultibyteStreamWriter.writelines",
                 c_basename="_multibytecodec_MultibyteStreamWriter_writelines",
                 cls="MultibyteStreamWriter",
                 docstring="writelines($self, lines, /)\n" "--",
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
                     Parameter(name="lines", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="reset",
                 full_name="_multibytecodec.MultibyteStreamWriter.reset",
                 c_basename="_multibytecodec_MultibyteStreamWriter_reset",
                 cls="MultibyteStreamWriter",
                 docstring="reset($self, /)\n" "--",
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
             )
         ],
         docs={"codecctx_getsets_errors_doc": "how to treat errors"}
     );
