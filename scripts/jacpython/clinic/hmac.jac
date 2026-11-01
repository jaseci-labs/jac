"""The Argument Clinic signatures of _hmac.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/hmac.jac from them. Taken from
CPython 3.14.6 Modules/hmacmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_hmac",
         version="3.14.6",
         sources=["Modules/hmacmodule.c"],
         classes={"HMAC": "HMACObject *"},
         functions=[
             Function(
                 name="new",
                 full_name="_hmac.new",
                 c_basename="_hmac_new",
                 docstring="new($module, /, key, msg=None, digestmod=None)\n"
                 "--\n"
                 "\n"
                 "Return a new HMAC object.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", format_unit="O"),
                     Parameter(
                         name="msg",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="digestmod",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="compute_digest",
                 full_name="_hmac.compute_digest",
                 c_basename="_hmac_compute_digest",
                 docstring="compute_digest($module, /, key, msg, digest)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", format_unit="O"),
                     Parameter(name="msg", format_unit="O"),
                     Parameter(name="digest", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="compute_md5",
                 full_name="_hmac.compute_md5",
                 c_basename="_hmac_compute_md5",
                 docstring="compute_md5($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha1",
                 full_name="_hmac.compute_sha1",
                 c_basename="_hmac_compute_sha1",
                 docstring="compute_sha1($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha224",
                 full_name="_hmac.compute_sha224",
                 c_basename="_hmac_compute_sha2_224",
                 docstring="compute_sha224($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha256",
                 full_name="_hmac.compute_sha256",
                 c_basename="_hmac_compute_sha2_256",
                 docstring="compute_sha256($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha384",
                 full_name="_hmac.compute_sha384",
                 c_basename="_hmac_compute_sha2_384",
                 docstring="compute_sha384($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha512",
                 full_name="_hmac.compute_sha512",
                 c_basename="_hmac_compute_sha2_512",
                 docstring="compute_sha512($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha3_224",
                 full_name="_hmac.compute_sha3_224",
                 c_basename="_hmac_compute_sha3_224",
                 docstring="compute_sha3_224($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha3_256",
                 full_name="_hmac.compute_sha3_256",
                 c_basename="_hmac_compute_sha3_256",
                 docstring="compute_sha3_256($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha3_384",
                 full_name="_hmac.compute_sha3_384",
                 c_basename="_hmac_compute_sha3_384",
                 docstring="compute_sha3_384($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_sha3_512",
                 full_name="_hmac.compute_sha3_512",
                 c_basename="_hmac_compute_sha3_512",
                 docstring="compute_sha3_512($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_blake2s_32",
                 full_name="_hmac.compute_blake2s_32",
                 c_basename="_hmac_compute_blake2s_32",
                 docstring="compute_blake2s_32($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="compute_blake2b_32",
                 full_name="_hmac.compute_blake2b_32",
                 c_basename="_hmac_compute_blake2b_32",
                 docstring="compute_blake2b_32($module, key, msg, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="key", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="msg", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="copy",
                 full_name="_hmac.HMAC.copy",
                 c_basename="_hmac_HMAC_copy",
                 cls="HMAC",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy (\"clone\") of the HMAC object.",
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
                 name="update",
                 full_name="_hmac.HMAC.update",
                 c_basename="_hmac_HMAC_update",
                 cls="HMAC",
                 docstring="update($self, /, msg)\n"
                 "--\n"
                 "\n"
                 "Update the HMAC object with the given message.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="msg", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="digest",
                 full_name="_hmac.HMAC.digest",
                 c_basename="_hmac_HMAC_digest",
                 cls="HMAC",
                 docstring="digest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the digest of the bytes passed to the update() method so far.\n"
                 "\n"
                 "This method may raise a MemoryError.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="hexdigest",
                 full_name="_hmac.HMAC.hexdigest",
                 c_basename="_hmac_HMAC_hexdigest",
                 cls="HMAC",
                 docstring="hexdigest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return hexadecimal digest of the bytes passed to the update() method so far.\n"
                 "\n"
                 "This may be used to exchange the value safely in email or other\n"
                 "non-binary environments.\n"
                 "\n"
                 "This method may raise a MemoryError.",
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
                 full_name="_hmac.HMAC.name",
                 c_basename="_hmac_HMAC_name",
                 kind="GETTER",
                 cls="HMAC",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="block_size",
                 full_name="_hmac.HMAC.block_size",
                 c_basename="_hmac_HMAC_block_size",
                 kind="GETTER",
                 cls="HMAC",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="digest_size",
                 full_name="_hmac.HMAC.digest_size",
                 c_basename="_hmac_HMAC_digest_size",
                 kind="GETTER",
                 cls="HMAC",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             )
         ]
     );
