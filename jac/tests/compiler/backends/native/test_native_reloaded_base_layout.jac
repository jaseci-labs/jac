"""A consumer lays out an imported subclass from its defining module's layout.

The link plan lays a unit's tree out again whenever it reloads the unit to
compile it, so a sibling importer lowered earlier holds types that point into
the old, released tree. Under the old backend the consumer adopted the stale,
already adopted copy and emitted the reloaded, unadopted one: its struct
lacked the base's slots, and every write to the subclass's own fields landed
on the base's -- in a game, `restore()` writing a pickup's `active` flag over
its position and then storing through a null `visual`.

MIR lays an imported class out from its defining module. A class or function
reached through the released tree is taken from the reloaded module of the
same path, so the consumer lowers against the slots the defining module
holds and its stores land on the subclass's own fields.
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
    (prog, level, save, _) = compile_with_stale();
    return (prog, level, save);
}

"""`compile_after_reload`, also handing back Pickup's module from before the
reload."""
def compile_with_stale -> tuple[JacProgram, uni.Module, uni.Module, uni.Module] {
    prog = JacProgram();
    level = prog.compile(file_path=LEVEL, options=native_force_opts());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    stale_mod = loaded(prog, PICKUP);
    assert stale_mod is not None , "the sibling importer did not load Pickup's module";
    get_layout_registry(stale_mod, prog);
    for key in list(prog.mod.hub.keys()) {
        if os.path.realpath(key) == os.path.realpath(PICKUP) {
            del prog.mod.hub[key];
        }
    }
    save = prog.compile(file_path=SAVE, options=native_force_opts());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert save is not None and level is not None;
    return (prog, level, save, stale_mod);
}

test "the reload lays Pickup out again" {
    (prog, level, save, stale_mod) = compile_with_stale();
    pickup = loaded(prog, PICKUP);
    assert pickup is not None , "the consumer did not load Pickup's module";
    stale = by_source_name(get_layout_registry(stale_mod, prog).layouts).get("Pickup");
    fresh = by_source_name(get_layout_registry(pickup, prog).layouts).get("Pickup");
    assert stale is not None and fresh is not None;
    assert stale is not fresh , "the reload did not lay Pickup out again";
}

"""A layout's fields as (name, slot) pairs, in slot order."""
def slots_of(fields: list[any]) -> list[tuple[str, int]] {
    return [(str(fld.name), int(fld.index)) for fld in fields];
}

test "the reloaded defining module lays Pickup out with its base's slots" {
    (prog, level, save) = compile_after_reload();
    pickup = loaded(prog, PICKUP);
    assert pickup is not None , "the consumer did not load Pickup's module";
    defining = by_source_name(get_layout_registry(pickup, prog).layouts)["Pickup"];
    assert slots_of(defining.fields) == SLOTS , slots_of(defining.fields);
}

test "the consumer writes a reloaded subclass's own fields, not its base's" {
    # MIR lays an imported class out from its defining module, so the
    # consumer's stores land on Pickup's own slots: `deactivate` clears
    # `active` and sets `respawn`, and the base's `pos` and `yaw` survive.
    import ctypes;
    import from tests.support { get_func }
    (prog, level, save) = compile_after_reload();
    layout: any = save.gen.native_layout;
    assert "deactivate" in layout.functions , sorted(layout.functions);
    assert "deactivate_probe" in layout.functions , sorted(layout.functions);
    probe = get_func(save.gen.native_engine, "deactivate_probe", ctypes.c_int64);
    assert probe() == 7 * 10000 + 15 * 100 + 9 * 10 + 0 , probe();
}
