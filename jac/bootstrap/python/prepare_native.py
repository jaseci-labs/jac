"""Build JacPython's native object using the pinned build-time CPython.

No compiler bytecode, request seed, or Python adapter is shipped. The output
object contains the native Jac compiler and its native runtime support.
"""
import hashlib
import json
import os
from pathlib import Path
import sys

TRIPLES = {
    "linux-x86_64": "x86_64-unknown-linux-gnu",
    "linux-aarch64": "aarch64-unknown-linux-gnu",
    "macos-x86_64": "x86_64-apple-macosx12.0.0",
    "macos-aarch64": "arm64-apple-macosx11.0.0",
}


def registered_exports(root):
    """The PyInit_* entry points build.sh links as static built-ins.

    jacpython-modules.txt is the one list of replaced modules; build.sh writes
    each name into Modules/Setup.local. The link succeeds only when the merged
    object defines every entry point, so the registry is also the export
    contract this build checks against the compiled plan.
    """
    registry = root / "bootstrap/python/jacpython-modules.txt"
    exports = []
    for line in registry.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        exports.append("PyInit_" + line.split()[0])
    return exports


STATIC_TYPE_EXPORTS = [
    # Type objects of the object-model units whose C sources the build excludes
    # (range, cell, enumerate, picklebuffer, interpolation, template). The
    # compiler-bridge patch points object.c's static_types table at these
    # symbols, so the merged object must define them or the interpreter link
    # fails; the PyInit_* registry alone does not cover them.
    "PyCell_Type",
    "PyEnum_Type",
    "_PyInterpolation_Type",
    "PyPickleBuffer_Type",
    "PyRange_Type",
    "PyRangeIter_Type",
    "PyLongRangeIter_Type",
    "PyReversed_Type",
    "_PyTemplate_Type",
    "_PyTemplateIter_Type",
]


def missing_exports(expected, exported):
    """The expected entry points absent from a collection of symbol names."""
    present = set(exported)
    return [name for name in expected if name not in present]


def undefined_exports(module, expected):
    """The expected entry points the merged module does not define itself."""
    missing = []
    for name in expected:
        try:
            value = module.get_function(name)
        except NameError:
            missing.append(name)
            continue
        if value.is_declaration:
            missing.append(name)
    return missing


def native_plan(root, triple):
    """The compiled link plan for native_api.jac and its compile program.

    Both the build and the test suite compile the same entry with the same
    options, so the export contract the build checks is exactly what the
    regression test exercises. Plan construction is pure Jac lowering: it
    needs no LLVM shim and no CPython source tree.
    """
    import jaclang
    from jaclang.compiler.driver.program import JacProgram
    from jaclang.compiler.driver.compile_options import CompileOptions
    from jaclang.compiler.backends.native.link_plan import build_link_plan

    root = Path(root)
    program = JacProgram()
    entry = root / "jaclang/compiler/backends/py/jacpython/native_api.jac"
    options = CompileOptions(
        aot_mode=True, default_codespace="native", skip_native_engine=True,
        native_required=True,
        memory_profile="rc", no_ir_cache=False, opt_level=2, native_target=triple,
    )
    plan = build_link_plan(program, [str(entry)], options)
    return program, plan


def main(argv):
    root = Path(argv[1]).resolve()
    output = Path(argv[2]).resolve()
    triple = TRIPLES[argv[3]]
    pin = json.loads((root / "bootstrap/python/sources.json").read_text())["cpython"]
    if tuple(map(int, pin["version"].split("."))) != sys.version_info[:3]:
        raise RuntimeError("Build JacPython with pinned CPython " + pin["version"])
    sys.path.insert(0, str(root))
    os.environ.pop("JAC_HANDOFF", None)
    output.mkdir(parents=True, exist_ok=True)

    from jaclang.compiler.backends.native.lowering import native_fallbacks_in_ir
    from jaclang.compiler.backends.native.link_glue import init_object_codegen
    from jaclang.compiler.backends.native.link_plan import (
        ArtifactKind, whole_program_module,
        internalize_native_implementation, _platform_of,
    )
    import jaclang.compiler.backends.native.llvm.binding as llvm

    expected = registered_exports(root)
    program, plan = native_plan(root, triple)
    if program.errors_had:
        for error in program.errors_had:
            print(error.pretty_print(), file=sys.stderr)
        raise RuntimeError("JacPython native compilation failed")
    # A registry entry whose binding is not reachable from native_api.jac has no
    # PyInit_* in the object, and the interpreter link then fails with unresolved
    # symbols. Check the compiled plan's public exports so the build names the
    # actual defect instead of a later linker error. build.sh's old check grepped
    # native_api.jac for the symbol text; archwire.jac injects the imports, so
    # only the lowered plan can answer this.
    missing = missing_exports(expected, plan.pub_exports())
    if missing:
        raise RuntimeError(
            "JacPython export contract is broken: bootstrap/python/"
            "jacpython-modules.txt registers modules whose PyInit_* symbols the "
            "native_api.jac compilation closure does not export: "
            + ", ".join(missing)
            + ". Wire each binding module into "
            "jaclang/compiler/backends/py/jacpython/native_api.jac in "
            "jaclang/archwire.jac."
        )
    missing = missing_exports(STATIC_TYPE_EXPORTS, plan.pub_exports())
    if missing:
        raise RuntimeError(
            "JacPython export contract is broken: object.c's static_types "
            "table references static type objects the native_api.jac "
            "compilation closure does not define: " + ", ".join(missing)
            + ". Wire their object_model units into "
            "jaclang/compiler/backends/py/jacpython/native_api.jac in "
            "jaclang/archwire.jac."
        )
    init_object_codegen()
    spec = plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False)
    compiled, runtime_exports = whole_program_module(plan, spec)
    native_fallbacks_in_ir(str(compiled)).require()
    internalize_native_implementation(
        compiled, plan.pub_exports() + runtime_exports + ["__jac_shared_init"],
    )
    # The plan promises the symbols; the merged module must define them, not
    # merely declare them. This is the last point before code generation where a
    # dropped binding is still a readable error.
    missing = undefined_exports(compiled, expected + STATIC_TYPE_EXPORTS)
    if missing:
        raise RuntimeError(
            "JacPython export contract is broken: the merged native module does "
            "not define: " + ", ".join(missing)
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
    missing = undefined_exports(compiled, expected + STATIC_TYPE_EXPORTS)
    if missing:
        raise RuntimeError(
            "JacPython export contract is broken after optimization: "
            + ", ".join(missing)
        )
    compiled.verify()
    object_bytes = machine.emit_object(compiled)
    (output / "jacpython.o").write_bytes(object_bytes)
    (output / "sha256").write_text(hashlib.sha256(object_bytes).hexdigest() + "\n")


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


if __name__ == "__main__":
    main(sys.argv)
