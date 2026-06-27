import from ctypes { POINTER, c_char_p, c_int }
import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.module { parse_assembly }
def get_function_cfg(func: Any, show_inst: Any = True) -> object {
    assert (func is not None);
    import from jaclang.compiler.passes.native.llvm { ir }
    if isinstance(func, ir.Function) {
        mod = parse_assembly(str(func.module));
        func = mod.get_function(func.name);
    }
    with ffi.OutputString() as dotstr {
        ffi.lib.LLVMPY_WriteCFG(func, dotstr, show_inst);
        return str(dotstr);
    }
}


def view_dot_graph(graph: Any, filename: Any = None, view: Any = False) -> object {
    import graphviz as gv;
    src = gv.Source(graph);
    if view {
        return src.render(filename, view=view);
    } else {
        try {
            __IPYTHON__;
        } except NameError {
            return src;
        } else {
            import IPython.display as display;
            format = 'svg';
            return display.SVG(data=src.pipe(format));
        }
    }
}

with entry {
    ffi.lib.LLVMPY_WriteCFG.argtypes = [ffi.LLVMValueRef, POINTER(c_char_p), c_int];
}
