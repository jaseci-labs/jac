import json;
import os;

glob KERNEL_TARGET_FORMAT: int = 1;

obj KernelTarget {
    has format: int = KERNEL_TARGET_FORMAT,
        `root: str = "",
        scope_modules: list[str] = [],
        root_module: str = "",
        kernel_unit_rel: list[str] = [],
        native_lowered_rel: list[str] = [],
        native_only_rel: list[str] = [],
        link_mode: str = "";

    def to_dict -> dict[str, object];
    def to_json -> str;
    def module_path(module: str) -> str;
    def root_module_path -> str;
    def is_native_only(rel: str) -> bool;
    def is_native_lowered(rel: str) -> bool;
}

glob _TARGET: list[KernelTarget] = [],
     _GENERATION: list[int] = [0],
     _ROOT_REAL: list[tuple[int, str]] = [];

def _rel_under(rel: str, entries: list[str]) -> bool;

def _str_list(value: object) -> list[str];

def kernel_target_from_dict(data: dict[str, object]) -> (KernelTarget | None);

def read_kernel_target(path: str) -> (KernelTarget | None);

def with_link_mode(spec: KernelTarget, link_mode: str) -> KernelTarget;

def write_kernel_target(spec: KernelTarget, path: str);

def set_kernel_target(spec: (KernelTarget | None)) -> (KernelTarget | None);

def active_kernel_target -> (KernelTarget | None);

def kernel_target_active -> bool;

def kernel_target_generation -> int;

def target_pkg_root -> str;

def _target_root_real -> str;

def is_target_package_path(path: str) -> bool;

def target_package_rel(path: str) -> (str | None);
