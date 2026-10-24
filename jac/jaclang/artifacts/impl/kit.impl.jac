impl kit_image -> (tuple[str, SealedImage] | None) {
    if not _KIT {
        _KIT.append(_find_kit());
    }
    (site_pkg, image) = _KIT[0];
    return (site_pkg, image) if image is not None else None;
}

impl pr_kit_omits(name: str) -> bool {
    """Whether the build asked to leave `name` out of its kit. Only the CI kit
    lanes ask, through `JAC_KIT_OMIT` (setup-jac sets it for a pull request
    without the `native:<name>` label); a release, nightly or local build never
    sets it, so it ships everything.""";
    return name in os.environ.get("JAC_KIT_OMIT", "").split(",");
}

impl kit_path(rel: str) -> str {
    found = kit_image();
    return os.path.join(found[0], rel) if found is not None else "";
}

impl _find_kit -> tuple[str, (SealedImage | None)] {
    import jaclang;
    site_pkg = os.path.join(os.path.dirname(sys.prefix), "site", "jaclang");
    if not os.path.isdir(os.path.join(site_pkg, "_precompiled")) {
        return ("", None);
    }
    if os.path.realpath(site_pkg)
        == os.path.realpath(os.path.dirname(str(jaclang.__file__))) {
        return ("", None);
    }
    try {
        import from jaclang.jac0core.sealed { load_image }
        return (site_pkg, load_image(os.path.join(site_pkg, "_precompiled")));
    } except Exception {
        return ("", None);
    }
}

impl _unsealed_runtime_site -> str {
    """The running jaclang when it sits in a runtime tree that is not sealed
    yet. mkpayload stages the C floor under `<root>/python/floor` before it
    seals `<root>/site/jaclang`, so the seal links the kernel against the
    floor the image will ship.""";
    import jaclang;
    site_pkg = os.path.dirname(str(jaclang.__file__));
    floor = os.path.join(os.path.dirname(os.path.dirname(site_pkg)), "python", "floor");
    return site_pkg if os.path.isdir(floor) else "";
}

impl runtime_floor_root(sealed: bool) -> str {
    """The `python/floor` directory of the runtime this process runs on: the
    sealed image's own for a sealed process, the kit's for a rerouted
    checkout, the tree's own for a runtime being sealed. Empty when there is
    none.""";
    site_pkg = "";
    if sealed {
        import from jaclang.jac0core { sealed as sealed_mod }
        image = sealed_mod._jaclang_image();
        site_pkg = str(image.pkg_dir) if image is not None else "";
    } else {
        found = kit_image();
        site_pkg = found[0] if found is not None else _unsealed_runtime_site();
    }
    if not site_pkg {
        return "";
    }
    return os.path.join(os.path.dirname(os.path.dirname(site_pkg)), "python", "floor");
}

impl osarch(triple: str = "") -> str {
    """`<os>-<arch>` as the build trees and floors name a platform
    (linux-x86_64, macos-aarch64), for a target triple or this host.""";
    import platform;
    text = (triple or f"{sys.platform}-{platform.machine()}").lower();
    arch = "aarch64" if ("aarch64" in text or "arm64" in text) else "x86_64";
    if "wasm" in text {
        return "wasm32";
    }
    if "darwin" in text or "apple" in text or "macos" in text {
        return f"macos-{arch}";
    }
    if "win" in text {
        return f"windows-{arch}";
    }
    return f"linux-{arch}";
}
