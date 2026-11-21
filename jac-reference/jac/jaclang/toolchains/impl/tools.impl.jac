impl ToolArtifact.located(slot: Path, download: Download) -> Path {
    return slot / self.marker(download);
}

impl ToolArtifact.on_system -> str {
    return "";
}

impl ToolArtifact.works(path: Path) -> bool {
    return True;
}

impl ToolArtifact.probe_checkout -> Probe {
    if use_system_tools() {
        system = self.on_system();
        if system {
            return Probe.hit(Source.SYSTEM, system, {});
        }
    }
    download = self.pinned();
    if download is None {
        return Probe.missing(f"jac manages no {self.name} for {host_platform()}");
    }
    slot = installed(download, self.marker(download));
    if slot is None {
        return Probe.missing(f"{self.name} {download.version} is not provisioned");
    }
    return Probe.hit(
        Source.CACHE, str(self.located(slot, download)), {"version": download.version}
    );
}

impl ToolArtifact.checkout_path -> str {
    download = self.pinned();
    slot = bucket("toolchains-installed").path();
    return str(slot / download.key() if download is not None else slot);
}

impl ToolArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    download = self.pinned();
    if download is None {
        raise ArtifactUnavailable(f"jac manages no {self.name} for {host_platform()}");
    }
    location = self.located(install(download, self.marker(download)), download);
    if not self.works(location) {
        raise ArtifactUnavailable(
            f"the managed {self.name} could not execute at {location}"
        );
    }
}

impl _runs(argv: list[str]) -> str {
    try {
        result = subprocess.run(argv, capture_output=True, text=True, timeout=15);
    } except (OSError, subprocess.TimeoutExpired) {
        return "";
    }
    return (result.stdout + result.stderr).strip() if result.returncode == 0 else "";
}

impl NodeArtifact.pinned -> (Download | None) {
    return NODE_ARTIFACTS.get(host_platform());
}

impl NodeArtifact.marker(download: Download) -> str {
    top = download.url.rsplit("/", 1)[1].removesuffix(".tar.xz").removesuffix(
        ".tar.gz"
    ).removesuffix(
        ".zip"
    );
    return top + ("/node.exe" if os.name == "nt" else "/bin/node");
}

impl NodeArtifact.on_system -> str {
    found = shutil.which("node");
    if found and _runs([found, "--version"]).startswith("v22.") {
        return str(Path(found).resolve());
    }
    return "";
}

impl NodeArtifact.works(path: Path) -> bool {
    try {
        subprocess.run(
            [str(path), "--version"], check=True, capture_output=True, timeout=15
        );
    } except (OSError, subprocess.SubprocessError) {
        return False;
    }
    return True;
}

impl compatible_jdk(home: Path) -> bool {
    import re;
    javac = home / "bin" / executable("javac");
    return javac.is_file()
        and bool(re.search(r"javac 21[.\s]", _runs([str(javac), "-version"])));
}

impl JdkArtifact.pinned -> (Download | None) {
    return JDK_ARTIFACTS.get(host_platform());
}

impl JdkArtifact._home(download: Download) -> str {
    home = f"jdk-{JDK_VERSION}";
    return home + "/Contents/Home" if download.platform.startswith("mac-") else home;
}

impl JdkArtifact.marker(download: Download) -> str {
    return self._home(download) + "/bin/" + executable("javac");
}

impl JdkArtifact.located(slot: Path, download: Download) -> Path {
    return slot / self._home(download);
}

impl JdkArtifact.on_system -> str {
    requested = os.environ.get("JAVA_HOME", "");
    if requested and compatible_jdk(Path(requested).expanduser()) {
        return str(Path(requested).expanduser());
    }
    found = shutil.which(executable("javac"));
    if found {
        home = Path(found).resolve().parent.parent;
        if compatible_jdk(home) {
            return str(home);
        }
    }
    return "";
}

impl JdkArtifact.works(path: Path) -> bool {
    return compatible_jdk(path);
}

impl PatchelfArtifact.pinned -> (Download | None) {
    return PATCHELF_ARTIFACTS.get(host_platform());
}

impl PatchelfArtifact.marker(download: Download) -> str {
    return "patchelf-0.17.2.4.data/scripts/patchelf";
}

impl PatchelfArtifact.on_system -> str {
    return shutil.which("patchelf") or "";
}

impl tool_path(name: str) -> Path {
    found = require(name).found;
    assert found is not None;
    return Path(found.path);
}
