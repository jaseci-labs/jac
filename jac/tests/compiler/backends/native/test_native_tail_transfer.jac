"""Required tail transfers preserve errors and reject lost cleanup or ABI work."""

import ctypes;
import os;
import re;
import subprocess;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.unitree { Module, FuncCall }
import from jaclang.compiler.frontend.diagnostics { E1315, E5092, E5095, E5109 }
import from jaclang.compiler.backends.native.llvm { binding as llvm }
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
import from jaclang.compiler.passes.transform { PassResult }
import from tests.support { get_func, native_build }

def compile_tail(
    source: str, rejected: str = "", dependencies: dict[str, str] | None = None
) -> Module {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "tail.jac");
        with open(path, "w") as stream {
            stream.write(source);
        }
        for (name, contents) in (dependencies or {}).items() {
            with open(os.path.join(tmp, name), "w") as stream {
                stream.write(contents);
            }
        }
        program = JacProgram();
        module = program.compile(
            path,
            options=CompileOptions(
                force_codespace="native",
                force_target_program=True,
                memory_profile="nogc",
                no_ir_cache=True,
                skip_native_engine=bool(rejected),
                opt_level=0
            )
        );
        errors = "\n".join(str(error) for error in program.errors_had);
        if rejected {
            assert any(error.code in (E5095, E5109) for error in program.errors_had)
                and rejected in errors , errors;
        } else {
            assert not errors , errors;
            assert module is not None and module.gen.llvm_ir is not None;
            llvm.parse_assembly(str(module.gen.llvm_ir)).verify();
        }
        assert module is not None;
        return module;
    }
}

test "mutual tail transfers verify and execute without optimization" {
    module = compile_tail(
        "def even(n: int) -> int { if n == 0 { return 42; } "
        "return __musttail(odd(n - 1)); } "
        "def odd(n: int) -> int { if n == 0 { return 43; } "
        "return __musttail(even(n - 1)); }"
    );
    assert str(module.gen.llvm_ir).count("musttail call") == 2;
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "even", ctypes.c_int64, ctypes.c_int64);
    assert run(1000000) == 42;
    assert run(1000001) == 43;
}

