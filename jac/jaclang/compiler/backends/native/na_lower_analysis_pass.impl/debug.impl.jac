impl NativeLowering._na_debug_on -> bool {
    _opts = self.prog.options;
    return _opts is not None and bool(_opts.na_debug);
}
