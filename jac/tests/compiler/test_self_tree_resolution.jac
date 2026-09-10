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
import from jaclang.compiler.driver.modresolver { resolve_relative_path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

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

def _with_shadow_copy(body: Callable[[Path, str], None]) {
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
            file_path=str(home_pkg / 'app.jac'), options=CompileOptions(no_cgen=True)
        );
        errs = [str(e) for e in prog.errors_had];
        assert not errs , f"identity split across package copies: {errs}";
    }
    _with_shadow_copy(body);
}

test "the compiler's own package stays with the running compiler" {
    home = tempfile.mkdtemp();
    copy = Path(home) / 'jaclang' / 'server' / 'serving';
    copy.mkdir(parents=True);
    (Path(home) / 'jaclang' / '__init__.jac').write_text('');
    (copy / 'app.jac').write_text('obj ServingApp {}\n');
    (copy / 'openapi.jac').write_text(
        'import from jaclang.server.serving.app { ServingApp }\n'
    );
    try {
        resolved = resolve_relative_path(
            'jaclang.server.serving.openapi', str(copy / 'app.jac')
        );
        running = os.path.dirname(os.path.realpath(jaclang.__file__));
        assert os.path.realpath(resolved).startswith(running + os.sep) , f"resolved into the foreign copy: {resolved}";
    } finally {
        shutil.rmtree(home, ignore_errors=True);
    }
}

test "a directory without a marker resolves as the namespace package the runtime makes of it" {
    # The runtime claims a marker-less directory whose subtree holds Jac
    # source as an implicit namespace package; the resolver answered nothing
    # for the bare directory, so `import from pkg { sub }` could not find
    # `sub` and go-to-definition had nowhere to land.
    import from jaclang.compiler.driver.modresolver { resolve_module }
    base_dir = tempfile.mkdtemp();
    try {
        pkg = os.path.join(base_dir, "nspkg");
        os.makedirs(os.path.join(pkg, "inner"));
        with open(os.path.join(pkg, "inner", "leaf.jac"), "w") as fh {
            fh.write("glob LEAF: int = 1;\n");
        }
        with open(os.path.join(base_dir, "user.jac"), "w") as fh {
            fh.write("import from nspkg.inner { leaf }\n");
        }
        base = os.path.join(base_dir, "user.jac");
        (pkg_path, pkg_lang) = resolve_module("nspkg", base);
        assert pkg_path == pkg , f"bare package: {pkg_path}";
        assert pkg_lang == "jac" , pkg_lang;
        (inner_path, _) = resolve_module("nspkg.inner", base);
        assert inner_path == os.path.join(pkg, "inner") , f"nested bare package: {inner_path}";
        (leaf_path, _) = resolve_module("nspkg.inner.leaf", base);
        assert leaf_path == os.path.join(pkg, "inner", "leaf.jac") , f"leaf: {leaf_path}";
    } finally {
        shutil.rmtree(base_dir, ignore_errors=True);
    }
}

test "a marker-less package of the compiler's own tree stays with the running compiler" {
    # jaclang/server/serving carries no __init__.jac; the package itself must
    # still resolve into the running compiler's tree, never into a foreign
    # copy, or the sealed binary compiles both and one class gets two
    # identities (E1053 "Cannot assign RunPlan to parameter of type RunPlan").
    home = tempfile.mkdtemp();
    copy = Path(home) / 'jaclang' / 'server' / 'serving';
    copy.mkdir(parents=True);
    (Path(home) / 'jaclang' / '__init__.jac').write_text('');
    (copy / 'app.jac').write_text('obj ServingApp {}\n');
    try {
        resolved = resolve_relative_path(
            'jaclang.server.serving', str(copy / 'app.jac')
        );
        running = os.path.dirname(os.path.realpath(jaclang.__file__));
        assert os.path.realpath(resolved).startswith(running + os.sep) , f"resolved into the foreign copy: {resolved}";
        assert os.path.isdir(resolved) , f"a marker-less package resolves to its directory: {resolved}";
    } finally {
        shutil.rmtree(home, ignore_errors=True);
    }
}
