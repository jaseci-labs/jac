"""#8139 Step 1: the invariant "sealed means served" has a runtime consumer.

`sealed.load_image` is the binary's startup gate for its own image: the
manifest is the build's own statement of what it sealed natively, and a
jaclang image that cannot serve that statement on this host refuses to load
with a named error instead of degrading to a tier a sealed build does not
have. These tests drive `load_image` with crafted images, which is exactly
how a shipped binary meets a stripped, stale, or wrong-platform install.
"""

import json;
import os;
import platform;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.sealed {
    JIR_FORMAT_VERSION,
    MANIFEST_FORMAT,
    MANIFEST_NAME,
    SealedImage,
    load_image,
    python_tag
}

def _host_triple -> str {
    arch = platform.machine().lower();
    arch = {"arm64": "aarch64", "amd64": "x86_64"}.get(arch, arch);
    if sys.platform == "darwin" {
        return f"{arch}-apple-darwin";
    }
    return f"{arch}-unknown-linux-gnu";
}

glob WRONG_TRIPLE: str = "x86_64-pc-windows-msvc";

"""Write a sealed image under a fresh temp dir and return its path.

`roots` entries become both the native record and (unless `orphan` names
them) real artifact files on disk, so each test states only the defect it
is about.
"""
def _write_image(
    package: str = "jaclang",
    fmt: int = MANIFEST_FORMAT,
    native: (dict | None) = None,
    artifacts: (dict | None) = None,
    make_files: bool = True
) -> Path {
    pdir = Path(tempfile.mkdtemp(prefix="jac_seal_invariant_")) / "_precompiled";
    pdir.mkdir(parents=True);
    manifest: dict = {
        "format": fmt,
        "package": package,
        "python_tag": python_tag(),
        "jir_format_version": JIR_FORMAT_VERSION,
        "modules": {}
    };
    if native is not None {
        manifest["native"] = native;
    }
    if artifacts is not None {
        manifest["native_artifacts"] = artifacts;
        if make_files {
            for `entry in artifacts.values() {
                for key in ("lib", "layout") {
                    rel = `entry.get(key);
                    if rel {
                        target = pdir / rel;
                        target.parent.mkdir(parents=True, exist_ok=True);
                        target.write_bytes(b"{}" if key == "layout" else b"\x7fELF");
                    }
                }
            }
        }
    }
    (pdir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True), encoding="utf-8"
    );
    return pdir;
}

def _root_entry(stem: str, triple: (str | None) = None) -> dict {
    return {
        "lib": f"native/host/libjac_{stem}.so",
        "layout": f"native/host/{stem}.layout.json",
        "triple": triple if triple is not None else _host_triple(),
        "lib_sha256": "0" * 64,
        "layout_sha256": "0" * 64
    };
}

test "a jaclang image whose native roots resolve loads" {
    pdir = _write_image(
        native={"roots": ["jaclang.jac0core.unitree"], "skip_reason": None},
        artifacts={"jaclang.jac0core.unitree": _root_entry("unitree")}
    );
    image = load_image(pdir);
    assert image is not None;
    assert image.package == "jaclang";
}

test "a declared root with no artifact entry refuses to load, by name" {
    pdir = _write_image(
        native={"roots": ["jaclang.jac0core.unitree"], "skip_reason": None},
        artifacts={}
    );
    with testraises(RuntimeError, `match="jaclang.jac0core.unitree") {
        load_image(pdir);
    }
}

test "a deliberately removed artifact file fails the image at load" {
    pdir = _write_image(
        native={"roots": ["jaclang.jac0core.unitree"], "skip_reason": None},
        artifacts={"jaclang.jac0core.unitree": _root_entry("unitree")}
    );
    (pdir / "native/host/libjac_unitree.so").unlink();
    with testraises(RuntimeError, `match="missing its artifact file") {
        load_image(pdir);
    }
}

test "a wrong-platform artifact refuses to load rather than dlopen-failing later" {
    pdir = _write_image(
        native={"roots": ["jaclang.jac0core.unitree"], "skip_reason": None},
        artifacts={
            "jaclang.jac0core.unitree": _root_entry("unitree", triple=WRONG_TRIPLE)
        }
    );
    with testraises(RuntimeError, `match="targets") {
        load_image(pdir);
    }
}

test "an image that skipped its native seal is refused on a native-capable host" {
    pdir = _write_image(native={"roots": [], "skip_reason": "platform:win"});
    with testraises(RuntimeError, `match="without its native seal") {
        load_image(pdir);
    }
}

test "a skip stamped with THIS capable platform is a build defect, refused" {
    # The manifest's word is not enough: linux and macOS have a native
    # backend, so a skip naming them can only come from a broken build, and
    # honoring it would be silent degradation. (On Windows, where no backend
    # exists, `platform:win` is the one legitimate skip.)
    if sys.platform.startswith("win") {
        pdir = _write_image(native={"roots": [], "skip_reason": "platform:win"});
        assert load_image(pdir) is not None;
    } else {
        pdir = _write_image(
            native={"roots": [], "skip_reason": f"platform:{sys.platform}"}
        );
        with testraises(RuntimeError, `match="native backend") {
            load_image(pdir);
        }
    }
}

test "a jaclang image behind the current manifest format refuses to load" {
    pdir = _write_image(fmt=MANIFEST_FORMAT - 1);
    with testraises(RuntimeError, `match="stale or partially updated") {
        load_image(pdir);
    }
}

test "a current-format jaclang image without a native record refuses to load" {
    pdir = _write_image(native=None);
    with testraises(RuntimeError, `match="no.*native seal record") {
        load_image(pdir);
    }
}

test "app images keep their compatibility: older formats, no native record" {
    pdir = _write_image(package="someapp", fmt=4, native=None);
    image = load_image(pdir);
    assert image is not None;
    assert image.package == "someapp";
}

test "JAC_NO_SEAL against an existing image refuses instead of degrading" {
    pdir = _write_image(
        native={"roots": ["jaclang.jac0core.unitree"], "skip_reason": None},
        artifacts={"jaclang.jac0core.unitree": _root_entry("unitree")}
    );
    saved = os.environ.pop("JAC_NO_SEAL", None);
    os.environ["JAC_NO_SEAL"] = "1";
    try {
        with testraises(RuntimeError, `match="JAC_NO_SEAL") {
            load_image(pdir);
        }
    } finally {
        os.environ.pop("JAC_NO_SEAL", None);
        if saved is not None {
            os.environ["JAC_NO_SEAL"] = saved;
        }
    }
}

test "a corrupt artifact entry raises at resolution; an absent one is None" {
    pdir = _write_image(
        native={"roots": ["jaclang.jac0core.unitree"], "skip_reason": None},
        artifacts={"jaclang.jac0core.unitree": _root_entry("unitree")}
    );
    image = load_image(pdir);
    assert image is not None;
    # Absent entry: this module was never sealed, so the bootstrap tier is
    # the correct answer and the resolver says "no artifact" with None.
    assert image.native_artifact("jaclang.never.sealed") is None;
    # Present-but-corrupt entry: the sha in the manifest does not match the
    # bytes on disk. A sealed build has no fallback tier for this module, so
    # the resolver must raise, never quietly downgrade.
    with testraises(RuntimeError, `match="sha256") {
        image.native_artifact("jaclang.jac0core.unitree");
    }
}

test "a dev source tree (no image) still bootstraps: load_image is None" {
    empty = Path(tempfile.mkdtemp(prefix="jac_no_image_")) / "_precompiled";
    assert load_image(empty) is None;
}
