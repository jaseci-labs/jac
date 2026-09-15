"""Build JacPython's native objects using the pinned build-time CPython.

No compiler bytecode, request seed, or Python adapter is shipped. The output
objects contain the native Jac compiler and evaluator support.
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
from jaclang.compiler.backends.native.shared_emit import (
    init_object_codegen, inject_shared_init, internalize_native_implementation,
)
import jaclang.compiler.backends.native.llvm.binding as llvm

generation = json.loads((root / "bootstrap/python/generated/evaluator-generation.json").read_text())
if generation["cpython"] != pin["version"]:
    raise RuntimeError("Native handler generation does not match the CPython pin")
if generation["generator_sha256"] != hashlib.sha256((root / "bootstrap/python/generate_evaluator.py").read_bytes()).hexdigest():
    raise RuntimeError("Regenerate native evaluator sources after changing the generator")
for name, expected in generation["outputs"].items():
    generated_path = root / ("jaclang/runtime/python" if name.endswith(".jac") else "bootstrap/python/generated") / name
    if hashlib.sha256(generated_path.read_bytes()).hexdigest() != expected:
        raise RuntimeError("Native evaluator generated source changed independently: " + name)

program = JacProgram()
entry = root / "jaclang/compiler/backends/py/jacpython/native_api.jac"
module = program.compile(file_path=str(entry), options=CompileOptions(
    aot_mode=True, default_codespace="native", force_target_program=True,
    native_required=True,
    memory_profile="managed", no_ir_cache=False, opt_level=2, native_target=triple,
))
if program.errors_had:
    for error in program.errors_had:
        print(error.pretty_print(), file=sys.stderr)
    raise RuntimeError("JacPython native compilation failed")
if module is None:
    raise RuntimeError("JacPython native compilation produced no module")
ir_text = native_linked_ir_text(module)
require_native_ir(ir_text)
ir_text, runtime_exports = inject_shared_init(ir_text, module.gen.interop_manifest)
init_object_codegen()
compiled = llvm.parse_assembly(ir_text)
internalize_native_implementation(
    compiled, list(module.gen._exported_symbols) + runtime_exports + ["__jac_shared_init"],
)
compiled.verify()
machine = llvm.Target.from_triple(triple).create_target_machine(
    opt=2, reloc="pic", codemodel="small",
)
object_bytes = machine.emit_object(compiled)
(output / "jacpython.o").write_bytes(object_bytes)
(output / "sha256").write_text(hashlib.sha256(object_bytes).hexdigest() + "\n")
# Evaluator units use foreign ownership and emit separate C ABI objects. Keeping
# frame cleanup separate also keeps its private frame-runtime dependencies out
# of the reference-only unit used by isolated reference-boundary fixtures.
evaluator_units = []


def emit_evaluator_unit(module_name, artifact_name, exports):
    support_program = JacProgram()
    support_entry = root / "jaclang/runtime/python" / (module_name + ".jac")
    support = support_program.compile(file_path=str(support_entry), options=CompileOptions(
        aot_mode=True, default_codespace="native", force_target_program=True,
        native_required=True, memory_profile="nogc", no_ir_cache=False,
        opt_level=2, native_target=triple,
    ))
    if support_program.errors_had:
        for error in support_program.errors_had:
            print(error.pretty_print(), file=sys.stderr)
        raise RuntimeError("Native evaluator compilation failed: " + module_name)
    if support is None:
        raise RuntimeError("Native evaluator unit produced no module: " + module_name)
    support_ir = native_linked_ir_text(support)
    require_native_ir(support_ir)
    support_module = llvm.parse_assembly(support_ir)
    defined = {
        function.name for function in support_module.functions
        if not function.is_declaration
    }
    missing = set(exports) - defined
    if missing:
        raise RuntimeError("Missing native evaluator definitions: " + ", ".join(sorted(missing)))
    if artifact_name == "evaluator_entry":
        # The generated ABI expressions need the target's configured headers.
        # Keep checked native IR until that C IR can be linked and optimized.
        support_module.verify()
        for function in support_module.functions:
            if function.name.startswith("__jac_") or function.name in {
                "malloc", "calloc", "realloc", "free", "pthread_getspecific",
                "pthread_setspecific", "pthread_key_create",
            }:
                raise RuntimeError("Evaluator retains Jac runtime machinery: " + function.name)
        (output / "evaluator_entry.ll").write_text(str(support_module))
        (output / "evaluator_entry.exports.json").write_text(json.dumps(exports) + "\n")
        evaluator_units.append({
            "source": str(support_entry.relative_to(root)),
            "source_sha256": hashlib.sha256(support_entry.read_bytes()).hexdigest(),
            "object": "evaluator_entry.o", "exports": sorted(exports),
            "memory_profile": "nogc", "emission": "awaiting target-configured ABI IR",
        })
        return
    internalize_native_implementation(support_module, exports)
    support_module.verify()
    with llvm.create_pipeline_tuning_options(speed_level=2) as tuning:
        with llvm.create_pass_builder(machine, tuning) as passes:
            with passes.getModulePassManager() as manager:
                manager.run(support_module, passes)
    support_module.verify()
    for function in support_module.functions:
        if function.name.startswith("__jac_") or function.name in {
            "malloc", "calloc", "realloc", "free", "pthread_getspecific",
            "pthread_setspecific", "pthread_key_create",
        }:
            raise RuntimeError("Evaluator unit retains Jac runtime machinery: " + function.name)
    support_bytes = machine.emit_object(support_module)
    (output / (artifact_name + ".o")).write_bytes(support_bytes)
    (output / (artifact_name + ".sha256")).write_text(
        hashlib.sha256(support_bytes).hexdigest() + "\n"
    )
    evaluator_units.append({
        "source": str(support_entry.relative_to(root)),
        "source_sha256": hashlib.sha256(support_entry.read_bytes()).hexdigest(),
        "object": artifact_name + ".o",
        "object_sha256": hashlib.sha256(support_bytes).hexdigest(),
        "optimized_ir_sha256": hashlib.sha256(str(support_module).encode()).hexdigest(),
        "exports": sorted(exports),
        "memory_profile": "nogc",
    })


emit_evaluator_unit("evaluator_support", "evaluator_support", [
    "_PyEval_SliceIndex", "_PyEval_SliceIndexNotNone",
    "_PyEval_GetAwaitable", "_PyEval_GetANext",
    "_PyEval_CheckExceptTypeValid", "_PyEval_CheckExceptStarTypeValid",
    "jacpy_eval_raise",
])
emit_evaluator_unit("evaluator_frames", "evaluator_frames", [
    "_PyEval_FrameClearAndPop",
])
emit_evaluator_unit("evaluator_monitoring", "evaluator_monitoring", [
    "_PyEval_MonitorRaise", "jacpy_monitor_no_tools_for_unwind",
    "jacpy_monitor_reraise", "jacpy_monitor_stop_iteration",
    "jacpy_monitor_unwind", "jacpy_monitor_handled", "jacpy_monitor_throw",
    "PyThreadState_EnterTracing", "PyThreadState_LeaveTracing", "_PyEval_CallTracing",
    "PyEval_SetProfile", "PyEval_SetProfileAllThreads",
    "PyEval_SetTrace", "PyEval_SetTraceAllThreads",
    "_PyEval_SetCoroutineOriginTrackingDepth", "_PyEval_GetCoroutineOriginTrackingDepth",
    "_PyEval_SetAsyncGenFirstiter", "_PyEval_SetAsyncGenFinalizer",
])
emit_evaluator_unit("evaluator_errors", "evaluator_errors", [
    "_Py_Check_ArgsIterable", "_PyEval_FormatKwargsError",
    "_PyEval_FormatExcCheckArg", "_PyEval_FormatExcUnbound", "_PyEval_FormatAwaitableError",
    "PyEval_GetFuncName", "PyEval_GetFuncDesc", "_PyEval_SpecialMethodCanSuggest",
])
emit_evaluator_unit("evaluator_imports", "evaluator_imports", [
    "_PyEval_LoadName", "_PyEval_ImportName", "_PyEval_ImportFrom",
])
emit_evaluator_unit("evaluator_exceptions", "evaluator_exceptions", [
    "jacpy_exception_table_handler",
])
emit_evaluator_unit("evaluator_arguments", "evaluator_arguments", [
    "jacpy_missing_arguments", "jacpy_too_many_positional", "jacpy_positional_only_as_keyword",
])
emit_evaluator_unit("evaluator_binding", "evaluator_binding", [
    "jacpy_binding_close_impl", "jacpy_frame_push_impl",
])
emit_evaluator_unit("evaluator_calls", "evaluator_calls", [
    "jacpy_eval_vector_impl", "jacpy_callargs_close_impl", "jacpy_frame_push_ex_impl",
])
emit_evaluator_unit("evaluator_legacy", "evaluator_legacy", [
    "PyEval_EvalCode", "jacpy_eval_code_ex_impl",
])
emit_evaluator_unit("evaluator_context", "evaluator_context", [
    "jacpy_get_builtins", "jacpy_get_globals", "jacpy_get_frame_object",
    "jacpy_get_locals", "jacpy_get_frame_locals", "jacpy_get_builtin",
    "_PyEval_EnsureBuiltins", "_PyEval_EnsureBuiltinsWithModule",
])
emit_evaluator_unit("evaluator_unpack", "evaluator_unpack", [
    "jacpy_unpack_iterable", "jacpy_unpack_close_impl",
])
emit_evaluator_unit("evaluator_matching", "evaluator_matching", [
    "jacpy_match_keys_impl", "_PyEval_MatchClass",
])
emit_evaluator_unit("evaluator_groups", "evaluator_groups", [
    "_PyEval_ExceptionGroupMatch",
])
emit_evaluator_unit("evaluator_recursion", "evaluator_recursion", [
    "Py_GetRecursionLimit", "Py_SetRecursionLimit", "_Py_CheckRecursiveCallPy",
    "PyUnstable_ThreadState_ResetStackProtection", "jacpy_initialize_recursion",
    "jacpy_set_stack_protection", "jacpy_reached_recursion_margin",
    "jacpy_enter_recursion_unchecked", "jacpy_check_recursion",
])
emit_evaluator_unit("evaluator_utilities", "evaluator_utilities", [
    "jacpy_merge_compiler_flags", "jacpy_request_code_extra",
    "jacpy_running_main_module", "_PyEval_LoadGlobalStackRef",
    "jacpy_object_array_from_stack_impl",
])
emit_evaluator_unit("evaluator_entry", "evaluator_entry", [
    "jacpy_eval_frame_entry", "jacpy_enter_recursive_py", "jacpy_leave_recursive_py",
])
provenance_inputs = [
    "jaclang/runtime/python/references.jac",
    "jaclang/runtime/python/evaluator_lookup.jac",
    "bootstrap/python/compiler-bridge.patch",
    "bootstrap/python/evaluator_refs.c",
    "bootstrap/python/evaluator_refs.h",
    "bootstrap/python/evaluator_frames.c",
    "bootstrap/python/evaluator_frames.h",
    "bootstrap/python/evaluator_objects.c",
    "bootstrap/python/evaluator_objects.h",
    "bootstrap/python/evaluator_binding.c",
    "bootstrap/python/evaluator_binding.h",
    "bootstrap/python/evaluator_recursion.c",
    "bootstrap/python/evaluator_recursion.h",
    "bootstrap/python/evaluator_metadata.c",
    "bootstrap/python/evaluator_metadata.h",
    "bootstrap/python/evaluator_entry.c",
    "bootstrap/python/evaluator_entry.h",
    "bootstrap/python/evaluator_activation.c", "bootstrap/python/evaluator_activation.h",
    "bootstrap/python/evaluator_operations.h", "bootstrap/python/generate_evaluator.py",
    "bootstrap/python/link_evaluator.py",
    "bootstrap/python/generated/evaluator_scratch.h",
    "bootstrap/python/generated/evaluator_tier1_abi.c",
    "bootstrap/python/generated/evaluator_tier2_abi.c",
    "bootstrap/python/generated/evaluator-generation.json",
    "jaclang/runtime/python/evaluator_activation.jac",
    "jaclang/runtime/python/evaluator_handlers.jac",
]
(output / "evaluator-provenance.json").write_text(json.dumps({
    "schema": 1,
    "cpython_version": pin["version"],
    "cpython_archive_sha256": pin["sha256"],
    "target": triple,
    "main_evaluator": "jac-native",
    "dispatch": "checked native tail transfers",
    "opcode_handlers": "jac-native-control/typed-c-slot-primitives",
    "tier_two_executor": "jac-native-interpreter",
    "jit_stencils": "retained CPython generation inputs; optional JIT configuration",
    "retired_runtime_sources": ["Python/ceval.c", "Python/generated_cases.c.h", "Python/opcode_targets.h"],
    "units": evaluator_units,
    "inputs": {
        path: hashlib.sha256((root / path).read_bytes()).hexdigest()
        for path in provenance_inputs
    },
    "evidence": "emitter inputs and native objects; not linked-runtime acceptance",
}, indent=2, sort_keys=True) + "\n")
print("JacPython: built native compiler and evaluator support objects; no interpreted demotions", flush=True)
# This one-shot emitter has closed its artifact files. Let the OS reclaim its
# compiler graph and LLVM context rather than traversing them again at Python
# shutdown; no runtime initialization or cache work is deferred to that phase.
sys.stderr.flush()
os._exit(0)
