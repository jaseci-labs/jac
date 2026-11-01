"""Build JacPython's native object using the pinned build-time CPython.

No compiler bytecode, request seed, or Python adapter is shipped. The output
object contains the native Jac compiler and its native runtime support.
"""
import hashlib
import json
import os
import re
from pathlib import Path
import sys

STATIC_TYPE_EXPORTS = [
    "PyCell_Type", "PyEnum_Type", "_PyInterpolation_Type", "PyPickleBuffer_Type",
    "PyRange_Type", "PyRangeIter_Type", "PyLongRangeIter_Type", "PyReversed_Type",
    "_PyTemplate_Type", "_PyTemplateIter_Type",
]


def registered_exports(root):
    """Return the PyInit_* symbols required by the built-in module registry."""
    registry = root / "bootstrap/python/jacpython-modules.txt"
    return [
        "PyInit_" + line.split()[0]
        for line in registry.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def missing_exports(expected, exported):
    """Return required symbols absent from a list of exported names."""
    present = set(exported)
    return [name for name in expected if name not in present]


def undefined_exports(module, expected, kind="function"):
    """Return expected symbols that are absent or only declared in a module."""
    if kind == "function":
        lookup = module.get_function
    elif kind == "global":
        lookup = module.get_global_variable
    else:
        raise ValueError("unknown symbol kind: " + kind)
    missing = []
    for name in expected:
        try:
            value = lookup(name)
        except NameError:
            missing.append(name)
            continue
        if value.is_declaration:
            missing.append(name)
    return missing


def main(argv):
    root = Path(argv[1]).resolve()
    output = Path(argv[2]).resolve()
    triple = {
        "linux-x86_64": "x86_64-unknown-linux-gnu",
        "linux-aarch64": "aarch64-unknown-linux-gnu",
        "macos-x86_64": "x86_64-apple-macosx12.0.0",
        "macos-aarch64": "arm64-apple-macosx11.0.0",
    }[argv[3]]
    # Jac modules this build wrote for the object (the frozen modules that
    # scripts/jacpython/gen_frozen.jac writes and the _PyRuntime that
    # gen_runtime_image.jac writes). They are lowered with the runtime
    # but are not sources: the build key covers their generators and inputs.
    generated = [Path(path).resolve() for path in argv[4:]]
    pin = json.loads((root / "bootstrap/python/sources.json").read_text())["cpython"]
    if tuple(map(int, pin["version"].split("."))) != sys.version_info[:3]:
        raise RuntimeError("Build JacPython with pinned CPython " + pin["version"])
    sys.path.insert(0, str(root))
    os.environ.pop("JAC_HANDOFF", None)
    output.mkdir(parents=True, exist_ok=True)

    import jaclang
    from jaclang.compiler.driver.program import JacProgram
    from jaclang.compiler.driver.compile_options import CompileOptions
    from jaclang.compiler.backends.native.lowering import native_fallbacks_in_ir
    from jaclang.compiler.backends.native.link_glue import init_object_codegen
    from jaclang.compiler.backends.native.link_plan import (
        ArtifactKind, build_link_plan, whole_program_module,
        internalize_native_implementation, _platform_of,
    )
    import jaclang.compiler.backends.native.llvm.binding as llvm
    from jaclang.compiler.backends.native.llvm.binding.value import Linkage, Visibility

    # 128-bit unsigned division for x86_64 Linux, as compiler-rt's __udivti3 and
    # __umodti3 compute it. libmpdec's uint128 path calls them. Without a
    # definition here, the link pulls in Zig's compiler-rt object for them, and that
    # object also defines memset, memcpy, memmove, memcmp, bcmp, strlen and the
    # libm functions; the executable would then bind every C and Jac call to those
    # simple loops instead of glibc's. Defining the two helpers keeps compiler-rt out.
    INT128_DIVISION_IR = r"""
    define { i64, i64 } @__udivti3(i64 noundef %0, i64 noundef %1, i64 noundef %2, i64 noundef %3) local_unnamed_addr #0 {
      %5 = zext i64 %1 to i128
      %6 = shl nuw i128 %5, 64
      %7 = zext i64 %0 to i128
      %8 = or disjoint i128 %6, %7
      %9 = zext i64 %3 to i128
      %10 = shl nuw i128 %9, 64
      %11 = zext i64 %2 to i128
      %12 = or disjoint i128 %10, %11
      %13 = icmp eq i64 %3, 0
      br i1 %13, label %14, label %24

    14:
      %15 = icmp ult i64 %1, %2
      br i1 %15, label %19, label %16

    16:
      %17 = udiv i64 %1, %2
      %18 = urem i64 %1, %2
      br label %19

    19:
      %20 = phi i64 [ %17, %16 ], [ 0, %14 ]
      %21 = phi i64 [ %18, %16 ], [ %1, %14 ]
      %22 = tail call { i64, i64 } asm "divq $4", "={ax},={dx},{ax},{dx},rm,~{dirflag},~{fpsr},~{flags}"(i64 %0, i64 %21, i64 %2)
      %23 = extractvalue { i64, i64 } %22, 0
      br label %82

    24:
      %25 = icmp ult i128 %8, %12
      br i1 %25, label %82, label %26

    26:
      %27 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %3, i1 true)
      %28 = trunc nuw nsw i64 %27 to i32
      %29 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %1, i1 true)
      %30 = trunc nuw nsw i64 %29 to i32
      %31 = sub nsw i32 %28, %30
      %32 = icmp slt i32 %31, 0
      br i1 %32, label %82, label %33

    33:
      %34 = zext nneg i32 %31 to i128
      %35 = shl i128 %12, %34
      %36 = add nuw nsw i32 %28, 1
      %37 = sub nsw i32 %36, %30
      %38 = and i32 %37, 1
      %39 = icmp eq i64 %27, %29
      br i1 %39, label %47, label %40

    40:
      %41 = and i32 %37, -2
      br label %62

    42:
      %43 = lshr i128 %71, 64
      %44 = trunc nuw i128 %43 to i64
      %45 = trunc i128 %78 to i64
      %46 = shl i128 %78, 1
      br label %47

    47:
      %48 = phi i64 [ poison, %33 ], [ %44, %42 ]
      %49 = phi i64 [ poison, %33 ], [ %45, %42 ]
      %50 = phi i128 [ 0, %33 ], [ %46, %42 ]
      %51 = phi i128 [ %8, %33 ], [ %75, %42 ]
      %52 = phi i128 [ %35, %33 ], [ %79, %42 ]
      %53 = icmp eq i32 %38, 0
      %54 = icmp uge i128 %51, %52
      %55 = zext i1 %54 to i128
      %56 = or disjoint i128 %50, %55
      %57 = lshr i128 %50, 64
      %58 = trunc nuw i128 %57 to i64
      %59 = trunc i128 %56 to i64
      %60 = select i1 %53, i64 %48, i64 %58
      %61 = select i1 %53, i64 %49, i64 %59
      br label %82

    62:
      %63 = phi i128 [ 0, %40 ], [ %78, %62 ]
      %64 = phi i128 [ %8, %40 ], [ %75, %62 ]
      %65 = phi i128 [ %35, %40 ], [ %79, %62 ]
      %66 = phi i32 [ 0, %40 ], [ %80, %62 ]
      %67 = icmp ult i128 %64, %65
      %68 = select i1 %67, i128 0, i128 %65
      %69 = sub nuw i128 %64, %68
      %70 = lshr i128 %65, 1
      %71 = shl i128 %63, 2
      %72 = select i1 %67, i128 0, i128 2
      %73 = icmp uge i128 %69, %70
      %74 = select i1 %73, i128 %70, i128 0
      %75 = sub nuw i128 %69, %74
      %76 = zext i1 %73 to i128
      %77 = or disjoint i128 %72, %76
      %78 = or disjoint i128 %77, %71
      %79 = lshr i128 %65, 2
      %80 = add i32 %66, 2
      %81 = icmp eq i32 %80, %41
      br i1 %81, label %42, label %62

    82:
      %83 = phi i64 [ %23, %19 ], [ 0, %24 ], [ 0, %26 ], [ %61, %47 ]
      %84 = phi i64 [ %20, %19 ], [ 0, %24 ], [ 0, %26 ], [ %60, %47 ]
      %85 = insertvalue { i64, i64 } poison, i64 %83, 0
      %86 = insertvalue { i64, i64 } %85, i64 %84, 1
      ret { i64, i64 } %86
    }

    define { i64, i64 } @__umodti3(i64 noundef %0, i64 noundef %1, i64 noundef %2, i64 noundef %3) local_unnamed_addr #0 {
      %5 = zext i64 %1 to i128
      %6 = shl nuw i128 %5, 64
      %7 = zext i64 %0 to i128
      %8 = or disjoint i128 %6, %7
      %9 = zext i64 %3 to i128
      %10 = shl nuw i128 %9, 64
      %11 = zext i64 %2 to i128
      %12 = or disjoint i128 %10, %11
      %13 = icmp eq i64 %3, 0
      br i1 %13, label %14, label %22

    14:
      %15 = icmp ult i64 %1, %2
      br i1 %15, label %18, label %16

    16:
      %17 = urem i64 %1, %2
      br label %18

    18:
      %19 = phi i64 [ %17, %16 ], [ %1, %14 ]
      %20 = tail call { i64, i64 } asm "divq $4", "={ax},={dx},{ax},{dx},rm,~{dirflag},~{fpsr},~{flags}"(i64 %0, i64 %19, i64 %2)
      %21 = extractvalue { i64, i64 } %20, 1
      br label %86

    22:
      %23 = icmp ult i128 %8, %12
      br i1 %23, label %86, label %24

    24:
      %25 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %3, i1 true)
      %26 = trunc nuw nsw i64 %25 to i32
      %27 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %1, i1 true)
      %28 = trunc nuw nsw i64 %27 to i32
      %29 = sub nsw i32 %26, %28
      %30 = icmp slt i32 %29, 0
      br i1 %30, label %86, label %31

    31:
      %32 = zext nneg i32 %29 to i128
      %33 = shl i128 %12, %32
      %34 = add nuw nsw i32 %26, 1
      %35 = sub nsw i32 %34, %28
      %36 = and i32 %35, 3
      %37 = icmp ult i32 %29, 3
      br i1 %37, label %44, label %38

    38:
      %39 = and i32 %35, -4
      br label %64

    40:
      %41 = trunc i128 %82 to i64
      %42 = lshr i128 %82, 64
      %43 = trunc nuw i128 %42 to i64
      br label %44

    44:
      %45 = phi i64 [ poison, %31 ], [ %41, %40 ]
      %46 = phi i64 [ poison, %31 ], [ %43, %40 ]
      %47 = phi i128 [ %8, %31 ], [ %82, %40 ]
      %48 = phi i128 [ %33, %31 ], [ %83, %40 ]
      %49 = icmp eq i32 %36, 0
      br i1 %49, label %86, label %50

    50:
      %51 = phi i128 [ %56, %50 ], [ %47, %44 ]
      %52 = phi i128 [ %57, %50 ], [ %48, %44 ]
      %53 = phi i32 [ %58, %50 ], [ 0, %44 ]
      %54 = icmp ult i128 %51, %52
      %55 = select i1 %54, i128 0, i128 %52
      %56 = sub nuw i128 %51, %55
      %57 = lshr i128 %52, 1
      %58 = add i32 %53, 1
      %59 = icmp eq i32 %58, %36
      br i1 %59, label %60, label %50

    60:
      %61 = trunc i128 %56 to i64
      %62 = lshr i128 %56, 64
      %63 = trunc nuw i128 %62 to i64
      br label %86

    64:
      %65 = phi i128 [ %8, %38 ], [ %82, %64 ]
      %66 = phi i128 [ %33, %38 ], [ %83, %64 ]
      %67 = phi i32 [ 0, %38 ], [ %84, %64 ]
      %68 = icmp ult i128 %65, %66
      %69 = select i1 %68, i128 0, i128 %66
      %70 = sub nuw i128 %65, %69
      %71 = lshr i128 %66, 1
      %72 = icmp ult i128 %70, %71
      %73 = select i1 %72, i128 0, i128 %71
      %74 = sub nuw i128 %70, %73
      %75 = lshr i128 %66, 2
      %76 = icmp ult i128 %74, %75
      %77 = select i1 %76, i128 0, i128 %75
      %78 = sub nuw i128 %74, %77
      %79 = lshr i128 %66, 3
      %80 = icmp ult i128 %78, %79
      %81 = select i1 %80, i128 0, i128 %79
      %82 = sub nuw i128 %78, %81
      %83 = lshr i128 %66, 4
      %84 = add i32 %67, 4
      %85 = icmp eq i32 %84, %39
      br i1 %85, label %40, label %64

    86:
      %87 = phi i64 [ %21, %18 ], [ %0, %22 ], [ %0, %24 ], [ %45, %44 ], [ %61, %60 ]
      %88 = phi i64 [ 0, %18 ], [ %1, %22 ], [ %1, %24 ], [ %46, %44 ], [ %63, %60 ]
      %89 = insertvalue { i64, i64 } poison, i64 %87, 0
      %90 = insertvalue { i64, i64 } %89, i64 %88, 1
      ret { i64, i64 } %90
    }

    declare i64 @llvm.ctlz.i64(i64, i1 immarg)

    attributes #0 = { nounwind }
    """

    program = JacProgram()
    # The roots of the native object: the compiler's entry points and the C
    # entries the interpreter calls them through, the table of
    # built-in modules (its PyInit addresses root every native extension module)
    # and the object model and interpreter ports, which define interpreter types
    # and functions under their C names for C callers no Jac module imports.
    entries = [
        root / "jaclang/compiler/backends/py/jacpython/native_api.jac",
        root / "jaclang/compiler/backends/py/jacpython/native_bridge.jac",
        root / "jaclang/runtime/python/inittab.jac",
        *sorted(
            path
            for package in ("object_model", "interpreter")
            for path in (root / "jaclang/runtime/python" / package).glob("*.jac")
            if path.name != "__init__.jac"
        ),
        *generated,
    ]
    options = CompileOptions(
        aot_mode=True, default_codespace="native", skip_native_engine=True,
        native_required=True,
        memory_profile="rc", no_ir_cache=False, opt_level=2, native_target=triple,
        # libpython is linked by the system linker, which takes TLS relocations,
        # and every frame arms through LLVM's builtin setjmp.
        native_tls=True, native_sjlj=True,
        # The runtime reads C memory through pointer views on every path, so views
        # are not null-checked. The instruction handlers (preserve_none C entries)
        # tail-call each other once per instruction and allocate nothing Jac
        # manages, so they jump straight into their bodies; other C entries still
        # escape the region a compile request runs in.
        native_unchecked_views=True, native_direct_c_entries=True,
        # The runtime's own heap (reference-counted objects and the storage of
        # their lists, dicts and sets) is the mimalloc this object links, not libc
        # malloc: one compile request allocates and frees hundreds of them, and
        # mimalloc's thread-local heaps take frees from any thread. Memory the Jac
        # sources allocate through their C imports (malloc, PyMem_RawMalloc) stays
        # libc's.
        native_heap="mi",
    )
    plan = build_link_plan(program, [str(entry) for entry in entries], options)
    if program.errors_had:
        for error in program.errors_had:
            print(error.pretty_print(), file=sys.stderr)
        raise RuntimeError("JacPython native compilation failed")
    expected_exports = registered_exports(root)
    missing = missing_exports(expected_exports + STATIC_TYPE_EXPORTS, plan.pub_exports())
    if missing:
        raise RuntimeError("JacPython export contract is broken; compiled roots do not export: " + ", ".join(missing))
    init_object_codegen()
    spec = plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False)
    compiled, runtime_exports = whole_program_module(plan, spec)
    missing = undefined_exports(compiled, expected_exports) + undefined_exports(
        compiled, STATIC_TYPE_EXPORTS, "global",
    )
    if missing:
        raise RuntimeError("JacPython export contract is broken; merged module does not define: " + ", ".join(missing))
    if triple.startswith("x86_64") and "linux" in triple:
        division = llvm.parse_assembly(INT128_DIVISION_IR)
        division.triple = compiled.triple
        division.data_layout = compiled.data_layout
        compiled.link_in(division)
        runtime_exports = runtime_exports + ["__udivti3", "__umodti3"]
    compiled_ir = str(compiled)
    native_fallbacks_in_ir(compiled_ir).require()
    # Every unit must agree on how thread-local slots are held and how frames
    # arm: the accessors and the raise path are shared, so a unit lowered without
    # these options would bring back the pthread-key lookup or libc's setjmp. The
    # C API's thread-specific storage (PyThread_tss_get and the old key API) is
    # the one place that calls pthread_getspecific by design. Only x86_64 arms
    # through LLVM's builtin setjmp; other targets keep _setjmp under native_sjlj.
    by_design = {"PyThread_tss_get", "PyThread_get_key_value"}
    builtin_sjlj = plan.triple.startswith("x86_64")
    for symbol, option in (("@pthread_getspecific", "native_tls"), ("@_setjmp", "native_sjlj")):
        if option == "native_sjlj" and not builtin_sjlj:
            continue
        if not getattr(options, option) or symbol not in compiled_ir:
            continue
        for function in re.finditer(r'^define [^\n]*?@"?([\w.$]+)"?\((.*?)^\}', compiled_ir, re.M | re.S):
            name = function.group(1).split(".")[0]
            if not re.search('@"?' + re.escape(symbol[1:]) + r'"?\(', function.group(2)):
                continue
            if name not in by_design:
                raise RuntimeError(f"a JacPython unit was lowered without {option} ({name})")
    internalize_native_implementation(
        compiled, plan.pub_exports() + runtime_exports + ["__jac_shared_init"],
    )
    # CPython compiles with -fno-semantic-interposition: libpython's own references
    # to its exported functions and data bind inside the library. Protected
    # visibility keeps a definition exported and makes it dso_local, so Jac code
    # reaches the instruction table and the C API without the GOT or the PLT.
    # The C API names this object only declares (`_PyRuntime`, `_Py_Dealloc`, the
    # C modules' tables) are defined by libpython's remaining C objects, so they
    # bind the same way.
    for value in [*compiled.functions, *compiled.global_variables]:
        if value.name.startswith("llvm."):
            continue
        if value.linkage in (Linkage.internal, Linkage.private) or value.visibility != Visibility.default:
            continue
        if value.is_declaration and not re.match(r"_?Py", value.name):
            continue
        value.visibility = Visibility.protected
    compiled.verify()
    machine = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small",
    )
    # Every unit carries private copies of the same runtime helpers (the raise
    # path, reference-count release, list append, UTF-8 cursors): merging the
    # identical bodies leaves one copy of each in the object. The option is
    # process-wide; this process builds nothing after the object.
    llvm.set_option("", "-enable-merge-functions=true")
    # The functions that only set or report an error mark their call sites as
    # unlikely, so the error paths are placed after the hot code that tests for
    # them instead of between its instructions.
    ERROR_PATHS = {
        "PyErr_SetString", "PyErr_SetObject", "PyErr_SetNone", "PyErr_Format",
        "PyErr_FormatV", "PyErr_NoMemory", "PyErr_BadInternalCall",
        "PyErr_BadArgument", "PyErr_SetFromErrno", "PyErr_SetFromErrnoWithFilename",
        "PyErr_SetFromErrnoWithFilenameObject", "PyErr_SetFromErrnoWithFilenameObjects",
        "PyErr_FormatUnraisable", "PyErr_WriteUnraisable", "PyErr_SetImportError",
        "_PyErr_SetString", "_PyErr_SetObject", "_PyErr_SetNone", "_PyErr_Format",
        "_PyErr_FormatFromCause", "_PyErr_NoMemory", "_PyErr_BadInternalCall",
        "_PyErr_SetKeyError", "_PyArg_BadArgument", "Py_FatalError",
        "_Py_FatalErrorFunc", "_Py_FatalErrorFormat", "object_error",
        "__jac_exception_context_slow",
    }
    for function in compiled.functions:
        if function.is_declaration:
            continue
        name = function.name
        base = name[:-4] if name.endswith(".jac") else name
        if base in ERROR_PATHS or base.rsplit(".", 1)[-1] in ERROR_PATHS:
            function.add_function_attribute("cold")
    # Units are optimized one at a time; the merged module is where bindings,
    # algorithms and object-API calls from different units can inline. The object
    # reaches the CPython link as machine code, so ThinLTO cannot do this later.
    builder = llvm.create_pass_builder(
        machine, llvm.create_pipeline_tuning_options(speed_level=2),
    )
    builder.getModulePassManager().run(compiled, builder)
    missing = undefined_exports(compiled, expected_exports) + undefined_exports(
        compiled, STATIC_TYPE_EXPORTS, "global",
    )
    if missing:
        raise RuntimeError("JacPython export contract is broken after optimization: " + ", ".join(missing))
    compiled.verify()
    object_bytes = machine.emit_object(compiled)
    (output / "jacpython.o").write_bytes(object_bytes)
    (output / "sha256").write_text(hashlib.sha256(object_bytes).hexdigest() + "\n")


    def lowered_sources():
        """Every source the object was lowered from, relative to the jac root: the
        plan's units, their annexes and their compile-time inputs. A dependency can
        only be added by editing one of these, so they key the object exactly. The
        generated modules are left out: they live in the build tree."""
        from jaclang.compiler.driver.jir import _related_files, _ct_dep_rows, _ct_row_path
        registry = program.native_units()
        paths = set()
        skipped = {os.path.realpath(path) for path in generated}
        for unit in plan.units:
            real = os.path.realpath(unit.path)
            if real in skipped:
                continue
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
