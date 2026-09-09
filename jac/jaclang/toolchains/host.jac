import os;
import platform;
import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }

def host_platform -> str {
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

def executable(name: str) -> str {
    return name + ".exe" if os.name == "nt" else name;
}

def run_step(
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


def use_system_tools -> bool {
    return os.environ.get("JAC_TOOLCHAIN_USE_SYSTEM", "1").lower()
        not in ["0", "false", "no"];
}
