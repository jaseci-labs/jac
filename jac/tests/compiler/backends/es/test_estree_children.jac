"""es_children lists every field of every ESTree node.

The free-identifier audit and es_node_to_dict walk a node through
es_children rather than through reflection, because the ES backend runs in
the native compiler kernel where `vars()` is not available. A field added to
an estree class without an es_children entry would be skipped silently, so
this compares the two for every class.
"""
import inspect;
import jaclang.compiler.backends.es.estree as es;
import from jaclang.runtime.object_interop { fields }

test "es_children names exactly the declared fields of every ESTree node" {
    checked = 0;
    for (name, cls) in inspect.getmembers(es, inspect.isclass) {
        if cls.__module__ != es.__name__
            or not issubclass(cls, es.Node)
            or cls in (es.Node, es.Expression, es.Statement) {
            continue;
        }
        declared = {f.name for f in fields(cls)} - {"type", "loc"};
        instance: any = cls.__new__(cls);
        for field_name in declared | {"type", "loc"} {
            setattr(instance, field_name, f"{name}.{field_name}");
        }
        children = es.es_children(instance);
        listed = set(children.keys());
        assert listed == declared , f"{name}: es_children lists {sorted(
            listed
        )}, the class declares {sorted(declared)}";
        for field_name in declared {
            assert children[field_name] == f"{name}.{field_name}" , (
                f"{name}.{field_name}: es_children reads something other than the field"
            );
        }
        checked += 1;
    }
    assert checked > 60 , checked;
}
