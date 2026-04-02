"""Pre-build the admin dashboard UI for PyPI release.

Runs `jac build main.jac` in the admin UI source directory and copies
the output into jac_scale/admin/_dist/ so it ships with the package.

Usage (from jac-scale/ directory):
    jac run scripts/build_admin_ui.jac
"""

import shutil;
import subprocess;
import sys;

import from pathlib { Path }

with entry {
    pkg_root = Path(__file__).resolve().parent.parent;
    ui_dir = pkg_root / "jac_scale" / "admin" / "ui";
    dist_dst = pkg_root / "jac_scale" / "admin" / "_dist";

    if not (ui_dir / "main.jac").exists() {
        print(f"ERROR: Admin UI source not found at {ui_dir}");
        sys.exit(1);
    }

    print(f"Building admin UI from {ui_dir}...");
    result = subprocess.run(
        ["jac", "build", "main.jac"],
        cwd=str(ui_dir),
        capture_output=True,
        text=True,
        timeout=300
    );

    if result.returncode != 0 {
        print(f"ERROR: Build failed:\n{result.stderr}");
        sys.exit(1);
    }

    ui_dist = ui_dir / ".jac" / "client" / "dist";
    if not (ui_dist / "index.html").exists() {
        print(f"ERROR: Build output not found at {ui_dist}");
        sys.exit(1);
    }

    if dist_dst.exists() {
        shutil.rmtree(str(dist_dst));
    }
    shutil.copytree(str(ui_dist), str(dist_dst));

    file_count = len([f for f in dist_dst.rglob("*") if f.is_file()]);
    print(f"Bundled {file_count} files -> {dist_dst}");
}
