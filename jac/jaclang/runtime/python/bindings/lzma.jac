"""The _lzma module: LZMACompressor, LZMADecompressor, LZMAError and the constants."""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    PyLong_FromLongLong,
    PyModule_Add,
    PyObject,
    PyTuple_New
}

import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception,
    jacpy_binding_state_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.lzma {
    LZMACompressor_methods,
    LZMADecompressor_methods,
    LZMADecompressor_doc,
    module_methods,
    _lzma_LZMADecompressor_new
}
import from jaclang.runtime.python.modules.lzma {
    COMPRESSOR_TYPE,
    DECOMPRESSOR_TYPE,
    EMPTY_TUPLE,
    FORMAT_ALONE,
    FORMAT_AUTO,
    FORMAT_RAW,
    FORMAT_XZ,
    LZMACompressor_token,
    LZMADecompressor_token,
    LZMA_CHECK_CRC32,
    LZMA_CHECK_CRC64,
    LZMA_CHECK_ID_MAX,
    LZMA_CHECK_NONE,
    LZMA_CHECK_SHA256,
    LZMA_CHECK_UNKNOWN,
    LZMA_ERROR,
    LZMA_FILTER_ARM,
    LZMA_FILTER_ARMTHUMB,
    LZMA_FILTER_DELTA,
    LZMA_FILTER_IA64,
    LZMA_FILTER_LZMA1,
    LZMA_FILTER_LZMA2,
    LZMA_FILTER_POWERPC,
    LZMA_FILTER_SPARC,
    LZMA_FILTER_X86,
    LZMA_MF_BT2,
    LZMA_MF_BT3,
    LZMA_MF_BT4,
    LZMA_MF_HC3,
    LZMA_MF_HC4,
    LZMA_MODE_FAST,
    LZMA_MODE_NORMAL,
    LZMA_PRESET_DEFAULT,
    LZMA_PRESET_EXTREME,
    lzma_compressor_new,
    lzma_encode_filter_properties
}
import from jaclang.runtime.python.bindings.members {
    MemberField,
    MemberType,
    record_clear
}

def:priv compressor_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, LZMACompressor_token.handle);
}

def:priv compressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, LZMACompressor_token.handle, visitor, context);
}

def:priv decompressor_dealloc(instance: ptr[PyObject]) {
    record_clear(jacpy_binding_record(instance, LZMADecompressor_token.handle), 16);
    dispose_payload(instance, LZMADecompressor_token.handle);
}

def:priv decompressor_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, LZMADecompressor_token.handle, visitor, context);
}

glob:priv compressor_doc: str = "LZMACompressor(format=FORMAT_XZ, check=-1, preset=None, filters=None)\n\nCreate a compressor object for compressing data incrementally.\n\nformat specifies the container format to use for the output. This can\nbe FORMAT_XZ (default), FORMAT_ALONE, or FORMAT_RAW.\n\ncheck specifies the integrity check to use. For FORMAT_XZ, the default\nis CHECK_CRC64. FORMAT_ALONE and FORMAT_RAW do not support integrity\nchecks; for these formats, check must be omitted, or be CHECK_NONE.\n\nThe settings used by the compressor can be specified either as a\npreset compression level (with the 'preset' argument), or in detail\nas a custom filter chain (with the 'filters' argument). For FORMAT_XZ\nand FORMAT_ALONE, the default is to use the PRESET_DEFAULT preset\nlevel. For FORMAT_RAW, the caller must always specify a filter chain;\nthe raw compressor does not support preset compression levels.\n\npreset (if provided) should be an integer in the range 0-9, optionally\nOR-ed with the constant PRESET_EXTREME.\n\nfilters (if provided) should be a sequence of dicts. Each dict should\nhave an entry for \"id\" indicating the ID of the filter, plus\nadditional entries for options to the filter.\n\nFor one-shot compression, use the compress() function instead.\n";

