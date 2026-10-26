"""The Argument Clinic signatures of _json.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/json.jac from them. Taken from
CPython 3.14.6 Modules/_json.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_json",
         version="3.14.6",
         sources=["Modules/_json.c"],
         docs={
             "pydoc_scanstring": "scanstring(string, end, strict=True) -> (string, end)\n"
             "\n"
             "Scan the string s for a JSON string. End is the index of the\n"
             "character in s after the quote that started the JSON string.\n"
             "Unescapes all valid JSON string escape sequences and raises ValueError\n"
             "on attempt to decode an invalid string. If strict is False then literal\n"
             "control characters are allowed in the string.\n"
             "\n"
             "Returns a tuple of the decoded string and the index of the character in s\n"
             "after the end quote.",
             "pydoc_encode_basestring_ascii": "encode_basestring_ascii(string) -> string\n"
             "\n"
             "Return an ASCII-only JSON representation of a Python string",
             "pydoc_encode_basestring": "encode_basestring(string) -> string\n"
             "\n"
             "Return a JSON representation of a Python string",
             "scanner_doc": "JSON scanner object",
             "encoder_doc": "Encoder(markers, default, encoder, indent, key_separator, item_separator, sort_keys, skipkeys, allow_nan)",
             "module_doc": "json speedups\n",
             "scanner_members_strict_doc": "strict",
             "scanner_members_object_hook_doc": "object_hook",
             "scanner_members_parse_float_doc": "parse_float",
             "scanner_members_parse_int_doc": "parse_int",
             "scanner_members_parse_constant_doc": "parse_constant",
             "encoder_members_markers_doc": "markers",
             "encoder_members_default_doc": "default",
             "encoder_members_encoder_doc": "encoder",
             "encoder_members_indent_doc": "indent",
             "encoder_members_key_separator_doc": "key_separator",
             "encoder_members_item_separator_doc": "item_separator",
             "encoder_members_sort_keys_doc": "sort_keys",
             "encoder_members_skipkeys_doc": "skipkeys"
         }
     );
