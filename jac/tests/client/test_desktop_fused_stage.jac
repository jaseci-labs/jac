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
