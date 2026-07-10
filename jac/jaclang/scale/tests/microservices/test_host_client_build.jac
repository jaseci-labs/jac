import os;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.utils { host_arch }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    HostClientBuild
}


def _with_jac_executable(value: str | None) -> str | None {
    saved = os.environ.pop("JAC_EXECUTABLE", None);
    if value is not None {
        os.environ["JAC_EXECUTABLE"] = value;
    }
    return saved;
}


def _restore_jac_executable(saved: str | None) {
    os.environ.pop("JAC_EXECUTABLE", None);
    if saved is not None {
        os.environ["JAC_EXECUTABLE"] = saved;
    }
}


test "resolve prefers the driver's own jac when it exists" {
    with tempfile.NamedTemporaryFile(suffix="-jac", delete=False) as tmp {
        tmp.write(b"ELF");
        own_jac = tmp.name;
    }
    saved = _with_jac_executable(own_jac);
    try {
        build = HostClientBuild(project_dir=".", client_entry="main.jac");
        assert build._resolve_jac(b"pod-binary", host_arch()) == own_jac;
        assert build._tmp_jac == "";
    } finally {
        _restore_jac_executable(saved);
        os.unlink(own_jac);
    }
}


test "no jac on the host falls back to the downloaded pod binary" {
    saved = _with_jac_executable("/nonexistent/jac");
    try {
        build = HostClientBuild(project_dir=".", client_entry="main.jac");
        exe = build._resolve_jac(b"pod-binary-bytes", host_arch());
        assert exe != "" and exe == build._tmp_jac;
        assert Path(exe).read_bytes() == b"pod-binary-bytes";
        assert os.access(exe, os.X_OK);
    } finally {
        if build._tmp_jac {
            os.unlink(build._tmp_jac);
        }
        _restore_jac_executable(saved);
    }
}


test "a cross-arch pod binary is not runnable on the host: build is skipped" {
    saved = _with_jac_executable("/nonexistent/jac");
    try {
        build = HostClientBuild(project_dir=".", client_entry="main.jac");
        other = "aarch64" if host_arch() == "x86_64" else "x86_64";
        assert build._resolve_jac(b"pod-binary", other) == "";
        assert build._tmp_jac == "";
    } finally {
        _restore_jac_executable(saved);
    }
}


test "join without a started thread is a safe no-op" {
    build = HostClientBuild(project_dir=".", client_entry="");
    build.join();
}
