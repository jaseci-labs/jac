import ctypes;
import jaclang.compiler.frontend.unitree as uni;
import from tests.support { compile_native, get_func }

test "native field factories use ordinary calls and fresh values per instance" {
    (engine, _) = compile_native("native_field_factories.jac");
    probe = get_func(engine, "probe", ctypes.c_bool);
    assert probe();
    assert probe();
}

test "synthetic pipe calls preserve the source graph after lowering" {
    (engine, module) = compile_native("pipe_fwd.jac");
    chain = get_func(engine, "pipe_chain", ctypes.c_int64, ctypes.c_int64);
    spread = get_func(
        engine, "pipe_tuple", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert chain(5) == 7;
    assert spread(3, 4) == 7;
    for expr in module.get_all_sub_nodes(uni.BinaryExpr) {
        assert expr.left.parent is expr;
        assert expr.right.parent is expr;
    }
}
