import copy;
import from pathlib { Path }

def python_source(path: str, program: JacProgram) -> tuple[str, Module | None];

def python_text(path: str, program: JacProgram) -> str;
