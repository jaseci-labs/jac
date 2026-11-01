"""The Argument Clinic signatures of _opcode.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/opcode.jac from them. Taken from
CPython 3.14.6 Modules/_opcode.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_opcode",
         version="3.14.6",
         sources=["Modules/_opcode.c"],
         functions=[
             Function(
                 name="stack_effect",
                 full_name="_opcode.stack_effect",
                 c_basename="_opcode_stack_effect",
                 docstring="stack_effect($module, opcode, oparg=None, /, *, jump=None)\n"
                 "--\n"
                 "\n"
                 "Compute the stack effect of the opcode.",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i"
                     ),
                     Parameter(
                         name="oparg",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="jump",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="is_valid",
                 full_name="_opcode.is_valid",
                 c_basename="_opcode_is_valid",
                 docstring="is_valid($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if opcode is valid, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_arg",
                 full_name="_opcode.has_arg",
                 c_basename="_opcode_has_arg",
                 docstring="has_arg($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode uses its oparg, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_const",
                 full_name="_opcode.has_const",
                 c_basename="_opcode_has_const",
                 docstring="has_const($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode accesses a constant, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_name",
                 full_name="_opcode.has_name",
                 c_basename="_opcode_has_name",
                 docstring="has_name($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode accesses an attribute by name, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_jump",
                 full_name="_opcode.has_jump",
                 c_basename="_opcode_has_jump",
                 docstring="has_jump($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode has a jump target, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_free",
                 full_name="_opcode.has_free",
                 c_basename="_opcode_has_free",
                 docstring="has_free($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode accesses a free variable, False otherwise.\n"
                 "\n"
                 "Note that 'free' in this context refers to names in the current scope\n"
                 "that are referenced by inner scopes or names in outer scopes that are\n"
                 "referenced from this scope. It does not include references to global\n"
                 "or builtin scopes.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_local",
                 full_name="_opcode.has_local",
                 c_basename="_opcode_has_local",
                 docstring="has_local($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode accesses a local variable, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="has_exc",
                 full_name="_opcode.has_exc",
                 c_basename="_opcode_has_exc",
                 docstring="has_exc($module, /, opcode)\n"
                 "--\n"
                 "\n"
                 "Return True if the opcode sets an exception handler, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="opcode", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1
             ),
             Function(
                 name="get_specialization_stats",
                 full_name="_opcode.get_specialization_stats",
                 c_basename="_opcode_get_specialization_stats",
                 docstring="get_specialization_stats($module, /)\n"
                 "--\n"
                 "\n"
                 "Return the specialization stats",
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
                 name="get_nb_ops",
                 full_name="_opcode.get_nb_ops",
                 c_basename="_opcode_get_nb_ops",
                 docstring="get_nb_ops($module, /)\n"
                 "--\n"
                 "\n"
                 "Return array of symbols of binary ops.\n"
                 "\n"
                 "Indexed by the BINARY_OP oparg value.",
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
                 name="get_intrinsic1_descs",
                 full_name="_opcode.get_intrinsic1_descs",
                 c_basename="_opcode_get_intrinsic1_descs",
                 docstring="get_intrinsic1_descs($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of names of the unary intrinsics.",
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
                 name="get_intrinsic2_descs",
                 full_name="_opcode.get_intrinsic2_descs",
                 c_basename="_opcode_get_intrinsic2_descs",
                 docstring="get_intrinsic2_descs($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of names of the binary intrinsics.",
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
                 name="get_special_method_names",
                 full_name="_opcode.get_special_method_names",
                 c_basename="_opcode_get_special_method_names",
                 docstring="get_special_method_names($module, /)\n"
                 "--\n"
                 "\n"
                 "Return a list of special method names.",
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
                 name="get_executor",
                 full_name="_opcode.get_executor",
                 c_basename="_opcode_get_executor",
                 docstring="get_executor($module, /, code, offset)\n"
                 "--\n"
                 "\n"
                 "Return the executor object at offset in code if exists, None otherwise.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="code", format_unit="O"),
                     Parameter(
                         name="offset", converter="int", type="int", format_unit="i"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             )
         ]
     );
