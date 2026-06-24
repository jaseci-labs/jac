"""In-tree LLVM IR builder + binding for the native (na) backend (issue #6925).

Derived from numba/llvmlite (BSD-2-Clause): the two pure-Python layers -- `ir`
(the IR builder) and `binding` (ctypes marshalling over the LLVMPY_* C ABI) --
were translated to Jac with `py2jac` and are now first-party code maintained
here. The verbatim C++ LLVMPY_* shim it binds to lives at jac/native/ (compiled
+ statically linked by Zig). See docs/docs/internals/llvmlite_decoupling.md.
"""
import os;

glob ir_layer_typed_pointers_enabled: bool =
    os.environ.get('LLVMLITE_ENABLE_IR_LAYER_TYPED_POINTERS', '1') == '1';
