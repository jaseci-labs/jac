"""Issue #6669 fixture (imported half): the Object-Spatial spawn lives HERE, in
an imported (non-entry) module. The entry module that imports `run_it` uses no
OSP of its own, so the OSP kernel's glob-init (`__jac_glob_init_osp_kernel`) is
referenced only transitively through this module. NativeCompilePass must still
link the kernel; otherwise the binary builds cleanly but fails at load with
`undefined symbol: __jac_glob_init_osp_kernel`.

Expected: `run_it()` -> 7 (walker accumulates `here.tag` over one spawn)."""

node N {
    has tag: int = 0;
}

walker WA {
    has n: int = 0;

    can a with N entry {
        self.n += here.tag;
    }
}

def run_it() -> int {
    a = N(tag=7);
    r = a spawn WA();
    return r.n;
}
