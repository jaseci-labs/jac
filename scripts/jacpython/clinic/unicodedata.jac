"""The Argument Clinic signatures of unicodedata.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/unicodedata.jac from them. Taken from
CPython 3.14.6 Modules/unicodedata.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="unicodedata",
         version="3.14.6",
         sources=["Modules/unicodedata.c"],
         classes={"UCD": "PreviousDBVersion *"},
         functions=[
             Function(
                 name="decimal",
                 full_name="unicodedata.UCD.decimal",
                 c_basename="unicodedata_UCD_decimal",
                 cls="UCD",
                 docstring="decimal($self, chr, default=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Converts a Unicode character into its equivalent decimal value.\n"
                 "\n"
                 "Returns the decimal value assigned to the character chr as integer.\n"
                 "If no such value is defined, default is returned, or, if not given,\n"
                 "ValueError is raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     ),
                     Parameter(
                         name="default",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="digit",
                 full_name="unicodedata.UCD.digit",
                 c_basename="unicodedata_UCD_digit",
                 cls="UCD",
                 docstring="digit($self, chr, default=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Converts a Unicode character into its equivalent digit value.\n"
                 "\n"
                 "Returns the digit value assigned to the character chr as integer.\n"
                 "If no such value is defined, default is returned, or, if not given,\n"
                 "ValueError is raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     ),
                     Parameter(
                         name="default",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="numeric",
                 full_name="unicodedata.UCD.numeric",
                 c_basename="unicodedata_UCD_numeric",
                 cls="UCD",
                 docstring="numeric($self, chr, default=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Converts a Unicode character into its equivalent numeric value.\n"
                 "\n"
                 "Returns the numeric value assigned to the character chr as float.\n"
                 "If no such value is defined, default is returned, or, if not given,\n"
                 "ValueError is raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     ),
                     Parameter(
                         name="default",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="category",
                 full_name="unicodedata.UCD.category",
                 c_basename="unicodedata_UCD_category",
                 cls="UCD",
                 docstring="category($self, chr, /)\n"
                 "--\n"
                 "\n"
                 "Returns the general category assigned to the character chr as string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="bidirectional",
                 full_name="unicodedata.UCD.bidirectional",
                 c_basename="unicodedata_UCD_bidirectional",
                 cls="UCD",
                 docstring="bidirectional($self, chr, /)\n"
                 "--\n"
                 "\n"
                 "Returns the bidirectional class assigned to the character chr as string.\n"
                 "\n"
                 "If no such value is defined, an empty string is returned.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="combining",
                 full_name="unicodedata.UCD.combining",
                 c_basename="unicodedata_UCD_combining",
                 cls="UCD",
                 docstring="combining($self, chr, /)\n"
                 "--\n"
                 "\n"
                 "Returns the canonical combining class assigned to the character chr as integer.\n"
                 "\n"
                 "Returns 0 if no combining class is defined.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="mirrored",
                 full_name="unicodedata.UCD.mirrored",
                 c_basename="unicodedata_UCD_mirrored",
                 cls="UCD",
                 docstring="mirrored($self, chr, /)\n"
                 "--\n"
                 "\n"
                 "Returns the mirrored property assigned to the character chr as integer.\n"
                 "\n"
                 "Returns 1 if the character has been identified as a \"mirrored\"\n"
                 "character in bidirectional text, 0 otherwise.",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="east_asian_width",
                 full_name="unicodedata.UCD.east_asian_width",
                 c_basename="unicodedata_UCD_east_asian_width",
                 cls="UCD",
                 docstring="east_asian_width($self, chr, /)\n"
                 "--\n"
                 "\n"
                 "Returns the east asian width assigned to the character chr as string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="decomposition",
                 full_name="unicodedata.UCD.decomposition",
                 c_basename="unicodedata_UCD_decomposition",
                 cls="UCD",
                 docstring="decomposition($self, chr, /)\n"
                 "--\n"
                 "\n"
                 "Returns the character decomposition mapping assigned to the character chr as string.\n"
                 "\n"
                 "An empty string is returned in case no such mapping is defined.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="is_normalized",
                 full_name="unicodedata.UCD.is_normalized",
                 c_basename="unicodedata_UCD_is_normalized",
                 cls="UCD",
                 docstring="is_normalized($self, form, unistr, /)\n"
                 "--\n"
                 "\n"
                 "Return whether the Unicode string unistr is in the normal form 'form'.\n"
                 "\n"
                 "Valid values for form are 'NFC', 'NFKC', 'NFD', and 'NFKD'.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="form",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="unistr",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="normalize",
                 full_name="unicodedata.UCD.normalize",
                 c_basename="unicodedata_UCD_normalize",
                 cls="UCD",
                 docstring="normalize($self, form, unistr, /)\n"
                 "--\n"
                 "\n"
                 "Return the normal form 'form' for the Unicode string unistr.\n"
                 "\n"
                 "Valid values for form are 'NFC', 'NFKC', 'NFD', and 'NFKD'.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="form",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="unistr",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="name",
                 full_name="unicodedata.UCD.name",
                 c_basename="unicodedata_UCD_name",
                 cls="UCD",
                 docstring="name($self, chr, default=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Returns the name assigned to the character chr as a string.\n"
                 "\n"
                 "If no name is defined, default is returned, or, if not given,\n"
                 "ValueError is raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="chr",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="C"
                     ),
                     Parameter(
                         name="default",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="lookup",
                 full_name="unicodedata.UCD.lookup",
                 c_basename="unicodedata_UCD_lookup",
                 cls="UCD",
                 docstring="lookup($self, name, /)\n"
                 "--\n"
                 "\n"
                 "Look up character by name.\n"
                 "\n"
                 "If a character with the given name is found, return the\n"
                 "corresponding character.  If not found, KeyError is raised.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s#"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "unicodedata_docstring": "This module provides access to the Unicode Character Database which\n"
             "defines character properties for all Unicode characters. The data in\n"
             "this database is based on the UnicodeData.txt file version\n"
             " which is publicly available from ftp://ftp.unicode.org/.\n"
             "\n"
             "The module uses the same names and symbols as defined by the\n"
             "UnicodeData File Format ."
         }
     );
