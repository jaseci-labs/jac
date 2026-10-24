import os;
import platform;
import subprocess;
import from pathlib { Path }

def host_platform -> str;

def executable(name: str) -> str;

def shared_library_name(stem: str) -> str;

def run_step(
    label: str,
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    input_text: str | None = None
);


def use_system_tools -> bool;
