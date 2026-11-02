"""The Argument Clinic signatures of _posixshmem.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/posixshmem.jac from them. Taken from
CPython 3.14.6 Modules/_multiprocessing/posixshmem.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_posixshmem",
         version="3.14.6",
         sources=["Modules/_multiprocessing/posixshmem.c"],
         functions=[
             Function(
                 name="shm_open",
                 full_name="_posixshmem.shm_open",
                 c_basename="_posixshmem_shm_open",
                 docstring="shm_open($module, /, path, flags, mode=511)\n"
                 "--\n"
                 "\n"
                 "Open a shared memory object.  Returns a file descriptor (integer).",
                 condition="defined(HAVE_SHM_OPEN)",
                 returns="int",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="path", converter="unicode", format_unit="U"),
                     Parameter(
                         name="flags", converter="int", type="int", format_unit="i"
                     ),
                     Parameter(
                         name="mode",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=511,
                         c_default="511"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_FORMAT_KEYWORDS",
                 min_pos=2,
                 max_pos=3,
                 limited_capi=True
             ),
             Function(
                 name="shm_unlink",
                 full_name="_posixshmem.shm_unlink",
                 c_basename="_posixshmem_shm_unlink",
                 docstring="shm_unlink($module, path, /)\n"
                 "--\n"
                 "\n"
                 "Remove a shared memory object (similar to unlink()).\n"
                 "\n"
                 "Remove a shared memory object name, and, once all processes have\n"
                 "unmapped the object, de-allocates and destroys the contents of the\n"
                 "associated memory region.",
                 condition="defined(HAVE_SHM_UNLINK)",
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
             )
         ]
     );
