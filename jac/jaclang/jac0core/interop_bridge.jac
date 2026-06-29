import ctypes;
import logging;
import from collections.abc { Callable }
import type from jaclang.jac0core.codeinfo { InteropManifest }

glob logger = logging.getLogger(__name__),
     JAC_TO_CTYPES: dict[(str, type)] = {
         'int': ctypes.c_int64,
         'float': ctypes.c_double,
         'bool': ctypes.c_bool,
         'str': ctypes.c_char_p
     },
     JAC_TO_CTYPES_STR: dict[(str, str)] = {
         'int': 'ctypes.c_int64',
         'float': 'ctypes.c_double',
         'bool': 'ctypes.c_bool',
         'str': 'ctypes.c_char_p'
     };

def register_py_callbacks(
    manifest: InteropManifest,
    py_func_table: dict[(str, Callable[(..., object)])],
    callbacks_list: list
) {
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    for binding in manifest.native_imports {
        ret_ct = JAC_TO_CTYPES.get(binding.ret_type, ctypes.c_int64);
        arg_cts = [JAC_TO_CTYPES.get(pt, ctypes.c_int64) for pt in binding.param_types];
        cb_type = ctypes.CFUNCTYPE(ret_ct, *arg_cts);
        def _make_callback(
            func_name: str, table: dict[(str, Callable[(..., object)])]
        ) -> Callable[(..., object)] {
            warned = [False];
            def callback(*args: object) -> object {
                fn = table.get(func_name);
                if (fn is not None) {
                    return fn(*args);
                }
                if not warned[0] {
                    logger.warning(
                        f"Native code called Python function '{func_name}' butit's not registered. Returning 0. Ensure Python code defining '{func_name}'executes before native code calls it."
                    );
                    warned[0] = True;
                }
                return 0;
            }
            return callback;
        }
        cb = cb_type(_make_callback(binding.name, py_func_table));
        callbacks_list.append(cb);
        cb_addr = ctypes.cast(cb, ctypes.c_void_p).value;
        llvm.add_symbol(binding.name, cb_addr);
    }
}
