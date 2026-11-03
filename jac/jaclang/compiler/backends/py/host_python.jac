import ast;
import marshal;

obj HostPython(PythonEngine) {
    def parse_module(source: str, path: str) -> PyModule;
    def code_bytes(module: uni.Module) -> bytes;
    def python_source(module: uni.Module) -> str;
}

def host_python_ast(module: uni.Module) -> ast.Module;

def host_node(cg: CgNode) -> ast.AST;

def host_value(value: any) -> any;
