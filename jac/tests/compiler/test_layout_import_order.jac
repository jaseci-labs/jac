"""Imported layouts are completed before their children adopt their slots."""

import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.compiler.passes.layout_pass {
    ArchetypeLayout,
    FieldInfo,
    LayoutRegistry,
    adopt_imported_bases
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
