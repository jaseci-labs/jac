"""Interface identity work scales with source modules, not symbol visits."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.types.stubcat.writer { CatalogWriter }

test "interface symbol identities resolve each module path once" {
    program = JacProgram();
    source = '\n'.join(f'def function_{i} -> int {{ return {i}; }}' for i in range(40));
    options = CompileOptions(symtab_ir_only=True, force_target_program=True);
    boundary = program.compile('identity.jac', use_str=source, options=options);
    twin = JacProgram().compile('identity.jac', use_str=source, options=options);
    external = JacProgram().compile('external.jac', use_str=source, options=options);
    writer = CatalogWriter(evaluator=None, pkg_dir=os.getcwd(), boundary=boundary);
    with patch('os.path.realpath', wraps=os.path.realpath) as resolve {
        for mod in [boundary, twin, external] {
            for sym in mod.names_in_scope.values() {
                writer._sym_ident(sym);
                writer._scope_ident(sym.parent_tab);
                writer.ref_module(mod);
                writer.rel_of(mod.loc.mod_path);
            }
        }
        assert resolve.call_count <= 2 , (
            f'two module paths required {resolve.call_count} filesystem resolutions'
        );
    }
    assert writer._mod_ident(boundary) == writer._mod_ident(twin);
    assert writer.in_boundary(twin) and not writer.in_boundary(external);
    for name in boundary.names_in_scope.keys() {
        assert (
            writer._sym_ident(boundary.names_in_scope[name])
            == writer._sym_ident(twin.names_in_scope[name])
        );
    }
}

test "interface path identities expire with the writer" {
    with TemporaryDirectory() as td {
        base = Path(td);
        for name in ['first', 'second'] {
            (base / name).mkdir();
        }
        alias = base / 'alias';
        alias.symlink_to(base / 'first', target_is_directory=True);
        writer = CatalogWriter(evaluator=None, pkg_dir=td);
        assert writer.rel_of(str(alias / 'unit.jac')) == 'first/unit.jac';
        alias.unlink();
        alias.symlink_to(base / 'second', target_is_directory=True);
        next_writer = CatalogWriter(evaluator=None, pkg_dir=td);
        assert next_writer.rel_of(str(alias / 'unit.jac')) == 'second/unit.jac';
    }
}
