import subprocess;
import tempfile;
import from pathlib { Path }

def emit_c(llvm_ir: str) -> str;
