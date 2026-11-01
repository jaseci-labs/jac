"""The Argument Clinic signatures of _suggestions.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/suggestions.jac from them. Taken from
the C sources it replaces (Modules/_suggestions.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_suggestions",
         version="3.14.6",
         sources=["Modules/_suggestions.c"],
         functions=[
             Function(
                 name="_generate_suggestions",
                 full_name="_suggestions._generate_suggestions",
                 c_basename="_suggestions__generate_suggestions",
                 docstring="_generate_suggestions($module, candidates, item, /)\n"
                 "--\n"
                 "\n"
                 "Returns the candidate in candidates that's closest to item",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="candidates", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="item",
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
             )
         ]
     );
