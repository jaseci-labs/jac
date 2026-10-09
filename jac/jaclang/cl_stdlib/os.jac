def:pub getcwd -> str {
    proc = globalThis.process;
    return str(proc.cwd());
}
