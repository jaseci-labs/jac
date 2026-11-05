"""The Argument Clinic signatures of pyexpat.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/pyexpat.jac from them. Taken from
CPython 3.14.6 Modules/pyexpat.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="pyexpat",
         version="3.14.6",
         sources=["Modules/pyexpat.c"],
         classes={"xmlparser": "xmlparseobject *"},
         functions=[
             Function(
                 name="ParserCreate",
                 full_name="pyexpat.ParserCreate",
                 c_basename="pyexpat_ParserCreate",
                 docstring="ParserCreate($module, /, encoding=None, namespace_separator=None,\n"
                 "             intern=<unrepresentable>)\n"
                 "--\n"
                 "\n"
                 "Return a new XML parser object.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
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
                         name="namespace_separator",
                         converter="str",
                         type="const char *",
                         format_unit="z",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="intern",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=3
             ),
             Function(
                 name="ErrorString",
                 full_name="pyexpat.ErrorString",
                 c_basename="pyexpat_ErrorString",
                 docstring="ErrorString($module, code, /)\n"
                 "--\n"
                 "\n"
                 "Returns string error for given number.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="code",
                         kind="POSITIONAL_ONLY",
                         converter="long",
                         type="long",
                         format_unit="l"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="SetReparseDeferralEnabled",
                 full_name="pyexpat.xmlparser.SetReparseDeferralEnabled",
                 c_basename="pyexpat_xmlparser_SetReparseDeferralEnabled",
                 cls="xmlparser",
                 docstring="SetReparseDeferralEnabled($self, enabled, /)\n"
                 "--\n"
                 "\n"
                 "Enable/Disable reparse deferral; enabled by default with Expat >=2.6.0.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="enabled",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="GetReparseDeferralEnabled",
                 full_name="pyexpat.xmlparser.GetReparseDeferralEnabled",
                 c_basename="pyexpat_xmlparser_GetReparseDeferralEnabled",
                 cls="xmlparser",
                 docstring="GetReparseDeferralEnabled($self, /)\n"
                 "--\n"
                 "\n"
                 "Retrieve reparse deferral enabled status; always returns false with Expat <2.6.0.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="Parse",
                 full_name="pyexpat.xmlparser.Parse",
                 c_basename="pyexpat_xmlparser_Parse",
                 cls="xmlparser",
                 docstring="Parse($self, data, isfinal=False, /)\n"
                 "--\n"
                 "\n"
                 "Parse XML data.\n"
                 "\n"
                 "'isfinal' should be true at end of input.",
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
                     Parameter(name="data", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="isfinal",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
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
                 name="ParseFile",
                 full_name="pyexpat.xmlparser.ParseFile",
                 c_basename="pyexpat_xmlparser_ParseFile",
                 cls="xmlparser",
                 docstring="ParseFile($self, file, /)\n"
                 "--\n"
                 "\n"
                 "Parse XML data from file-like object.",
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
                     Parameter(name="file", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="SetBase",
                 full_name="pyexpat.xmlparser.SetBase",
                 c_basename="pyexpat_xmlparser_SetBase",
                 cls="xmlparser",
                 docstring="SetBase($self, base, /)\n"
                 "--\n"
                 "\n"
                 "Set the base URL for the parser.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="base",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="GetBase",
                 full_name="pyexpat.xmlparser.GetBase",
                 c_basename="pyexpat_xmlparser_GetBase",
                 cls="xmlparser",
                 docstring="GetBase($self, /)\n"
                 "--\n"
                 "\n"
                 "Return base URL string for the parser.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="GetInputContext",
                 full_name="pyexpat.xmlparser.GetInputContext",
                 c_basename="pyexpat_xmlparser_GetInputContext",
                 cls="xmlparser",
                 docstring="GetInputContext($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the untranslated text of the input that caused the current event.\n"
                 "\n"
                 "If the event was generated by a large amount of text (such as\n"
                 "a start tag for an element with many attributes), not all of the\n"
                 "text may be available.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="ExternalEntityParserCreate",
                 full_name="pyexpat.xmlparser.ExternalEntityParserCreate",
                 c_basename="pyexpat_xmlparser_ExternalEntityParserCreate",
                 cls="xmlparser",
                 docstring="ExternalEntityParserCreate($self, context, encoding=<unrepresentable>,\n"
                 "                           /)\n"
                 "--\n"
                 "\n"
                 "Create a parser for parsing an external entity based on the information passed to the ExternalEntityRefHandler.",
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
                         name="context",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z"
                     ),
                     Parameter(
                         name="encoding",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="SetParamEntityParsing",
                 full_name="pyexpat.xmlparser.SetParamEntityParsing",
                 c_basename="pyexpat_xmlparser_SetParamEntityParsing",
                 cls="xmlparser",
                 docstring="SetParamEntityParsing($self, flag, /)\n"
                 "--\n"
                 "\n"
                 "Controls parsing of parameter entities (including the external DTD subset).\n"
                 "\n"
                 "Possible flag values are XML_PARAM_ENTITY_PARSING_NEVER,\n"
                 "XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE and\n"
                 "XML_PARAM_ENTITY_PARSING_ALWAYS. Returns true if setting the flag\n"
                 "was successful.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="flag",
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
                 name="UseForeignDTD",
                 full_name="pyexpat.xmlparser.UseForeignDTD",
                 c_basename="pyexpat_xmlparser_UseForeignDTD",
                 cls="xmlparser",
                 docstring="UseForeignDTD($self, flag=True, /)\n"
                 "--\n"
                 "\n"
                 "Allows the application to provide an artificial external subset if one is not specified as part of the document instance.\n"
                 "\n"
                 "This readily allows the use of a 'default' document type controlled\n"
                 "by the application, while still getting the advantage of providing\n"
                 "document type information to the parser.  'flag' defaults to True if\n"
                 "not provided.",
                 condition="(XML_COMBINED_VERSION >= 19505)",
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
                         name="flag",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="SetBillionLaughsAttackProtectionActivationThreshold",
                 full_name="pyexpat.xmlparser.SetBillionLaughsAttackProtectionActivationThreshold",
                 c_basename="pyexpat_xmlparser_SetBillionLaughsAttackProtectionActivationThreshold",
                 cls="xmlparser",
                 docstring="SetBillionLaughsAttackProtectionActivationThreshold($self, threshold, /)\n"
                 "--\n"
                 "\n"
                 "Sets the number of output bytes needed to activate protection against billion laughs attacks.\n"
                 "\n"
                 "The number of output bytes includes amplification from entity expansion\n"
                 "and reading DTD files.\n"
                 "\n"
                 "Parser objects usually have a protection activation threshold of 8 MiB,\n"
                 "but the actual default value depends on the underlying Expat library.\n"
                 "\n"
                 "Activation thresholds below 4 MiB are known to break support for DITA 1.3\n"
                 "payload and are hence not recommended.",
                 condition="(XML_COMBINED_VERSION >= 20400)",
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
                         name="threshold",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_long_long",
                         type="unsigned long long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLongLong_Converter"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="SetBillionLaughsAttackProtectionMaximumAmplification",
                 full_name="pyexpat.xmlparser.SetBillionLaughsAttackProtectionMaximumAmplification",
                 c_basename="pyexpat_xmlparser_SetBillionLaughsAttackProtectionMaximumAmplification",
                 cls="xmlparser",
                 docstring="SetBillionLaughsAttackProtectionMaximumAmplification($self, max_factor,\n"
                 "                                                     /)\n"
                 "--\n"
                 "\n"
                 "Sets the maximum tolerated amplification factor for protection against billion laughs attacks.\n"
                 "\n"
                 "The amplification factor is calculated as \"(direct + indirect) / direct\"\n"
                 "while parsing, where \"direct\" is the number of bytes read from the primary\n"
                 "document in parsing and \"indirect\" is the number of bytes added by expanding\n"
                 "entities and reading external DTD files, combined.\n"
                 "\n"
                 "The 'max_factor' value must be a non-NaN floating point value greater than\n"
                 "or equal to 1.0. Amplification factors greater than 30,000 can be observed\n"
                 "in the middle of parsing even with benign files in practice. In particular,\n"
                 "the activation threshold should be carefully chosen to avoid false positives.\n"
                 "\n"
                 "Parser objects usually have a maximum amplification factor of 100,\n"
                 "but the actual default value depends on the underlying Expat library.",
                 condition="(XML_COMBINED_VERSION >= 20400)",
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
                         name="max_factor",
                         kind="POSITIONAL_ONLY",
                         converter="float",
                         type="float",
                         format_unit="f"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="SetAllocTrackerActivationThreshold",
                 full_name="pyexpat.xmlparser.SetAllocTrackerActivationThreshold",
                 c_basename="pyexpat_xmlparser_SetAllocTrackerActivationThreshold",
                 cls="xmlparser",
                 docstring="SetAllocTrackerActivationThreshold($self, threshold, /)\n"
                 "--\n"
                 "\n"
                 "Sets the number of allocated bytes of dynamic memory needed to activate protection against disproportionate use of RAM.\n"
                 "\n"
                 "Parser objects usually have an allocation activation threshold of 64 MiB,\n"
                 "but the actual default value depends on the underlying Expat library.",
                 condition="(XML_COMBINED_VERSION >= 20702)",
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
                         name="threshold",
                         kind="POSITIONAL_ONLY",
                         converter="unsigned_long_long",
                         type="unsigned long long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLongLong_Converter"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="SetAllocTrackerMaximumAmplification",
                 full_name="pyexpat.xmlparser.SetAllocTrackerMaximumAmplification",
                 c_basename="pyexpat_xmlparser_SetAllocTrackerMaximumAmplification",
                 cls="xmlparser",
                 docstring="SetAllocTrackerMaximumAmplification($self, max_factor, /)\n"
                 "--\n"
                 "\n"
                 "Sets the maximum amplification factor between direct input and bytes of dynamic memory allocated.\n"
                 "\n"
                 "The amplification factor is calculated as \"allocated / direct\" while\n"
                 "parsing, where \"direct\" is the number of bytes read from the primary\n"
                 "document in parsing and \"allocated\" is the number of bytes of\n"
                 "dynamic memory allocated in the parser hierarchy.\n"
                 "\n"
                 "The 'max_factor' value must be a non-NaN floating point value\n"
                 "greater than or equal to 1.0.  Amplification factors greater than\n"
                 "100.0 can be observed near the start of parsing even with benign\n"
                 "files in practice.  In particular, the activation threshold should\n"
                 "be carefully chosen to avoid false positives.\n"
                 "\n"
                 "Parser objects usually have a maximum amplification factor of 100,\n"
                 "but the actual default value depends on the underlying Expat library.",
                 condition="(XML_COMBINED_VERSION >= 20702)",
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
                         name="max_factor",
                         kind="POSITIONAL_ONLY",
                         converter="float",
                         type="float",
                         format_unit="f"
                     )
                 ],
                 flags="METH_METHOD|METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "Xmlparsetype__doc__": "XML parser",
             "pyexpat_module_documentation": "Python wrapper for Expat parser."
         }
     );
