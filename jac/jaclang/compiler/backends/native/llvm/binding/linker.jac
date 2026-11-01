"""Link `source` into `target`; `source` is consumed either way."""
def link_modules(target: ModuleRef, source: ModuleRef) {
    err: ptr[u8] = ptr[u8]();
    failed = LLVMPY_LinkModules(target.live(), source.live(), &mut err);
    source.detach();
    message = take_text(err);
    if failed != 0 {
        raise RuntimeError(message);
    }
}
