"""The Argument Clinic signatures of _imp.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/imp.jac from them. Taken from
the C sources it replaces (Python/import.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_imp",
         version="3.14.6",
         sources=["Python/import.c"],
         functions=[
             Function(
                 name="lock_held",
                 full_name="_imp.lock_held",
                 c_basename="_imp_lock_held",
                 docstring="lock_held($module, /)\n"
                 "--\n"
                 "\n"
                 "Return True if the import lock is currently held, else False.\n"
                 "\n"
                 "On platforms without threads, return False.",
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
                 name="acquire_lock",
                 full_name="_imp.acquire_lock",
                 c_basename="_imp_acquire_lock",
                 docstring="acquire_lock($module, /)\n"
                 "--\n"
                 "\n"
                 "Acquires the interpreter's import lock for the current thread.\n"
                 "\n"
                 "This lock should be used by import hooks to ensure thread-safety when\n"
                 "importing modules.  On platforms without threads, this function does\n"
                 "nothing.",
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
                 name="release_lock",
                 full_name="_imp.release_lock",
                 c_basename="_imp_release_lock",
                 docstring="release_lock($module, /)\n"
                 "--\n"
                 "\n"
                 "Release the interpreter's import lock.\n"
                 "\n"
                 "On platforms without threads, this function does nothing.",
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
                 name="_fix_co_filename",
                 full_name="_imp._fix_co_filename",
                 c_basename="_imp__fix_co_filename",
                 docstring="_fix_co_filename($module, code, path, /)\n"
                 "--\n"
                 "\n"
                 "Changes code.co_filename to specify the passed-in file path.\n"
                 "\n"
                 "  code\n"
                 "    Code object to change.\n"
                 "  path\n"
                 "    File path to use.",
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
                         type="PyCodeObject *",
                         format_unit="O!",
                         subclass_of="&PyCode_Type"
                     ),
                     Parameter(
                         name="path",
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
                 name="create_builtin",
                 full_name="_imp.create_builtin",
                 c_basename="_imp_create_builtin",
                 docstring="create_builtin($module, spec, /)\n"
                 "--\n"
                 "\n"
                 "Create an extension module.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="spec", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="extension_suffixes",
                 full_name="_imp.extension_suffixes",
                 c_basename="_imp_extension_suffixes",
                 docstring="extension_suffixes($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns the list of file suffixes used to identify extension modules.",
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
                 name="init_frozen",
                 full_name="_imp.init_frozen",
                 c_basename="_imp_init_frozen",
                 docstring="init_frozen($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Initializes a frozen module.",
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
                 pos_only=1
             ),
             Function(
                 name="find_frozen",
                 full_name="_imp.find_frozen",
                 c_basename="_imp_find_frozen",
                 docstring="find_frozen($module, name, /, *, withdata=False)\n"
                 "--\n"
                 "\n"
                 "Return info about the corresponding frozen module (if there is one) or None.\n"
                 "\n"
                 "The returned info (a 2-tuple):\n"
                 "\n"
                 " * data         the raw marshalled bytes\n"
                 " * is_package   whether or not it is a package\n"
                 " * origname     the originally frozen module's name, or None if not\n"
                 "                a stdlib module (this will usually be the same as\n"
                 "                the module's current name)",
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
                     ),
                     Parameter(
                         name="withdata",
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
                 name="get_frozen_object",
                 full_name="_imp.get_frozen_object",
                 c_basename="_imp_get_frozen_object",
                 docstring="get_frozen_object($module, name, data=None, /)\n"
                 "--\n"
                 "\n"
                 "Create a code object for a frozen module.",
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
                     ),
                     Parameter(
                         name="data",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="is_frozen_package",
                 full_name="_imp.is_frozen_package",
                 c_basename="_imp_is_frozen_package",
                 docstring="is_frozen_package($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the module name is of a frozen package.",
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
                 pos_only=1
             ),
             Function(
                 name="is_builtin",
                 full_name="_imp.is_builtin",
                 c_basename="_imp_is_builtin",
                 docstring="is_builtin($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the module name corresponds to a built-in module.",
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
                 pos_only=1
             ),
             Function(
                 name="is_frozen",
                 full_name="_imp.is_frozen",
                 c_basename="_imp_is_frozen",
                 docstring="is_frozen($module, name, /)\n"
                 "--\n"
                 "\n"
                 "Returns True if the module name corresponds to a frozen module.",
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
                 pos_only=1
             ),
             Function(
                 name="_frozen_module_names",
                 full_name="_imp._frozen_module_names",
                 c_basename="_imp__frozen_module_names",
                 docstring="_frozen_module_names($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns the list of available frozen modules.",
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
                 name="_override_frozen_modules_for_tests",
                 full_name="_imp._override_frozen_modules_for_tests",
                 c_basename="_imp__override_frozen_modules_for_tests",
                 docstring="_override_frozen_modules_for_tests($module, override, /)\n"
                 "--\n"
                 "\n"
                 "(internal-only) Override PyConfig.use_frozen_modules.\n"
                 "\n"
                 "(-1: \"off\", 1: \"on\", 0: no override)\n"
                 "See frozen_modules() in Lib/test/support/import_helper.py.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="override",
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
                 name="_override_multi_interp_extensions_check",
                 full_name="_imp._override_multi_interp_extensions_check",
                 c_basename="_imp__override_multi_interp_extensions_check",
                 docstring="_override_multi_interp_extensions_check($module, override, /)\n"
                 "--\n"
                 "\n"
                 "(internal-only) Override PyInterpreterConfig.check_multi_interp_extensions.\n"
                 "\n"
                 "(-1: \"never\", 1: \"always\", 0: no override)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="override",
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
                 name="create_dynamic",
                 full_name="_imp.create_dynamic",
                 c_basename="_imp_create_dynamic",
                 docstring="create_dynamic($module, spec, file=<unrepresentable>, /)\n"
                 "--\n"
                 "\n"
                 "Create an extension module.",
                 condition="defined(HAVE_DYNAMIC_LOADING)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="spec", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="file",
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
                 name="exec_dynamic",
                 full_name="_imp.exec_dynamic",
                 c_basename="_imp_exec_dynamic",
                 docstring="exec_dynamic($module, mod, /)\n"
                 "--\n"
                 "\n"
                 "Initialize an extension module.",
                 condition="defined(HAVE_DYNAMIC_LOADING)",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="mod", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="exec_builtin",
                 full_name="_imp.exec_builtin",
                 c_basename="_imp_exec_builtin",
                 docstring="exec_builtin($module, mod, /)\n"
                 "--\n"
                 "\n"
                 "Initialize a built-in module.",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="mod", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="source_hash",
                 full_name="_imp.source_hash",
                 c_basename="_imp_source_hash",
                 docstring="source_hash($module, /, key, source)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="key", converter="long", type="long", format_unit="l"
                     ),
                     Parameter(
                         name="source",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             )
         ],
         docs={
             "doc_imp": "(Extremely) low-level import machinery bits as used by importlib."
         }
     );
