impl running_jacpython -> bool {
    return hasattr(ctypes.pythonapi, "_PyJac_CompilerRequired");
}

impl _repo_root -> str {
    return os.path.dirname(jaclang_pkg_root());
}

impl jacpython_binary -> str {
    return os.path.join(_repo_root(), "zig-out", "jacpython", "bin", "jac");
}

impl _this_process(source: Source) -> Probe {
    if running_jacpython() {
        return Probe.hit(source, sys.executable, {});
    }
    built = jacpython_binary();
    return Probe.missing(
        f"this jac bundles CPython; the JacPython build is {built}"
            if os.path.isfile(built)
            else "this jac bundles CPython; `jac native build jacpython` builds a jac on JacPython"
    );
}

impl JacPythonArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }
    return Probe.hit(Source.SEALED, sys.executable, {})
        if running_jacpython()
        else Probe.by_design();
}

impl JacPythonArtifact.probe_checkout -> Probe {
    return _this_process(Source.CHECKOUT);
}

impl JacPythonArtifact.probe_kit -> Probe {
    if kit_image() is None {
        return Probe.missing("this process runs on no kit");
    }
    return _this_process(Source.KIT);
}

impl JacPythonArtifact.checkout_path -> str {
    return jacpython_binary();
}

impl JacPythonArtifact.built -> Probe {
    path = jacpython_binary();
    return Probe.hit(Source.CHECKOUT, path, {})
        if os.path.isfile(path)
        else Probe.missing();
}

impl JacPythonArtifact.build_blocker -> str {
    import shutil;
    return "" if shutil.which("zig") else "zig is not on PATH";
}

impl JacPythonArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    import subprocess;
    prefix = os.path.dirname(os.path.dirname(jacpython_binary()));
    argv = ["zig", "build", "-Dpython=jacpython", "--prefix", prefix];
    if not exact {
        argv.append("-Dreuse-python=true");
    }
    log("  " + " ".join(argv));
    subprocess.run(argv, cwd=_repo_root(), check=True);
    log(f"  run JacPython with {jacpython_binary()}");
}
