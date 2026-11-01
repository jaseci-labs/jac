"""Bytecode for a compiled module, made inside the kernel.

The Python code generator leaves the module's recipe on `module.gen.py_recipe`.
It lowers into JacPython's AST, JacPython's compiler turns that into the
module's code object in-process, and JacPython's marshal turns the code object
into the bytes caches store. What leaves the kernel is Python objects: the code
object, and on request the generated Python as an `ast.Module`."""
import from c {
    def PyMarshal_WriteObjectToString(x: ptr[PyObject], version: i32) -> ptr[PyObject];
    def PyMarshal_ReadObjectFromString(data: ptr[u8], length: i64) -> ptr[PyObject];
    def PyBytes_AsString(value: ptr[PyObject]) -> ptr[u8];
}

glob CODE_MARSHAL_VERSION: i32 = 5;

obj GeneratedPythonRejected(KernelError) {
    has path: str,
        reason: str,
        line: int = 0,
        col: int = 0;

    def __str__ -> str;
}

def python_tree(module: uni.Module) -> Module;

def kernel_code_object(module: uni.Module) -> any;

def kernel_python_ast(module: uni.Module) -> any;

def code_bytes(code: ptr[PyObject]) -> bytes;

def code_from_bytes(data: bytes) -> ptr[PyObject];
