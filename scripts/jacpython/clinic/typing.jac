"""The Argument Clinic signatures of _typing.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/typing.jac from them. Taken from
CPython 3.14.6 Modules/_typingmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_typing",
         version="3.14.6",
         sources=["Modules/_typingmodule.c"],
         functions=[
             Function(
                 name="_idfunc",
                 full_name="_typing._idfunc",
                 c_basename="_typing__idfunc",
                 docstring="_idfunc($module, x, /)\n" "--",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="x", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={"typing_doc": "Primitives and accelerators for the typing module.\n"}
     );
