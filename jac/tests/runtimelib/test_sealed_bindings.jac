"""Sealed cross-boundary bindings import their server module by its dotted
path from the image root, so a module that imports a sibling relatively
still resolves when the served entry never loaded it."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.server.server { ModuleIntrospector }


test "a served surface entry resolves a server module with a relative import" {
    with TemporaryDirectory() as tmp {
        img = Path(tmp);
        pkg = img / "pkg";
        pkg.mkdir();
        (pkg / "sib.jac").write_text(
            "def helper -> str { return \"from sibling\"; }\n"
        );
        (pkg / "mod.jac").write_text(
            "import from .sib { helper }\n\ndef:pub answer -> str { return helper(); }\n"
        );
        prepare_application(str(pkg / "mod.jac"), Jac.get_program(), str(img));
        import types;
        import from jaclang.compiler.frontend.codeinfo { SurfaceEntry }
        intro = ModuleIntrospector("mod", str(pkg));
        intro._module = types.ModuleType("entry");
        intro._module.__file__ = str(img / "entry.jac");
        intro._manifest_root = str(img);
        intro._surface = {
            "answer": SurfaceEntry(
                name="answer",
                kind="function",
                exposure="public",
                placement="server",
                src="pkg/mod.jac"
            )
        };
        functions = intro._collect_functions();
        assert "answer" in functions , "the surface entry did not register";
        assert functions["answer"]() == "from sibling";
        assert intro.is_auth_required_for_function("answer") is False;
    }
}
