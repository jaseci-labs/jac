"""A local read before it is assigned raises UnboundLocalError natively.

CPython raises `UnboundLocalError: cannot access local variable 'x' where it
is not associated with a value` when a read of a local runs before any
assignment to it. The native backend read the local's zeroed slot instead:
a scalar came back as 0, a reference as a null pointer, and when the read
came before the assignment in the source it did not lower at all and the
call it fed was handed a null default (a SIGTRAP or SIGSEGV, not an
exception). A read that may run before the local is assigned now checks a
per-local bound flag and raises the catchable error; the reads that follow
an assignment in the same or an enclosing block are not checked.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity, compile_native_ir, unit_symbol }
import from jaclang.compiler.backends.native.llvm { ir }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures",
     FIXTURE: str = "unbound_locals.jac",
     GUARDED: list[str] = [
         "total_of",
         "early_scalar",
         "picked",
         "named_len",
         "aug_first",
         "unpacked",
         "walrus_seen",
         "while_break",
         "carried",
         "as_name_error",
         "chained_index",
         "chained_unpack",
         "chained_late"
     ],
     EXPECTED: list[str] = [
         "3",
         "caught cannot access local variable 'extra' where it is not associated with a value",
         "caught cannot access local variable 'later' where it is not associated with a value",
         "caught cannot access local variable 'z' where it is not associated with a value",
         "5",
         "caught cannot access local variable 'x' where it is not associated with a value",
         "5",
         "caught cannot access local variable 's' where it is not associated with a value",
         "caught cannot access local variable 'total' where it is not associated with a value",
         "3",
         "caught cannot access local variable 'a' where it is not associated with a value",
         "3",
         "caught cannot access local variable 'n' where it is not associated with a value",
         "3",
         "caught cannot access local variable 'found' where it is not associated with a value",
         "[0, 1, 4]",
         "[0, 2, 4]",
         "[7]",
         "caught cannot access local variable 'v' where it is not associated with a value",
         "NameError: cannot access local variable 'w' where it is not associated with a value",
         "18",
         "4 9 9",
         "5",
         "2",
         "5",
         "caught cannot access local variable 'y' where it is not associated with a value"
     ];

"""The names of the bound flags `fn` keeps for its locals."""
def bound_flags(fn: ir.Function) -> list[str] {
    return [
        inst.name for blk in fn.blocks
        for inst in blk.instructions
        if isinstance(inst, ir.AllocaInstr) and inst.name.endswith(".bound")
    ];
}

test "a local read before its assignment raises UnboundLocalError natively" {
    out = assert_native_identity(str(FIXTURES / FIXTURE), profiles=["rc", "managed"]);
    assert out.splitlines() == EXPECTED , out;
}

test "the fixture lowers natively and only the unsettled reads keep a bound flag" {
    mod = compile_native_ir(FIXTURE);
    module = mod.gen.llvm_ir;
    for name in GUARDED {
        fn = module.globals.get(unit_symbol(mod, name));
        assert isinstance(fn, ir.Function) and fn.blocks , f"{name} did not lower natively";
        assert bound_flags(fn) , f"{name} reads a local that may be unbound without checking it";
    }
    for name in ["straight", "count", "summed", "raised"] {
        fn = module.globals.get(unit_symbol(mod, name));
        assert isinstance(fn, ir.Function) and fn.blocks , f"{name} did not lower natively";
        assert not bound_flags(fn) , f"{name} checks locals every path has assigned: {bound_flags(
            fn
        )}";
    }
}
