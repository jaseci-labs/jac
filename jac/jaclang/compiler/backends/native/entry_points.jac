def validate_native_application(module: Module, shared: bool, memory: str) -> str;

def _scan_rc_machinery(llvm_ir_str: str) -> tuple[list[str], list[str]];


def _inject_entry_elf(llvm_ir_str: str) -> str;

def inject_main(llvm_ir_str: str) -> str;


def _inject_entry_pe(llvm_ir_str: str) -> str;
