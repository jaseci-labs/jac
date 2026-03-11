"""Implementation file for stub_param_goto_def.jac."""

import jaclang.jac0core.unitree as uni;
import from typing { Optional }

impl ModuleProcessor.process_module(name: str, module: uni.Module) -> None { }

impl ModuleProcessor.process_list(modules: list[uni.Module]) -> None { }

impl ModuleProcessor.process_optional(module: uni.Module | None) -> None { }

impl ModuleProcessor.process_dict(mapping: dict[str, uni.Module]) -> None { }

impl ModuleProcessor.process_opt2(module: Optional[uni.Module]) -> None { }
