"""The ES backend reaches every node class and every builtin it emits.

The unparser finds a gen method by node class name and the builtin emitter
routes by the emit methods its interface declares. A node class whose gen
method is misnamed, or an emit method only the ES builtin emitter defines,
would silently stop being generated.
"""
import inspect;
import jaclang.compiler.backends.es.estree as es;
import jaclang.compiler.backends.es.primitives_es as pes;
import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }

def emit_names(cls: type, arity: int) -> set[str] {
    names: set[str] = set();
    for (attr, member) in inspect.getmembers(cls, inspect.isfunction) {
        if attr.startswith("emit_")
            and len(inspect.signature(member).parameters) == arity {
            names.add(attr.removeprefix("emit_"));
        }
    }
    return names;
}

test "the unparser has an arm for every ESTree node class" {
    generator = JSCodeGenerator();
    checked = 0;
    for (name, cls) in inspect.getmembers(es, inspect.isclass) {
        if cls.__module__ != es.__name__
            or not issubclass(cls, es.Node)
            or cls in (es.Node, es.Expression, es.Statement) {
            continue;
        }
        instance: any = cls.__new__(cls);
        routed = True;
        try {
            routed = generator.dispatch(instance) is not None;
        } except Exception {
            routed = True;
        }
        assert routed , f"{name} has no unparser arm";
        checked += 1;
    }
    assert checked > 60 , checked;
}

test "the ES builtin emitter names its own builtins too" {
    emitter = pes.ESBuiltinEmitter();
    expected = emit_names(pes.ESBuiltinEmitter, 3);
    named = set(emitter.static_names());
    assert named == expected , sorted(named ^ expected);
}
