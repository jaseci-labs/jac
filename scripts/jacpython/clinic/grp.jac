"""The Argument Clinic signatures of grp.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/grp.jac from them. Taken from
the C sources it replaces (Modules/grpmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="grp",
         version="3.14.6",
         sources=["Modules/grpmodule.c"],
         functions=[
             Function(
                 name="getgrgid",
                 full_name="grp.getgrgid",
                 c_basename="grp_getgrgid",
                 docstring="getgrgid($module, /, id)\n"
                 "--\n"
                 "\n"
                 "Return the group database entry for the given numeric group ID.\n"
                 "\n"
                 "If id is not valid, raise KeyError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="id", format_unit="O")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="getgrnam",
                 full_name="grp.getgrnam",
                 c_basename="grp_getgrnam",
                 docstring="getgrnam($module, /, name)\n"
                 "--\n"
                 "\n"
                 "Return the group database entry for the given group name.\n"
                 "\n"
                 "If name is not valid, raise KeyError.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="name", converter="unicode", format_unit="U")
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="getgrall",
                 full_name="grp.getgrall",
                 c_basename="grp_getgrall",
                 docstring="getgrall($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of all available group entries, in arbitrary order.\n"
                 "\n"
                 "An entry whose name starts with '+' or '-' represents an instruction\n"
                 "to use YP/NIS and may not be accessible via getgrnam or getgrgid.",
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
         docs={
             "struct_group__doc__": "grp.struct_group: Results from getgr*() routines.\n"
             "\n"
             "This object may be accessed either as a tuple of\n"
             "  (gr_name,gr_passwd,gr_gid,gr_mem)\n"
             "or via the object attributes as named in the above tuple.\n",
             "grp__doc__": "Access to the Unix group database.\n"
             "\n"
             "Group entries are reported as 4-tuples containing the following fields\n"
             "from the group database, in order:\n"
             "\n"
             "  gr_name   - name of the group\n"
             "  gr_passwd - group password (encrypted); often empty\n"
             "  gr_gid    - numeric ID of the group\n"
             "  gr_mem    - list of members\n"
             "\n"
             "The gid is an integer, name and password are strings.  (Note that most\n"
             "users are not explicitly listed as members of the groups they are in\n"
             "according to the password database.  Check both databases to get\n"
             "complete membership information.)"
         }
     );
