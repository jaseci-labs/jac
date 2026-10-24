def:priv dict_dealloc(instance: ptr[PyObject]);

def:priv dict_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def:priv dict_clear(instance: ptr[PyObject]) -> i32;

def:priv dict_id(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv compressor_dealloc(instance: ptr[PyObject]);

def:priv compressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32;

def:priv compressor_clear(instance: ptr[PyObject]) -> i32;

def:priv last_mode(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv decompressor_dealloc(instance: ptr[PyObject]);

def:priv decompressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32;

def:priv decompressor_clear(instance: ptr[PyObject]) -> i32;

def:priv eof(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def:priv needs_input(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

glob:priv dict_type = TypeDefinition(
         "compression.zstd.ZstdDict",
         ZstdDict_doc,
         [],
         u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
         TypeHooks(
             create=_zstd_ZstdDict_new_new,
             dealloc=dict_dealloc,
             traverse=dict_traverse,
             clear=dict_clear,
             repr=zstd_dict_repr,
             length=zstd_dict_length
         ),
         [
             PropertyDefinition(
                 "dict_id",
                 PropertyCallbacks(read=dict_id),
                 0,
                 "The Zstandard dictionary, an int between 0 and 2**32.\n\nA non-zero value represents an ordinary Zstandard dictionary,\nconforming to the standardised format.\n\nA value of zero indicates a 'raw content' dictionary,\nwithout any restrictions on format or content."
             )
         ]
             + ZstdDict_getset
     ),
     compressor_type = TypeDefinition(
         "compression.zstd.ZstdCompressor",
         ZstdCompressor_doc,
         ZstdCompressor_methods,
         u64(TypeFlags.GC.value),
         TypeHooks(
             create=_zstd_ZstdCompressor_new_new,
             dealloc=compressor_dealloc,
             traverse=compressor_traverse,
             clear=compressor_clear
         ),
         [
             PropertyDefinition(
                 "last_mode",
                 PropertyCallbacks(read=last_mode),
                 0,
                 "The last mode used to this compressor object, its value can be .CONTINUE,\n.FLUSH_BLOCK, .FLUSH_FRAME. Initialized to .FLUSH_FRAME.\n\nIt can be used to get the current state of a compressor, such as, data\nflushed, or a frame ended."
             )
         ]
     ),
     decompressor_type = TypeDefinition(
         "compression.zstd.ZstdDecompressor",
         ZstdDecompressor_doc,
         ZstdDecompressor_methods,
         u64(TypeFlags.IMMUTABLE.value | TypeFlags.GC.value),
         TypeHooks(
             create=_zstd_ZstdDecompressor_new_new,
             dealloc=decompressor_dealloc,
             traverse=decompressor_traverse,
             clear=decompressor_clear
         ),
         [
             PropertyDefinition(
                 "eof",
                 PropertyCallbacks(read=eof),
                 0,
                 "True means the end of the first frame has been reached. If decompress data\nafter that, an EOFError exception will be raised."
             ),
             PropertyDefinition(
                 "needs_input",
                 PropertyCallbacks(read=needs_input),
                 0,
                 "If the max_length output limit in .decompress() method has been reached,\nand the decompressor has (or may has) unconsumed input data, it will be set\nto False. In this case, passing b'' to the .decompress() method may output\nfurther data."
             )
         ]
             + ZstdDecompressor_getset
     );

def:priv set_type_constant(type: ptr[PyObject], name: str, value: i32) -> bool;

def:priv execute(module: ptr[PyObject]) -> i32;

glob:priv definition = ModuleDefinition(
         "_zstd",
         "Implementation module for Zstandard compression.",
         module_methods,
         ModuleHooks(execute=execute),
         STATE_SLOTS
     );

def:pub PyInit__zstd -> ptr[PyObject];

impl dict_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, ZstdDict_token.handle);
}

impl dict_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, ZstdDict_token.handle, visitor, context);
}

impl dict_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, ZstdDict_token.handle);
}

impl dict_id(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return zstd_dict_id(instance);
}

impl compressor_dealloc(instance: ptr[PyObject]) {
    release_compressor_context(instance);
    dispose_payload(instance, ZstdCompressor_token.handle);
}

impl compressor_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, ZstdCompressor_token.handle, visitor, context);
}

impl compressor_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, ZstdCompressor_token.handle);
}

impl last_mode(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = compressor_of(instance);
    return PyLong_FromLong(i64(state.last_mode)) if state is not None else NULL;
}

impl decompressor_dealloc(instance: ptr[PyObject]) {
    release_decompressor_context(instance);
    dispose_payload(instance, ZstdDecompressor_token.handle);
}

impl decompressor_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, ZstdDecompressor_token.handle, visitor, context);
}

impl decompressor_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, ZstdDecompressor_token.handle);
}

impl eof(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = decompressor_of(instance);
    return PyBool_FromLong(i64(state.eof)) if state is not None else NULL;
}

