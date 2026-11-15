import json;
import os;
import pickle;
import shutil;
import tempfile;
import from pathlib { Path }


def _copy_resources(source: Path, destination: Path, output: Path);


def _write_application(
    application: PreparedApplication,
    program: JacProgram,
    base: Path,
    project_root: Path,
    output: Path,
    sources: list[str]
) -> dict[str, any];


def _requirements(config: JacConfig, server: bool) -> list[str];


def export_project(
    config: JacConfig,
    name: str,
    output: Path,
    entry_override: str = '',
    force: bool = False
) -> Path;
