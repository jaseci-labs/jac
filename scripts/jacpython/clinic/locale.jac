"""The Argument Clinic signatures of _locale.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/locale.jac from them. Taken from
the C sources it replaces (Modules/_localemodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_locale",
         version="3.14.6",
         sources=["Modules/_localemodule.c"],
         functions=[
             Function(
                 name="setlocale",
                 full_name="_locale.setlocale",
                 c_basename="_locale_setlocale",
                 docstring="setlocale($module, category, locale=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Activates/queries locale processing.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="category",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="locale",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z",
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
                 name="localeconv",
                 full_name="_locale.localeconv",
                 c_basename="_locale_localeconv",
                 docstring="localeconv($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns numeric and monetary locale-specific parameters.",
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
                 name="strcoll",
                 full_name="_locale.strcoll",
                 c_basename="_locale_strcoll",
                 docstring="strcoll($module, os1, os2, /)\n"
                 "--\n"
                 "\n"
                 "Compares two strings according to the locale.",
                 condition="defined(HAVE_WCSCOLL)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="os1",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     ),
                     Parameter(
                         name="os2",
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
                 name="strxfrm",
                 full_name="_locale.strxfrm",
                 c_basename="_locale_strxfrm",
                 docstring="strxfrm($module, string, /)\n"
                 "--\n"
                 "\n"
                 "Return a string that can be used as a key for locale-aware comparisons.",
                 condition="defined(HAVE_WCSXFRM)",
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
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="_getdefaultlocale",
                 full_name="_locale._getdefaultlocale",
                 c_basename="_locale__getdefaultlocale",
                 docstring="_getdefaultlocale($module, /)\n" "--",
                 condition="defined(MS_WINDOWS)",
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
                 name="nl_langinfo",
                 full_name="_locale.nl_langinfo",
                 c_basename="_locale_nl_langinfo",
                 docstring="nl_langinfo($module, key, /)\n"
                 "--\n"
                 "\n"
                 "Return the value for the locale information associated with key.",
                 condition="defined(HAVE_LANGINFO_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="key",
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
                 name="gettext",
                 full_name="_locale.gettext",
                 c_basename="_locale_gettext",
                 docstring="gettext($module, msg, /)\n"
                 "--\n"
                 "\n"
                 "gettext(msg) -> string\n"
                 "\n"
                 "Return translation of msg.",
                 condition="defined(HAVE_LIBINTL_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="msg",
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
                 name="dgettext",
                 full_name="_locale.dgettext",
                 c_basename="_locale_dgettext",
                 docstring="dgettext($module, domain, msg, /)\n"
                 "--\n"
                 "\n"
                 "dgettext(domain, msg) -> string\n"
                 "\n"
                 "Return translation of msg in domain.",
                 condition="defined(HAVE_LIBINTL_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="domain",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z"
                     ),
                     Parameter(
                         name="msg",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="dcgettext",
                 full_name="_locale.dcgettext",
                 c_basename="_locale_dcgettext",
                 docstring="dcgettext($module, domain, msg, category, /)\n"
                 "--\n"
                 "\n"
                 "Return translation of msg in domain and category.",
                 condition="defined(HAVE_LIBINTL_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="domain",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z"
                     ),
                     Parameter(
                         name="msg",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="category",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="textdomain",
                 full_name="_locale.textdomain",
                 c_basename="_locale_textdomain",
                 docstring="textdomain($module, domain, /)\n"
                 "--\n"
                 "\n"
                 "Set the C library's textdmain to domain, returning the new domain.",
                 condition="defined(HAVE_LIBINTL_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="domain",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="bindtextdomain",
                 full_name="_locale.bindtextdomain",
                 c_basename="_locale_bindtextdomain",
                 docstring="bindtextdomain($module, domain, dir, /)\n"
                 "--\n"
                 "\n"
                 "Bind the C library's domain to dir.",
                 condition="defined(HAVE_LIBINTL_H)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="domain",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(name="dir", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="bind_textdomain_codeset",
                 full_name="_locale.bind_textdomain_codeset",
                 c_basename="_locale_bind_textdomain_codeset",
                 docstring="bind_textdomain_codeset($module, domain, codeset, /)\n"
                 "--\n"
                 "\n"
                 "Bind the C library's domain to codeset.",
                 condition="defined(HAVE_LIBINTL_H) && defined(HAVE_BIND_TEXTDOMAIN_CODESET)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="domain",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     ),
                     Parameter(
                         name="codeset",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="z"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getencoding",
                 full_name="_locale.getencoding",
                 c_basename="_locale_getencoding",
                 docstring="getencoding($module, /)\n"
                 "--\n"
                 "\n"
                 "Get the current locale encoding.",
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
             )
         ],
         docs={"locale__doc__": "Support for POSIX locales."}
     );
