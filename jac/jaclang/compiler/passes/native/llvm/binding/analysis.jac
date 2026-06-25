"""
A collection of analysis utilities
"""
import from ctypes { POINTER, c_char_p, c_int }
import from jaclang.compiler.passes.native.llvm.binding { ffi }
import from jaclang.compiler.passes.native.llvm.binding.module { parse_assembly }
"""Return a string of the control-flow graph of the function in DOT
    format. If the input `func` is not a materialized function, the module
    containing the function is parsed to create an actual LLVM module.
    The `show_inst` flag controls whether the instructions of each block
    are printed.
    """
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

"""
    View the given DOT source.  If view is True, the image is rendered
    and viewed by the default application in the system.  The file path of
    the output is returned.  If view is False, a graphviz.Source object is
    returned.  If view is False and the environment is in a IPython session,
    an IPython image object is returned and can be displayed inline in the
    notebook.

    This function requires the graphviz package.

    Args
    ----
    - graph [str]: a DOT source code
    - filename [str]: optional.  if given and view is True, this specifies
                      the file path for the rendered output to write to.
    - view [bool]: if True, opens the rendered output file.

    """
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