glob:priv compressor_type = TypeDefinition(
         "_lzma.LZMACompressor",
         compressor_doc,
         LZMACompressor_methods,
         u64(TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=lzma_compressor_new,
             dealloc=compressor_dealloc,
             traverse=compressor_traverse
         )
     ),
     decompressor_type = TypeDefinition(
         "_lzma.LZMADecompressor",
         LZMADecompressor_doc,
         LZMADecompressor_methods,
         u64(TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=_lzma_LZMADecompressor_new,
             dealloc=decompressor_dealloc,
             traverse=decompressor_traverse
         ),
         members=[
             MemberField(
                 "check",
                 MemberType.INT.value,
                 0,
                 readonly=True,
                 doc="ID of the integrity check used by the input stream."
             ),
             MemberField(
                 "eof",
                 MemberType.BOOL.value,
                 4,
                 readonly=True,
                 doc="True if the end-of-stream marker has been reached."
             ),
             MemberField(
                 "needs_input",
                 MemberType.BOOL.value,
                 5,
                 readonly=True,
                 doc="True if more input is needed before more decompressed data can be produced."
             ),
             MemberField(
                 "unused_data",
                 MemberType.OBJECT_EX.value,
                 8,
                 readonly=True,
                 doc="Data found after the end of the compressed stream."
             )
         ],
         record_size=16
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
    LZMACompressor_token.handle = compressor_type.handle;
    LZMADecompressor_token.handle = decompressor_type.handle;
    if not store(module, EMPTY_TUPLE, PyTuple_New(0)) {
        return i32(-1);
    }
    # Some of the constants are more than 32 bits wide, so they are added as
    # long long values.
    constants = [
        ("FORMAT_AUTO", i64(FORMAT_AUTO)),
        ("FORMAT_XZ", i64(FORMAT_XZ)),
        ("FORMAT_ALONE", i64(FORMAT_ALONE)),
        ("FORMAT_RAW", i64(FORMAT_RAW)),
        ("CHECK_NONE", i64(LZMA_CHECK_NONE)),
        ("CHECK_CRC32", i64(LZMA_CHECK_CRC32)),
        ("CHECK_CRC64", i64(LZMA_CHECK_CRC64)),
        ("CHECK_SHA256", i64(LZMA_CHECK_SHA256)),
        ("CHECK_ID_MAX", i64(LZMA_CHECK_ID_MAX)),
        ("CHECK_UNKNOWN", i64(LZMA_CHECK_UNKNOWN)),
        ("FILTER_LZMA1", i64(LZMA_FILTER_LZMA1)),
        ("FILTER_LZMA2", i64(LZMA_FILTER_LZMA2)),
        ("FILTER_DELTA", i64(LZMA_FILTER_DELTA)),
        ("FILTER_X86", i64(LZMA_FILTER_X86)),
        ("FILTER_IA64", i64(LZMA_FILTER_IA64)),
        ("FILTER_ARM", i64(LZMA_FILTER_ARM)),
        ("FILTER_ARMTHUMB", i64(LZMA_FILTER_ARMTHUMB)),
        ("FILTER_SPARC", i64(LZMA_FILTER_SPARC)),
        ("FILTER_POWERPC", i64(LZMA_FILTER_POWERPC)),
        ("MF_HC3", LZMA_MF_HC3),
        ("MF_HC4", LZMA_MF_HC4),
        ("MF_BT2", LZMA_MF_BT2),
        ("MF_BT3", LZMA_MF_BT3),
        ("MF_BT4", LZMA_MF_BT4),
        ("MODE_FAST", LZMA_MODE_FAST),
        ("MODE_NORMAL", LZMA_MODE_NORMAL),
        ("PRESET_DEFAULT", i64(LZMA_PRESET_DEFAULT)),
        ("PRESET_EXTREME", i64(LZMA_PRESET_EXTREME))
    ];
    for (name, value) in constants {
        if PyModule_Add(module, name, PyLong_FromLongLong(value)) < 0 {
            return i32(-1);
        }
    }
    if not add_state_owned(
        module,
        LZMA_ERROR,
        "LZMAError",
        jacpy_binding_exception("_lzma.LZMAError", NULL, "Call to liblzma failed.")
    )
        or not add_state_owned(
            module, COMPRESSOR_TYPE, "LZMACompressor", compressor_type.create(module)
        )
        or not add_state_owned(
            module,
            DECOMPRESSOR_TYPE,
            "LZMADecompressor",
            decompressor_type.create(module)
        ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv methods: list[MethodDefinition] = module_methods
         + [
             MethodDefinition(
                 "_encode_filter_properties",
                 MethodCallbacks(positional=lzma_encode_filter_properties),
                 "_encode_filter_properties($module, filter, /)\n--\n\nReturn a bytes object encoding the options (properties) of the filter specified by *filter* (a dict).\n\nThe result does not include the filter ID itself, only the options.",
                 8
             )
         ],
     definition = ModuleDefinition(
         "_lzma", "", methods, ModuleHooks(execute=execute), 4
     );

def:pub PyInit__lzma -> ptr[PyObject] {
    return definition.initialize();
}
