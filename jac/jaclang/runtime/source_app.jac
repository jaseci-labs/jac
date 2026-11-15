import argparse;
import builtins;
import json;
import os;
import pickle;
import from pathlib { Path }

glob SOURCE_FORMAT: int = 1;

def artifact_path(base: Path, relative: str) -> Path;

def _load_application(record: dict[str, any], base: Path) -> PreparedApplication;

def load_runtime(directory: Path);

def load_project(manifest_path: Path, name: str = '') -> PreparedApplication;

def main(manifest_path: str, name: str = '', argv: list[str] | None = None) -> int;
