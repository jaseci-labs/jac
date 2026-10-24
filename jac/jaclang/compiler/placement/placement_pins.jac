import fnmatch;
import os;

glob PIN_SPACES: tuple[str, ...] = ('server', 'client', 'native');

def validate_pins(pins: dict[str, str], toml_path: str) -> dict[str, str];

def module_dot_path(source_path: str, root_dir: str) -> str;

def match_pin(
    source_path: str, root_dir: str, pins: dict[str, str], element_name: str = ''
) -> str;

def config_pins_for(source_path: str) -> dict[str, str];


def config_pin_for(source_path: str, element_name: str) -> str;


def config_element_pin(source_path: str, element_name: str) -> str;


def config_module_pin(source_path: str) -> str;


def effective_pin_for(
    source_path: str, element_name: str, prog: (JacProgram | None) = None
) -> str;


def effective_module_pin(source_path: str, prog: (JacProgram | None) = None) -> str;


def config_project_kind(source_path: str) -> str;


def config_kind_space(source_path: str, fallback_kind: str = '') -> str;


def pins_digest(source_path: str) -> str;


def npm_dependency_names(source_path: str) -> set[str];

def client_framework(source_path: str) -> str;

glob _FRAMEWORK_PACKAGES: dict[str, set[str]] = {
         "react": {"react", "react-dom"},
         "preact": {"preact"},
         "solid": {"solid-js"}
     };


obj BareImportVerdict {
    has world: str = 'py',
        rule: str = 'python import',
        path: str = '';
}


def npm_package_root(spec: str) -> str;

def _declared_npm_rule(spec: str, source_path: str) -> str;


def _installed_npm_rule(spec: str, source_path: str) -> str;


def in_client_npm_world(spec: str, source_path: str) -> bool;


def classify_bare_import(spec: str, source_path: str) -> BareImportVerdict;
