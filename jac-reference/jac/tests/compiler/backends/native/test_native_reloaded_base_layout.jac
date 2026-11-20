"""A consumer lays out an imported subclass from its defining module's layout.

`_register_imported_hierarchy` merges every imported module's layout registry
into the consumer's, and an importer's registry also carries the layouts it
took from its own imports. `adopt_imported_bases` then gives an imported
subclass its base's slots by rewriting the layout object the consumer holds,
and `_codegen_archetype` emits the struct from the layout the defining module
holds. The two are one object until the defining module's tree is laid out
again, which the link plan does whenever it reloads a unit to compile it: a
sibling importer lowered earlier still holds the old, already adopted layout.
The merge kept whichever copy arrived first, so a consumer that reached the
sibling before the defining module adopted the stale copy and emitted the
reloaded, unadopted one. Its struct lacked the base's slots, every write to
the subclass's own fields landed on the base's, and the unit was cached that
way for every later link. In a game this was `restore()` writing a pickup's
`active` flag over its position and then storing through a null `visual`.

The defining module's layout now replaces any copy that reached the consumer
first, so adoption and emission agree on one object.
"""

import os;
import from tests.support { TESTS_DIR, by_source_name, native_force_opts }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     LEVEL = os.path.join(FIXTURES, "reload_base_level.jac"),
     PICKUP = os.path.join(FIXTURES, "reload_base_pickup.jac"),
     SAVE = os.path.join(FIXTURES, "reload_base_save.jac"),
     SLOTS = [("pos", 2), ("yaw", 3), ("active", 4), ("respawn", 5), ("kind", 6)];

"""The module of `path` in `prog`, if its tree is loaded."""
def loaded(prog: JacProgram, path: str) -> (uni.Module | None) {
    for (key, mod) in prog.mod.hub.items() {
        if os.path.realpath(key) == os.path.realpath(path) {
            return mod;
        }
    }
    return None;
}

"""Lower the sibling importer, reload `Pickup`'s defining module the way the
link plan does before compiling it again, then lower the consumer."""
def compile_after_reload -> tuple[JacProgram, uni.Module, uni.Module] {
    prog = JacProgram();
    level = prog.compile(file_path=LEVEL, options=native_force_opts());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    for key in list(prog.mod.hub.keys()) {
        if os.path.realpath(key) == os.path.realpath(PICKUP) {
            del prog.mod.hub[key];
        }
    }
    save = prog.compile(file_path=SAVE, options=native_force_opts());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert save is not None and level is not None;
    return (prog, level, save);
}

test "the sibling importer still holds the layout from before the reload" {
    (prog, level, save) = compile_after_reload();
    pickup = loaded(prog, PICKUP);
    assert pickup is not None , "the consumer did not load Pickup's module";
    stale = by_source_name(get_layout_registry(level, prog).layouts).get("Pickup");
    fresh = by_source_name(get_layout_registry(pickup, prog).layouts).get("Pickup");
    assert stale is not None and fresh is not None;
    assert stale is not fresh , "the reload did not lay Pickup out again";
}

"""A layout's fields as (name, slot) pairs, in slot order."""
def slots_of(fields: list[any]) -> list[tuple[str, int]] {
    return [(str(fld.name), int(fld.index)) for fld in fields];
}

test "a consumer lays out a reloaded subclass with its base's slots" {
    (prog, level, save) = compile_after_reload();
    exported = save.gen.native_layout;
    assert exported is not None , "the consumer exported no native layout";
    structs = by_source_name(exported.structs);
    assert "Pickup" in structs , f"no Pickup struct in {list(structs)}";
    got = slots_of(structs["Pickup"].fields);
    assert got == SLOTS , f"consumer's Pickup slots {got}, defining module's {SLOTS}";
    pickup = loaded(prog, PICKUP);
    assert pickup is not None;
    defining = by_source_name(get_layout_registry(pickup, prog).layouts)["Pickup"];
    assert slots_of(defining.fields) == SLOTS;
}

"""The body of `Pickup`'s struct type in `mod`'s lowered IR."""
def pickup_struct(mod: uni.Module) -> str {
    for line in str(mod.gen.llvm_ir or "").split("\n") {
        if line.startswith('%"Pickup$') and " = type " in line {
            return line.split(" = type ", 1)[1].strip();
        }
    }
    return "";
}

test "the consumer emits the struct its sibling importer emits" {
    (prog, level, save) = compile_after_reload();
    sibling = pickup_struct(level);
    consumer = pickup_struct(save);
    assert sibling == "{i8**, i64, i64, double, i1, double, i8*}" , sibling;
    assert consumer == sibling , f"consumer {consumer} vs sibling {sibling}";
}
