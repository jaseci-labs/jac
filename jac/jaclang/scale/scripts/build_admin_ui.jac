"""Pre-build the admin dashboard UI for PyPI release.

Runs `jac build main.jac` in the admin UI source directory and copies
the built output (HTML/JS/CSS) into jac_scale/admin/_dist/ so it ships
with the package. At runtime, the server copies these bundled assets
instead of building from source on first request.

Usage (from jac-scale/ directory):
    jac run scripts/build_admin_ui.jac
"""

import shutil;
import subprocess;
import sys;

import from pathlib { Path }

glob w = sys.stdout.write;

"""Run the admin UI build pipeline."""
def main -> int {
    script_dir = Path(__file__).resolve().parent;
    pkg_root = script_dir.parent;
    ui_dir = pkg_root / "jac_scale" / "admin" / "ui";
    dist_dst = pkg_root / "jac_scale" / "admin" / "_dist";

    w(f"Admin UI source: {ui_dir}\n");
    w(f"Bundle destination: {dist_dst}\n\n");

    # Verify source exists
    if not (ui_dir / "main.jac").exists() {
        w("ERROR: Admin UI source not found (missing main.jac)\n");
        return 1;
    }

    # Run jac build
    w("Building admin UI with `jac build main.jac`...\n");
    result = subprocess.run(
        ["jac", "build", "main.jac"],
        cwd=str(ui_dir),
        capture_output=True,
        text=True,
        timeout=300
    );

    if result.returncode != 0 {
        w(f"ERROR: Build failed:\n{result.stderr}\n");
        if result.stdout {
            w(f"stdout:\n{result.stdout}\n");
        }
        return 1;
    }

    # Locate built output
    ui_dist = ui_dir / ".jac" / "client" / "dist";
    if not ui_dist.exists() {
        w(f"ERROR: Build output not found at {ui_dist}\n");
        return 1;
    }

    # Copy to package _dist directory
    if dist_dst.exists() {
        shutil.rmtree(str(dist_dst));
    }
    shutil.copytree(str(ui_dist), str(dist_dst));

    # Count bundled files
    files = list(dist_dst.rglob("*"));
    file_count = len(
        [
            f
            for f in files
            if f.is_file()
        ]
    );
    w(f"\nBundled {file_count} files -> {dist_dst}\n");

    # Verify index.html exists
    if not (dist_dst / "index.html").exists() {
        w("ERROR: index.html not found in build output\n");
        return 1;
    }

    w("Admin UI pre-built successfully.\n");
    return 0;
}

with entry {
    sys.exit(main());
}
