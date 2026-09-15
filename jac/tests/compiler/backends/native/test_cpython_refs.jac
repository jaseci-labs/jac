"""Typed foreign owners use CPython lifetimes and its exact stackref ABI."""

import ctypes;
import os;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from unittest { SkipTest }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.backends.native.llvm { binding as llvm }
import from tests.support { JAC_ROOT }
import from tests.compiler.backends.native.fixtures.cpython_refs {
    check_slice_helper,
    check_await_helper,
    check_anext_helper,
    check_except_type_helper,
    check_raise_helper
}

glob _boundary_state: dict[str, any] = {};

def cpython_source -> str {
    explicit = os.environ.get("JAC_CPYTHON_SOURCE");
    if explicit {
        assert (Path(explicit) / "pyconfig.h").is_file();
        return explicit;
    }
    for source in sorted((Path(JAC_ROOT) / ".python-build").glob("**/src/cpython")) {
        if (source / "pyconfig.h").is_file() {
            return str(source);
        }
    }
    raise SkipTest(
        "requires the pinned configured CPython source; set JAC_CPYTHON_SOURCE"
    );
    return "";
}

def boundary -> any {
    if "library" in _boundary_state {
        return _boundary_state["library"];
    }
    source = cpython_source();
    zig = shutil.which("zig");
    if zig is None {
        raise SkipTest("requires the pinned Zig compiler");
    }
    assert zig is not None;
    directory = tempfile.TemporaryDirectory();
    _boundary_state["directory"] = directory;
    path = os.path.join(directory.name, "refs.so");
    command = [
        zig,
        "cc",
        "-shared",
        "-fPIC",
        "-O2",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-I",
        source,
        "-isystem",
        os.path.join(source, "Include"),
        os.path.join(JAC_ROOT, "bootstrap", "python", "evaluator_refs.c"),
        "-o",
        path
    ];
    if sys.platform == "darwin" {
        command.extend(["-undefined", "dynamic_lookup"]);
    }
    result = subprocess.run(command, capture_output=True, text=True, timeout=120);
    assert result.returncode == 0 , result.stderr;
    library = ctypes.PyDLL(path, mode=ctypes.RTLD_GLOBAL);
    _boundary_state["library"] = library;
    for name in (
        "jacpy_eval_is_none",
        "jacpy_eval_index_check",
        "jacpy_as_ssize",
        "jacpy_eval_error_pending",
        "jacpy_type_error",
        "jacpy_ref_null",
        "jacpy_ref_is_null",
        "jacpy_coro_check",
        "jacpy_has_await",
        "jacpy_gen_yieldfrom",
        "jacpy_type_error_for_object",
        "jacpy_runtime_error",
        "jacpy_asyncgen_check",
        "jacpy_has_anext",
        "jacpy_anext_call",
        "jacpy_type_error_from_cause",
        "jacpy_ref_new",
        "jacpy_ref_close",
        "jacpy_stack_null",
        "jacpy_stack_new",
        "jacpy_stack_steal",
        "jacpy_stack_dup",
        "jacpy_stack_promote",
        "jacpy_stack_object_steal",
        "jacpy_stack_object_borrow",
        "jacpy_stack_close",
        "jacpy_stack_is_null",
        "jacpy_eval_tuple_check",
        "jacpy_eval_tuple_size",
        "jacpy_eval_tuple_item",
        "jacpy_eval_exception_class_check",
        "jacpy_eval_exception_group_subclass",
        "jacpy_eval_type_error",
        "jacpy_eval_topmost_exception",
        "jacpy_eval_exception_instance_check",
        "jacpy_eval_exception_type_new",
        "jacpy_eval_runtime_error",
        "jacpy_eval_bad_exception_result"
    ) {
        address = ctypes.cast(getattr(library, name), ctypes.c_void_p).value;
        assert address is not None;
        llvm.add_symbol(name, address);
    }
    return library;
}

