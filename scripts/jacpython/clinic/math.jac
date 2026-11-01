"""The Argument Clinic signatures of math.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/math.jac from them. Taken from
the C sources it replaces (Modules/mathmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="math",
         version="3.14.6",
         sources=["Modules/mathmodule.c"],
         functions=[
             Function(
                 name="gcd",
                 full_name="math.gcd",
                 c_basename="math_gcd",
                 docstring="gcd($module, /, *integers)\n"
                 "--\n"
                 "\n"
                 "Greatest Common Divisor.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="integers",
                         kind="VAR_POSITIONAL",
                         converter="varpos_array",
                         type="PyObject * const *"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="parser for METH_FASTCALL"
             ),
             Function(
                 name="lcm",
                 full_name="math.lcm",
                 c_basename="math_lcm",
                 docstring="lcm($module, /, *integers)\n"
                 "--\n"
                 "\n"
                 "Least Common Multiple.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="integers",
                         kind="VAR_POSITIONAL",
                         converter="varpos_array",
                         type="PyObject * const *"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="parser for METH_FASTCALL"
             ),
             Function(
                 name="ceil",
                 full_name="math.ceil",
                 c_basename="math_ceil",
                 docstring="ceil($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the ceiling of x as an Integral.\n"
                 "\n"
                 "This is the smallest integer >= x.",
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
             ),
             Function(
                 name="floor",
                 full_name="math.floor",
                 c_basename="math_floor",
                 docstring="floor($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the floor of x as an Integral.\n"
                 "\n"
                 "This is the largest integer <= x.",
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
             ),
             Function(
                 name="fsum",
                 full_name="math.fsum",
                 c_basename="math_fsum",
                 docstring="fsum($module, seq, /)\n"
                 "--\n"
                 "\n"
                 "Return an accurate floating-point sum of values in the iterable seq.\n"
                 "\n"
                 "Assumes IEEE-754 floating-point arithmetic.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="seq", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="isqrt",
                 full_name="math.isqrt",
                 c_basename="math_isqrt",
                 docstring="isqrt($module, n, /)\n"
                 "--\n"
                 "\n"
                 "Return the integer part of the square root of the input.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="n", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="factorial",
                 full_name="math.factorial",
                 c_basename="math_factorial",
                 docstring="factorial($module, n, /)\n" "--\n" "\n" "Find n!.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="n", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="trunc",
                 full_name="math.trunc",
                 c_basename="math_trunc",
                 docstring="trunc($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Truncates the Real x to the nearest Integral toward 0.\n"
                 "\n"
                 "Uses the __trunc__ magic method.",
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
             ),
             Function(
                 name="frexp",
                 full_name="math.frexp",
                 c_basename="math_frexp",
                 docstring="frexp($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the mantissa and exponent of x, as pair (m, e).\n"
                 "\n"
                 "If x is a finite nonzero number, then m is a float with\n"
                 "0.5 <= abs(m) < 1.0 and an integer e is such that\n"
                 "x == m * 2**e exactly.  Else, return (x, 0).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="ldexp",
                 full_name="math.ldexp",
                 c_basename="math_ldexp",
                 docstring="ldexp($module, x, i, /)\n"
                 "--\n"
                 "\n"
                 "Return x * (2**i).\n"
                 "\n"
                 "This is essentially the inverse of frexp().",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(name="i", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="modf",
                 full_name="math.modf",
                 c_basename="math_modf",
                 docstring="modf($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the fractional and integer parts of x.\n"
                 "\n"
                 "Both results carry the sign of x and are floats.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="log2",
                 full_name="math.log2",
                 c_basename="math_log2",
                 docstring="log2($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the base 2 logarithm of x.",
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
             ),
             Function(
                 name="log10",
                 full_name="math.log10",
                 c_basename="math_log10",
                 docstring="log10($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the base 10 logarithm of x.",
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
             ),
             Function(
                 name="fma",
                 full_name="math.fma",
                 c_basename="math_fma",
                 docstring="fma($module, x, y, z, /)\n"
                 "--\n"
                 "\n"
                 "Fused multiply-add operation.\n"
                 "\n"
                 "Compute (x * y) + z with a single round.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="y",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="z",
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
                 pos_only=3
             ),
             Function(
                 name="fmod",
                 full_name="math.fmod",
                 c_basename="math_fmod",
                 docstring="fmod($module, x, y, /)\n"
                 "--\n"
                 "\n"
                 "Return fmod(x, y), according to platform C.\n"
                 "\n"
                 "x % y may differ.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="y",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="dist",
                 full_name="math.dist",
                 c_basename="math_dist",
                 docstring="dist($module, p, q, /)\n"
                 "--\n"
                 "\n"
                 "Return the Euclidean distance between two points p and q.\n"
                 "\n"
                 "The points should be specified as sequences (or iterables) of\n"
                 "coordinates.  Both inputs must have the same dimension.\n"
                 "\n"
                 "Roughly equivalent to:\n"
                 "    sqrt(sum((px - qx) ** 2.0 for px, qx in zip(p, q)))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="p", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="q", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="hypot",
                 full_name="math.hypot",
                 c_basename="math_hypot",
                 docstring="hypot($module, /, *coordinates)\n"
                 "--\n"
                 "\n"
                 "Multidimensional Euclidean distance from the origin to a point.\n"
                 "\n"
                 "Roughly equivalent to:\n"
                 "    sqrt(sum(x**2 for x in coordinates))\n"
                 "\n"
                 "For a two dimensional point (x, y), gives the hypotenuse\n"
                 "using the Pythagorean theorem:  sqrt(x*x + y*y).\n"
                 "\n"
                 "For example, the hypotenuse of a 3/4/5 right triangle is:\n"
                 "\n"
                 "    >>> hypot(3.0, 4.0)\n"
                 "    5.0",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="coordinates",
                         kind="VAR_POSITIONAL",
                         converter="varpos_array",
                         type="PyObject * const *"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="parser for METH_FASTCALL"
             ),
             Function(
                 name="sumprod",
                 full_name="math.sumprod",
                 c_basename="math_sumprod",
                 docstring="sumprod($module, p, q, /)\n"
                 "--\n"
                 "\n"
                 "Return the sum of products of values from two iterables p and q.\n"
                 "\n"
                 "Roughly equivalent to:\n"
                 "\n"
                 "    sum(map(operator.mul, p, q, strict=True))\n"
                 "\n"
                 "For float and mixed int/float inputs, the intermediate products\n"
                 "and sums are computed with extended precision.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="p", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="q", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="pow",
                 full_name="math.pow",
                 c_basename="math_pow",
                 docstring="pow($module, x, y, /)\n"
                 "--\n"
                 "\n"
                 "Return x**y (x to the power of y).",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="y",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="degrees",
                 full_name="math.degrees",
                 c_basename="math_degrees",
                 docstring="degrees($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Convert angle x from radians to degrees.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="radians",
                 full_name="math.radians",
                 c_basename="math_radians",
                 docstring="radians($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Convert angle x from degrees to radians.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="isfinite",
                 full_name="math.isfinite",
                 c_basename="math_isfinite",
                 docstring="isfinite($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return True if x is neither an infinity nor a NaN, and False otherwise.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="isnan",
                 full_name="math.isnan",
                 c_basename="math_isnan",
                 docstring="isnan($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return True if x is a NaN (not a number), and False otherwise.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="isinf",
                 full_name="math.isinf",
                 c_basename="math_isinf",
                 docstring="isinf($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return True if x is a positive or negative infinity, and False otherwise.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="isclose",
                 full_name="math.isclose",
                 c_basename="math_isclose",
                 docstring="isclose($module, /, a, b, *, rel_tol=1e-09, abs_tol=0.0)\n"
                 "--\n"
                 "\n"
                 "Determine whether two floating-point numbers are close in value.\n"
                 "\n"
                 "  rel_tol\n"
                 "    maximum difference for being considered \"close\", relative to the\n"
                 "    magnitude of the input values\n"
                 "  abs_tol\n"
                 "    maximum difference for being considered \"close\", regardless of the\n"
                 "    magnitude of the input values\n"
                 "\n"
                 "Return True if a is close in value to b, and False otherwise.\n"
                 "\n"
                 "For the values to be considered close, the difference between them\n"
                 "must be smaller than at least one of the tolerances.\n"
                 "\n"
                 "-inf, inf and NaN behave similarly to the IEEE 754 Standard.  That\n"
                 "is, NaN is not close to anything, even itself.  inf and -inf are\n"
                 "only close to themselves.",
                 returns="bool",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="a", converter="double", type="double", format_unit="d"
                     ),
                     Parameter(
                         name="b", converter="double", type="double", format_unit="d"
                     ),
                     Parameter(
                         name="rel_tol",
                         kind="KEYWORD_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=1e-09,
                         c_default="1e-09"
                     ),
                     Parameter(
                         name="abs_tol",
                         kind="KEYWORD_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d",
                         default_kind="value",
                         py_default=0.0,
                         c_default="0.0"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="prod",
                 full_name="math.prod",
                 c_basename="math_prod",
                 docstring="prod($module, iterable, /, *, start=1)\n"
                 "--\n"
                 "\n"
                 "Calculate the product of all the elements in the input iterable.\n"
                 "\n"
                 "The default start value for the product is 1.\n"
                 "\n"
                 "When the iterable is empty, return the start value.  This function is\n"
                 "intended specifically for use with numeric values and may reject\n"
                 "non-numeric types.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="iterable", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="start",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         py_default=1,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="perm",
                 full_name="math.perm",
                 c_basename="math_perm",
                 docstring="perm($module, n, k=None, /)\n"
                 "--\n"
                 "\n"
                 "Number of ways to choose k items from n items without repetition and with order.\n"
                 "\n"
                 "Evaluates to n! / (n - k)! when k <= n and evaluates\n"
                 "to zero when k > n.\n"
                 "\n"
                 "If k is not specified or is None, then k defaults to n\n"
                 "and the function returns n!.\n"
                 "\n"
                 "Raises TypeError if either of the arguments are not integers.\n"
                 "Raises ValueError if either of the arguments are negative.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="n", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(
                         name="k",
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
                 name="comb",
                 full_name="math.comb",
                 c_basename="math_comb",
                 docstring="comb($module, n, k, /)\n"
                 "--\n"
                 "\n"
                 "Number of ways to choose k items from n items without repetition and without order.\n"
                 "\n"
                 "Evaluates to n! / (k! * (n - k)!) when k <= n and evaluates\n"
                 "to zero when k > n.\n"
                 "\n"
                 "Also called the binomial coefficient because it is equivalent\n"
                 "to the coefficient of k-th term in polynomial expansion of the\n"
                 "expression (1 + x)**n.\n"
                 "\n"
                 "Raises TypeError if either of the arguments are not integers.\n"
                 "Raises ValueError if either of the arguments are negative.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(name="n", kind="POSITIONAL_ONLY", format_unit="O"),
                     Parameter(name="k", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="nextafter",
                 full_name="math.nextafter",
                 c_basename="math_nextafter",
                 docstring="nextafter($module, x, y, /, *, steps=None)\n"
                 "--\n"
                 "\n"
                 "Return the floating-point value the given number of steps after x towards y.\n"
                 "\n"
                 "If steps is not specified or is None, it defaults to 1.\n"
                 "\n"
                 "Raises a TypeError, if x or y is not a double, or if steps is not\n"
                 "an integer.  Raises ValueError if steps is negative.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="y",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     ),
                     Parameter(
                         name="steps",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="ulp",
                 full_name="math.ulp",
                 c_basename="math_ulp",
                 docstring="ulp($module, x, /)\n"
                 "--\n"
                 "\n"
                 "Return the value of the least significant bit of the float x.",
                 returns="double",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="x",
                         kind="POSITIONAL_ONLY",
                         converter="double",
                         type="double",
                         format_unit="d"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ],
         docs={
             "math_log_doc": "log(x, [base=math.e])\n"
             "Return the logarithm of x to the given base.\n"
             "\n"
             "If the base is not specified, returns the natural logarithm (base e) of x.",
             "module_doc": "This module provides access to the mathematical functions\n"
             "defined by the C standard.",
             "math_asinh_doc": "asinh($module, x, /)\n"
             "--\n"
             "\n"
             "Return the inverse hyperbolic sine of x.",
             "math_atan_doc": "atan($module, x, /)\n"
             "--\n"
             "\n"
             "Return the arc tangent (measured in radians) of x.\n"
             "\n"
             "The result is between -pi/2 and pi/2.",
             "math_cbrt_doc": "cbrt($module, x, /)\n"
             "--\n"
             "\n"
             "Return the cube root of x.",
             "math_cosh_doc": "cosh($module, x, /)\n"
             "--\n"
             "\n"
             "Return the hyperbolic cosine of x.",
             "math_exp_doc": "exp($module, x, /)\n"
             "--\n"
             "\n"
             "Return e raised to the power of x.",
             "math_exp2_doc": "exp2($module, x, /)\n"
             "--\n"
             "\n"
             "Return 2 raised to the power of x.",
             "math_expm1_doc": "expm1($module, x, /)\n"
             "--\n"
             "\n"
             "Return exp(x)-1.\n"
             "\n"
             "This function avoids the loss of precision involved in the direct evaluation of exp(x)-1 for small x.",
             "math_fabs_doc": "fabs($module, x, /)\n"
             "--\n"
             "\n"
             "Return the absolute value of the float x.",
             "math_sinh_doc": "sinh($module, x, /)\n"
             "--\n"
             "\n"
             "Return the hyperbolic sine of x.",
             "math_tanh_doc": "tanh($module, x, /)\n"
             "--\n"
             "\n"
             "Return the hyperbolic tangent of x.",
             "math_acos_doc": "acos($module, x, /)\n"
             "--\n"
             "\n"
             "Return the arc cosine (measured in radians) of x.\n"
             "\n"
             "The result is between 0 and pi.",
             "math_acosh_doc": "acosh($module, x, /)\n"
             "--\n"
             "\n"
             "Return the inverse hyperbolic cosine of x.",
             "math_asin_doc": "asin($module, x, /)\n"
             "--\n"
             "\n"
             "Return the arc sine (measured in radians) of x.\n"
             "\n"
             "The result is between -pi/2 and pi/2.",
             "math_atanh_doc": "atanh($module, x, /)\n"
             "--\n"
             "\n"
             "Return the inverse hyperbolic tangent of x.",
             "math_cos_doc": "cos($module, x, /)\n"
             "--\n"
             "\n"
             "Return the cosine of x (measured in radians).",
             "math_log1p_doc": "log1p($module, x, /)\n"
             "--\n"
             "\n"
             "Return the natural logarithm of 1+x (base e).\n"
             "\n"
             "The result is computed in a way which is accurate for x near zero.",
             "math_sin_doc": "sin($module, x, /)\n"
             "--\n"
             "\n"
             "Return the sine of x (measured in radians).",
             "math_sqrt_doc": "sqrt($module, x, /)\n"
             "--\n"
             "\n"
             "Return the square root of x.",
             "math_tan_doc": "tan($module, x, /)\n"
             "--\n"
             "\n"
             "Return the tangent of x (measured in radians).",
             "math_erf_doc": "erf($module, x, /)\n" "--\n" "\n" "Error function at x.",
             "math_erfc_doc": "erfc($module, x, /)\n"
             "--\n"
             "\n"
             "Complementary error function at x.",
             "math_gamma_doc": "gamma($module, x, /)\n"
             "--\n"
             "\n"
             "Gamma function at x.",
             "math_lgamma_doc": "lgamma($module, x, /)\n"
             "--\n"
             "\n"
             "Natural logarithm of absolute value of Gamma function at x.",
             "math_atan2_doc": "atan2($module, y, x, /)\n"
             "--\n"
             "\n"
             "Return the arc tangent (measured in radians) of y/x.\n"
             "\n"
             "Unlike atan(y/x), the signs of both x and y are considered.",
             "math_copysign_doc": "copysign($module, x, y, /)\n"
             "--\n"
             "\n"
             "Return a float with the magnitude (absolute value) of x but the sign of y.\n"
             "\n"
             "On platforms that support signed zeros, copysign(1.0, -0.0)\n"
             "returns -1.0.\n",
             "math_remainder_doc": "remainder($module, x, y, /)\n"
             "--\n"
             "\n"
             "Difference between x and the closest integer multiple of y.\n"
             "\n"
             "Return x - n*y where n*y is the closest integer multiple of y.\n"
             "In the case where x is exactly halfway between two multiples of\n"
             "y, the nearest even value of n is used. The result is always exact."
         }
     );
