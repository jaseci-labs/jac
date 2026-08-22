"""C source generation (Emit leg of first-class C interop).

Emits C from the Jac UniIR as a codegen backend alongside the Python,
ECMAScript, and native targets. See jaseci-labs/jaseci#7145 (Leg 3).
"""

from jaclang.compiler.passes.c.c_gen_pass import CGenPass  # noqa: F401
