"""Imported layouts are completed before their children adopt their slots."""

import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.compiler.passes.layout_pass {
    ArchetypeLayout,
    FieldInfo,
    LayoutRegistry,
    MethodSlot,
    adopt_imported_bases
}

test "overriding every imported method preserves the base slots" {
    (mod, failed) = parse("", "method_order.jac");
    assert not failed;
    reg = LayoutRegistry();
    mod.gen.layout_registry = reg;
    for (name, names) in [
        ("Base", ["first", "second"]),
        ("Child", ["second", "first"])
    ] {
        mro = ["Child", "Base"] if name == "Child" else ["Base"];
        methods = [
            MethodSlot(name=method, index=index, owner=name)
            for (index, method) in enumerate(names)
        ];
        reg.layouts[name] = ArchetypeLayout(
            name=name,
            arch_type="obj",
            parents=["Base"] if name == "Child" else [],
            mro=mro,
            has_vtable=True,
            vtable_ptr_slot=0,
            methods=methods,
            method_index={method: index for (index, method) in enumerate(names)}
        );
        reg.mro_order[name] = mro;
    }
    adopt_imported_bases(mod);
    child = reg.layouts["Child"];
    assert child.method_index == {"first": 0, "second": 1};
    assert [method.owner for method in child.methods] == ["Child", "Child"];
    assert reg.layouts["Base"].method_index == {"first": 0, "second": 1};
}

test "partial imported MROs still adopt fields in ancestor order" {
    (mod, failed) = parse("", "layout_order.jac");
    assert not failed;
    reg = LayoutRegistry();
    mod.gen.layout_registry = reg;
    for (name, parent, field) in [
        ("Leaf", "Middle", "leaf"),
        ("Middle", "Base", "middle"),
        ("Base", "", "base")
    ] {
        mro = [name, parent] if parent else [name];
        reg.layouts[name] = ArchetypeLayout(
            name=name,
            arch_type="obj",
            parents=[parent] if parent else [],
            mro=mro,
            fields=[FieldInfo(name=field, index=0, type_tag="int", owner=name)],
            field_index={field: 0}
        );
        reg.mro_order[name] = mro;
    }
    adopt_imported_bases(mod);
    assert reg.layouts["Leaf"].field_index == {"base": 0, "middle": 1, "leaf": 2};
    assert reg.layouts["Middle"].field_index == {"base": 0, "middle": 1};
}
