"""Test fixture for go-to-def and highlighting on compound param types in stub files."""

import jaclang.jac0core.unitree as uni;
import from typing { Optional }

obj ModuleProcessor {
    # Case 1: simple compound type  uni.Module
    def process_module(name: str, module: uni.Module) -> None;
    # Case 2: nested generic  list[uni.Module]
    def process_list(modules: list[uni.Module]) -> None;
    # Case 3: union type  uni.Module | None
    def process_optional(module: uni.Module | None) -> None;
    # Case 4: nested dict generic  dict[str, uni.Module]
    def process_dict(mapping: dict[str, uni.Module]) -> None;
    # Case 5: Optional[uni.Module]
    def process_opt2(module: Optional[uni.Module]) -> None;
}
