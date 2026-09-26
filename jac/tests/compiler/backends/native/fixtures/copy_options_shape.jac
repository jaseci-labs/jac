"""A mirror of the compiler's `CompileOptions` shape, copied the way the
driver copies it: `copy.copy(options)` then a field or two rebound on the copy.

Many scalar, `str`, optional and list fields, an `any` field, and a `postinit`
that fills defaults -- which `copy.copy` must not run again. One method imports
`copy` in its own body, as `CompileOptions.for_symbols` does. Both backends
print and the outputs are diffed.
"""

import copy;

obj Opts {
    has symtab_ir_only: bool = False,
        native_required: bool = False,
        native_require: (list[str] | None) = None,
        native_link_mode: (str | None) = None,
        force_codespace: str = "",
        memory_profile: (str | None) = None,
        na_gc_mode: (str | None) = None,
        native_threads: (int | None) = None,
        opt_level: (int | None) = None,
        rc_debug_codegen: (bool | None) = None,
        suppress_codes: list[str] = [],
        project_root: (str | None) = None,
        entry_point: str = "",
        cancel_token: any = None,
        postinit_runs: int = 0;

    def postinit {
        self.postinit_runs = self.postinit_runs + 1;
        if self.native_require is None {
            self.native_require = [];
        }
        if self.memory_profile is None {
            self.memory_profile = "managed";
        }
        if self.na_gc_mode is None {
            self.na_gc_mode = "cycles";
        }
        if self.opt_level is None {
            self.opt_level = 2;
        }
    }

    def for_symbols(need_tree: bool = False) -> Opts {
        import copy;
        result = copy.copy(self);
        result.symtab_ir_only = True;
        result.native_required = not need_tree;
        return result;
    }

    def with_codespace(space: str) -> Opts {
        result = copy.copy(self);
        result.force_codespace = space;
        return result;
    }

    def show {
        print(
            self.symtab_ir_only,
            self.native_required,
            show_list(self.native_require),
            show_str(self.native_link_mode),
            self.force_codespace,
            show_str(self.memory_profile),
            show_str(self.na_gc_mode),
            show_int(self.native_threads),
            show_int(self.opt_level),
            show_bool(self.rc_debug_codegen),
            self.suppress_codes,
            show_str(self.project_root),
            self.entry_point,
            self.postinit_runs
        );
    }
}

def show_str(v: (str | None)) -> str {
    if v is None {
        return "None";
    }
    return v;
}

def show_int(v: (int | None)) -> str {
    if v is None {
        return "None";
    }
    return str(v);
}

def show_bool(v: (bool | None)) -> str {
    if v is None {
        return "None";
    }
    return str(v);
}

def show_list(v: (list[str] | None)) -> str {
    if v is None {
        return "None";
    }
    return str(v);
}

def bind(options: Opts, path: str) -> Opts {
    bound = copy.copy(options);
    bound.entry_point = path;
    bound.native_threads = 8;
    return bound;
}

with entry {
    base = Opts(suppress_codes=["W1"], project_root="/p");
    base.show();
    bound = bind(base, "main.jac");
    bound.show();
    base.show();
    native = bound.with_codespace("native");
    native.opt_level = 3;
    native.native_link_mode = "objects";
    native.symtab_ir_only = True;
    native.suppress_codes.append("W2");
    native.show();
    bound.show();
    print(base.suppress_codes is native.suppress_codes, native.cancel_token is None);
    again = copy.copy(native);
    again.project_root = None;
    again.memory_profile = "rc";
    again.show();
    native.show();
    symbols = again.for_symbols(need_tree=True);
    symbols.show();
    again.show();
}
