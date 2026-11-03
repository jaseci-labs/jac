import os;
import tempfile;

def wasm_ir(program: JacProgram, file_path: str) -> tuple[str, set[str]];

def wasm_ir_units(
    program: JacProgram, file_path: str
) -> tuple[str, set[str], list[list[str]]];

def wasm_artifact_inputs(
    program: JacProgram, file_path: str
) -> tuple[bytes, list[list[str]]];


def route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None];

