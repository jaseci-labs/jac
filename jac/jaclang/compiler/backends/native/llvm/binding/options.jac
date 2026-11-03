"""Set an LLVM command-line option, as `set_option("jac", "-debug-pass=Structure")`."""
def set_option(name: str, option: str) {
    LLVMPY_SetCommandLine(name, option);
}
