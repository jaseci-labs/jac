"""The kernel's bytecode product: a compiled module's JacPython code object,
built in memory by JacPython's compiler inside the kernel. The result is an
owned reference, which `CompiledUnit.code` carries to the module binding."""
def kernel_code_object(module: uni.Module) -> ptr[PyObject];
