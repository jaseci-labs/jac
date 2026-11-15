import ast;
import marshal;
import struct;
import sys;
import types;
import from collections.abc { Callable }


def decode_ops(code: bytes, container: CirContainer) -> list[tuple[any, ...]];

def _call_kw(cls: any, kw: dict[str, object]) -> any;

obj CirSplice {
    has stmts: list[ast.stmt] = [];
}

obj CirCompiledModule {
    has mod_path: str,
        tree: ast.Module,
        code_obj: any = None,
        bytecode: bytes = b"";
}

obj CirResult {
    has modules: list[CirCompiledModule] = [],
        diags: list[CirDiag] = [];
}

def cir_bind_classes(class_names: list[str]) -> list[type];

def cir_bind_keys(key_names: list[str]) -> list[str];

def _parse_splice(
    src: str, line_offset: int, python_compiler: any = None
) -> CirSplice;

def _pop_values(stack: list[object], n: int, what: str) -> list[object];

def transcribe_module(
    mod: CirModule,
    classes: list[type],
    keys: list[str],
    container: CirContainer,
    python_compiler: any = None
) -> any;

def transcribe(ir_bytes: bytes) -> tuple[list[tuple[str, ast.Module]], list[CirDiag]];

def compile_ir(ir_bytes: bytes, python_compiler: any = None) -> CirResult;

def generated_python(gen: CodeGenTarget) -> str;
