"""Where a project's archwire.jac lives. Host code names and finds wiring
files here without importing the wiring model, which the kernel compiles."""
import os;

glob ARCH_FILE_NAME: str = "archwire.jac";

def is_arch_file(path: str) -> bool;

def arch_file_for(path: str) -> (str | None);
