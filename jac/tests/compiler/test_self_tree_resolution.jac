"""A module inside a package resolves that package's dotted imports in its own tree.

When two content-identical copies of a package are reachable -- the file
being compiled sits in one, while importlib can reach the other (the sealed
binary's bundled jaclang against a checked-out jaclang source tree, or an
installed wheel of the project being checked) -- every dotted self-import
must resolve inside the tree the compiled file belongs to. Splitting the
resolution across copies hands one program two identities for the same
class, which surfaces as nonsense diagnostics of the shape "Cannot assign
ServingApp to parameter of type ServingApp" (E1053).

The one package exempt from this rule is the compiler's own: jaclang.* is
whatever tree the running compiler was loaded from, because jac0core is
compiled under the self-compile rules that `is_compiler_source_path`
gates, and a second copy of it is a different compiler's source, not a
module of this one. A checkout of jaclang checks itself through the
`[dev] jaclang_source` reroute, never through a sealed binary.
"""

import os;
import shutil;
import sys;
import tempfile;
import importlib;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.modresolver { resolve_relative_path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob PKG_FILES: dict[str, str] = {
         '__init__.jac': '',
         'app.jac': (
             'obj Gadget { has n: int = 0; }\n\n'
             'def use_gadget -> int {\n'
             '    import from dup_pkg.helper { widget_id }\n'
             '    return widget_id(Gadget());\n'
             '}\n'
         ),
         'helper.jac': (
             'import from dup_pkg.app { Gadget }\n\n'
             'def widget_id(g: Gadget) -> int { return g.n; }\n'
         ),

     };

def _write_copy(base: str) -> Path {
    pkg = Path(base) / 'dup_pkg';
    pkg.mkdir(parents=True);
    for (rel, content) in PKG_FILES.items() {
        (pkg / rel).write_text(content);
    }
    return pkg;
}

def _with_shadow_copy(body: callable) {
    home = tempfile.mkdtemp();
    shadow = tempfile.mkdtemp();
    home_pkg = _write_copy(home);
    _write_copy(shadow);
    sys.path.insert(0, shadow);
    importlib.invalidate_caches();
    try {
        body(home_pkg, shadow);
    } finally {
        sys.path.remove(shadow);
        sys.modules.pop('dup_pkg', None);
        sys.modules.pop('dup_pkg.app', None);
        sys.modules.pop('dup_pkg.helper', None);
        importlib.invalidate_caches();
        shutil.rmtree(home, ignore_errors=True);
        shutil.rmtree(shadow, ignore_errors=True);
    }
}

test "dotted self-import resolves in the importing file's own tree" {
    def body(home_pkg: Path, shadow: str) {
        resolved = resolve_relative_path('dup_pkg.helper', str(home_pkg / 'app.jac'));
        assert os.path.realpath(resolved)
            == os.path.realpath(str(home_pkg / 'helper.jac')) , f"resolved into the shadow copy: {resolved}";
    }
    _with_shadow_copy(body);
}

test "type check holds one identity per class across a self-import cycle" {
    def body(home_pkg: Path, shadow: str) {
        prog = JacProgram();
        prog.compile(
            file_path=str(home_pkg / 'app.jac'),
            options=CompileOptions(
                type_check=True, no_cgen=True, force_target_program=True
            )
        );
        errs = [str(e) for e in prog.errors_had];
        assert not errs , f"identity split across package copies: {errs}";
    }
    _with_shadow_copy(body);
}

test "the compiler's own package stays with the running compiler" {
    home = tempfile.mkdtemp();
    copy = Path(home) / 'jaclang' / 'runtimelib' / 'serving';
    copy.mkdir(parents=True);
    (Path(home) / 'jaclang' / '__init__.jac').write_text('');
    (copy / 'app.jac').write_text('obj ServingApp {}\n');
    (copy / 'openapi.jac').write_text(
        'import from jaclang.runtimelib.serving.app { ServingApp }\n'
    );
    try {
        resolved = resolve_relative_path(
            'jaclang.runtimelib.serving.openapi', str(copy / 'app.jac')
        );
        running = os.path.dirname(os.path.realpath(jaclang.__file__));
        assert os.path.realpath(resolved).startswith(running + os.sep) , f"resolved into the foreign copy: {resolved}";
    } finally {
        shutil.rmtree(home, ignore_errors=True);
    }
}
