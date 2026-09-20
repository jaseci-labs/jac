"""Native source paths must retain the OS variant through dependency linking."""

import os;
import from jaclang.compiler.frontend.codeinfo {
    resolve_native_module,
    set_native_target_override
}

test "Python standard-library names have no native replacement modules" {
    import from tempfile { TemporaryDirectory }
    with TemporaryDirectory() as directory {
        for name in [
            "math",
            "sys",
            "os",
            "os.path",
            "json",
            "socket",
            "compression.zstd"
        ] {
            assert resolve_native_module(name, directory) == (None, None);
        }
    }
}

test "native package imports use the same provider as semantic imports" {
    import from tempfile { TemporaryDirectory }
    import from jaclang.project.modresolver { resolve_module }
    import from jaclang.compiler.native_scope {
        activate_scope_lowering,
        deactivate_scope_lowering
    }
    with TemporaryDirectory() as directory {
        compiler = os.path.join(directory, "jaclang", "compiler");
        os.makedirs(compiler);
        os.mkdir(os.path.join(directory, "jaclang", "jac0core"));
        checkout = os.path.join(compiler, "jc_materialize.jac");
        with open(checkout, "w") as source {
            source.write("def:pub local_provider -> int { return 42; }\n");
        }
        fixture = os.path.join(directory, "tests", "fixture.jac");
        os.mkdir(os.path.dirname(fixture));
        with open(fixture, "w") as source {
            source.write("");
        }
        activate_scope_lowering(checkout);
        try {
            for importer in [fixture, os.path.join(compiler, "entry.jac")] {
                (expected, language) = resolve_module(
                    "jaclang.compiler.jc_materialize", importer
                );
                assert language == "jac";
                (_, actual) = resolve_native_module(
                    "jaclang.compiler.jc_materialize", os.path.dirname(importer)
                );
                assert actual is not None;
                assert os.path.realpath(actual) == os.path.realpath(expected);
                assert (os.path.realpath(actual) == os.path.realpath(checkout))
                    == (os.path.dirname(importer) == compiler);
            }
        } finally {
            deactivate_scope_lowering();
        }
    }
}

test "explicit native relative imports retain their level and target variant" {
    import from tempfile { TemporaryDirectory }
    import from pathlib { Path }
    with TemporaryDirectory() as directory {
        workspace = Path(directory);
        child = workspace / "formats" / "q1";
        child.mkdir(parents=True);
        # Same-named providers must not steal a parent-relative import.
        for file in [
            workspace / "records.jac",
            child.parent / "records.jac",
            child / "records.jac",
            child.parent / "records.darwin.jac"
        ] {
            file.write_text("obj Record { has value: int = 42; }\n");
        }
        package = child.parent / "shared";
        package.mkdir();
        (package / "__init__.jac").write_text("obj Shared {}\n");
        prior = set_native_target_override("aarch64-apple-darwin");
        try {
            for (name, expected) in [
                (".records", child / "records.jac"),
                ("..records", child.parent / "records.darwin.jac"),
                ("...records", workspace / "records.jac"),
                ("..shared", package / "__init__.jac"),
                ("...formats.shared", package / "__init__.jac")
            ] {
                (source, resolved) = resolve_native_module(name, str(child));
                assert source is not None and resolved is not None;
                assert os.path.realpath(resolved) == str(expected.resolve());
                assert os.path.realpath(child / source) == str(expected.resolve());
            }
            set_native_target_override("x86_64-unknown-linux-gnu");
            (_, resolved) = resolve_native_module("..records", str(child));
            assert resolved == str(child.parent / "records.jac");
            # Explicit relative names must not bind a bundled native module.
            assert resolve_native_module("..math", str(child)) == (None, None);
            assert resolve_native_module("..records", str(child), allow_inferred=False)
                == (None, None);
            # A dotted suffix must not trigger an ancestor search either.
            assert resolve_native_module(".formats.records", str(child))
                == (None, None);
        } finally {
            set_native_target_override(prior);
        }
    }
}

test "qualified and relative native support imports select the same target variant" {
    import jaclang;
    import from jaclang.compiler.native_scope {
        activate_scope_lowering,
        deactivate_scope_lowering
    }
    directory = os.path.join(os.path.dirname(jaclang.__file__), "dist", "fused");
    prior = set_native_target_override("aarch64-apple-darwin");
    activate_scope_lowering(os.path.join(directory, "embed.jac"));
    try {
        for (triple, suffix) in [
            ("aarch64-apple-darwin", "dl.darwin.jac"),
            ("x86_64-unknown-linux-gnu", "dl.jac")
        ] {
            set_native_target_override(triple);
            (_, qualified) = resolve_native_module("jaclang.dist.fused.dl", directory);
            (_, relative) = resolve_native_module(".dl", directory);
            assert qualified == relative;
            assert qualified is not None and os.path.basename(qualified) == suffix;
        }
    } finally {
        deactivate_scope_lowering();
        set_native_target_override(prior);
    }
}
