"""The Argument Clinic signatures of binascii.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/binascii.jac from them. Taken from
CPython 3.14.6 Modules/binascii.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="binascii",
         version="3.14.6",
         sources=["Modules/binascii.c"],
         functions=[
             Function(
                 name="a2b_uu",
                 full_name="binascii.a2b_uu",
                 c_basename="binascii_a2b_uu",
                 docstring="a2b_uu($module, data, /)\n"
                 "--\n"
                 "\n"
                 "Decode a line of uuencoded data.",
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
                         converter="ascii_buffer",
                         type="Py_buffer",
                         format_unit="O&",
                         c_default="{NULL, NULL}",
                         convert_with="ascii_buffer_converter",
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
                 name="b2a_uu",
                 full_name="binascii.b2a_uu",
                 c_basename="binascii_b2a_uu",
                 docstring="b2a_uu($module, data, /, *, backtick=False)\n"
                 "--\n"
                 "\n"
                 "Uuencode line of data.",
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
                         name="backtick",
                         kind="KEYWORD_ONLY",
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
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="a2b_base64",
                 full_name="binascii.a2b_base64",
                 c_basename="binascii_a2b_base64",
                 docstring="a2b_base64($module, data, /, *, strict_mode=False)\n"
                 "--\n"
                 "\n"
                 "Decode a line of base64 data.\n"
                 "\n"
                 "  strict_mode\n"
                 "    When set to True, bytes that are not part of the base64 standard are not allowed.\n"
                 "    The same applies to excess data after padding (= / ==).",
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
                         converter="ascii_buffer",
                         type="Py_buffer",
                         format_unit="O&",
                         c_default="{NULL, NULL}",
                         convert_with="ascii_buffer_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="strict_mode",
                         kind="KEYWORD_ONLY",
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
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="b2a_base64",
                 full_name="binascii.b2a_base64",
                 c_basename="binascii_b2a_base64",
                 docstring="b2a_base64($module, data, /, *, newline=True)\n"
                 "--\n"
                 "\n"
                 "Base64-code line of data.",
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
                         name="newline",
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
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="crc_hqx",
                 full_name="binascii.crc_hqx",
                 c_basename="binascii_crc_hqx",
                 docstring="crc_hqx($module, data, crc, /)\n"
                 "--\n"
                 "\n"
                 "Compute CRC-CCITT incrementally.",
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
                         name="crc",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_int",
                         type="unsigned int",
                         format_unit="I"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="crc32",
                 full_name="binascii.crc32",
                 c_basename="binascii_crc32",
                 docstring="crc32($module, data, crc=0, /)\n"
                 "--\n"
                 "\n"
                 "Compute CRC-32 incrementally.",
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
                         name="crc",
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
                 name="b2a_hex",
                 full_name="binascii.b2a_hex",
                 c_basename="binascii_b2a_hex",
                 docstring="b2a_hex($module, /, data, sep=<unrepresentable>, bytes_per_sep=1)\n"
                 "--\n"
                 "\n"
                 "Hexadecimal representation of binary data.\n"
                 "\n"
                 "  sep\n"
                 "    An optional single character or byte to separate hex bytes.\n"
                 "  bytes_per_sep\n"
                 "    How many bytes between separators.  Positive values count from the\n"
                 "    right, negative values count from the left.\n"
                 "\n"
                 "The return value is a bytes object.  This function is also\n"
                 "available as \"hexlify()\".\n"
                 "\n"
                 "Example:\n"
                 ">>> binascii.b2a_hex(b'\\xb9\\x01\\xef')\n"
                 "b'b901ef'\n"
                 ">>> binascii.hexlify(b'\\xb9\\x01\\xef', ':')\n"
                 "b'b9:01:ef'\n"
                 ">>> binascii.b2a_hex(b'\\xb9\\x01\\xef', b'_', 2)\n"
                 "b'b9_01ef'",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                         name="sep",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="bytes_per_sep",
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
                 max_pos=3
             ),
             Function(
                 name="hexlify",
                 full_name="binascii.hexlify",
                 c_basename="binascii_hexlify",
                 docstring="hexlify($module, /, data, sep=<unrepresentable>, bytes_per_sep=1)\n"
                 "--\n"
                 "\n"
                 "Hexadecimal representation of binary data.\n"
                 "\n"
                 "  sep\n"
                 "    An optional single character or byte to separate hex bytes.\n"
                 "  bytes_per_sep\n"
                 "    How many bytes between separators.  Positive values count from the\n"
                 "    right, negative values count from the left.\n"
                 "\n"
                 "The return value is a bytes object.  This function is also\n"
                 "available as \"b2a_hex()\".",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                         name="sep",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="bytes_per_sep",
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
                 max_pos=3
             ),
             Function(
                 name="a2b_hex",
                 full_name="binascii.a2b_hex",
                 c_basename="binascii_a2b_hex",
                 docstring="a2b_hex($module, hexstr, /)\n"
                 "--\n"
                 "\n"
                 "Binary data of hexadecimal representation.\n"
                 "\n"
                 "hexstr must contain an even number of hex digits (upper or lower case).\n"
                 "This function is also available as \"unhexlify()\".",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="hexstr",
                         kind="POSITIONAL_ONLY",
                         converter="ascii_buffer",
                         type="Py_buffer",
                         format_unit="O&",
                         c_default="{NULL, NULL}",
                         convert_with="ascii_buffer_converter",
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
                 name="unhexlify",
                 full_name="binascii.unhexlify",
                 c_basename="binascii_unhexlify",
                 docstring="unhexlify($module, hexstr, /)\n"
                 "--\n"
                 "\n"
                 "Binary data of hexadecimal representation.\n"
                 "\n"
                 "hexstr must contain an even number of hex digits (upper or lower case).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="hexstr",
                         kind="POSITIONAL_ONLY",
                         converter="ascii_buffer",
                         type="Py_buffer",
                         format_unit="O&",
                         c_default="{NULL, NULL}",
                         convert_with="ascii_buffer_converter",
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
                 name="a2b_qp",
                 full_name="binascii.a2b_qp",
                 c_basename="binascii_a2b_qp",
                 docstring="a2b_qp($module, /, data, header=False)\n"
                 "--\n"
                 "\n"
                 "Decode a string of qp-encoded data.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         converter="ascii_buffer",
                         type="Py_buffer",
                         format_unit="O&",
                         c_default="{NULL, NULL}",
                         convert_with="ascii_buffer_converter",
                         by_reference=True
                     ),
                     Parameter(
                         name="header",
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
                 name="b2a_qp",
                 full_name="binascii.b2a_qp",
                 c_basename="binascii_b2a_qp",
                 docstring="b2a_qp($module, /, data, quotetabs=False, istext=True, header=False)\n"
                 "--\n"
                 "\n"
                 "Encode a string using quoted-printable encoding.\n"
                 "\n"
                 "On encoding, when istext is set, newlines are not encoded, and white\n"
                 "space at end of lines is.  When istext is not set, \\r and \\n (CR/LF)\n"
                 "are both encoded.  When quotetabs is set, space and tabs are encoded.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                         name="quotetabs",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     ),
                     Parameter(
                         name="istext",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="header",
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
                 max_pos=4
             )
         ],
         docs={"doc_binascii": "Conversion between binary data and ASCII"}
     );
