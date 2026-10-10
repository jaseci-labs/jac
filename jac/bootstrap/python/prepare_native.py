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
os.environ["JAC_KERNEL_BUILDING"] = "1"
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
    aot_mode=True, default_codespace="native", skip_native_engine=True,
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
# Units are optimized one at a time; the merged module is where bindings,
# algorithms and object-API calls from different units can inline. The object
# reaches the CPython link as machine code, so ThinLTO cannot do this later.
builder = llvm.create_pass_builder(
    machine, llvm.create_pipeline_tuning_options(speed_level=2),
)
builder.getModulePassManager().run(compiled, builder)
compiled.verify()
object_bytes = machine.emit_object(compiled)
(output / "jacpython.o").write_bytes(object_bytes)
(output / "sha256").write_text(hashlib.sha256(object_bytes).hexdigest() + "\n")
# The interpreter's ThinLTO link can fold this module in only when its LLVM
# matches ours: bitcode readers reject newer writers. build.sh compares this
# version against zig's clang and falls back to the machine-code object.
(output / "llvm-version").write_text(
    ".".join(map(str, llvm.llvm_version_info)) + "\n"
)
(output / "jacpython.bc").write_bytes(compiled.as_bitcode())


def lowered_sources():
    """Every source the object was lowered from, relative to the jac root: the
    plan's units, their annexes and their compile-time inputs. A dependency can
    only be added by editing one of these, so they key the object exactly."""
    from jaclang.compiler.driver.jir import _related_files, _ct_dep_rows, _ct_row_path
    registry = program.native_units()
    paths = set()
    for unit in plan.units:
        real = os.path.realpath(unit.path)
        paths.add(real)
        for rel, _digest in _related_files(unit.path):
            paths.add(os.path.realpath(os.path.join(os.path.dirname(real), rel)))
        ent = registry.entries.get(real)
        if ent is not None and ent.compile_deps:
            for dep, _digest, _body in _ct_dep_rows(ent.compile_deps.decode("utf-8")):
                paths.add(os.path.realpath(_ct_row_path(dep, ent.compile_deps_base)))
    jac_root = os.path.realpath(str(root))
    rels = []
    for path in sorted(paths):
        rel = os.path.relpath(path, jac_root)
        if rel.startswith(".."):
            raise RuntimeError(f"JacPython lowered a source outside the jac root: {path}")
        rels.append(rel.replace(os.sep, "/"))
    return rels


(output / "sources").write_text("".join(rel + "\n" for rel in lowered_sources()))
print("JacPython: built native compiler object; no interpreted demotions", flush=True)
# This one-shot emitter has closed both artifact files. Let the OS reclaim its
# compiler graph and LLVM context rather than traversing them again at Python
# shutdown; no runtime initialization or cache work is deferred to that phase.
sys.stderr.flush()
os._exit(0)
