"""The Argument Clinic signatures of _ssl.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/ssl.jac from them. Taken from
CPython 3.14.6 Modules/_ssl.c, Modules/_ssl/debughelpers.c, Modules/_ssl/misc.c, Modules/_ssl/cert.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_ssl",
         version="3.14.6",
         sources=[
             "Modules/_ssl.c",
             "Modules/_ssl/debughelpers.c",
             "Modules/_ssl/misc.c",
             "Modules/_ssl/cert.c"
         ],
         classes={
             "_SSLContext": "PySSLContext *",
             "_SSLSocket": "PySSLSocket *",
             "MemoryBIO": "PySSLMemoryBIO *",
             "SSLSession": "PySSLSession *",
             "Certificate": "PySSLCertificate *"
         },
         functions=[
             Function(
                 name="_test_decode_cert",
                 full_name="_ssl._test_decode_cert",
                 c_basename="_ssl__test_decode_cert",
                 docstring="_test_decode_cert($module, path, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="path",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="RAND_add",
                 full_name="_ssl.RAND_add",
                 c_basename="_ssl_RAND_add",
                 docstring="RAND_add($module, string, entropy, /)\n"
                 "--\n"
                 "\n"
                 "Mix string into the OpenSSL PRNG state.\n"
                 "\n"
                 "entropy (a float) is a lower bound on the entropy contained in\n"
                 "string.  See RFC 4086.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="string",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="s*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     ),
                     Parameter(
                         name="entropy",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="RAND_bytes",
                 full_name="_ssl.RAND_bytes",
                 c_basename="_ssl_RAND_bytes",
                 docstring="RAND_bytes($module, n, /)\n"
                 "--\n"
                 "\n"
                 "Generate n cryptographically strong pseudo-random bytes.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="n",
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
                 name="RAND_status",
                 full_name="_ssl.RAND_status",
                 c_basename="_ssl_RAND_status",
                 docstring="RAND_status($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the OpenSSL PRNG has been seeded with enough data and False if not.\n"
                 "\n"
                 "It is necessary to seed the PRNG with RAND_add() on some platforms\n"
                 "before using the ssl() function.",
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
                 name="get_default_verify_paths",
                 full_name="_ssl.get_default_verify_paths",
                 c_basename="_ssl_get_default_verify_paths",
                 docstring="get_default_verify_paths($module, /)\n"
                 "--\n"
                 "\n"
                 "Return search paths and environment vars that are used by SSLContext's set_default_verify_paths() to load default CAs.\n"
                 "\n"
                 "The values are 'cert_file_env', 'cert_file', 'cert_dir_env', 'cert_dir'.",
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
                 name="txt2obj",
                 full_name="_ssl.txt2obj",
                 c_basename="_ssl_txt2obj",
                 docstring="txt2obj($module, /, txt, name=False)\n"
                 "--\n"
                 "\n"
                 "Lookup NID, short name, long name and OID of an ASN1_OBJECT.\n"
                 "\n"
                 "By default objects are looked up by OID. With name=True short and\n"
                 "long name are also matched.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="txt",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="name",
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
                 name="nid2obj",
                 full_name="_ssl.nid2obj",
                 c_basename="_ssl_nid2obj",
                 docstring="nid2obj($module, nid, /)\n"
                 "--\n"
                 "\n"
                 "Lookup NID, short name, long name and OID of an ASN1_OBJECT by NID.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="nid",
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
                 name="enum_certificates",
                 full_name="_ssl.enum_certificates",
                 c_basename="_ssl_enum_certificates",
                 docstring="enum_certificates($module, /, store_name)\n"
                 "--\n"
                 "\n"
                 "Retrieve certificates from Windows' cert store.\n"
                 "\n"
                 "store_name may be one of 'CA', 'ROOT' or 'MY'.  The system may\n"
                 "provide more cert storages, too.  The function returns a list of\n"
                 "(bytes, encoding_type, trust) tuples.  The encoding_type flag can be\n"
                 "interpreted with X509_ASN_ENCODING or PKCS_7_ASN_ENCODING.  The\n"
                 "trust setting is either a set of OIDs or the boolean True.",
                 condition="defined(_MSC_VER)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="store_name",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="enum_crls",
                 full_name="_ssl.enum_crls",
                 c_basename="_ssl_enum_crls",
                 docstring="enum_crls($module, /, store_name)\n"
                 "--\n"
                 "\n"
                 "Retrieve CRLs from Windows' cert store.\n"
                 "\n"
                 "store_name may be one of 'CA', 'ROOT' or 'MY'.  The system may provide\n"
                 "more cert storages, too.  The function returns a list of (bytes,\n"
                 "encoding_type) tuples.  The encoding_type flag can be interpreted with\n"
                 "X509_ASN_ENCODING or PKCS_7_ASN_ENCODING.",
                 condition="defined(_MSC_VER)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="store_name",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="__new__",
                 full_name="_ssl._SSLContext.__new__",
                 c_basename="_ssl__SSLContext",
                 kind="METHOD_NEW",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="protocol",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             ),
             Function(
                 name="set_ciphers",
                 full_name="_ssl._SSLContext.set_ciphers",
                 c_basename="_ssl__SSLContext_set_ciphers",
                 cls="_SSLContext",
                 docstring="set_ciphers($self, cipherlist, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cipherlist",
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
                 name="get_ciphers",
                 full_name="_ssl._SSLContext.get_ciphers",
                 c_basename="_ssl__SSLContext_get_ciphers",
                 cls="_SSLContext",
                 docstring="get_ciphers($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="_set_alpn_protocols",
                 full_name="_ssl._SSLContext._set_alpn_protocols",
                 c_basename="_ssl__SSLContext__set_alpn_protocols",
                 cls="_SSLContext",
                 docstring="_set_alpn_protocols($self, protos, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="protos",
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
                 name="verify_mode",
                 full_name="_ssl._SSLContext.verify_mode",
                 c_basename="_ssl__SSLContext_verify_mode",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="verify_mode",
                 full_name="_ssl._SSLContext.verify_mode",
                 c_basename="_ssl__SSLContext_verify_mode",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="verify_flags",
                 full_name="_ssl._SSLContext.verify_flags",
                 c_basename="_ssl__SSLContext_verify_flags",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="verify_flags",
                 full_name="_ssl._SSLContext.verify_flags",
                 c_basename="_ssl__SSLContext_verify_flags",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="minimum_version",
                 full_name="_ssl._SSLContext.minimum_version",
                 c_basename="_ssl__SSLContext_minimum_version",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="minimum_version",
                 full_name="_ssl._SSLContext.minimum_version",
                 c_basename="_ssl__SSLContext_minimum_version",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="maximum_version",
                 full_name="_ssl._SSLContext.maximum_version",
                 c_basename="_ssl__SSLContext_maximum_version",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="maximum_version",
                 full_name="_ssl._SSLContext.maximum_version",
                 c_basename="_ssl__SSLContext_maximum_version",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="num_tickets",
                 full_name="_ssl._SSLContext.num_tickets",
                 c_basename="_ssl__SSLContext_num_tickets",
                 kind="GETTER",
                 cls="_SSLContext",
                 docstring="Control the number of TLSv1.3 session tickets.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="num_tickets",
                 full_name="_ssl._SSLContext.num_tickets",
                 c_basename="_ssl__SSLContext_num_tickets",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="security_level",
                 full_name="_ssl._SSLContext.security_level",
                 c_basename="_ssl__SSLContext_security_level",
                 kind="GETTER",
                 cls="_SSLContext",
                 docstring="The current security level.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="options",
                 full_name="_ssl._SSLContext.options",
                 c_basename="_ssl__SSLContext_options",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="options",
                 full_name="_ssl._SSLContext.options",
                 c_basename="_ssl__SSLContext_options",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_host_flags",
                 full_name="_ssl._SSLContext._host_flags",
                 c_basename="_ssl__SSLContext__host_flags",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="_host_flags",
                 full_name="_ssl._SSLContext._host_flags",
                 c_basename="_ssl__SSLContext__host_flags",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="check_hostname",
                 full_name="_ssl._SSLContext.check_hostname",
                 c_basename="_ssl__SSLContext_check_hostname",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="check_hostname",
                 full_name="_ssl._SSLContext.check_hostname",
                 c_basename="_ssl__SSLContext_check_hostname",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="protocol",
                 full_name="_ssl._SSLContext.protocol",
                 c_basename="_ssl__SSLContext_protocol",
                 kind="GETTER",
                 cls="_SSLContext",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="load_cert_chain",
                 full_name="_ssl._SSLContext.load_cert_chain",
                 c_basename="_ssl__SSLContext_load_cert_chain",
                 cls="_SSLContext",
                 docstring="load_cert_chain($self, /, certfile, keyfile=None, password=None)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="certfile", format_unit="O"),
                     Parameter(
                         name="keyfile",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="password",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=3
             ),
             Function(
                 name="load_verify_locations",
                 full_name="_ssl._SSLContext.load_verify_locations",
                 c_basename="_ssl__SSLContext_load_verify_locations",
                 cls="_SSLContext",
                 docstring="load_verify_locations($self, /, cafile=None, capath=None, cadata=None)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cafile",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="capath",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="cadata",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=3
             ),
             Function(
                 name="load_dh_params",
                 full_name="_ssl._SSLContext.load_dh_params",
                 c_basename="_ssl__SSLContext_load_dh_params",
                 cls="_SSLContext",
                 docstring="load_dh_params($self, path, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="path", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_wrap_socket",
                 full_name="_ssl._SSLContext._wrap_socket",
                 c_basename="_ssl__SSLContext__wrap_socket",
                 cls="_SSLContext",
                 docstring="_wrap_socket($self, /, sock, server_side, server_hostname=None, *,\n"
                 "             owner=None, session=None)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="sock",
                         format_unit="O!",
                         subclass_of="get_state_ctx(self)->Sock_Type"
                     ),
                     Parameter(
                         name="server_side",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     ),
                     Parameter(
                         name="server_hostname",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="owner",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="session",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=3
             ),
             Function(
                 name="_wrap_bio",
                 full_name="_ssl._SSLContext._wrap_bio",
                 c_basename="_ssl__SSLContext__wrap_bio",
                 cls="_SSLContext",
                 docstring="_wrap_bio($self, /, incoming, outgoing, server_side,\n"
                 "          server_hostname=None, *, owner=None, session=None)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="incoming",
                         type="PySSLMemoryBIO *",
                         format_unit="O!",
                         subclass_of="get_state_ctx(self)->PySSLMemoryBIO_Type"
                     ),
                     Parameter(
                         name="outgoing",
                         type="PySSLMemoryBIO *",
                         format_unit="O!",
                         subclass_of="get_state_ctx(self)->PySSLMemoryBIO_Type"
                     ),
                     Parameter(
                         name="server_side",
                         converter="bool",
                         type="int",
                         format_unit="p"
                     ),
                     Parameter(
                         name="server_hostname",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="owner",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="session",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=3,
                 max_pos=4
             ),
             Function(
                 name="session_stats",
                 full_name="_ssl._SSLContext.session_stats",
                 c_basename="_ssl__SSLContext_session_stats",
                 cls="_SSLContext",
                 docstring="session_stats($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="set_default_verify_paths",
                 full_name="_ssl._SSLContext.set_default_verify_paths",
                 c_basename="_ssl__SSLContext_set_default_verify_paths",
                 cls="_SSLContext",
                 docstring="set_default_verify_paths($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="set_ecdh_curve",
                 full_name="_ssl._SSLContext.set_ecdh_curve",
                 c_basename="_ssl__SSLContext_set_ecdh_curve",
                 cls="_SSLContext",
                 docstring="set_ecdh_curve($self, name, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="name", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="sni_callback",
                 full_name="_ssl._SSLContext.sni_callback",
                 c_basename="_ssl__SSLContext_sni_callback",
                 kind="GETTER",
                 cls="_SSLContext",
                 docstring="Set a callback that will be called when a server name is provided by the SSL/TLS client in the SNI extension.\n"
                 "\n"
                 "If the argument is None then the callback is disabled.  The method\n"
                 "is called with the SSLSocket, the server name as a string, and the\n"
                 "SSLContext object.\n"
                 "\n"
                 "See RFC 6066 for details of the SNI extension.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="sni_callback",
                 full_name="_ssl._SSLContext.sni_callback",
                 c_basename="_ssl__SSLContext_sni_callback",
                 kind="SETTER",
                 cls="_SSLContext",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="cert_store_stats",
                 full_name="_ssl._SSLContext.cert_store_stats",
                 c_basename="_ssl__SSLContext_cert_store_stats",
                 cls="_SSLContext",
                 docstring="cert_store_stats($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns quantities of loaded X.509 certificates.\n"
                 "\n"
                 "X.509 certificates with a CA extension and certificate revocation\n"
                 "lists inside the context's cert store.\n"
                 "\n"
                 "NOTE: Certificates in a capath directory aren't loaded unless they\n"
                 "have been used at least once.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_ca_certs",
                 full_name="_ssl._SSLContext.get_ca_certs",
                 c_basename="_ssl__SSLContext_get_ca_certs",
                 cls="_SSLContext",
                 docstring="get_ca_certs($self, /, binary_form=False)\n"
                 "--\n"
                 "\n"
                 "Returns a list of dicts with information of loaded CA certs.\n"
                 "\n"
                 "If the optional argument is True, returns a DER-encoded copy of the\n"
                 "CA certificate.\n"
                 "\n"
                 "NOTE: Certificates in a capath directory aren't loaded unless they\n"
                 "have been used at least once.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="binary_form",
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
                 max_pos=1
             ),
             Function(
                 name="set_psk_client_callback",
                 full_name="_ssl._SSLContext.set_psk_client_callback",
                 c_basename="_ssl__SSLContext_set_psk_client_callback",
                 cls="_SSLContext",
                 docstring="set_psk_client_callback($self, /, callback)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="callback", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="set_psk_server_callback",
                 full_name="_ssl._SSLContext.set_psk_server_callback",
                 c_basename="_ssl__SSLContext_set_psk_server_callback",
                 cls="_SSLContext",
                 docstring="set_psk_server_callback($self, /, callback, identity_hint=None)\n"
                 "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="callback", format_unit="O"),
                     Parameter(
                         name="identity_hint",
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
                 name="do_handshake",
                 full_name="_ssl._SSLSocket.do_handshake",
                 c_basename="_ssl__SSLSocket_do_handshake",
                 cls="_SSLSocket",
                 docstring="do_handshake($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="getpeercert",
                 full_name="_ssl._SSLSocket.getpeercert",
                 c_basename="_ssl__SSLSocket_getpeercert",
                 cls="_SSLSocket",
                 docstring="getpeercert($self, der=False, /)\n"
                 "--\n"
                 "\n"
                 "Returns the certificate for the peer.\n"
                 "\n"
                 "If no certificate was provided, returns None.  If a certificate was\n"
                 "provided, but not validated, returns an empty dictionary.  Otherwise\n"
                 "returns a dict containing information about the peer certificate.\n"
                 "\n"
                 "If the optional argument is True, returns a DER-encoded copy of the\n"
                 "peer certificate, or None if no certificate was provided.  This will\n"
                 "return the certificate even if it wasn't validated.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="der",
                         kind="POSITIONAL_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="get_verified_chain",
                 full_name="_ssl._SSLSocket.get_verified_chain",
                 c_basename="_ssl__SSLSocket_get_verified_chain",
                 cls="_SSLSocket",
                 docstring="get_verified_chain($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_unverified_chain",
                 full_name="_ssl._SSLSocket.get_unverified_chain",
                 c_basename="_ssl__SSLSocket_get_unverified_chain",
                 cls="_SSLSocket",
                 docstring="get_unverified_chain($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="shared_ciphers",
                 full_name="_ssl._SSLSocket.shared_ciphers",
                 c_basename="_ssl__SSLSocket_shared_ciphers",
                 cls="_SSLSocket",
                 docstring="shared_ciphers($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="cipher",
                 full_name="_ssl._SSLSocket.cipher",
                 c_basename="_ssl__SSLSocket_cipher",
                 cls="_SSLSocket",
                 docstring="cipher($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="version",
                 full_name="_ssl._SSLSocket.version",
                 c_basename="_ssl__SSLSocket_version",
                 cls="_SSLSocket",
                 docstring="version($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="selected_alpn_protocol",
                 full_name="_ssl._SSLSocket.selected_alpn_protocol",
                 c_basename="_ssl__SSLSocket_selected_alpn_protocol",
                 cls="_SSLSocket",
                 docstring="selected_alpn_protocol($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="compression",
                 full_name="_ssl._SSLSocket.compression",
                 c_basename="_ssl__SSLSocket_compression",
                 cls="_SSLSocket",
                 docstring="compression($self, /)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="context",
                 full_name="_ssl._SSLSocket.context",
                 c_basename="_ssl__SSLSocket_context",
                 kind="GETTER",
                 cls="_SSLSocket",
                 docstring="This changes the context associated with the SSLSocket.\n"
                 "\n"
                 "This is typically used from within a callback function set by the\n"
                 "sni_callback on the SSLContext to change the certificate information\n"
                 "associated with the SSLSocket before the cryptographic exchange\n"
                 "handshake messages.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="context",
                 full_name="_ssl._SSLSocket.context",
                 c_basename="_ssl__SSLSocket_context",
                 kind="SETTER",
                 cls="_SSLSocket",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="server_side",
                 full_name="_ssl._SSLSocket.server_side",
                 c_basename="_ssl__SSLSocket_server_side",
                 kind="GETTER",
                 cls="_SSLSocket",
                 docstring="Whether this is a server-side socket.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="server_hostname",
                 full_name="_ssl._SSLSocket.server_hostname",
                 c_basename="_ssl__SSLSocket_server_hostname",
                 kind="GETTER",
                 cls="_SSLSocket",
                 docstring="The currently set server hostname (for SNI).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="owner",
                 full_name="_ssl._SSLSocket.owner",
                 c_basename="_ssl__SSLSocket_owner",
                 kind="GETTER",
                 cls="_SSLSocket",
                 docstring="The Python-level owner of this object.\n"
                 "\n"
                 "Passed as \"self\" in servername callback.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="owner",
                 full_name="_ssl._SSLSocket.owner",
                 c_basename="_ssl__SSLSocket_owner",
                 kind="SETTER",
                 cls="_SSLSocket",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="write",
                 full_name="_ssl._SSLSocket.write",
                 c_basename="_ssl__SSLSocket_write",
                 cls="_SSLSocket",
                 docstring="write($self, b, /)\n"
                 "--\n"
                 "\n"
                 "Writes the bytes-like object b into the SSL object.\n"
                 "\n"
                 "Returns the number of bytes written.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="b",
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
                 name="pending",
                 full_name="_ssl._SSLSocket.pending",
                 c_basename="_ssl__SSLSocket_pending",
                 cls="_SSLSocket",
                 docstring="pending($self, /)\n"
                 "--\n"
                 "\n"
                 "Returns the number of already decrypted bytes available for read, pending on the connection.",
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
                 full_name="_ssl._SSLSocket.read",
                 c_basename="_ssl__SSLSocket_read",
                 cls="_SSLSocket",
                 docstring="read(size, [buffer])\n"
                 "Read up to size bytes from the SSL socket.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="buffer",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="w*",
                         c_default="{NULL, NULL}",
                         group=1,
                         by_reference=True
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="parser for METH_VARARGS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="shutdown",
                 full_name="_ssl._SSLSocket.shutdown",
                 c_basename="_ssl__SSLSocket_shutdown",
                 cls="_SSLSocket",
                 docstring="shutdown($self, /)\n"
                 "--\n"
                 "\n"
                 "Does the SSL shutdown handshake with the remote end.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="get_channel_binding",
                 full_name="_ssl._SSLSocket.get_channel_binding",
                 c_basename="_ssl__SSLSocket_get_channel_binding",
                 cls="_SSLSocket",
                 docstring="get_channel_binding($self, /, cb_type='tls-unique')\n"
                 "--\n"
                 "\n"
                 "Get channel binding data for current connection.\n"
                 "\n"
                 "Raise ValueError if the requested `cb_type` is not supported.\n"
                 "Return bytes of the data or None if the data is not available (e.g.\n"
                 "before the handshake).\n"
                 "Only 'tls-unique' channel binding data from RFC 5929 is supported.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="cb_type",
                         converter="str",
                         type="const char *",
                         format_unit="s",
                         default_kind="value",
                         py_default="tls-unique",
                         c_default="\"tls-unique\""
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="verify_client_post_handshake",
                 full_name="_ssl._SSLSocket.verify_client_post_handshake",
                 c_basename="_ssl__SSLSocket_verify_client_post_handshake",
                 cls="_SSLSocket",
                 docstring="verify_client_post_handshake($self, /)\n"
                 "--\n"
                 "\n"
                 "Initiate TLS 1.3 post-handshake authentication",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="session",
                 full_name="_ssl._SSLSocket.session",
                 c_basename="_ssl__SSLSocket_session",
                 kind="GETTER",
                 cls="_SSLSocket",
                 docstring="The underlying SSLSession object.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="session",
                 full_name="_ssl._SSLSocket.session",
                 c_basename="_ssl__SSLSocket_session",
                 kind="SETTER",
                 cls="_SSLSocket",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="session_reused",
                 full_name="_ssl._SSLSocket.session_reused",
                 c_basename="_ssl__SSLSocket_session_reused",
                 kind="GETTER",
                 cls="_SSLSocket",
                 docstring="Was the client session reused during handshake?",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="__new__",
                 full_name="_ssl.MemoryBIO.__new__",
                 c_basename="_ssl_MemoryBIO",
                 kind="METHOD_NEW",
                 cls="MemoryBIO",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_NOTHING",
                 self_type_check=True
             ),
             Function(
                 name="pending",
                 full_name="_ssl.MemoryBIO.pending",
                 c_basename="_ssl_MemoryBIO_pending",
                 kind="GETTER",
                 cls="MemoryBIO",
                 docstring="The number of bytes pending in the memory BIO.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="eof",
                 full_name="_ssl.MemoryBIO.eof",
                 c_basename="_ssl_MemoryBIO_eof",
                 kind="GETTER",
                 cls="MemoryBIO",
                 docstring="Whether the memory BIO is at EOF.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="read",
                 full_name="_ssl.MemoryBIO.read",
                 c_basename="_ssl_MemoryBIO_read",
                 cls="MemoryBIO",
                 docstring="read($self, size=-1, /)\n"
                 "--\n"
                 "\n"
                 "Read up to size bytes from the memory BIO.\n"
                 "\n"
                 "If size is not specified, read the entire buffer.\n"
                 "If the return value is an empty bytes instance, this means either\n"
                 "EOF or that no data is available. Use the \"eof\" property to\n"
                 "distinguish between the two.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="size",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="write",
                 full_name="_ssl.MemoryBIO.write",
                 c_basename="_ssl_MemoryBIO_write",
                 cls="MemoryBIO",
                 docstring="write($self, b, /)\n"
                 "--\n"
                 "\n"
                 "Writes the bytes b into the memory BIO.\n"
                 "\n"
                 "Returns the number of bytes written.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="b",
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
                 name="write_eof",
                 full_name="_ssl.MemoryBIO.write_eof",
                 c_basename="_ssl_MemoryBIO_write_eof",
                 cls="MemoryBIO",
                 docstring="write_eof($self, /)\n"
                 "--\n"
                 "\n"
                 "Write an EOF marker to the memory BIO.\n"
                 "\n"
                 "When all data has been read, the \"eof\" property will be True.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="time",
                 full_name="_ssl.SSLSession.time",
                 c_basename="_ssl_SSLSession_time",
                 kind="GETTER",
                 cls="SSLSession",
                 docstring="Session creation time (seconds since epoch).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="timeout",
                 full_name="_ssl.SSLSession.timeout",
                 c_basename="_ssl_SSLSession_timeout",
                 kind="GETTER",
                 cls="SSLSession",
                 docstring="Session timeout (delta in seconds).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="ticket_lifetime_hint",
                 full_name="_ssl.SSLSession.ticket_lifetime_hint",
                 c_basename="_ssl_SSLSession_ticket_lifetime_hint",
                 kind="GETTER",
                 cls="SSLSession",
                 docstring="Ticket life time hint.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="id",
                 full_name="_ssl.SSLSession.id",
                 c_basename="_ssl_SSLSession_id",
                 kind="GETTER",
                 cls="SSLSession",
                 docstring="Session ID.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="has_ticket",
                 full_name="_ssl.SSLSession.has_ticket",
                 c_basename="_ssl_SSLSession_has_ticket",
                 kind="GETTER",
                 cls="SSLSession",
                 docstring="Does the session contain a ticket?",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 parser="parser for "
             ),
             Function(
                 name="public_bytes",
                 full_name="_ssl.Certificate.public_bytes",
                 c_basename="_ssl_Certificate_public_bytes",
                 cls="Certificate",
                 docstring="public_bytes($self, /, format=Encoding.PEM)\n" "--",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="format",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="PY_SSL_ENCODING_PEM"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=1
             ),
             Function(
                 name="get_info",
                 full_name="_ssl.Certificate.get_info",
                 c_basename="_ssl_Certificate_get_info",
                 cls="Certificate",
                 docstring="get_info($self, /)\n" "--",
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
             "SSLError_doc": "An error occurred in the SSL implementation.",
             "SSLCertVerificationError_doc": "A certificate could not be verified.",
             "SSLZeroReturnError_doc": "SSL/TLS session closed cleanly.",
             "SSLWantReadError_doc": "Non-blocking SSL socket needs to read more data\n"
             "before the requested operation can be completed.",
             "SSLWantWriteError_doc": "Non-blocking SSL socket needs to write more data\n"
             "before the requested operation can be completed.",
             "SSLSyscallError_doc": "System error when attempting SSL operation.",
             "SSLEOFError_doc": "SSL/TLS connection terminated abruptly.",
             "module_doc": "Implementation module for SSL socket operations.  See the socket module\n"
             "for documentation."
         }
     );
