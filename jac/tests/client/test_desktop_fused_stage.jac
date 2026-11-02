"""Staging the fused runtime copies the .jac source files beside the desktop
host. A `.jac/` cache directory left in dist/fused by a jac run matches the
`*.jac` glob too, and copy2 on a directory raised IsADirectoryError, so
`jac build <desktop app>` failed on any dev checkout that had compiled there."""

import shutil;
import tempfile;
import from pathlib { Path }
import jaclang.client.targets.desktop.desktop_build as desktop_build;

test "staging skips directories that match the jac glob" {
    src = Path(tempfile.mkdtemp(prefix="fused_src_"));
    out = Path(tempfile.mkdtemp(prefix="fused_out_"));
    try {
        (src / "bringup.jac").write_text("with entry {}\n");
        (src / "embed.jac").write_text("with entry {}\n");
        (src / ".jac").mkdir();
        (src / ".jac" / "cache").mkdir();
        original = getattr(desktop_build, "_fused_runtime_dir");
        setattr(desktop_build, "_fused_runtime_dir", lambda { src; });
        try {
            desktop_build._stage_fused_runtime(out);
        } finally {
            setattr(desktop_build, "_fused_runtime_dir", original);
        }
        staged = sorted([p.name for p in (out / "fused").iterdir()]);
        assert staged == ["bringup.jac", "embed.jac"] , staged;
    } finally {
        shutil.rmtree(src, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "staging carries each fused module's impl annex" {
    src = Path(tempfile.mkdtemp(prefix="fused_src_"));
    out = Path(tempfile.mkdtemp(prefix="fused_out_"));
    try {
        (src / "bringup.jac").write_text("def boot -> int;\n");
        (src / "impl").mkdir();
        (src / "impl" / "bringup.impl.jac").write_text(
            "impl boot -> int {\n    return 1;\n}\n"
        );
        original = getattr(desktop_build, "_fused_runtime_dir");
        setattr(desktop_build, "_fused_runtime_dir", lambda { src; });
        try {
            desktop_build._stage_fused_runtime(out);
        } finally {
            setattr(desktop_build, "_fused_runtime_dir", original);
        }
        assert (out / "fused" / "impl" / "bringup.impl.jac").is_file();
    } finally {
        shutil.rmtree(src, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "a spliced CEF unit takes the bodies from its annexes but not the fragment's imports" {
    src = Path(tempfile.mkdtemp(prefix="cef_src_"));
    try {
        (src / "impl").mkdir();
        (src / "host.jac").write_text(
            'import from "libc.so.6" {\n    def abort -> None;\n}\n\ndef run;\n'
        );
        (src / "impl" / "host.impl.jac").write_text("impl run {\n    plat();\n}\n");
        (src / "plat.jac").write_text("def plat;\n");
        (src / "impl" / "plat.impl.jac").write_text(
            'import from "libc.so.6" {\n    def abort -> None;\n}\n\nimpl plat {\n    abort();\n}\n'
        );
        unit = desktop_build._inject_platform(
            desktop_build._unit_source(src / "host.jac"),
            desktop_build._unit_source(src / "plat.jac", keep_imports=False)
        );
    } finally {
        shutil.rmtree(src, ignore_errors=True);
    }
    assert unit.count('import from "libc.so.6"') == 1 , unit;
    assert "impl run {" in unit and "impl plat {" in unit , unit;
    assert unit.index("def plat;") < unit.index("def run;") , unit;
}