impl needs_input(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = decompressor_of(instance);
    return PyBool_FromLong(i64(state.needs_input)) if state is not None else NULL;
}

impl set_type_constant(type: ptr[PyObject], name: str, value: i32) -> bool {
    number = PyLong_FromLong(i64(value));
    if not number {
        return False;
    }
    status = jacpy_object_setattr_text(type, name, number);
    jacpy_release(number);
    return status == 0;
}

impl execute(module: ptr[PyObject]) -> i32 {
    ZstdDict_token.handle = dict_type.handle;
    ZstdCompressor_token.handle = compressor_type.handle;
    ZstdDecompressor_token.handle = decompressor_type.handle;
    if not add_state_owned(module, ZSTD_DICT_TYPE, "ZstdDict", dict_type.create(module))
        or not add_state_owned(
            module,
            ZSTD_COMPRESSOR_TYPE,
            "ZstdCompressor",
            compressor_type.create(module)
        )
        or not add_state_owned(
            module,
            ZSTD_DECOMPRESSOR_TYPE,
            "ZstdDecompressor",
            decompressor_type.create(module)
        )
        or not add_state_owned(
            module,
            ZSTD_ERROR,
            "ZstdError",
            jacpy_binding_exception(
                "compression.zstd.ZstdError",
                NULL,
                "An error occurred in the zstd library."
            )
        ) {
        return i32(-1);
    }
    if PyModule_AddIntConstant(module, "zstd_version_number", zstd_version_number()) < 0
        or not add_owned(module, "zstd_version", c_string_text(zstd_version()))
        or PyModule_AddIntConstant(module, "ZSTD_CLEVEL_DEFAULT", zstd_default_level())
            < 0
        or not add_owned(
            module, "ZSTD_DStreamOutSize", PyLong_FromSize_t(zstd_dstream_out_size())
        ) {
        return i32(-1);
    }

    constants = [
        ("ZSTD_c_compressionLevel", ZSTD_c_compressionLevel),
        ("ZSTD_c_windowLog", ZSTD_c_windowLog),
        ("ZSTD_c_hashLog", ZSTD_c_hashLog),
        ("ZSTD_c_chainLog", ZSTD_c_chainLog),
        ("ZSTD_c_searchLog", ZSTD_c_searchLog),
        ("ZSTD_c_minMatch", ZSTD_c_minMatch),
        ("ZSTD_c_targetLength", ZSTD_c_targetLength),
        ("ZSTD_c_strategy", ZSTD_c_strategy),
        ("ZSTD_c_enableLongDistanceMatching", ZSTD_c_enableLongDistanceMatching),
        ("ZSTD_c_ldmHashLog", ZSTD_c_ldmHashLog),
        ("ZSTD_c_ldmMinMatch", ZSTD_c_ldmMinMatch),
        ("ZSTD_c_ldmBucketSizeLog", ZSTD_c_ldmBucketSizeLog),
        ("ZSTD_c_ldmHashRateLog", ZSTD_c_ldmHashRateLog),
        ("ZSTD_c_contentSizeFlag", ZSTD_c_contentSizeFlag),
        ("ZSTD_c_checksumFlag", ZSTD_c_checksumFlag),
        ("ZSTD_c_dictIDFlag", ZSTD_c_dictIDFlag),
        ("ZSTD_c_nbWorkers", ZSTD_c_nbWorkers),
        ("ZSTD_c_jobSize", ZSTD_c_jobSize),
        ("ZSTD_c_overlapLog", ZSTD_c_overlapLog),
        ("ZSTD_d_windowLogMax", ZSTD_d_windowLogMax),
        ("ZSTD_fast", ZSTD_fast),
        ("ZSTD_dfast", ZSTD_dfast),
        ("ZSTD_greedy", ZSTD_greedy),
        ("ZSTD_lazy", ZSTD_lazy),
        ("ZSTD_lazy2", ZSTD_lazy2),
        ("ZSTD_btlazy2", ZSTD_btlazy2),
        ("ZSTD_btopt", ZSTD_btopt),
        ("ZSTD_btultra", ZSTD_btultra),
        ("ZSTD_btultra2", ZSTD_btultra2)
    ];
    for (name, value) in constants {
        if PyModule_AddIntConstant(module, name, i64(value)) < 0 {
            return i32(-1);
        }
    }

    compressor = jacpy_binding_state_get(module, i64(ZSTD_COMPRESSOR_TYPE));
    if not set_type_constant(compressor, "CONTINUE", ZSTD_e_continue)
        or not set_type_constant(compressor, "FLUSH_BLOCK", ZSTD_e_flush)
        or not set_type_constant(compressor, "FLUSH_FRAME", ZSTD_e_end) {
        return i32(-1);
    }
    PyType_Freeze(compressor);
    return i32(0);
}

impl PyInit__zstd -> ptr[PyObject] {
    return definition.initialize();
}
