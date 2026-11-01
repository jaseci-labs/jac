"""The Argument Clinic signatures of _operator.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/operator.jac from them. Taken from
the C sources it replaces (Modules/_operator.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_operator",
         version="3.14.6",
         sources=["Modules/_operator.c"],
         functions=[
             Function(
                 name="truth",
                 full_name="_operator.truth",
                 c_basename="_operator_truth",
                 docstring="truth($module, a, /)\n"
                 "--\n"
                 "\n"
                 "Return True if a is true, False otherwise.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="add",
                 full_name="_operator.add",
                 c_basename="_operator_add",
                 docstring="add($module, a, b, /)\n" "--\n" "\n" "Same as a + b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="sub",
                 full_name="_operator.sub",
                 c_basename="_operator_sub",
                 docstring="sub($module, a, b, /)\n" "--\n" "\n" "Same as a - b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="mul",
                 full_name="_operator.mul",
                 c_basename="_operator_mul",
                 docstring="mul($module, a, b, /)\n" "--\n" "\n" "Same as a * b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="matmul",
                 full_name="_operator.matmul",
                 c_basename="_operator_matmul",
                 docstring="matmul($module, a, b, /)\n" "--\n" "\n" "Same as a @ b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="floordiv",
                 full_name="_operator.floordiv",
                 c_basename="_operator_floordiv",
                 docstring="floordiv($module, a, b, /)\n" "--\n" "\n" "Same as a // b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="truediv",
                 full_name="_operator.truediv",
                 c_basename="_operator_truediv",
                 docstring="truediv($module, a, b, /)\n" "--\n" "\n" "Same as a / b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="mod",
                 full_name="_operator.mod",
                 c_basename="_operator_mod",
                 docstring="mod($module, a, b, /)\n" "--\n" "\n" "Same as a % b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="neg",
                 full_name="_operator.neg",
                 c_basename="_operator_neg",
                 docstring="neg($module, a, /)\n" "--\n" "\n" "Same as -a.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="pos",
                 full_name="_operator.pos",
                 c_basename="_operator_pos",
                 docstring="pos($module, a, /)\n" "--\n" "\n" "Same as +a.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="abs",
                 full_name="_operator.abs",
                 c_basename="_operator_abs",
                 docstring="abs($module, a, /)\n" "--\n" "\n" "Same as abs(a).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="inv",
                 full_name="_operator.inv",
                 c_basename="_operator_inv",
                 docstring="inv($module, a, /)\n" "--\n" "\n" "Same as ~a.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="invert",
                 full_name="_operator.invert",
                 c_basename="_operator_invert",
                 docstring="invert($module, a, /)\n" "--\n" "\n" "Same as ~a.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="lshift",
                 full_name="_operator.lshift",
                 c_basename="_operator_lshift",
                 docstring="lshift($module, a, b, /)\n" "--\n" "\n" "Same as a << b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="rshift",
                 full_name="_operator.rshift",
                 c_basename="_operator_rshift",
                 docstring="rshift($module, a, b, /)\n" "--\n" "\n" "Same as a >> b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="not_",
                 full_name="_operator.not_",
                 c_basename="_operator_not_",
                 docstring="not_($module, a, /)\n" "--\n" "\n" "Same as not a.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="and_",
                 full_name="_operator.and_",
                 c_basename="_operator_and_",
                 docstring="and_($module, a, b, /)\n" "--\n" "\n" "Same as a & b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="xor",
                 full_name="_operator.xor",
                 c_basename="_operator_xor",
                 docstring="xor($module, a, b, /)\n" "--\n" "\n" "Same as a ^ b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="or_",
                 full_name="_operator.or_",
                 c_basename="_operator_or_",
                 docstring="or_($module, a, b, /)\n" "--\n" "\n" "Same as a | b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="iadd",
                 full_name="_operator.iadd",
                 c_basename="_operator_iadd",
                 docstring="iadd($module, a, b, /)\n" "--\n" "\n" "Same as a += b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="isub",
                 full_name="_operator.isub",
                 c_basename="_operator_isub",
                 docstring="isub($module, a, b, /)\n" "--\n" "\n" "Same as a -= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="imul",
                 full_name="_operator.imul",
                 c_basename="_operator_imul",
                 docstring="imul($module, a, b, /)\n" "--\n" "\n" "Same as a *= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="imatmul",
                 full_name="_operator.imatmul",
                 c_basename="_operator_imatmul",
                 docstring="imatmul($module, a, b, /)\n" "--\n" "\n" "Same as a @= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ifloordiv",
                 full_name="_operator.ifloordiv",
                 c_basename="_operator_ifloordiv",
                 docstring="ifloordiv($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Same as a //= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="itruediv",
                 full_name="_operator.itruediv",
                 c_basename="_operator_itruediv",
                 docstring="itruediv($module, a, b, /)\n" "--\n" "\n" "Same as a /= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="imod",
                 full_name="_operator.imod",
                 c_basename="_operator_imod",
                 docstring="imod($module, a, b, /)\n" "--\n" "\n" "Same as a %= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ilshift",
                 full_name="_operator.ilshift",
                 c_basename="_operator_ilshift",
                 docstring="ilshift($module, a, b, /)\n" "--\n" "\n" "Same as a <<= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="irshift",
                 full_name="_operator.irshift",
                 c_basename="_operator_irshift",
                 docstring="irshift($module, a, b, /)\n" "--\n" "\n" "Same as a >>= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="iand",
                 full_name="_operator.iand",
                 c_basename="_operator_iand",
                 docstring="iand($module, a, b, /)\n" "--\n" "\n" "Same as a &= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ixor",
                 full_name="_operator.ixor",
                 c_basename="_operator_ixor",
                 docstring="ixor($module, a, b, /)\n" "--\n" "\n" "Same as a ^= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ior",
                 full_name="_operator.ior",
                 c_basename="_operator_ior",
                 docstring="ior($module, a, b, /)\n" "--\n" "\n" "Same as a |= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="concat",
                 full_name="_operator.concat",
                 c_basename="_operator_concat",
                 docstring="concat($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Same as a + b, for a and b sequences.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="iconcat",
                 full_name="_operator.iconcat",
                 c_basename="_operator_iconcat",
                 docstring="iconcat($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Same as a += b, for a and b sequences.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="contains",
                 full_name="_operator.contains",
                 c_basename="_operator_contains",
                 docstring="contains($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Same as b in a (note reversed operands).",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="indexOf",
                 full_name="_operator.indexOf",
                 c_basename="_operator_indexOf",
                 docstring="indexOf($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Return the first index of b in a.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="countOf",
                 full_name="_operator.countOf",
                 c_basename="_operator_countOf",
                 docstring="countOf($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Return the number of items in a which are, or which equal, b.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="getitem",
                 full_name="_operator.getitem",
                 c_basename="_operator_getitem",
                 docstring="getitem($module, a, b, /)\n" "--\n" "\n" "Same as a[b].",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="setitem",
                 full_name="_operator.setitem",
                 c_basename="_operator_setitem",
                 docstring="setitem($module, a, b, c, /)\n"
                 "--\n"
                 "\n"
                 "Same as a[b] = c.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="c", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3
             ),
             Function(
                 name="delitem",
                 full_name="_operator.delitem",
                 c_basename="_operator_delitem",
                 docstring="delitem($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Same as del a[b].",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="eq",
                 full_name="_operator.eq",
                 c_basename="_operator_eq",
                 docstring="eq($module, a, b, /)\n" "--\n" "\n" "Same as a == b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ne",
                 full_name="_operator.ne",
                 c_basename="_operator_ne",
                 docstring="ne($module, a, b, /)\n" "--\n" "\n" "Same as a != b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="lt",
                 full_name="_operator.lt",
                 c_basename="_operator_lt",
                 docstring="lt($module, a, b, /)\n" "--\n" "\n" "Same as a < b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="le",
                 full_name="_operator.le",
                 c_basename="_operator_le",
                 docstring="le($module, a, b, /)\n" "--\n" "\n" "Same as a <= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="gt",
                 full_name="_operator.gt",
                 c_basename="_operator_gt",
                 docstring="gt($module, a, b, /)\n" "--\n" "\n" "Same as a > b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ge",
                 full_name="_operator.ge",
                 c_basename="_operator_ge",
                 docstring="ge($module, a, b, /)\n" "--\n" "\n" "Same as a >= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pow",
                 full_name="_operator.pow",
                 c_basename="_operator_pow",
                 docstring="pow($module, a, b, /)\n" "--\n" "\n" "Same as a ** b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ipow",
                 full_name="_operator.ipow",
                 c_basename="_operator_ipow",
                 docstring="ipow($module, a, b, /)\n" "--\n" "\n" "Same as a **= b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="index",
                 full_name="_operator.index",
                 c_basename="_operator_index",
                 docstring="index($module, a, /)\n" "--\n" "\n" "Same as a.__index__()",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="is_",
                 full_name="_operator.is_",
                 c_basename="_operator_is_",
                 docstring="is_($module, a, b, /)\n" "--\n" "\n" "Same as a is b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="is_not",
                 full_name="_operator.is_not",
                 c_basename="_operator_is_not",
                 docstring="is_not($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Same as a is not b.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="is_none",
                 full_name="_operator.is_none",
                 c_basename="_operator_is_none",
                 docstring="is_none($module, a, /)\n" "--\n" "\n" "Same as a is None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="is_not_none",
                 full_name="_operator.is_not_none",
                 c_basename="_operator_is_not_none",
                 docstring="is_not_none($module, a, /)\n"
                 "--\n"
                 "\n"
                 "Same as a is not None.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="length_hint",
                 full_name="_operator.length_hint",
                 c_basename="_operator_length_hint",
                 docstring="length_hint($module, obj, default=0, /)\n"
                 "--\n"
                 "\n"
                 "Return an estimate of the number of items in obj.\n"
                 "\n"
                 "This is useful for presizing containers when building from an iterable.\n"
                 "\n"
                 "If the object supports len(), the result will be exact.\n"
                 "Otherwise, it may over- or under-estimate by an arbitrary amount.\n"
                 "The result will be an integer >= 0.",
                 returns="Py_ssize_t",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="obj", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="default",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="_compare_digest",
                 full_name="_operator._compare_digest",
                 c_basename="_operator__compare_digest",
                 docstring="_compare_digest($module, a, b, /)\n"
                 "--\n"
                 "\n"
                 "Return 'a == b'.\n"
                 "\n"
                 "This function uses an approach designed to prevent\n"
                 "timing analysis, making it appropriate for cryptography.\n"
                 "\n"
                 "a and b must both be of the same type: either str (ASCII only),\n"
                 "or any bytes-like object.\n"
                 "\n"
                 "Note: If a and b are of different lengths, or if an error occurs,\n"
                 "a timing attack could theoretically reveal information about the\n"
                 "types and lengths of a and b--but not their values.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="a", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="b", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             )
         ],
         docs={
             "operator_doc": "Operator interface.\n"
             "\n"
             "This module exports a set of functions implemented in C corresponding\n"
             "to the intrinsic operators of Python.  For example, operator.add(x, y)\n"
             "is equivalent to the expression x+y.  The function names are those\n"
             "used for special methods; variants without leading and trailing\n"
             "'__' are also provided for convenience.",
             "_operator_call__doc__": "call($module, obj, /, *args, **kwargs)\n"
             "--\n"
             "\n"
             "Same as obj(*args, **kwargs).",
             "reduce_doc": "Return state information for pickling",
             "itemgetter_doc": "itemgetter(item, /, *items)\n"
             "--\n"
             "\n"
             "Return a callable object that fetches the given item(s) from its operand.\n"
             "After f = itemgetter(2), the call f(r) returns r[2].\n"
             "After g = itemgetter(2, 5, 3), the call g(r) returns (r[2], r[5], r[3])",
             "attrgetter_doc": "attrgetter(attr, /, *attrs)\n"
             "--\n"
             "\n"
             "Return a callable object that fetches the given attribute(s) from its operand.\n"
             "After f = attrgetter('name'), the call f(r) returns r.name.\n"
             "After g = attrgetter('name', 'date'), the call g(r) returns (r.name, r.date).\n"
             "After h = attrgetter('name.first', 'name.last'), the call h(r) returns\n"
             "(r.name.first, r.name.last).",
             "methodcaller_doc": "methodcaller(name, /, *args, **kwargs)\n"
             "--\n"
             "\n"
             "Return a callable object that calls the given method on its operand.\n"
             "After f = methodcaller('name'), the call f(r) returns r.name().\n"
             "After g = methodcaller('name', 'date', foo=1), the call g(r) returns\n"
             "r.name('date', foo=1)."
         }
     );
