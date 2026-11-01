"""The Argument Clinic signatures of _statistics.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/statistics.jac from them. Taken from
the C sources it replaces (Modules/_statisticsmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_statistics",
         version="3.14.6",
         sources=["Modules/_statisticsmodule.c"],
         functions=[
             Function(
                 name="_normal_dist_inv_cdf",
                 full_name="_statistics._normal_dist_inv_cdf",
                 c_basename="_statistics__normal_dist_inv_cdf",
                 docstring="_normal_dist_inv_cdf($module, p, mu, sigma, /)\n" "--",
                 returns="double",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="p",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="mu",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="sigma",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3,
                 limited_capi=True
             )
         ],
         docs={"statistics_doc": "Accelerators for the statistics module.\n"}
     );
