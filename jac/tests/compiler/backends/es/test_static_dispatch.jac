"""The ES backend's static dispatch tables cover what they route to.

The unparser picks a gen method per node class and the primitive emitters are
reached through dispatch/dispatch_static rather than through getattr, because
the ES backend runs in the native compiler kernel. A node class without an
unparser arm, or an emit method missing from its interface's name lists,
would silently stop being generated, so these compare the tables with the
classes they route to.
"""
import inspect;
import jaclang.compiler.backends.es.estree as es;
import jaclang.compiler.backends.common.primitives as prim;
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

test "every primitive emitter interface names each of its emit methods" {
    checked = 0;
    for (name, cls) in inspect.getmembers(prim, inspect.isclass) {
        if cls.__module__ != prim.__name__
            or not issubclass(cls, prim.PrimitiveEmitter)
            or cls is prim.PrimitiveEmitter {
            continue;
        }
        instance: any = cls.__new__(cls);
        assert set(instance.method_names()) == emit_names(cls, 4) , name;
        assert set(instance.static_names()) == emit_names(cls, 3) , name;
        checked += 1;
    }
    assert checked == 12 , checked;
}

test "the ES builtin emitter names its own builtins too" {
    emitter = pes.ESBuiltinEmitter();
    expected = emit_names(pes.ESBuiltinEmitter, 3) - {"sized_cast"};
    named = set(emitter.static_names());
    assert named == expected , sorted(named ^ expected);
}
