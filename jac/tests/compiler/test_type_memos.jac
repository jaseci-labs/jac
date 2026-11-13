"""The type evaluator's memos reuse what is stable and recompute what moved.

Specializing a generic member rebuilds the class's type-variable solution and
clones the member's function type; narrowing an expression re-derives its
reference key and flow node. Each is memoized, and each memo has a condition
under which it must not answer: changed type arguments, a solution dict the
caller builds itself, an active `and` narrowing override, a released check.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Name }
import from jaclang.compiler.types.types { CLASS_GRAPH_EPOCH, ClassType, FunctionType }
import from jaclang.compiler.types.type_utils {
    apply_solved_type_vars,
    build_type_var_solution,
    convert_to_instance,
    ensure_mro_fresh
}

glob VIRTUAL_PATH: str = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "_type_memo_probe.jac"
     ),
     SOURCE: str = (
         "obj Box[T] {\n"
         "    has item: T;\n"
         "\n"
         "    def get -> T {\n"
         "        return self.item;\n"
         "    }\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    b = Box[int](item=1);\n"
         "    x = b.get();\n"
         "}\n"
     );

def probe -> tuple[any, any, ClassType] {
    prog = JacProgram();
    mod = prog.compile(
        file_path=VIRTUAL_PATH, use_str=SOURCE, options=CompileOptions(no_cgen=True)
    );
    evaluator = prog.get_type_evaluator();
    box = evaluator.get_type_of_symbol(mod.names_in_scope["Box"]);
    assert isinstance(box, ClassType);
    return (mod, evaluator, box);
}

def instance_of(cls: (ClassType | None)) -> ClassType {
    assert cls is not None;
    inst = convert_to_instance(cls);
    assert isinstance(inst, ClassType);
    return inst;
}

test "a class's type-variable solution is reused until its type arguments change" {
    (_, evaluator, box) = probe();
    int_t = instance_of(evaluator.prefetch.int_class);
    str_t = instance_of(evaluator.prefetch.str_class);
    box_int = box.specialize_generics([int_t]);
    first = build_type_var_solution(box_int);
    assert box_int._tv_solution is first;
    assert build_type_var_solution(box_int) is first;
    assert first["T"] is int_t;
    box_int.private.type_args = [str_t];
    moved = build_type_var_solution(box_int);
    assert moved is not first;
    assert moved["T"] is str_t;
}

test "a specialized method is reused only for a cached solution" {
    (_, evaluator, box) = probe();
    int_t = instance_of(evaluator.prefetch.int_class);
    box_int = box.specialize_generics([int_t]);
    method = evaluator.get_type_of_symbol(
        box.shared.symbol_table.names_in_scope["get"]
    );
    assert isinstance(method, FunctionType);
    assert method.specialize(box_int) is method.specialize(box_int);
    solution = build_type_var_solution(box_int);
    assert apply_solved_type_vars(method, solution, box_int)
        is apply_solved_type_vars(method, solution, box_int);
    plain = {"T": int_t};
    assert apply_solved_type_vars(method, plain, box_int)
        is not apply_solved_type_vars(method, plain, box_int);
}

test "expression narrowing is memoized, bypassed under an override, and released" {
    (mod, evaluator, _) = probe();
    reads = [
        n
        for n in mod.get_all_sub_nodes(Name)
        if n.value == "b" and n.type is not None
    ];
    assert reads , "the probe has no typed read of b";
    read = reads[-1];
    declared = read.type;
    evaluator.release_check_caches();
    evaluator.get_narrowed_type_for_expr(read, declared, read);
    assert len(evaluator._narrow_expr_memo) == 1;
    evaluator.release_check_caches();
    assert not evaluator._narrow_expr_memo;
    evaluator._and_narrowing_overrides[0] = declared;
    try {
        evaluator.get_narrowed_type_for_expr(read, declared, read);
        assert not evaluator._narrow_expr_memo , "a narrowing under an override was memoized";
    } finally {
        evaluator._and_narrowing_overrides.clear();
    }
}

test "a class is re-verified after any base or MRO setter runs" {
    (_, _, box) = probe();
    ensure_mro_fresh(box);
    assert box.shared._fresh_epoch == CLASS_GRAPH_EPOCH[0];
    before = CLASS_GRAPH_EPOCH[0];
    box.shared.base_classes = list(box.shared.base_classes);
    assert CLASS_GRAPH_EPOCH[0] > before;
    ensure_mro_fresh(box);
    assert box.shared._fresh_epoch == CLASS_GRAPH_EPOCH[0];
}
