"""Build JacPython's native object using the pinned build-time CPython.

No compiler bytecode, request seed, or Python adapter is shipped. The output
object contains the native Jac compiler and its native runtime support.
"""
import hashlib
import json
import os
from pathlib import Path
import sys
import shutil

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
stage = output / "source"
if stage.exists():
    shutil.rmtree(stage)
namespace = "_jacpython_native"
# Isolate the compilation subject from the host compiler's self-host program.
# These copies only relocate imports; every algorithm remains checked-in Jac.
for relative in (
    "compiler/frontend/python",
    "compiler/backends/py/jacpython",
    "runtime/python",
):
    for source in sorted((root / "jaclang" / relative).rglob("*.jac")):
        destination = stage / namespace / source.relative_to(root / "jaclang")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(source.read_text().replace("jaclang.", namespace + "."))

import jaclang
from jaclang.compiler.session.session import JacProgram
from jaclang.compiler.session.options import CompileOptions
from jaclang.compiler.backends.common.artifact_store import artifact_for
from jaclang.compiler.backends.native.na_compile_pass import (
    native_linked_ir_text, native_demoted_ir_symbols,
)
from jaclang.compiler.backends.native.lowering import native_lowering_issues
from jaclang.compiler.backends.native.shared_emit import init_object_codegen, inject_shared_init
import jaclang.compiler.backends.native.llvm.binding as llvm

program = JacProgram()
entry = stage / namespace / "compiler/backends/py/jacpython/native_api.jac"
module = program.compile(file_path=str(entry), options=CompileOptions(
    aot_mode=True, default_codespace="native", force_target_program=True,
    memory_profile="managed", no_ir_cache=False, opt_level=2, native_target=triple,
))
if program.errors_had:
    for error in program.errors_had:
        print(error.pretty_print(), file=sys.stderr)
    raise RuntimeError("JacPython native compilation failed")
if module is None:
    raise RuntimeError("JacPython native compilation produced no module")
ir_text = native_linked_ir_text(module)
issues = native_demoted_ir_symbols(ir_text)
issues.extend(issue.symbol for issue in native_lowering_issues(ir_text))
if issues:
    raise RuntimeError("JacPython may not demote to Python: " + ", ".join(sorted(set(issues))))
ir_text, _ = inject_shared_init(ir_text, artifact_for(module).interop_manifest)
init_object_codegen()
compiled = llvm.parse_assembly(ir_text)
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
