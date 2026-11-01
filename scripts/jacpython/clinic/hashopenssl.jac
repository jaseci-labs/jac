"""The Argument Clinic signatures of _hashlib.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/hashopenssl.jac from them. Taken from
CPython 3.14.6 Modules/_hashopenssl.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_hashlib",
         version="3.14.6",
         sources=["Modules/_hashopenssl.c"],
         classes={
             "HASH": "EVPobject *",
             "HASHXOF": "EVPobject *",
             "HMAC": "HMACobject *"
         },
         functions=[
             Function(
                 name="new",
                 full_name="_hashlib.new",
                 c_basename="_hashlib_new",
                 docstring="new($module, /, name, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Return a new hash object using the named algorithm.\n"
                 "\n"
                 "An optional string argument may be provided and will be\n"
                 "automatically hashed.\n"
                 "\n"
                 "The MD5 and SHA1 algorithms are always supported.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
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
                 name="openssl_md5",
                 full_name="_hashlib.openssl_md5",
                 c_basename="_hashlib_openssl_md5",
                 docstring="openssl_md5($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a md5 hash object; optionally initialized with a string",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha1",
                 full_name="_hashlib.openssl_sha1",
                 c_basename="_hashlib_openssl_sha1",
                 docstring="openssl_sha1($module, /, data=b'', *, usedforsecurity=True, string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha1 hash object; optionally initialized with a string",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha224",
                 full_name="_hashlib.openssl_sha224",
                 c_basename="_hashlib_openssl_sha224",
                 docstring="openssl_sha224($module, /, data=b'', *, usedforsecurity=True,\n"
                 "               string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha224 hash object; optionally initialized with a string",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha256",
                 full_name="_hashlib.openssl_sha256",
                 c_basename="_hashlib_openssl_sha256",
                 docstring="openssl_sha256($module, /, data=b'', *, usedforsecurity=True,\n"
                 "               string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha256 hash object; optionally initialized with a string",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha384",
                 full_name="_hashlib.openssl_sha384",
                 c_basename="_hashlib_openssl_sha384",
                 docstring="openssl_sha384($module, /, data=b'', *, usedforsecurity=True,\n"
                 "               string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha384 hash object; optionally initialized with a string",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha512",
                 full_name="_hashlib.openssl_sha512",
                 c_basename="_hashlib_openssl_sha512",
                 docstring="openssl_sha512($module, /, data=b'', *, usedforsecurity=True,\n"
                 "               string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha512 hash object; optionally initialized with a string",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha3_224",
                 full_name="_hashlib.openssl_sha3_224",
                 c_basename="_hashlib_openssl_sha3_224",
                 docstring="openssl_sha3_224($module, /, data=b'', *, usedforsecurity=True,\n"
                 "                 string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha3-224 hash object; optionally initialized with a string",
                 condition="defined(PY_OPENSSL_HAS_SHA3)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha3_256",
                 full_name="_hashlib.openssl_sha3_256",
                 c_basename="_hashlib_openssl_sha3_256",
                 docstring="openssl_sha3_256($module, /, data=b'', *, usedforsecurity=True,\n"
                 "                 string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha3-256 hash object; optionally initialized with a string",
                 condition="defined(PY_OPENSSL_HAS_SHA3)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha3_384",
                 full_name="_hashlib.openssl_sha3_384",
                 c_basename="_hashlib_openssl_sha3_384",
                 docstring="openssl_sha3_384($module, /, data=b'', *, usedforsecurity=True,\n"
                 "                 string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha3-384 hash object; optionally initialized with a string",
                 condition="defined(PY_OPENSSL_HAS_SHA3)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_sha3_512",
                 full_name="_hashlib.openssl_sha3_512",
                 c_basename="_hashlib_openssl_sha3_512",
                 docstring="openssl_sha3_512($module, /, data=b'', *, usedforsecurity=True,\n"
                 "                 string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a sha3-512 hash object; optionally initialized with a string",
                 condition="defined(PY_OPENSSL_HAS_SHA3)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_shake_128",
                 full_name="_hashlib.openssl_shake_128",
                 c_basename="_hashlib_openssl_shake_128",
                 docstring="openssl_shake_128($module, /, data=b'', *, usedforsecurity=True,\n"
                 "                  string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a shake-128 variable hash object; optionally initialized with a string",
                 condition="defined(PY_OPENSSL_HAS_SHAKE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="openssl_shake_256",
                 full_name="_hashlib.openssl_shake_256",
                 c_basename="_hashlib_openssl_shake_256",
                 docstring="openssl_shake_256($module, /, data=b'', *, usedforsecurity=True,\n"
                 "                  string=None)\n"
                 "--\n"
                 "\n"
                 "Returns a shake-256 variable hash object; optionally initialized with a string",
                 condition="defined(PY_OPENSSL_HAS_SHAKE)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="data",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
                         c_default="NULL"
                     ),
                     Parameter(
                         name="usedforsecurity",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=True,
                         c_default="1"
                     ),
                     Parameter(
                         name="string",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="pbkdf2_hmac",
                 full_name="_hashlib.pbkdf2_hmac",
                 c_basename="pbkdf2_hmac",
                 docstring="pbkdf2_hmac($module, /, hash_name, password, salt, iterations,\n"
                 "            dklen=None)\n"
                 "--\n"
                 "\n"
                 "Password based key derivation function 2 (PKCS #5 v2.0) with HMAC as pseudorandom function.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="hash_name",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="password",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="salt",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="iterations",
                         converter="long",
                         type="long",
                         format_unit="l"
                     ),
                     Parameter(
                         name="dklen",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=4,
                 max_pos=5
             ),
             Function(
                 name="scrypt",
                 full_name="_hashlib.scrypt",
                 c_basename="_hashlib_scrypt",
                 docstring="scrypt($module, /, password, *, salt, n, r, p, maxmem=0, dklen=64)\n"
                 "--\n"
                 "\n"
                 "scrypt password-based key derivation function.",
                 condition="defined(PY_OPENSSL_HAS_SCRYPT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="password",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="salt",
                         kind="KEYWORD_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="n",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     ),
                     Parameter(
                         name="r",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     ),
                     Parameter(
                         name="p",
                         kind="KEYWORD_ONLY",
                         converter="unsigned_long",
                         type="unsigned long",
                         format_unit="O&",
                         convert_with="_PyLong_UnsignedLong_Converter"
                     ),
                     Parameter(
                         name="maxmem",
                         kind="KEYWORD_ONLY",
                         converter="long",
                         type="long",
                         format_unit="l",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="dklen",
                         kind="KEYWORD_ONLY",
                         converter="long",
                         type="long",
                         format_unit="l",
                         default_kind="value",
                         py_default=64,
                         c_default="64"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 min_kw_only=4
             ),
             Function(
                 name="hmac_digest",
                 full_name="_hashlib.hmac_digest",
                 c_basename="_hashlib_hmac_singleshot",
                 docstring="hmac_digest($module, /, key, msg, digest)\n"
                 "--\n"
                 "\n"
                 "Single-shot HMAC.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="key",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="msg",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(name="digest", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=3
             ),
             Function(
                 name="hmac_new",
                 full_name="_hashlib.hmac_new",
                 c_basename="_hashlib_hmac_new",
                 docstring="hmac_new($module, /, key, msg=b'', digestmod=None)\n"
                 "--\n"
                 "\n"
                 "Return a new hmac object.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="key",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="msg",
                         format_unit="O",
                         default_kind="value",
                         py_default=b'',
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
                 name="get_fips_mode",
                 full_name="_hashlib.get_fips_mode",
                 c_basename="_hashlib_get_fips_mode",
                 docstring="get_fips_mode($module, /)\n"
                 "--\n"
                 "\n"
                 "Determine the OpenSSL FIPS mode of operation.\n"
                 "\n"
                 "For OpenSSL 3.0.0 and newer it returns the state of the default provider\n"
                 "in the default OSSL context. It's not quite the same as FIPS_mode() but\n"
                 "good enough for unittests.\n"
                 "\n"
                 "Effectively any non-zero return value indicates FIPS mode;\n"
                 "values other than 1 may have additional significance.",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="compare_digest",
                 full_name="_hashlib.compare_digest",
                 c_basename="_hashlib_compare_digest",
                 docstring="compare_digest($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Return 'a == b'.\n"
                 "\n"
                 "This function uses an approach designed to prevent\n"
                 "timing analysis, making it appropriate for cryptography.\n"
                 "\n"
                 "a and b must both be of the same type: either str (ASCII only),\n"
                 "or any bytes-like object.\n"
                 "\n"
                 "Note: If a and b are of different lengths, or if an error occurs,\n"
                 "a timing attack could theoretically reveal information about the\n"
                 "types and lengths of a and b--but not their values.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="copy",
                 full_name="_hashlib.HASH.copy",
                 c_basename="EVP_copy",
                 cls="HASH",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy of the hash object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="digest",
                 full_name="_hashlib.HASH.digest",
                 c_basename="EVP_digest",
                 cls="HASH",
                 docstring="digest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a bytes object.",
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
                 full_name="_hashlib.HASH.hexdigest",
                 c_basename="EVP_hexdigest",
                 cls="HASH",
                 docstring="hexdigest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a string of hexadecimal digits.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="update",
                 full_name="_hashlib.HASH.update",
                 c_basename="EVP_update",
                 cls="HASH",
                 docstring="update($self, obj, /)\n"
                 "--\n"
                 "\n"
                 "Update this hash object's state with the provided string.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="obj", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="digest",
                 full_name="_hashlib.HASHXOF.digest",
                 c_basename="EVPXOF_digest",
                 cls="HASHXOF",
                 docstring="digest($self, /, length)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a bytes object.",
                 condition="defined(PY_OPENSSL_HAS_SHAKE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="length",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="hexdigest",
                 full_name="_hashlib.HASHXOF.hexdigest",
                 c_basename="EVPXOF_hexdigest",
                 cls="HASHXOF",
                 docstring="hexdigest($self, /, length)\n"
                 "--\n"
                 "\n"
                 "Return the digest value as a string of hexadecimal digits.",
                 condition="defined(PY_OPENSSL_HAS_SHAKE)",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="length",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="copy",
                 full_name="_hashlib.HMAC.copy",
                 c_basename="_hashlib_HMAC_copy",
                 cls="HMAC",
                 docstring="copy($self, /)\n"
                 "--\n"
                 "\n"
                 "Return a copy (\"clone\") of the HMAC object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="update",
                 full_name="_hashlib.HMAC.update",
                 c_basename="_hashlib_HMAC_update",
                 cls="HMAC",
                 docstring="update($self, /, msg)\n"
                 "--\n"
                 "\n"
                 "Update the HMAC object with msg.",
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
                 full_name="_hashlib.HMAC.digest",
                 c_basename="_hashlib_HMAC_digest",
                 cls="HMAC",
                 docstring="digest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return the digest of the bytes passed to the update() method so far.",
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
                 full_name="_hashlib.HMAC.hexdigest",
                 c_basename="_hashlib_HMAC_hexdigest",
                 cls="HMAC",
                 docstring="hexdigest($self, /)\n"
                 "--\n"
                 "\n"
                 "Return hexadecimal digest of the bytes passed to the update() method so far.\n"
                 "\n"
                 "This may be used to exchange the value safely in email or other\n"
                 "non-binary environments.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             )
         ],
         docs={
             "hashtype_doc": "HASH(name, string=b'')\n"
             "--\n"
             "\n"
             "A hash is an object used to calculate a checksum of a string of information.\n"
             "\n"
             "Methods:\n"
             "\n"
             "update() -- updates the current digest with an additional string\n"
             "digest() -- return the current digest value\n"
             "hexdigest() -- return the current digest as a string of hexadecimal digits\n"
             "copy() -- return a copy of the current hash object\n"
             "\n"
             "Attributes:\n"
             "\n"
             "name -- the hash algorithm being used by this object\n"
             "digest_size -- number of bytes in this hashes output",
             "hashxoftype_doc": "HASHXOF(name, string=b'')\n"
             "--\n"
             "\n"
             "A hash is an object used to calculate a checksum of a string of information.\n"
             "\n"
             "Methods:\n"
             "\n"
             "update() -- updates the current digest with an additional string\n"
             "digest(length) -- return the current digest value\n"
             "hexdigest(length) -- return the current digest as a string of hexadecimal digits\n"
             "copy() -- return a copy of the current hash object\n"
             "\n"
             "Attributes:\n"
             "\n"
             "name -- the hash algorithm being used by this object\n"
             "digest_size -- number of bytes in this hashes output",
             "hmactype_doc": "The object used to calculate HMAC of a message.\n"
             "\n"
             "Methods:\n"
             "\n"
             "update() -- updates the current digest with an additional string\n"
             "digest() -- return the current digest value\n"
             "hexdigest() -- return the current digest as a string of hexadecimal digits\n"
             "copy() -- return a copy of the current hash object\n"
             "\n"
             "Attributes:\n"
             "\n"
             "name -- the name, including the hash algorithm used by this object\n"
             "digest_size -- number of bytes in digest() output\n",
             "EVP_getseters_name_doc": "algorithm name."
         }
     );