test "checked arithmetic errors survive a tail transfer and outer finally" {
    module = compile_tail(
        "def divide(n: int) -> int { return 12 // n; } "
        "def forward(n: int) -> int { return __musttail(divide(n)); } "
        "def probe(n: int) -> int { result = 0; try { result = forward(n); } "
        "except ZeroDivisionError { result = 40; } finally { result += 2; } "
        "return result; }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(0) == 42;
    assert run(3) == 6;
}

test "indirect handler transitions preserve the same tail guarantee" {
    module = compile_tail(
        "obj Dispatch { has even: imm Callable[[int, &Dispatch], int], "
        "odd: imm Callable[[int, &Dispatch], int]; } "
        "def even(n: int, state: &Dispatch) -> int { if n == 0 { return 42; } "
        "return __musttail(state.odd(n - 1, state)); } "
        "def odd(n: int, state: &Dispatch) -> int { if n == 0 { return 43; } "
        "return __musttail(state.even(n - 1, state)); } "
        "def probe(n: int) -> int { state: own Dispatch = Dispatch(even, odd); "
        "return even(n, &state); }"
    );
    text = str(module.gen.llvm_ir);
    transfers = [
        line
        for line in text.splitlines()
        if "musttail call" in line
    ];
    assert len(transfers) == 2;
    assert all("musttail call i64 %" in line for line in transfers);
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(1000000) == 42;
}

test "an ordinary indirect caller checks a tail callee's error slot" {
    module = compile_tail(
        "def divide(n: int) -> int { return 12 // n; } "
        "def forward(n: int) -> int { return __musttail(divide(n)); } "
        "def probe(n: int) -> int { fn: imm Callable[[int], int] = forward; try { return fn(n); } "
        "except ZeroDivisionError { return 42; } }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(0) == 42;
    assert run(3) == 4;
}

test "function pointer fields forward errors through tail dispatch" {
    module = compile_tail(
        "obj Dispatch { has invoke: imm Callable[[int, &Dispatch], int]; } "
        "def divide(n: int, state: &Dispatch) -> int { return 12 // n; } "
        "def forward(n: int, state: &Dispatch) -> int { return __musttail(state.invoke(n, state)); } "
        "def probe(n: int) -> int { state: own Dispatch = Dispatch(divide); "
        "try { return forward(n, &state); } except ZeroDivisionError { return 42; } }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(0) == 42;
    assert run(3) == 4;
}

test "a closure environment cannot be dropped to match a tail signature" {
    compile_tail(
        "def target(n: int) -> int { return n; } "
        "def probe(n: int) -> int { handler: imm Callable[[int], int] = target; "
        "return __musttail(handler(n)); }",
        "identical fixed argument and return layouts"
    );
}

test "a stored borrow still makes a record a view" {
    program = JacProgram();
    program.compile(
        file_path="borrow_record.jac",
        use_str="obj Item { has n: int; } obj View { has item: &Item; } "
        "def probe(n: int) -> int { item: own Item = Item(n); "
        "view: own View = View(&item); return view.item.n; }",
        options=CompileOptions(
            force_codespace="native",
            force_target_program=True,
            memory_profile="nogc",
            no_cgen=True
        )
    );
    assert any(error.code is E1315 for error in program.errors_had);
}

test "a closure cannot be stored as a bare handler address" {
    program = JacProgram();
    program.compile(
        file_path="closure_record.jac",
        use_str="obj Callback { has invoke: imm Callable[[int], int]; } "
        "def target(n: int) -> int { return n; } "
        "def probe(n: int) -> int { alias: imm Callable[[int], int] = target; "
        "record: own Callback = Callback(alias); return record.invoke(n); }",
        options=CompileOptions(
            force_codespace="native",
            force_target_program=True,
            memory_profile="nogc",
            native_required=True,
            skip_native_engine=True
        )
    );
    assert any(error.code is E5092 for error in program.errors_had) , "\n".join(
        str(error) for error in program.errors_had
    );
}

test "tail transfers emit native jumps on ARM64 and x86-64" {
    module = compile_tail(
        "def first(n: int) -> int { return __musttail(second(n)); } "
        "def second(n: int) -> int { if n == 0 { return 42; } "
        "return __musttail(first(n - 1)); }"
    );
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    for triple in ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"] {
        machine = llvm.Target.from_triple(triple).create_target_machine(
            opt=0, reloc="pic", codemodel="small"
        );
        compiled = llvm.parse_assembly(str(module.gen.llvm_ir));
        compiled.triple = triple;
        compiled.data_layout = str(machine.target_data);
        compiled.verify();
        assembly = machine.emit_assembly(compiled);
        assert isinstance(assembly, str);
        assert machine.emit_object(compiled);
        lines = [line.strip() for line in assembly.splitlines()];
        if triple.startswith("x86_64") {
            assert any(
                line.startswith("jmp") and "second" in line for line in lines
            ) , assembly;
            assert not any(
                line.startswith("call") and "second" in line for line in lines
            ) , assembly;
        } else {
            assert any(
                line.startswith("b\t") and "second" in line for line in lines
            ) , assembly;
            assert not any(
                line.startswith("bl\t") and "second" in line for line in lines
            ) , assembly;
        }
    }
}

test "many indirect transitions execute with a small native stack" {
    with tempfile.TemporaryDirectory() as tmp {
        source = os.path.join(tmp, "dispatch.jac");
        binary = os.path.join(tmp, "dispatch");
        with open(source, "w") as stream {
            stream.write(
                "obj Dispatch { has first: imm Callable[[int, &Dispatch], int], "
                "second: imm Callable[[int, &Dispatch], int]; } "
                "def first(n: int, state: &Dispatch) -> int { if n == 0 { return 42; } "
                "return __musttail(state.second(n - 1, state)); } "
                "def second(n: int, state: &Dispatch) -> int { return __musttail(state.first(n, state)); } "
                "def probe(n: int) -> int { state: own Dispatch = Dispatch(first, second); "
                "return first(n, &state); } with entry { print(probe(2000000)); }"
            );
        }
        with open(os.path.join(tmp, "jac.toml"), "w") as config {
            config.write("[native]\nopt = 0\n");
        }
        native_build(source, binary, memory="nogc");
        result = subprocess.run(
            ["sh", "-c", "ulimit -s 128 && exec \"$1\"", "tail-test", binary],
            capture_output=True,
            text=True,
            timeout=30
        );
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "42";
    }
}

test "indirect tail transfers emit register jumps on both native targets" {
    module = compile_tail(
        "obj Dispatch { has invoke: imm Callable[[&Dispatch, int], int]; } "
        "def transfer(state: &Dispatch, n: int) -> int { "
        "return __musttail(state.invoke(state, n)); }"
    );
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    for triple in ["x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu"] {
        machine = llvm.Target.from_triple(triple).create_target_machine(
            opt=0, reloc="pic", codemodel="small"
        );
        compiled = llvm.parse_assembly(str(module.gen.llvm_ir));
        compiled.triple = triple;
        compiled.data_layout = str(machine.target_data);
        compiled.verify();
        assembly = machine.emit_assembly(compiled);
        assert machine.emit_object(compiled);
        assert isinstance(assembly, str);
        body = re.search(r"(?ms)^transfer:.*?^\.Lfunc_end\d+:", assembly);
        assert body is not None , assembly;
        instructions = [line.strip() for line in body.group(0).splitlines()];
        if triple.startswith("x86_64") {
            assert any(
                line.startswith("jmp") and "*" in line for line in instructions
            ) , body.group(0);
            assert not any(line.startswith("call") for line in instructions) , body.group(
                0
            );
        } else {
            assert any(line.startswith("br\t") for line in instructions) , body.group(
                0
            );
            assert not any(
                line.startswith(("bl\t", "blr\t")) for line in instructions
            ) , body.group(0);
        }
    }
}

test "argument errors are checked before a tail transfer" {
    module = compile_tail(
        "def divide(n: int) -> int { return 12 // n; } "
        "def target(n: int) -> int { return 7; } "
        "def forward(n: int) -> int { return __musttail(target(divide(n))); } "
        "def probe(n: int) -> int { try { return forward(n); } "
        "except ZeroDivisionError { return 42; } }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(0) == 42;
    assert run(3) == 7;
}

test "a requested tail transfer refuses incompatible signatures" {
    compile_tail(
        "def target(n: int, m: int) -> int { return n + m; } "
        "def probe(n: int) -> int { return __musttail(target(n, 1)); }",
        "identical fixed argument and return layouts"
    );
    compile_tail(
        "def target(n: int) -> i32 { return i32(n); } "
        "def probe(n: int) -> int { return __musttail(target(n)); }",
        "identical fixed argument and return layouts"
    );
}

test "tail transfers keep their ABI and error protocol across modules" {
    module = compile_tail(
        "import from dependency { divide } "
        "def forward(n: int) -> int { return __musttail(divide(n)); } "
        "def probe(n: int) -> int { try { return forward(n); } "
        "except ZeroDivisionError { return 42; } }",
        dependencies={"dependency.jac": "def divide(n: int) -> int { return 12 // n; }"}
    );
    assert "musttail call" in str(module.gen.llvm_ir);
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(0) == 42;
    assert run(3) == 4;
}

test "a borrowed parameter can survive its forwarding native frame" {
    module = compile_tail(
        "obj Item { has n: int; } "
        "def target(item: &Item) -> int { return item.n; } "
        "def forward(item: &Item) -> int { return __musttail(target(item)); } "
        "def probe(n: int) -> int { item: own Item = Item(n); return forward(&item); }"
    );
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(42) == 42;
}

test "an owned local cannot be borrowed across a tail transfer" {
    compile_tail(
        "obj Item { has n: int; } "
        "def target(item: &Item) -> int { return item.n; } "
        "def probe(item: &Item) -> int { local: own Item = Item(7); "
        "return __musttail(target(&local)); }",
        "pending cleanup"
    );
}

test "a foreign ABI is refused even when its scalar signature matches" {
    compile_tail(
        "import from c { def labs(n: int) -> int; } "
        "def probe(n: int) -> int { return __musttail(labs(n)); }",
        "foreign call"
    );
}

test "void tail transfers return immediately with the same ABI" {
    module = compile_tail(
        "glob answer: int = 0; "
        "def target(n: int) -> None { answer = n; } "
        "def forward(n: int) -> None { return __musttail(target(n)); } "
        "def probe(n: int) -> int { forward(n); return answer; }"
    );
    assert "musttail call void" in str(module.gen.llvm_ir);
    engine = module.gen.native_engine;
    assert engine is not None;
    run = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert run(42) == 42;
}

test "active handlers and finalizers cannot be discarded for musttail" {
    for body in [
        "try { return __musttail(target(n)); } except Exception { return 1; }",
        "try { return __musttail(target(n)); } finally { print(1); }",
        "try { raise ValueError(); } except ValueError { return __musttail(target(n)); }"
    ] {
        compile_tail(
            "def target(n: int) -> int { return n; } def probe(n: int) -> int { "
                + body
                + " }",
            "active exception handler or finalizer"
        );
    }
}

test "owned locals and parameters retain their pending cleanup obligation" {
    compile_tail(
        "obj Item { has n: int; def drop { print(self.n); } } "
        "def target(n: int) -> int { return n; } "
        "def probe(n: int) -> int { item: own Item = Item(n); "
        "return __musttail(target(n)); }",
        "pending cleanup"
    );
    compile_tail(
        "obj Item { has n: int; def drop { print(self.n); } } "
        "def target(item: &Item) -> int { return item.n; } "
        "def probe(item: own Item) -> int { return __musttail(target(&item)); }",
        "pending cleanup"
    );
}

test "a context manager cannot lose its exit hook at a tail transfer" {
    compile_tail(
        "obj Guard { def __enter__() -> int { return 1; } "
        "def __exit__(a: int, b: int, c: int) -> bool { return False; } } "
        "def target(n: int) -> int { return n; } "
        "def probe(n: int) -> int { guard: own Guard = Guard(); "
        "with guard { return __musttail(target(n)); } return 0; }",
        "active context manager"
    );
}

test "musttail rejects ordinary expression use and non-call operands" {
    compile_tail(
        "def probe(n: int) -> int { return __musttail(n); }",
        "operand must be a function call"
    );
    compile_tail(
        "def target(n: int) -> int { return n; } "
        "def probe(n: int) -> int { x = __musttail(target(n)); return x; }",
        "complete expression of a return statement"
    );
}

test "a required tail transfer cannot compile to a non-native backend" {
    for backend in ["server", "client"] {
        program = JacProgram();
        program.compile(
            file_path="non_native_tail.jac",
            use_str="def target(n: int) -> int { return n; } "
            "def probe(n: int) -> int { return __musttail(target(n)); }",
            options=CompileOptions(
                force_codespace=backend, force_target_program=True, no_ir_cache=True
            )
        );
        assert any(error.code is E5109 for error in program.errors_had) , "\n".join(
            str(error) for error in program.errors_had
        );
    }
}

test "early and late lowering failures cannot demote a required tail transfer" {
    for body in [
        "import from collections { OrderedDict } d = OrderedDict(); ",
        "bad = __float_bits('not a float'); "
    ] {
        compile_tail(
            "def target(n: int) -> int { return n; } def probe(n: int) -> int { "
                + body
                + "return __musttail(target(n)); }",
            "cannot be demoted to Python"
        );
    }
    compile_tail(
        "obj Handler { static def target(n: int) -> int { return n; } "
        "static def probe(n: int) -> int { import from collections { OrderedDict } "
        "d = OrderedDict(); return __musttail(Handler.target(n)); } }",
        "cannot be demoted to Python"
    );
}

test "frame addresses hidden in integers or phi nodes cannot cross a tail transfer" {
    for mode in ["local", "integer", "phi"] {
        program = JacProgram();
        module = program.compile(
            file_path="tail_frame.jac",
            use_str="def target(n: int) -> int { return n; } "
            "def probe(n: int) -> int { return target(n); }",
            options=CompileOptions(no_cgen=True, force_target_program=True)
        );
        assert isinstance(module, Module);
        assert not program.errors_had;
        lowering = NaIRGenPass(ir_in=module, prog=program, completed=PassResult());
        native = ir.Module(name="frame");
        scalar = ir.IntType(64);
        signature = ir.FunctionType(scalar, [scalar]);
        caller = ir.Function(native, signature, name="caller");
        callee = ir.Function(native, signature, name="callee");
        entry_block = caller.append_basic_block("entry");
        builder = ir.IRBuilder(entry_block);
        slot = builder.alloca(scalar);
        builder.store(caller.args[0], slot);
        address: ir.Value = slot;
        if mode == "phi" {
            dispatch = caller.append_basic_block("dispatch");
            builder.branch(dispatch);
            builder.position_at_end(dispatch);
            merged = builder.phi(slot.type);
            merged.add_incoming(slot, entry_block);
            address = merged;
        }
        argument = builder.load(slot)
            if mode == "local"
            else builder.ptrtoint(address, scalar);
        transfer = builder.call(callee, [argument], tail="musttail");
        builder.ret(transfer);
        llvm.parse_assembly(str(native)).verify();
        lowering._tail_transfers[caller] = module.get_all_sub_nodes(FuncCall)[0];
        lowering._validate_tail_frame(caller);
        assert any(error.code is E5109 for error in lowering.errors_had)
            == (mode != "local");
    }
}
