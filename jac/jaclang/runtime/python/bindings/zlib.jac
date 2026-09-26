"""The zlib module: its three stream types, the error type and the constants."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_ParseTupleAndKeywords,
    PyBool_FromLong,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    PyUnicode_FromString,
    Py_NewRef,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    add_owned,
    add_state_owned,
    jacpy_binding_exception,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload,
    jacpy_binding_native_get,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke
}
import from jaclang.runtime.python.bindings.converters { convert_int }
import from jaclang.runtime.python.bindings.clinic.zlib {
    module_methods,
    Compress_methods,
    Decompress_methods,
    ZlibDecompressor_methods
}
import from jaclang.runtime.python.modules.zlib {
    ZlibStream,
    ZlibDecompressorState,
    Compress_token,
    Decompress_token,
    ZlibDecompressor_token,
    COMPRESS_TYPE,
    DECOMPRESS_TYPE,
    DECOMPRESSOR_TYPE,
    ZLIB_ERROR,
    ZLIB_VERSION,
    MAX_WBITS,
    DEFLATED,
    DEF_MEM_LEVEL,
    DEF_BUF_SIZE,
    Z_NO_COMPRESSION,
    Z_BEST_SPEED,
    Z_BEST_COMPRESSION,
    Z_DEFAULT_COMPRESSION,
    Z_FILTERED,
    Z_HUFFMAN_ONLY,
    Z_RLE,
    Z_FIXED,
    Z_DEFAULT_STRATEGY,
    Z_NO_FLUSH,
    Z_PARTIAL_FLUSH,
    Z_SYNC_FLUSH,
    Z_FULL_FLUSH,
    Z_FINISH,
    Z_BLOCK,
    Z_TREES,
    runtime_version,
    zlib_decompressor_new
}

def:priv compress_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, Compress_token.handle);
}

def:priv compress_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, Compress_token.handle, visitor, context);
}

def:priv decompress_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, Decompress_token.handle);
}

def:priv decompress_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, Decompress_token.handle, visitor, context);
}

def:priv stream(instance: ptr[PyObject]) -> ZlibStream | None {
    if jacpy_binding_native_present(instance, Decompress_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Decompress_token.handle);
        if isinstance(state, ZlibStream) {
            return state;
        }
    }
    return None;
}

def:priv decompress_unused_data(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    state = stream(instance);
    return Py_NewRef(state.unused_data) if state is not None else NULL;
}

def:priv decompress_unconsumed_tail(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    state = stream(instance);
    return Py_NewRef(state.unconsumed_tail) if state is not None else NULL;
}

def:priv decompress_eof(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = stream(instance);
    return PyBool_FromLong(i64(state.eof)) if state is not None else NULL;
}

glob:priv compress_type = TypeDefinition(
         "zlib.Compress",
         "",
         Compress_methods,
         u64(TypeFlags.DISALLOW_INSTANTIATION.value | TypeFlags.GC.value),
         TypeHooks(dealloc=compress_dealloc, traverse=compress_traverse)
     ),
     decompress_type = TypeDefinition(
         "zlib.Decompress",
         "",
         Decompress_methods,
         u64(TypeFlags.DISALLOW_INSTANTIATION.value | TypeFlags.GC.value),
         TypeHooks(dealloc=decompress_dealloc, traverse=decompress_traverse),
         [
             PropertyDefinition(
                 "unused_data", PropertyCallbacks(read=decompress_unused_data)
             ),
             PropertyDefinition(
                 "unconsumed_tail", PropertyCallbacks(read=decompress_unconsumed_tail)
             ),
             PropertyDefinition("eof", PropertyCallbacks(read=decompress_eof))
         ]
     );

def:priv decompressor(instance: ptr[PyObject]) -> ZlibDecompressorState | None {
    if jacpy_binding_native_present(instance, ZlibDecompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZlibDecompressor_token.handle);
        if isinstance(state, ZlibDecompressorState) {
            return state;
        }
    }
    return None;
}

def:priv decompressor_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, ZlibDecompressor_token.handle);
}

def:priv decompressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, ZlibDecompressor_token.handle, visitor, context);
}

def:priv decompressor_eof(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = decompressor(instance);
    return PyBool_FromLong(i64(state.eof)) if state is not None else NULL;
}

def:priv decompressor_unused_data(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    state = decompressor(instance);
    return Py_NewRef(state.unused_data) if state is not None else NULL;
}

def:priv decompressor_needs_input(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    state = decompressor(instance);
    return PyBool_FromLong(i64(state.needs_input)) if state is not None else NULL;
}

# PyArg_ParseTupleAndKeywords(args, kwargs, "|iO:_ZlibDecompressor", ...).
glob:priv decompressor_signature = CallSignature(
         "_ZlibDecompressor", ["wbits", "zdict"], 0, 2
     );

def:priv decompressor_bound(args: BoundArguments) -> ptr[PyObject] {
    wbits = MAX_WBITS;
    if args.values[0] != NULL {
        wbits = convert_int(args.values[0]);
    }
    return zlib_decompressor_new(args.context, wbits, args.values[1]);
}

def:priv decompressor_create(
    cls: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(decompressor_signature, args, kwargs, decompressor_bound, cls);
}

glob:priv decompressor_type = TypeDefinition(
         "zlib._ZlibDecompressor",
         "_ZlibDecompressor(wbits=15, zdict=b'')\n--\n\nCreate a decompressor object for decompressing data incrementally.\n\n  wbits = 15\n  zdict\n     The predefined compression dictionary. This is a sequence of bytes\n     (such as a bytes object) containing subsequences that are expected\n     to occur frequently in the data that is to be compressed. Those\n     subsequences that are expected to be most common should come at the\n     end of the dictionary. This must be the same dictionary as used by the\n     compressor that produced the input data.\n\n",
         ZlibDecompressor_methods,
         u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
         TypeHooks(
             create=decompressor_create,
             dealloc=decompressor_dealloc,
             traverse=decompressor_traverse
         ),
         [
             PropertyDefinition(
                 "eof",
                 PropertyCallbacks(read=decompressor_eof),
                 0,
                 "True if the end-of-stream marker has been reached."
             ),
             PropertyDefinition(
                 "unused_data",
                 PropertyCallbacks(read=decompressor_unused_data),
                 0,
                 "Data found after the end of the compressed stream."
             ),
             PropertyDefinition(
                 "needs_input",
                 PropertyCallbacks(read=decompressor_needs_input),
                 0,
                 "True if more input is needed before more decompressed data can be produced."
             )
         ]
     );

def:priv store(module: ptr[PyObject], slot: int, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    jacpy_binding_state_set(module, i64(slot), value);
    jacpy_release(value);
    return True;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    Compress_token.bind(compress_type.handle);
    Decompress_token.bind(decompress_type.handle);
    ZlibDecompressor_token.bind(decompressor_type.handle);
    if not store(module, COMPRESS_TYPE, compress_type.create(module))
        or not store(module, DECOMPRESS_TYPE, decompress_type.create(module))
        or not add_state_owned(
            module,
            DECOMPRESSOR_TYPE,
            "_ZlibDecompressor",
            decompressor_type.create(module)
        )
        or not add_state_owned(
            module, ZLIB_ERROR, "error", jacpy_binding_exception("zlib.error", "", "")
        ) {
        return i32(-1);
    }
    constants = [
        ("MAX_WBITS", i64(MAX_WBITS)),
        ("DEFLATED", i64(DEFLATED)),
        ("DEF_MEM_LEVEL", i64(DEF_MEM_LEVEL)),
        ("DEF_BUF_SIZE", DEF_BUF_SIZE),
        ("Z_NO_COMPRESSION", i64(Z_NO_COMPRESSION)),
        ("Z_BEST_SPEED", i64(Z_BEST_SPEED)),
        ("Z_BEST_COMPRESSION", i64(Z_BEST_COMPRESSION)),
        ("Z_DEFAULT_COMPRESSION", i64(Z_DEFAULT_COMPRESSION)),
        ("Z_FILTERED", i64(Z_FILTERED)),
        ("Z_HUFFMAN_ONLY", i64(Z_HUFFMAN_ONLY)),
        ("Z_RLE", i64(Z_RLE)),
        ("Z_FIXED", i64(Z_FIXED)),
        ("Z_DEFAULT_STRATEGY", i64(Z_DEFAULT_STRATEGY)),
        ("Z_NO_FLUSH", i64(Z_NO_FLUSH)),
        ("Z_PARTIAL_FLUSH", i64(Z_PARTIAL_FLUSH)),
        ("Z_SYNC_FLUSH", i64(Z_SYNC_FLUSH)),
        ("Z_FULL_FLUSH", i64(Z_FULL_FLUSH)),
        ("Z_FINISH", i64(Z_FINISH)),
        ("Z_BLOCK", i64(Z_BLOCK)),
        ("Z_TREES", i64(Z_TREES))
    ];
    for (name, value) in constants {
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    if not add_owned(module, "ZLIB_VERSION", PyUnicode_FromString(ZLIB_VERSION))
        or not add_owned(module, "ZLIB_RUNTIME_VERSION", runtime_version())
        or not add_owned(module, "__version__", PyUnicode_FromString("1.0")) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "zlib",
         "The functions in this module allow compression and decompression using the\nzlib library, which is based on GNU zip.\n\nadler32(string[, start]) -- Compute an Adler-32 checksum.\ncompress(data[, level]) -- Compress data, with compression level 0-9 or -1.\ncompressobj([level[, ...]]) -- Return a compressor object.\ncrc32(string[, start]) -- Compute a CRC-32 checksum.\ndecompress(string,[wbits],[bufsize]) -- Decompresses a compressed string.\ndecompressobj([wbits[, zdict]]) -- Return a decompressor object.\n\n'wbits' is window buffer size and container format.\nCompressor objects support compress() and flush() methods; decompressor\nobjects support decompress() and flush().",
         module_methods,
         ModuleHooks(execute=execute),
         4
     );

def:pub PyInit_zlib -> ptr[PyObject] {
    return definition.initialize();
}
