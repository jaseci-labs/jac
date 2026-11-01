"""The Argument Clinic signatures of pwd.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/pwd.jac from them. Taken from
the C sources it replaces (Modules/pwdmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="pwd",
         version="3.14.6",
         sources=["Modules/pwdmodule.c"],
         functions=[
             Function(
                 name="getpwuid",
                 full_name="pwd.getpwuid",
                 c_basename="pwd_getpwuid",
                 docstring="getpwuid($module, uidobj, /)\n"
                 "--\n"
                 "\n"
                 "Return the password database entry for the given numeric user ID.\n"
                 "\n"
                 "See `help(pwd)` for more on password database entries.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="uidobj", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 limited_capi=True
             ),
             Function(
                 name="getpwnam",
                 full_name="pwd.getpwnam",
                 c_basename="pwd_getpwnam",
                 docstring="getpwnam($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Return the password database entry for the given user name.\n"
                 "\n"
                 "See `help(pwd)` for more on password database entries.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="name",
                         kind="POSITIONAL_ONLY",
                         converter="unicode",
                         format_unit="U"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 limited_capi=True
             ),
             Function(
                 name="getpwall",
                 full_name="pwd.getpwall",
                 c_basename="pwd_getpwall",
                 docstring="getpwall($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of all available password database entries, in arbitrary order.\n"
                 "\n"
                 "See help(pwd) for more on password database entries.",
                 condition="defined(HAVE_GETPWENT)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN",
                 limited_capi=True
             )
         ],
         docs={
             "struct_passwd__doc__": "pwd.struct_passwd: Results from getpw*() routines.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (pw_name,pw_passwd,pw_uid,pw_gid,pw_gecos,pw_dir,pw_shell)\n"
             "or via the object attributes as named in the above tuple.",
             "pwd__doc__": "This module provides access to the Unix password database.\n"
             "It is available on all Unix versions.\n"
             "\n"
             "Password database entries are reported as 7-tuples containing the following\n"
             "items from the password database (see `<pwd.h>'), in order:\n"
             "pw_name, pw_passwd, pw_uid, pw_gid, pw_gecos, pw_dir, pw_shell.\n"
             "The uid and gid items are integers, all others are strings. An\n"
             "exception is raised if the entry asked for cannot be found."
         }
     );