test "native raise preserves operands causes and the handled exception" {
    boundary();
    source = (
        Path(JAC_ROOT) / "jaclang" / "runtime" / "python" / "evaluator_support.jac"
    ).read_text();
    module = compile_refs(source + "\ndef probe -> int { return 0; }\n", declarations=False);
    engine = module.gen.native_engine;
    assert engine is not None;
    address = engine.get_function_address("jacpy_eval_raise");
    assert address != 0;
    check_raise_helper(address);
}

test "native slice helpers preserve the pinned evaluator conversion and callback behavior" {
    library = boundary();
    for name in (
        "jacpy_eval_is_none",
        "jacpy_eval_index_check",
        "jacpy_as_ssize",
        "jacpy_eval_error_pending",
        "jacpy_type_error"
    ) {
        address = ctypes.cast(getattr(library, name), ctypes.c_void_p).value;
        assert address is not None;
        llvm.add_symbol(name, address);
    }
    source = (
        Path(JAC_ROOT) / "jaclang" / "runtime" / "python" / "evaluator_support.jac"
    ).read_text();
    module = compile_refs(source + "\ndef probe -> int { return 0; }\n", declarations=False);
    engine = module.gen.native_engine;
    assert engine is not None;
    for name in ("_PyEval_SliceIndex", "_PyEval_SliceIndexNotNone") {
        candidate_address = engine.get_function_address(name);
        assert candidate_address != 0;
        check_slice_helper(candidate_address, name);
        text = str(module.gen.llvm_ir);
        found = re.search(
            r"(?ms)^define [^\n]*@\"" + name + r"\"[^\n]*\n\{.*?^}", text
        );
        assert found is not None , text;
        assert "malloc" not in found.group() and "__jac_" not in found.group() , found.group();
        signature = found.group().splitlines()[0];
        assert "noalias" not in signature and "readonly" not in signature , signature;
    }
}

test "native async evaluator helpers preserve ownership and Python error causes" {
    boundary();
    source = (
        Path(JAC_ROOT) / "jaclang" / "runtime" / "python" / "evaluator_support.jac"
    ).read_text();
    module = compile_refs(source + "\ndef probe -> int { return 0; }\n", declarations=False);
    engine = module.gen.native_engine;
    assert engine is not None;
    await_address = engine.get_function_address("_PyEval_GetAwaitable");
    next_address = engine.get_function_address("_PyEval_GetANext");
    assert await_address != 0 and next_address != 0;
    check_await_helper(await_address);
    check_anext_helper(next_address);
    text = str(module.gen.llvm_ir);
    for name in ("_PyEval_GetAwaitable", "_PyEval_GetANext") {
        found = re.search(
            r"(?ms)^define [^\n]*@\"" + name + r"\"[^\n]*\n\{.*?^}", text
        );
        assert found is not None , text;
        assert "__jac_" not in found.group() and "malloc" not in found.group() , found.group();
    }
}

test "native exception type validation preserves pinned error precedence" {
    boundary();
    source = (
        Path(JAC_ROOT) / "jaclang" / "runtime" / "python" / "evaluator_support.jac"
    ).read_text();
    module = compile_refs(source + "\ndef probe -> int { return 0; }\n", declarations=False);
    engine = module.gen.native_engine;
    assert engine is not None;
    for name in ("_PyEval_CheckExceptTypeValid", "_PyEval_CheckExceptStarTypeValid") {
        address = engine.get_function_address(name);
        assert address != 0;
        check_except_type_helper(address, name);
        found = re.search(r"(?ms)^define [^\n]*@\"" + name + r"\"[^\n]*\n\{.*?^}", str(module.gen.llvm_ir));
        assert found is not None;
        assert "__jac_" not in found.group() and "malloc" not in found.group() , found.group();
    }
}

