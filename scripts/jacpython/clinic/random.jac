"""The Argument Clinic signatures of _random.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/random.jac from them. Taken from
the C sources it replaces (Modules/_randommodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_random",
         version="3.14.6",
         sources=["Modules/_randommodule.c"],
         classes={"Random": "RandomObject *"},
         functions=[
             Function(
                 name="random",
                 full_name="_random.Random.random",
                 c_basename="_random_Random_random",
                 cls="Random",
                 docstring="random($self, /)\n"
                 "--\n"
                 "\n"
                 "random() -> x in the interval [0, 1).",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="seed",
                 full_name="_random.Random.seed",
                 c_basename="_random_Random_seed",
                 cls="Random",
                 docstring="seed($self, n=None, /)\n"
                 "--\n"
                 "\n"
                 "seed([n]) -> None.\n"
                 "\n"
                 "Defaults to use urandom and falls back to a combination\n"
                 "of the current time and the process identifier.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="n",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="getstate",
                 full_name="_random.Random.getstate",
                 c_basename="_random_Random_getstate",
                 cls="Random",
                 docstring="getstate($self, /)\n"
                 "--\n"
                 "\n"
                 "getstate() -> tuple containing the current state.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="setstate",
                 full_name="_random.Random.setstate",
                 c_basename="_random_Random_setstate",
                 cls="Random",
                 docstring="setstate($self, state, /)\n"
                 "--\n"
                 "\n"
                 "setstate(state) -> None.  Restores generator state.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="state", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="getrandbits",
                 full_name="_random.Random.getrandbits",
                 c_basename="_random_Random_getrandbits",
                 cls="Random",
                 docstring="getrandbits($self, k, /)\n"
                 "--\n"
                 "\n"
                 "getrandbits(k) -> x.  Generates an int with k random bits.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="k",
                         kind="POSITIONAL_ONLY",
                         converter="uint64",
                         type="uint64_t",
                         format_unit="O&",
                         convert_with="_PyLong_UInt64_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__init__",
                 full_name="_random.Random.__init__",
                 c_basename="random_init",
                 kind="METHOD_INIT",
                 cls="Random",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="seed",
                         kind="POSITIONAL_ONLY",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             )
         ],
         docs={
             "random_doc": "Random() -> create a random number generator with its own internal state.",
             "module_doc": "Module implements the Mersenne Twister random number generator."
         }
     );
