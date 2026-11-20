"""A unit's interface records parameter names as the source spells them.

The IR keeps names unique within a function by appending `.N`, and which
parameter gets the suffix depends on what was named first. That order is an
accident of lowering, so recording the IR name made a unit's interface digest
differ between two lowerings of the same source, and every consumer was
lowered again.
"""
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen_pass { _source_param_names }

test "uniquified IR parameter names are recorded by their source names" {
    module = ir.Module(name="probe");
    i64 = ir.IntType(64);
    func = ir.Function(module, ir.FunctionType(i64, [i64, i64]), name="f");
    func.args[0].name = "here";
    func.args[0].name = "here";
    func.args[1].name = "count";
    assert func.args[0].name != "here";
    assert _source_param_names(func) == ["here", "count"];
}