test "runtime reference declarations drive native cleanup and stack promotion" {
    source = (Path(JAC_ROOT) / "jaclang" / "runtime" / "python" / "references.jac").read_text();
    module = compile_refs(source +
        '\ndef probe(value: &PyObjectRef) -> i64 { owner: own PyObjectRef = jacpy_ref_new(value); '
        'stack: own PyStackRef = jacpy_stack_steal(owner); '
        'borrowed: &PyObjectRef from stack = jacpy_stack_object_borrow(&stack); '
        'return jacpy_ref_is_null(borrowed); } '
        'def promote(value: &PyStackRef) -> own PyStackRef { return jacpy_stack_promote(value); }', declarations=False);
    engine = module.gen.native_engine;
    assert engine is not None;
    probe = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(engine.get_function_address("probe"));
    value: list = [];
    references = sys.getrefcount(value);
    assert probe(id(value)) == 0;
    assert sys.getrefcount(value) == references;
    promote = ctypes.PYFUNCTYPE(ctypes.c_uint64, ctypes.c_uint64)(engine.get_function_address("promote"));
    stack = promote(id(value) | 1);
    assert stack == id(value);
    assert sys.getrefcount(value) == references + 1;
    library = boundary();
    close_address = ctypes.cast(library.jacpy_stack_close, ctypes.c_void_p).value;
    assert close_address is not None;
    close = ctypes.PYFUNCTYPE(None, ctypes.c_uint64)(close_address);
    close(stack);
    assert sys.getrefcount(value) == references;
    text = str(module.gen.llvm_ir);
    assert "JacForeign." in text and "foreign.drop.word" in text;
    assert "JacCPython." not in text;
}

test "trusted C primitives preserve an unrelated pending Jac exception" {
    module = compile_refs(
        'import from c { @foreign_call(requires=["gil"], errors="none", reentrant=False) def jacpy_ref_is_null(value: &PyObjectRef) -> i64; def PyList_Size(value: &PyObjectRef) -> i64; def jacpy_ref_null -> own PyObjectRef; } '
        "def probe(value: &PyObjectRef) -> int { if jacpy_ref_is_null(value) == 0 { return 7; } return 11; } "
        "def ordinary(value: &PyObjectRef) -> int { return PyList_Size(value); } "
        "def uncontracted -> own PyObjectRef { return jacpy_ref_null(); } "
        "def jacpy_ref_new(value: &PyObjectRef, n: int) -> int { return 1 // n; } "
        "def native_caller(value: &PyObjectRef, n: int) -> int { return jacpy_ref_new(value, n); }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    context_address = engine.get_function_address("__jac_exception_context");
    assert context_address != 0;
    get_context = ctypes.PYFUNCTYPE(ctypes.c_void_p)(context_address);
    context = get_context();
    assert context is not None;
    pending = ctypes.c_int32.from_address(context);
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [];
    try {
        pending.value = 37;
        assert run(id(value)) == 7 and pending.value == 37;
    } finally {
        pending.value = 0;
    }
    text = str(module.gen.llvm_ir);
    for name in ("ordinary", "native_caller", "uncontracted") {
        found = re.search(
            r"(?ms)^define [^\n]*@\"" + name + r"\"[^\n]*\n\{.*?^}", text
        );
        assert found is not None , text;
        assert "__jac_exception_context" in found.group() , found.group();
    }
}

glob REFERENCE_TYPES: str = "import from jaclang.runtime.python.references { PyObjectRef, PyStackRef, jacpy_ref_close, jacpy_stack_close } ";

def compile_refs(source: str, rejected: str = "", memory: str = "nogc", declarations: bool = True) -> Module {
    if declarations { source = REFERENCE_TYPES + source; }
    if not rejected {
        boundary();
    }
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "refs.jac");
        with open(path, "w") as stream {
            stream.write(source);
        }
        program = JacProgram();
        module = program.compile(
            path,
            options=CompileOptions(
                force_codespace="native",
                force_target_program=True,
                native_required=True,
                memory_profile=memory,
                no_ir_cache=True,
                skip_native_engine=bool(rejected),
                opt_level=0
            )
        );
        errors = "\n".join(str(error) for error in program.errors_had);
        if rejected {
            assert rejected in errors , errors;
        } else {
            assert not errors , errors;
            assert module is not None and module.gen.llvm_ir is not None;
            llvm.parse_assembly(str(module.gen.llvm_ir)).verify();
            assert module.gen.native_engine is not None;
            assert module.gen.native_engine.get_function_address("probe") != 0 , str(
                module.gen.llvm_ir
            );
        }
        assert module is not None;
        return module;
    }
}

