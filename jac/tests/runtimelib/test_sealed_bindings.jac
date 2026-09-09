"""Sealed cross-boundary bindings import their server module by its dotted
path from the image root, so a module that imports a sibling relatively
still resolves when the served entry never loaded it."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.server { ModuleIntrospector }


test "a sealed binding resolves a server module with a relative import" {
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
        intro = ModuleIntrospector("mod", str(pkg));
        intro._register_sealed_bindings(
            {
                "cross_bindings": [
                    {
                        "name": "answer",
                        "src": "pkg/mod.jac",
                        "kind": "function",
                        "auth": False
                    }
                ]
            },
            str(img)
        );
        assert "answer" in intro._functions , "the binding did not register";
        assert intro._functions["answer"]() == "from sibling";
        assert intro._function_access["answer"] is False;
    }
}
