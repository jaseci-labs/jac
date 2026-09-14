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
