"""Build JacPython's native object using the pinned build-time CPython.

No compiler bytecode, request seed, or Python adapter is shipped. The output
object contains the native Jac compiler and its native runtime support.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
triple = {
    "linux-x86_64": "x86_64-unknown-linux-gnu",
    "linux-aarch64": "aarch64-unknown-linux-gnu",
    "macos-x86_64": "x86_64-apple-macosx12.0.0",
    "macos-aarch64": "arm64-apple-macosx11.0.0",
}[sys.argv[3]]
pin = json.loads((root / "bootstrap/python/sources.json").read_text())["cpython"]
if tuple(map(int, pin["version"].split("."))) != sys.version_info[:3]:
    raise RuntimeError("Build JacPython with pinned CPython " + pin["version"])
sys.path.insert(0, str(root))
os.environ["JAC_NO_DEV_SOURCE"] = "1"
os.environ["JAC_COMPILER_LIB"] = "off"
os.environ["JAC_STUBCAT_BUILDING"] = "1"
output.mkdir(parents=True, exist_ok=True)

import jaclang
from jaclang.compiler.driver.program import JacProgram
from jaclang.compiler.driver.compile_options import CompileOptions
from jaclang.compiler.backends.native.na_compile_pass import (
    native_linked_ir_text, require_native_ir,
)
from jaclang.compiler.backends.native.shared_emit import emit_shared_object

program = JacProgram()
entry = root / "jaclang/compiler/backends/py/jacpython/native_api.jac"
module = program.compile(file_path=str(entry), options=CompileOptions(
    aot_mode=True, default_codespace="native", force_target_program=True,
    native_required=True,
    memory_profile="rc", no_ir_cache=False, opt_level=2, native_target=triple,
))
if program.errors_had:
    for error in program.errors_had:
        print(error.pretty_print(), file=sys.stderr)
    raise RuntimeError("JacPython native compilation failed")
if module is None:
    raise RuntimeError("JacPython native compilation produced no module")
ir_text = native_linked_ir_text(module)
require_native_ir(ir_text)
object_bytes = emit_shared_object(
    ir_text,
    module.gen.interop_manifest,
    list(module.gen._exported_symbols),
    triple,
    opt_level=2,
).code
(output / "jacpython.o").write_bytes(object_bytes)
(output / "sha256").write_text(hashlib.sha256(object_bytes).hexdigest() + "\n")
print("JacPython: built native compiler object; no interpreted demotions", flush=True)
# This one-shot emitter has closed both artifact files. Let the OS reclaim its
# compiler graph and LLVM context rather than traversing them again at Python
# shutdown; no runtime initialization or cache work is deferred to that phase.
sys.stderr.flush()
os._exit(0)
