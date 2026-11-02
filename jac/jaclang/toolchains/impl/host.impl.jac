impl host_platform -> str {
    systems = {"Linux": "linux", "Darwin": "mac", "Windows": "windows"};
    arches = {
        "x86_64": "x64",
        "AMD64": "x64",
        "aarch64": "aarch64",
        "arm64": "aarch64"
    };
    system = systems.get(platform.system(), "");
    arch = arches.get(platform.machine(), "");
    if not system or not arch {
        raise RuntimeError(
            f"Unsupported toolchain host: {platform.system()} {platform.machine()}"
        );
    }
    return system + "-" + arch;
}

impl executable(name: str) -> str {
    return name + ".exe" if os.name == "nt" else name;
}

impl shared_library_name(stem: str) -> str {
    system = platform.system();
    if system == "Darwin" {
        return "lib" + stem + ".dylib";
    }
    if system == "Windows" {
        return stem + ".dll";
    }
    return "lib" + stem + ".so";
}

impl run_step(
    label: str,
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    input_text: str | None = None
) {
    console.print(label);
    subprocess.run(
        command, cwd=cwd, env=env, input=input_text, text=True, check=True, timeout=3600
    );
}

impl use_system_tools -> bool {
    return use_system_toolchains();
}
