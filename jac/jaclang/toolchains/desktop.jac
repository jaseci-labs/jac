import hashlib;
import os;
import sys;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.cache_paths { FileLock }
import from jaclang.toolchains.store { Artifact, cache_root, fetch, file_digest }
import from jaclang.toolchains.host { host_platform, run_step }
import from jaclang.toolchains.system {
    ensure_linux_desktop,
    ensure_patchelf,
    webkit_module
}

def source_workspace(source: Path, name: str) -> Path {
    digest = hashlib.sha256();
    digest.update(file_digest(Path(sys.executable)).encode());
    files = sorted(
        [
            p
            for p in source.iterdir()
            if p.is_file() and (p.suffix == ".jac" or p.name == "cef_sums.lock")
        ]
    );
    for path in files {
        digest.update(path.name.encode());
        digest.update(path.read_bytes());
    }
    destination = cache_root()
        / "build"
        / name
        / host_platform()
        / digest.hexdigest()[:20];
    with FileLock(destination.with_suffix(".lock")) {
        if not (destination / ".ready").exists() {
            destination.parent.mkdir(parents=True, exist_ok=True);
            with tempfile.TemporaryDirectory(dir=destination.parent) as tmp {
                staged = Path(tmp) / "source";
                staged.mkdir();
                for path in files {
                    shutil.copy2(path, staged / path.name);
                }
                (staged / ".ready").touch();
                staged.replace(destination);
            }
        }
    }
    return destination;
}

def ensure_webview(directory: Path) -> Path {
    ensure_linux_desktop();
    ensure_patchelf();
    artifact = Artifact(
        "webview-header",
        "0.12.0",
        "source",
        "https://raw.githubusercontent.com/webview/webview/0.12.0/core/include/webview/webview.h",
        "b1ff6e11431d031e5f7917e5301f4bcdf3910a2763a0720abfd291994eee7f7b"
    );
    module = webkit_module();
    version = subprocess.run(
        ["pkg-config", "--modversion", module],
        capture_output=True,
        text=True,
        check=True
    ).stdout.strip();
    identity = artifact.digest + "-" + module + "-" + version;
    output = directory / "libwebview.so";
    stamp = directory / ".webview-build";
    with FileLock(directory / ".build.lock") {
        if output.is_file() and stamp.is_file() and stamp.read_text() == identity {
            return output;
        }
        header = fetch(artifact);
        flags = subprocess.run(
            ["pkg-config", "--cflags", "--libs", "gtk+-3.0", module],
            capture_output=True,
            text=True,
            check=True
        ).stdout;
        import shlex;
        with tempfile.TemporaryDirectory(dir=directory) as tmp {
            build = Path(tmp);
            shutil.copy2(header, build / "webview.h");
            source = build / "webview.cc";
            source.write_text('#include "webview.h"\n');
            library = build / "libwebview.so";
            run_step(
                "Building native WebKitGTK wrapper",
                [
                    "g++",
                    "-std=c++17",
                    "-DWEBVIEW_BUILD_SHARED",
                    "-fPIC",
                    "-O2",
                    "-shared",
                    "-Wl,-soname,libwebview.so",
                    str(source),
                    "-o",
                    str(library)
                ]
                    + shlex.split(flags),
                build,
                dict(os.environ)
            );
            library.replace(output);
        }
        (directory / ".webkit_module").write_text(module);
        stamp.write_text(identity);
    }
    return output;
}
