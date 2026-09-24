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
from jaclang.compiler.backends.native.na_compile_pass import require_native_ir
from jaclang.compiler.backends.native.link_glue import init_object_codegen
from jaclang.compiler.backends.native.link_plan import (
    ArtifactKind, build_link_plan, whole_program_module,
    internalize_native_implementation, _platform_of,
)
import jaclang.compiler.backends.native.llvm.binding as llvm

program = JacProgram()
entry = root / "jaclang/compiler/backends/py/jacpython/native_api.jac"
options = CompileOptions(
    aot_mode=True, default_codespace="native", force_target_program=True,
    skip_native_engine=True,
    native_required=True,
    memory_profile="rc", no_ir_cache=False, opt_level=2, native_target=triple,
)
plan = build_link_plan(program, [str(entry)], options)
if program.errors_had:
    for error in program.errors_had:
        print(error.pretty_print(), file=sys.stderr)
    raise RuntimeError("JacPython native compilation failed")
init_object_codegen()
spec = plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False)
compiled, runtime_exports = whole_program_module(plan, spec)
require_native_ir(str(compiled))
internalize_native_implementation(
    compiled, plan.pub_exports() + runtime_exports + ["__jac_shared_init"],
)
compiled.verify()
machine = llvm.Target.from_triple(triple).create_target_machine(
    opt=2, reloc="pic", codemodel="small",
)
object_bytes = machine.emit_object(compiled)
(output / "jacpython.o").write_bytes(object_bytes)
(output / "sha256").write_text(hashlib.sha256(object_bytes).hexdigest() + "\n")
print("JacPython: built native compiler object; no interpreted demotions", flush=True)
# This one-shot emitter has closed both artifact files. Let the OS reclaim its
# compiler graph and LLVM context rather than traversing them again at Python
# shutdown; no runtime initialization or cache work is deferred to that phase.
sys.stderr.flush()
os._exit(0)
