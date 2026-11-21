import fnmatch;
import os;

glob VALID_SPACES: tuple[str, ...] = ('server', 'client', 'native');


def validate_pins(pins: dict[str, str], toml_path: str) -> dict[str, str];


def module_dot_path(source_path: str, root_dir: str) -> str;


def match_pin(
    source_path: str, root_dir: str, pins: dict[str, str], element_name: str = ''
) -> str;
