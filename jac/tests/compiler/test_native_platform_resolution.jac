"""Native source paths must retain the OS variant through dependency linking."""

import os;
import from jaclang.compiler.frontend.codeinfo {
    native_stdlib_root,
    resolve_native_module,
    set_native_target_override
}

test "sibling native errno import retains its platform filename" {
    stdlib_dir = native_stdlib_root();
    assert stdlib_dir is not None;
    prior = set_native_target_override("aarch64-apple-darwin");
    try {
        for (target, filename) in [
            ("aarch64-apple-darwin", "_errno_platform.darwin.jac"),
            ("x86_64-unknown-linux-gnu", "_errno_platform.jac")
        ] {
            set_native_target_override(target);
            (source, resolved) = resolve_native_module("_errno_platform", stdlib_dir);
            assert source is not None and resolved is not None;
            assert os.path.basename(resolved) == filename;
            assert os.path.realpath(os.path.join(stdlib_dir, source))
                == os.path.realpath(resolved);
        }
    } finally {
        set_native_target_override(prior);
    }
}

test "native package imports use the same provider as semantic imports" {
    import from tempfile { TemporaryDirectory }
    import from jaclang.project.modresolver { resolve_module }
    import from jaclang.compiler.frontend.codeinfo {
        set_native_unit_compile,
        reset_native_unit_compile
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
        previous = set_native_unit_compile(True);
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
            reset_native_unit_compile(previous);
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
