import os;

glob SPACE_SERVER: str = 'server',
     SPACE_CLIENT: str = 'client',
     SPACE_NATIVE: str = 'native';

glob NATIVE_POLICY_DIR_REL: tuple[str, ...] = ("client/targets/desktop/native", );
glob TOOLCHAIN_NATIVE_ONLY_REL: tuple[str, ...] = ("runtime", "na_stdlib"),
     TOOLCHAIN_MIXED_NATIVE_REL: tuple[str, ...] = (
         "client",
         "targets",
         "desktop",
         "native"
     );


def native_placement_hard(prog: JacProgram, mod_path: str) -> bool;


def native_placement_soft(prog: JacProgram, mod: uni.Module) -> bool;


def contexts_of(module: uni.Module) -> list[str];


def settle_server(module: uni.Module) -> bool;


def project_root_of(source_path: str) -> (str | None);


def require_project_root(source_path: str) -> str;


def module_spaces(mod: (uni.Module | None)) -> set[str];


def is_client_only(mod: (uni.Module | None)) -> bool;


def emits_server_code(mod: (uni.Module | None)) -> bool;


def discover_spaces(
    paths: list[str], prog: (JacProgram | None) = None
) -> dict[str, set[str]];


def pinned_module_space(source_path: str) -> str;


def spaces_are_client_only(spaces: set[str]) -> bool;


def _toolchain_rel(source_path: str) -> (str | None);

def variant_selected(source_path: str) -> (bool | None);

def native_only(source_path: str) -> bool;

def native_lowered(source_path: str) -> bool;

def native_unit(
    source_path: str,
    native_unit_compile: (bool | None) = None,
    prog: (JacProgram | None) = None
) -> bool;

def native_units_of(package_dir: str, sources: list[str]) -> list[str];

def session_declares_native(
    options: CompileOptions, source: str, element: str, program: JacProgram
) -> bool;
