"""Native source paths must retain the OS variant through dependency linking."""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.project.modresolver { resolve_relative_path }
import from jaclang.compiler.frontend.codeinfo {
    native_stdlib_root,
    resolve_native_module,
    set_native_target_override
}

test "native dependencies retain the ordinary resolver's package identity" {
    with tempfile.TemporaryDirectory() as work {
        workspace = Path(work);
        decoy = workspace / "jaclang/dist/fused/bringup.jac";
        decoy.parent.mkdir(parents=True);
        decoy.write_text("def open_runtime -> int { return 1; }");
        project = workspace / "build/launcher";
        project.mkdir(parents=True);
        (project / "jac.toml").write_text('[project]\nname = "launcher"\n');
        name = "jaclang.dist.fused.bringup";
        expected = resolve_relative_path(name, str(project / "main.jac"));
        assert Path(expected).resolve() != decoy.resolve();
        (_, native) = resolve_native_module(name, str(project));
        assert native is not None;
        assert Path(native).resolve() == Path(expected).resolve();
    }
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
