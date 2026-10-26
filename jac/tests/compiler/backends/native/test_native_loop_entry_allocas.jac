"""Builtins that need a stack slot take it from the function's entry block.

`float(s)` and `int(s)` hand the C parser the address of an end pointer,
`rpartition` keeps its scan cursor in memory, the set relations and copies
count through a slot, and a parallel `flow for` sizes its thread tables by
the thread count. A slot reserved where the call is lowered is a fresh one
every time a loop runs the call, given back only when the function returns,
so a long enough loop overflows the stack (it was a SIGSEGV on the guard
page inside `strtod`). The fixed-size slots belong in the entry block; the
thread tables, whose size is only known at run time, are given back after
the join.
"""

import os;
import resource;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native_ir, native_build, unit_symbol }
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures",
     FIXTURE: str = "loop_entry_allocas.jac",
     LOOPED: list[str] = ["floats", "ints", "tails", "set_checks", "fanned"],
     EXPECTED: list[str] = ["375000.0", "700000", "500000", "1000000", "90000"];

"""Whether `inst` reserves a slot whose size is known at compile time."""
def is_fixed_alloca(inst: ir.NamedValue) -> bool {
    return isinstance(inst, ir.AllocaInstr)
        and (not inst.operands or isinstance(inst.operands[0], ir.Constant));
}

"""The fixed-size allocas of `fn` outside its entry block."""
def misplaced_allocas(fn: ir.Function) -> list[str] {
    head = fn.entry_basic_block;
    found: list[str] = [];
    for blk in fn.blocks {
        if blk is head {
            continue;
        }
        for inst in blk.instructions {
            if is_fixed_alloca(inst) {
                found.append(f"{blk.name}: {str(inst).strip()}");
            }
        }
    }
    return found;
}

"""How many times `fn` calls the function named `callee`."""
def calls_to(fn: ir.Function, callee: str) -> int {
    count = 0;
    for blk in fn.blocks {
        for inst in blk.instructions {
            if isinstance(inst, ir.CallInstr)
                and getattr(inst.callee, "name", "") == callee {
                count += 1;
            }
        }
    }
    return count;
}

"""The allocas of `fn` whose size is only known at run time."""
def sized_allocas(fn: ir.Function) -> list[ir.NamedValue] {
    return [
        inst for blk in fn.blocks
        for inst in blk.instructions
        if isinstance(inst, ir.AllocaInstr) and not is_fixed_alloca(inst)
    ];
}

test "builtins called in a loop take their stack slots from the entry block" {
    # `rc` so the `flow for` fans out over threads
    mod = compile_native_ir(
        FIXTURE, options=CompileOptions(force_codespace="native", na_gc_mode="rc")
    );
    module = mod.gen.llvm_ir;
    for name in LOOPED {
        fn = module.globals.get(unit_symbol(mod, name));
        assert isinstance(fn, ir.Function) , f"{name} not found in the IR";
        bad = misplaced_allocas(fn);
        assert not bad , f"{name} reserves stack outside its entry block:\n"
            + "\n".join(bad);
    }
    # the thread tables are sized at run time, so they stay where they are and
    # are given back once the join is done
    fanned = module.globals.get(unit_symbol(mod, "fanned"));
    assert isinstance(fanned, ir.Function);
    assert calls_to(fanned, "pthread_create") , "the flow for did not fan out";
    assert sized_allocas(fanned) , "no thread tables in the fanned-out flow for";
    assert calls_to(fanned, "llvm.stacksave") == 1 , "the thread tables are not bracketed by a stack save";
    assert calls_to(fanned, "llvm.stackrestore") == 1 , "the thread tables are not given back after the join";
}

test "a long loop of them runs in a one-megabyte stack" {
    def small_stack {
        (_soft, hard) = resource.getrlimit(resource.RLIMIT_STACK);
        resource.setrlimit(resource.RLIMIT_STACK, (1024 * 1024, hard));
    }
    with tempfile.TemporaryDirectory() as scratch {
        binary = os.path.join(scratch, "loop_entry_allocas");
        native_build(str(FIXTURES / FIXTURE), binary, memory="rc");
        proc = subprocess.run(
            [binary],
            capture_output=True,
            text=True,
            timeout=120,
            preexec_fn=small_stack
        );
        assert proc.returncode == 0 , f"exit {proc.returncode} (a stack overflow is -11) {proc.stderr[-400:]}";
        assert proc.stdout.splitlines() == EXPECTED , proc.stdout;
    }
}
