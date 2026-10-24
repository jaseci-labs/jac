impl TargetSpec.kernel_file_name -> str {
    return f"{self.shared_prefix}jac_compiler{self.shared_suffix}";
}

impl triple_osarch(triple: str) -> str {
    text = triple.lower();
    arch = "";
    if "aarch64" in text or "arm64" in text {
        arch = "aarch64";
    } elif "x86_64" in text or "amd64" in text {
        arch = "x86_64";
    }
    os_name = "";
    if "darwin" in text or "apple" in text or "macos" in text {
        os_name = "macos";
    } elif "windows" in text or "win32" in text or "msvc" in text or "mingw" in text {
        os_name = "windows";
    } elif "linux" in text {
        os_name = "linux";
    }
    return f"{os_name}-{arch}" if os_name and arch else "";
}

impl target_spec(name: str) -> TargetSpec {
    wanted = name
        if name in [spec.osarch for spec in RELEASE_TARGETS]
        else triple_osarch(name);
    for spec in RELEASE_TARGETS {
        if spec.osarch == wanted {
            return spec;
        }
    }
    known = ", ".join(spec.osarch for spec in RELEASE_TARGETS);
    raise UnknownTarget(f"no release target named {name!r} (known: {known})");
}

impl host_target_spec -> TargetSpec {
    import platform;
    return target_spec(triple_osarch(f"{sys.platform}-{platform.machine()}"));
}
