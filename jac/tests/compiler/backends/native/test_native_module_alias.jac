"""Native module aliases retain their source module binding."""
import ctypes;
import re;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_mir, compile_native, get_func }

test "private helpers in modules with the same basename remain distinct" {
    (engine, _) = compile_native("native_private_same_basename.jac");
    demoted = compile_mir("native_private_same_basename.jac").demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "private_modules_probe", ctypes.c_int64);
    assert probe() == 31;
}

test "an imported module's private global does not shadow an imported public one" {
    (engine, fx) = compile_native("native_private_glob_import.jac");
    demoted = compile_mir("native_private_glob_import.jac").demoted();
    assert not demoted , str(demoted);
    ir = fx.llvm_ir();
    # The public global keeps its bare symbol; a unit-qualified @X_VALUE here is
    # private_glob_hidden's internal one, which the importer can never link.
    # Local names such as %"glob.X_VALUE" (a load of the public one) don't count.
    leaked = [
        ln
        for ln in ir.splitlines()
        if re.search(r'@"[^"]+\.X_VALUE"', ln)
    ];
    assert not leaked , "\n".join(leaked);
    probe = get_func(engine, "private_glob_probe", ctypes.c_int64);
    assert probe() == 21;
}

test "module aliases resolve native functions and globals" {
    (engine, _) = compile_native("native_module_alias.jac");
    demoted = compile_mir("native_module_alias.jac").demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "module_alias_probe", ctypes.c_int64);
    assert probe() == 52;
}

test "a class-form archetype is constructed through a module alias" {
    (engine, _) = compile_native("module_class_ctor.jac");
    demoted = compile_mir("module_class_ctor.jac").demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "module_class_ctor_probe", ctypes.c_int64);
    assert probe() == 16 + 32 + 1 + 8;
}

test "module aliases preserve lexical shadowing and standard library dispatch" {
    (engine, _) = compile_native("native_module_alias.jac");
    demoted = compile_mir("native_module_alias.jac").demoted();
    assert not demoted , str(demoted);
    shadowed = get_func(engine, "module_alias_shadow_probe", ctypes.c_int64);
    standard = get_func(engine, "standard_module_alias_probe", ctypes.c_int64);
    assert shadowed() == 9;
    assert standard() == 13;
}

test "dotted native module references preserve module identity" {
    (engine, _) = compile_native("native_dotted_module_alias.jac");
    demoted = compile_mir("native_dotted_module_alias.jac").demoted();
    assert not demoted , str(demoted);
    aliased = get_func(engine, "dotted_alias_probe", ctypes.c_int64);
    dotted = get_func(engine, "dotted_module_probe", ctypes.c_int64);
    assert aliased() == 25;
    assert dotted() == 7;
}

test "module aliases resolve bundled native library implementations" {
    (engine, _) = compile_native("native_stdlib_module_alias.jac");
    demoted = compile_mir("native_stdlib_module_alias.jac").demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "standard_library_module_alias_probe", ctypes.c_bool);
    assert probe();
    mixed_path = get_func(engine, "mixed_path_dispatch_probe", ctypes.c_bool);
    assert mixed_path();
}

test "qualified module members do not resolve a same-named local callable" {
    (engine, _) = compile_native("native_module_alias.jac");
    demoted = compile_mir("native_module_alias.jac").demoted();
    assert not demoted , str(demoted);
    probe = get_func(engine, "module_member_shadow_probe", ctypes.c_int64);
    assert probe() == 140;
}

test "module dispatch respects the binding rather than the source module spelling" {
    (engine, _) = compile_native("native_module_alias_shadowing.jac");
    demoted = compile_mir("native_module_alias_shadowing.jac").demoted();
    assert not demoted , str(demoted);
    standard = get_func(engine, "standard_module_shadow_probe", ctypes.c_int64);
    canonical = get_func(engine, "canonical_module_name_shadow_probe", ctypes.c_int64);
    assert standard() == 21;
    assert canonical() == 8;
}


test "cached public layouts do not demote another module's private helper" {
    fixtures = Path(__file__).parent / "fixtures";
    with tempfile.TemporaryDirectory() as directory {
        workspace = Path(directory);
        for side in ["private_left", "private_right"] {
            (workspace / side).mkdir();
            (workspace / side / "helpers.jac").write_text(
                (fixtures / side / "helpers.jac").read_text()
            );
        }
        source = workspace / "main.jac";
        source.write_text((fixtures / "native_private_same_basename.jac").read_text());
        (initial, _) = compile_native("main.jac", directory);
        probe = get_func(initial, "private_modules_probe", ctypes.c_int64);
        assert probe() == 31;
        # Recompile the caller while the dependency's public native layout is
        # reusable. Its unexported `adjust` must not poison the caller's helper.
        right = workspace / "private_right" / "helpers.jac";
        right.write_text(right.read_text().replace("value * 2", "value * 3"));
        (rebuilt, _) = compile_native("main.jac", directory);
        demoted = compile_mir("main.jac", directory).demoted();
        assert not demoted , str(demoted);
        updated = get_func(rebuilt, "private_modules_probe", ctypes.c_int64);
        assert updated() == 41;
    }
}
