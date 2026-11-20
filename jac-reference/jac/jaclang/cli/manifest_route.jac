import os;
import sys;
import platform;
import tomllib;
import from pathlib { Path }
import from importlib.metadata { version as pkg_version }

def handle_manifest_route(raw_argv: list[str]) -> None;
def resolve_cli_version -> str;
