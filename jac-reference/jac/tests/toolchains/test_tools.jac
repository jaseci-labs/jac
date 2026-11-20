"""Managed tools resolve through the artifact router: a compatible system copy
first (unless `[toolchains] system = false`), then the pinned copy in the
toolchain cache, and only then a loud, offline-refused install."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.artifacts.model { ArtifactUnavailable, Source }
import from jaclang.artifacts.router { forget, require, resolve }
import from jaclang.toolchains.tools { PatchelfArtifact }
import from tests.support { offline_project }

def _resolve(cache: str, system: str, use_system: bool = True) -> any {
    forget("patchelf");
    with patch.dict(os.environ, {"JAC_CACHE_HOME": cache}), patch(
        "jaclang.toolchains.tools.shutil.which", return_value=system or None
    ), patch("jaclang.project.config.use_system_toolchains", return_value=use_system), patch(
        "jaclang.artifacts.model.Artifact.host_supported", return_value=True
    ) {
        return resolve("patchelf");
    }
}

def _install_pinned(cache: str) -> Path {
    import from jaclang.toolchains.store { publish_install_slot }
    with patch.dict(os.environ, {"JAC_CACHE_HOME": cache}) {
        tool = PatchelfArtifact();
        download = tool.pinned();
        assert download is not None;
        slot = Path(tool.checkout_path());
        binary = slot / tool.marker(download);
        binary.parent.mkdir(parents=True);
        binary.write_text("");
        publish_install_slot(slot, {"name": "patchelf"});
        return binary;
    }
}

def _pinned_here -> bool {
    return PatchelfArtifact().pinned() is not None;
}

test "a system copy wins while [toolchains] system is on" {
    with TemporaryDirectory() as tmp {
        resolution = _resolve(tmp, "/usr/bin/patchelf");
        assert resolution.found is not None;
        assert resolution.found.source == Source.SYSTEM;
        assert resolution.found.path == "/usr/bin/patchelf";
        forget("patchelf");
    }
}

test "[toolchains] system = false ignores the system copy for the pinned one" {
    if not _pinned_here() {
        return;
    }
    with TemporaryDirectory() as tmp {
        binary = _install_pinned(tmp);
        resolution = _resolve(tmp, "/usr/bin/patchelf", use_system=False);
        assert resolution.found is not None;
        assert resolution.found.source == Source.CACHE;
        assert resolution.found.path == str(binary);
        forget("patchelf");
    }
}

test "a missing tool is refused in an offline project, never downloaded" {
    if not _pinned_here() {
        return;
    }
    with TemporaryDirectory() as tmp {
        forget("patchelf");
        with patch.dict(os.environ, {"JAC_CACHE_HOME": tmp}), patch(
            "jaclang.toolchains.tools.shutil.which", return_value=None
        ), patch("jaclang.toolchains.tools.install", side_effect=AssertionError), offline_project() {
            try {
                require("patchelf");
                assert False , "an offline project must not provision";
            } except ArtifactUnavailable as e {
                assert "offline" in str(e) , str(e);
            }
        }
        forget("patchelf");
    }
}
