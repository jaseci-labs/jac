"""The Argument Clinic signatures of _sysconfig.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/sysconfig.jac from them. Taken from
the C sources it replaces (Modules/_sysconfig.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_sysconfig",
         version="3.14.6",
         sources=["Modules/_sysconfig.c"],
         functions=[
             Function(
                 name="config_vars",
                 full_name="_sysconfig.config_vars",
                 c_basename="_sysconfig_config_vars",
                 docstring="config_vars($module, /)\n"
                 "--\n"
                 "\n"
                 "Returns a dictionary containing build variables intended to be exposed by sysconfig.",
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
         docs={"sysconfig__doc__": "A helper for the sysconfig module."}
     );
