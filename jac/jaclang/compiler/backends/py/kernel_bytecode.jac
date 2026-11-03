import from c {
    def PyMarshal_WriteObjectToString(x: ptr[PyObject], version: i32) -> ptr[PyObject];
}

glob CODE_MARSHAL_VERSION: i32 = 5;

obj KernelPython(PythonEngine) {
    override def parse_module(source: str, path: str) -> Module;
    override def code_bytes(module: uni.Module) -> bytes;
    override def python_source(module: uni.Module) -> str;
}

def python_tree(module: uni.Module) -> Module;

def kernel_code_object(module: uni.Module) -> ptr[PyObject];