glob DECLARATIONS: str = "import from jaclang.runtime.python.references { jacpy_ref_new, jacpy_stack_new, jacpy_stack_steal, jacpy_stack_object_steal, jacpy_stack_null, jacpy_stack_is_null, jacpy_stack_object_borrow } import from c { def PyList_Size(value: &PyObjectRef) -> i64; } ";

test "the pinned reference boundary preserves tags and finalizer reentrancy" {
    lib = boundary();
    result = subprocess.run(
        [
            sys.executable,
            "-I",
            "-S",
            os.path.join(
                JAC_ROOT,
                "tests",
                "compiler",
                "backends",
                "native",
                "fixtures",
                "cpython_refs.py"
            ),
            lib._name
        ],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert result.returncode == 0 , result.stdout + result.stderr;
    assert "reentrancy passed" in result.stdout;
}

test "foreign owners clean up without a Jac allocation or refcount" {
    module = compile_refs(
        DECLARATIONS
            + "def probe(value: &PyObjectRef) -> int { a: own PyObjectRef = jacpy_ref_new(value); b: own PyStackRef = jacpy_stack_new(&a); return PyList_Size(&a); }"
    );
    text = str(module.gen.llvm_ir);
    found = re.search(r"(?ms)^define [^\n]*@\"probe\"[^\n]*\n\{.*?^}", text);
    assert found is not None , text;
    body = found.group();
    assert "jacpy_ref_close" in body and "jacpy_stack_close" in body;
    assert "malloc" not in body and "__jac_rc" not in body;
    assert "noalias" not in body and "readonly" not in body;
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [1, 2, 3];
    before = sys.getrefcount(value);
    assert run(id(value)) == 3;
    assert sys.getrefcount(value) == before;
}

test "steals and native moves invalidate stack owners with the nonzero sentinel" {
    module = compile_refs(
        DECLARATIONS
            + "def probe(value: &PyObjectRef) -> int { a: own PyObjectRef = jacpy_ref_new(value); b: own PyStackRef = jacpy_stack_steal(a); c: own PyStackRef = b; d: own PyObjectRef = jacpy_stack_object_steal(c); return PyList_Size(&d); }"
    );
    text = str(module.gen.llvm_ir);
    assert "inttoptr (i64 1 to" in text , text;
    assert not re.search(r'store %"JacForeign.[^"\n]*PyStackRef[^"\n]*"\* null', text);
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [1, 2];
    before = sys.getrefcount(value);
    assert run(id(value)) == 2;
    assert sys.getrefcount(value) == before;
}

test "owned parameters close once and caller slots are consumed" {
    module = compile_refs(
        DECLARATIONS
            + "def consume(value: own PyStackRef) -> int { return 42; } def probe(value: &PyObjectRef) -> int { a: own PyStackRef = jacpy_stack_new(value); return consume(a); }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 42;
    assert sys.getrefcount(value) == before;
}

test "indirect handlers transfer foreign owners through a million tail calls" {
    module = compile_refs(
        DECLARATIONS
            + "obj Dispatch { has invoke: imm Callable[[own PyStackRef, int, &Dispatch], own PyStackRef]; } "
            + "def step(value: own PyStackRef, n: int, table: &Dispatch) -> own PyStackRef { if n == 0 { return value; } return __musttail(table.invoke(value, n - 1, table)); } "
            + "def probe(value: &PyObjectRef) -> int { table: own Dispatch = Dispatch(step); initial: own PyStackRef = jacpy_stack_new(value); result: own PyStackRef = step(initial, 1000000, &table); return jacpy_stack_is_null(&result); }"
    );
    text = str(module.gen.llvm_ir);
    assert "musttail call" in text , text;
    engine = module.gen.native_engine;
    assert engine is not None;
    address = engine.get_function_address("probe");
    assert address != 0;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(address);
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 0;
    assert sys.getrefcount(value) == before;
}

test "ordinary indirect handlers consume exactly one foreign owner on error" {
    module = compile_refs(
        DECLARATIONS
            + "obj Dispatch { has invoke: imm Callable[[own PyStackRef, int], int]; } "
            + "def divide(value: own PyStackRef, n: int) -> int { return 12 // n; } "
            + "def probe(value: &PyObjectRef) -> int { table: own Dispatch = Dispatch(divide); initial: own PyStackRef = jacpy_stack_new(value); try { return table.invoke(initial, 0); } except ZeroDivisionError { return 42; } }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    address = engine.get_function_address("probe");
    assert address != 0;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(address);
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 42;
    assert sys.getrefcount(value) == before;
}

test "foreign callable contracts cannot erase or change ownership" {
    for source in [
        "obj Dispatch { has invoke: imm Callable[[own PyStackRef], int]; } def target(value: &PyStackRef) -> int { return 0; } def probe -> int { table: own Dispatch = Dispatch(target); return 0; }",
        "obj Dispatch { has invoke: imm Callable[[&PyStackRef], int]; } def target(value: own PyStackRef) -> int { return 0; } def probe -> int { table: own Dispatch = Dispatch(target); return 0; }",
        "obj Dispatch { has invoke: imm Callable[[PyStackRef], int]; } def probe -> int { return 0; }",
        "obj Dispatch { has invoke: imm Callable[[&PyStackRef], &PyObjectRef]; } def probe -> int { return 0; }"
    ] {
        program = JacProgram();
        program.compile(
            file_path="foreign_callable_rejected.jac",
            use_str=REFERENCE_TYPES + source,
            options=CompileOptions(
                force_codespace="native",
                force_target_program=True,
                memory_profile="nogc",
                native_required=True,
                skip_native_engine=True
            )
        );
        assert program.errors_had , source;
    }
}

test "callable parameters transfer foreign owners through closure adapters" {
    module = compile_refs(
        DECLARATIONS
            + "def consume(value: own PyStackRef) -> int { return 42; } "
            + "def invoke(handler: imm Callable[[own PyStackRef], int], value: own PyStackRef) -> int { return handler(value); } "
            + "def probe(value: &PyObjectRef) -> int { initial: own PyStackRef = jacpy_stack_new(value); return invoke(consume, initial); }"
    );
    # Check the move before executing, since a missing move double-closes value.
    text = str(module.gen.llvm_ir);
    found = re.search(r"(?ms)^define [^\n]*@\"invoke\"[^\n]*\n\{.*?^}", text);
    assert found is not None , text;
    body = found.group();
    before_call = body.split('call i64 %"ccall.fn"')[0];
    writes = re.findall(r'(?m)^\s*store %"JacForeign.[^"\n]*PyStackRef[^"\n]*"\* (.*), %"JacForeign.[^"\n]*PyStackRef[^"\n]*"\*\* %"value\.1"$', before_call);
    assert writes and writes[-1].startswith("inttoptr (i64 1") , body;
    engine = module.gen.native_engine;
    assert engine is not None;
    address = engine.get_function_address("probe");
    assert address != 0;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(address);
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 42;
    assert sys.getrefcount(value) == before;
}

test "Jac exception unwinding releases foreign owners" {
    module = compile_refs(
        DECLARATIONS
            + "def divide(value: &PyObjectRef, n: int) -> int { a: own PyStackRef = jacpy_stack_new(value); return 12 // n; } def probe(value: &PyObjectRef) -> int { try { return divide(value, 0); } except ZeroDivisionError { return 42; } }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 42;
    assert sys.getrefcount(value) == before;
}

test "foreign references reject managed code and implicit aliasing" {
    compile_refs(
        DECLARATIONS + "def probe(value: &PyObjectRef) -> int { return 1; }",
        "native nogc ownership",
        memory="managed"
    );
    compile_refs(
        DECLARATIONS + "def probe(value: PyObjectRef) -> int { return 1; }",
        "has no ownership state"
    );
    compile_refs(
        DECLARATIONS + "def probe(value: imm PyObjectRef) -> int { return 1; }",
        "foreign resource parameters require"
    );
}

test "foreign resource functions cannot silently demote" {
    compile_refs(
        DECLARATIONS
            + "def probe(value: &PyObjectRef) -> int { import collections; a: own PyStackRef = jacpy_stack_new(value); return 1; }",
        "cannot be demoted"
    );
}

test "foreign owners retain their lexical finalizer timing" {
    events: list[str] = [];
    obj Payload {
        def __del__ {
            events.append("finalize");
        }
    }
    retain_type: any = ctypes.PYFUNCTYPE(None, ctypes.py_object);
    retain = retain_type(
        ctypes.cast(ctypes.pythonapi.Py_IncRef, ctypes.c_void_p).value
    );
    def produce -> int {
        value = Payload();
        retain(value);
        return id(value);
    }
    def observe(value: int) -> int {
        events.append("observe");
        return 0;
    }
    def checkpoint -> int {
        events.append("checkpoint");
        return 0;
    }
    producer = ctypes.PYFUNCTYPE(ctypes.c_void_p)(produce);
    observer = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(observe);
    marker = ctypes.PYFUNCTYPE(ctypes.c_int64)(checkpoint);
    for (name, callback) in [
        ("jacpy_test_produce", producer),
        ("jacpy_test_observe", observer),
        ("jacpy_test_checkpoint", marker)
    ] {
        address = ctypes.cast(callback, ctypes.c_void_p).value;
        assert address is not None;
        llvm.add_symbol(name, address);
    }
    module = compile_refs(
        "import from c { def jacpy_test_produce -> own PyObjectRef; def jacpy_test_observe(value: &PyObjectRef) -> int; def jacpy_test_checkpoint -> int; } def probe -> int { owner: own PyObjectRef = jacpy_test_produce(); jacpy_test_observe(&owner); jacpy_test_checkpoint(); return 42; }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64)(engine.get_function_address("probe"));
    assert run() == 42;
    assert events == ["observe", "checkpoint", "finalize"] , events;
}

test "null stack owners survive untaken branches and error return paths" {
    module = compile_refs(
        DECLARATIONS
            + "def fail(n: int) -> own PyStackRef { unused = 1 // n; return jacpy_stack_null(); } def probe(value: &PyObjectRef) -> int { if False { a: own PyStackRef = jacpy_stack_new(value); } try { b: own PyStackRef = fail(0); } except ZeroDivisionError { return 42; } return 0; }"
    );
    text = str(module.gen.llvm_ir);
    assert not re.search(r'(store|ret) %"JacForeign.[^"\n]*PyStackRef[^"\n]*"\* null', text) , text;
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 42;
    assert sys.getrefcount(value) == before;
}

test "foreign references reject unsafe representation and lifetime operations" {
    compile_refs(
        "def probe(value: &PyStackRef) -> int { if value { return 1; } return 0; }",
        "typed foreign ABI"
    );
    compile_refs(
        "def probe(value: &PyObjectRef) -> PyObjectRef { return value; }",
        "explicitly transfer ownership"
    );
    compile_refs(
        "obj Holder { has value: own PyStackRef; } def probe -> int { return 0; }",
        "foreign storage contract"
    );
    compile_refs(
        "def probe(value: own PyStackRef | None) -> int { return 0; }", "foreign resource"
    );
    compile_refs(
        "def probe -> int { value: own PyObjectRef = PyObjectRef(); return 0; }",
        "typed foreign ABI"
    );
}

test "debug and free threaded stack layouts are rejected at build time" {
    source = cpython_source();
    zig = shutil.which("zig");
    if zig is None {
        raise SkipTest("requires the pinned Zig compiler");
    }
    assert zig is not None;
    for flag in ("Py_DEBUG", "Py_STACKREF_DEBUG", "Py_GIL_DISABLED") {
        result = subprocess.run(
            [
                zig,
                "cc",
                "-fsyntax-only",
                "-D" + flag,
                "-I",
                source,
                "-isystem",
                os.path.join(source, "Include"),
                os.path.join(JAC_ROOT, "bootstrap", "python", "evaluator_refs.c")
            ],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode != 0
            and "require a non-debug GIL build" in result.stderr , result.stderr;
    }
}

test "a borrowed foreign owner cannot be consumed or moved into a second owner" {
    compile_refs(
        DECLARATIONS
            + "def probe(value: &PyObjectRef) -> int { a: own PyObjectRef = jacpy_ref_new(value); borrowed = &a; jacpy_ref_close(a); return PyList_Size(borrowed); }",
        "destroyed while still borrowed"
    );
    compile_refs(
        DECLARATIONS
            + "def probe(value: &PyObjectRef) -> int { a: own PyObjectRef = jacpy_ref_new(value); b: own PyStackRef = jacpy_stack_steal(a); return PyList_Size(&a); }",
        "after it was moved"
    );
}

test "tail dispatch preserves an owning CPython result without accumulating frames" {
    module = compile_refs(
        DECLARATIONS
            + "def left(value: &PyObjectRef, n: int) -> own PyStackRef { if n == 0 { return jacpy_stack_new(value); } return __musttail(right(value, n - 1)); } def right(value: &PyObjectRef, n: int) -> own PyStackRef { if n == 0 { return jacpy_stack_new(value); } return __musttail(left(value, n - 1)); } def probe(value: &PyObjectRef) -> int { owner: own PyStackRef = left(value, 1000000); return jacpy_stack_is_null(&owner); }"
    );
    text = str(module.gen.llvm_ir);
    assert text.count("musttail call") == 2 , text;
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
        engine.get_function_address("probe")
    );
    value = [];
    before = sys.getrefcount(value);
    assert run(id(value)) == 0;
    assert sys.getrefcount(value) == before;
}

test "foreign identity is nominal and nested containers cannot hide references" {
    compile_refs(
        "def probe(values: own list[list[PyStackRef]]) -> int { return 0; }",
        "foreign resources cannot be stored"
    );
    module = compile_refs(
        "obj PyObjectRef { has count: int; } def probe -> int { value: own PyObjectRef = PyObjectRef(7); return value.count; }", declarations=False
    );
    assert "JacForeign." not in str(module.gen.llvm_ir);
    engine = module.gen.native_engine;
    assert engine is not None;
    run = ctypes.PYFUNCTYPE(ctypes.c_int64)(engine.get_function_address("probe"));
    assert run() == 7;
}

test "a borrowed Python object remains tied to its stack owner" {
    declaration = "";
    for binding in ("borrowed", "borrowed: &PyObjectRef") {
        module = compile_refs(
            DECLARATIONS
                + declaration
                + "def probe(value: &PyObjectRef) -> int { owner: own PyStackRef = jacpy_stack_new(value); "
                + binding
                + " = jacpy_stack_object_borrow(&owner); return PyList_Size(borrowed); }"
        );
        engine = module.gen.native_engine;
        assert engine is not None;
        run = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_void_p)(
            engine.get_function_address("probe")
        );
        value = [1, 2, 3];
        before = sys.getrefcount(value);
        assert run(id(value)) == 3;
        assert sys.getrefcount(value) == before;
        compile_refs(
            DECLARATIONS
                + declaration
                + "def probe(value: &PyObjectRef) -> int { owner: own PyStackRef = jacpy_stack_new(value); "
                + binding
                + " = jacpy_stack_object_borrow(&owner); jacpy_stack_close(owner); return PyList_Size(borrowed); }",
            "destroyed while still borrowed"
        );
    }
    compile_refs(
        DECLARATIONS
            + declaration
            + "def probe(value: &PyObjectRef) -> int { owner: own PyStackRef = jacpy_stack_new(value); borrowed: own PyObjectRef = jacpy_stack_object_borrow(&owner); return PyList_Size(&borrowed); }",
        "view"
    );
    compile_refs(
        "import from c { def unknown(value: &PyObjectRef) -> &PyObjectRef; } def probe -> int { return 0; }",
        "explicitly transfer ownership"
    );
}

test "foreign resource classes cannot be inherited" {
    compile_refs("obj Child(PyObjectRef) {} def probe -> int { return 0; }", "sealed");
}
