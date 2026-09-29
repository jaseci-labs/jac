"""Zstandard compressor, decompressor and dictionary objects.

Derived from CPython 3.14.6 Modules/_zstd/ (_zstdmodule.c, compressor.c,
decompressor.c, zstddict.c, buffer.h); see ../LICENSE.cpython. Each object
holds its zstd context in native state guarded by a PyMutex, as the C objects
do; the library runs with the GIL released. A ZstdDict caches one digested
compression dictionary per compression level and one digested decompression
dictionary.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_GetConstant,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    PyBytes_AsString,
    PyBytes_Size,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_EOFError,
    PyExc_OverflowError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyLong_AsInt,
    PyLong_AsSize_t,
    PyLong_AsUnsignedLongLong,
    PyLong_FromSize_t,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawCalloc,
    PyMem_RawFree,
    PyMutex,
    PyMutex_Lock,
    PyMutex_Unlock,
    PyDict_Next,
    PyObject,
    PyTuple_GetItem,
    PyTuple_Size,
    PyTuple_Type,
    PyType_GetModule,
    PyUnicode_FromFormat,
    _PyBytes_Resize,
    jacpy_buffer_new,
    jacpy_bytes_from_memory,
    jacpy_is_dict,
    jacpy_is_long,
    jacpy_memory_copy,
    jacpy_memory_move,
    jacpy_release,
    jacpy_type_check
}
import from jaclang.runtime.python.capi { boundary_failure, object_error }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    jacpy_binding_state_set,
    visit_reference
}
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.output_buffer { BlocksOutputBuffer, Cursor }
import from zstd {
    obj ZSTD_inBuffer {
        has src: ptr = ptr(),
            size: u64 = 0,
            pos: u64 = 0;
    }  obj ZSTD_outBuffer {
        has dst: ptr = ptr(),
            size: u64 = 0,
            pos: u64 = 0;
    }  obj ZSTD_bounds {
        has error: u64 = 0,
            lowerBound: i32 = 0,
            upperBound: i32 = 0;
    }  obj ZDICT_params_t {
        has compressionLevel: i32 = 0,
            notificationLevel: u32 = 0,
            dictID: u32 = 0;
    }  def ZSTD_versionNumber -> u32;  def ZSTD_versionString -> ptr[u8];  def ZSTD_defaultCLevel -> i32;  def ZSTD_minCLevel -> i32;  def ZSTD_maxCLevel -> i32;  def ZSTD_DStreamOutSize -> u64;  def ZSTD_isError(
        code: u64
    ) -> u32;  def ZSTD_getErrorName(code: u64) -> ptr[u8];  def ZSTD_compressBound(
        srcSize: u64
    ) -> u64;  def ZSTD_createCCtx -> ptr;  def ZSTD_freeCCtx(cctx: ptr) -> u64;  def ZSTD_CCtx_setParameter(
        cctx: ptr, param: i32, value: i32
    ) -> u64;  def ZSTD_CCtx_setPledgedSrcSize(cctx: ptr, pledgedSrcSize: u64) -> u64;  def ZSTD_CCtx_reset(
        cctx: ptr, reset: i32
    ) -> u64;  def ZSTD_CCtx_refCDict(cctx: ptr, cdict: ptr) -> u64;  def ZSTD_CCtx_loadDictionary(
        cctx: ptr, content: ptr, contentSize: u64
    ) -> u64;  def ZSTD_CCtx_refPrefix(
        cctx: ptr, prefix: ptr, prefixSize: u64
    ) -> u64;  def ZSTD_compressStream2(
        cctx: ptr, output: &mut ZSTD_outBuffer, source: &mut ZSTD_inBuffer, endOp: i32
    ) -> u64;  def ZSTD_createCDict(
        dictBuffer: ptr, dictSize: u64, compressionLevel: i32
    ) -> ptr;  def ZSTD_freeCDict(cdict: ptr) -> u64;  def ZSTD_createDCtx -> ptr;  def ZSTD_freeDCtx(
        dctx: ptr
    ) -> u64;  def ZSTD_DCtx_setParameter(dctx: ptr, param: i32, value: i32) -> u64;  def ZSTD_DCtx_reset(
        dctx: ptr, reset: i32
    ) -> u64;  def ZSTD_DCtx_refDDict(dctx: ptr, ddict: ptr) -> u64;  def ZSTD_DCtx_loadDictionary(
        dctx: ptr, content: ptr, contentSize: u64
    ) -> u64;  def ZSTD_DCtx_refPrefix(
        dctx: ptr, prefix: ptr, prefixSize: u64
    ) -> u64;  def ZSTD_decompressStream(
        dctx: ptr, output: &mut ZSTD_outBuffer, source: &mut ZSTD_inBuffer
    ) -> u64;  def ZSTD_createDDict(dictBuffer: ptr, dictSize: u64) -> ptr;  def ZSTD_freeDDict(
        ddict: ptr
    ) -> u64;  def ZSTD_getDictID_fromDict(content: ptr, contentSize: u64) -> u32;  def ZSTD_getDictID_fromFrame(
        src: ptr, srcSize: u64
    ) -> u32;  def ZSTD_findFrameCompressedSize(src: ptr, srcSize: u64) -> u64;  def ZSTD_getFrameContentSize(
        src: ptr, srcSize: u64
    ) -> u64;  def ZSTD_cParam_getBounds(cParam: i32) -> ZSTD_bounds;  def ZSTD_dParam_getBounds(
        dParam: i32
    ) -> ZSTD_bounds;  def ZDICT_trainFromBuffer(
        dictBuffer: ptr,
        dictBufferCapacity: u64,
        samplesBuffer: ptr,
        samplesSizes: ptr[u64],
        nbSamples: u32
    ) -> u64;  def ZDICT_finalizeDictionary(
        dstDictBuffer: ptr,
        maxDictSize: u64,
        dictContent: ptr,
        dictContentSize: u64,
        samplesBuffer: ptr,
        samplesSizes: ptr[u64],
        nbSamples: u32,
        parameters: ZDICT_params_t
    ) -> u64;  def ZDICT_isError(errorCode: u64) -> u32;
}

# zstd.h parameter and directive values.
glob ZSTD_c_compressionLevel: i32 = 100,
     ZSTD_c_windowLog: i32 = 101,
     ZSTD_c_hashLog: i32 = 102,
     ZSTD_c_chainLog: i32 = 103,
     ZSTD_c_searchLog: i32 = 104,
     ZSTD_c_minMatch: i32 = 105,
     ZSTD_c_targetLength: i32 = 106,
     ZSTD_c_strategy: i32 = 107,
     ZSTD_c_enableLongDistanceMatching: i32 = 160,
     ZSTD_c_ldmHashLog: i32 = 161,
     ZSTD_c_ldmMinMatch: i32 = 162,
     ZSTD_c_ldmBucketSizeLog: i32 = 163,
     ZSTD_c_ldmHashRateLog: i32 = 164,
     ZSTD_c_contentSizeFlag: i32 = 200,
     ZSTD_c_checksumFlag: i32 = 201,
     ZSTD_c_dictIDFlag: i32 = 202,
     ZSTD_c_nbWorkers: i32 = 400,
     ZSTD_c_jobSize: i32 = 401,
     ZSTD_c_overlapLog: i32 = 402,
     ZSTD_d_windowLogMax: i32 = 100,
     ZSTD_fast: i32 = 1,
     ZSTD_dfast: i32 = 2,
     ZSTD_greedy: i32 = 3,
     ZSTD_lazy: i32 = 4,
     ZSTD_lazy2: i32 = 5,
     ZSTD_btlazy2: i32 = 6,
     ZSTD_btopt: i32 = 7,
     ZSTD_btultra: i32 = 8,
     ZSTD_btultra2: i32 = 9,
     ZSTD_e_continue: i32 = 0,
     ZSTD_e_flush: i32 = 1,
     ZSTD_e_end: i32 = 2;

glob:priv ZSTD_reset_session_only: i32 = 1,
     ZSTD_CONTENTSIZE_UNKNOWN: u64 = 0xFFFFFFFFFFFFFFFF,
     ZSTD_CONTENTSIZE_ERROR: u64 = 0xFFFFFFFFFFFFFFFE,
     SIZE_MAX: u64 = 0xFFFFFFFFFFFFFFFF,
     SSIZE_MAX: u64 = 0x7FFFFFFFFFFFFFFF,
     UINT32_MAX: u64 = 0xFFFFFFFF,
     # Py_CONSTANT_EMPTY_BYTES
     EMPTY_BYTES: u32 = 8;

# Module state slots (_zstd_state).
glob ZSTD_DICT_TYPE: int = 0,
     ZSTD_COMPRESSOR_TYPE: int = 1,
     ZSTD_DECOMPRESSOR_TYPE: int = 2,
     ZSTD_ERROR: int = 3,
     C_PARAMETER_TYPE: int = 4,
     D_PARAMETER_TYPE: int = 5,
     STATE_SLOTS: int = 6;

glob ZstdDict_token = ClassToken(),
     ZstdCompressor_token = ClassToken(),
     ZstdDecompressor_token = ClassToken();

# dictionary_type
glob:priv DICT_TYPE_DIGESTED: i32 = 0,
     DICT_TYPE_UNDIGESTED: i32 = 1,
     DICT_TYPE_PREFIX: i32 = 2;

# error_type, indexing the message formats of set_zstd_error().
enum ZstdErrorKind {
    DECOMPRESS = 0,
    COMPRESS = 1,
    SET_PLEDGED_INPUT_SIZE = 2,
    LOAD_D_DICT = 3,
    LOAD_C_DICT = 4,
    GET_C_BOUNDS = 5,
    GET_D_BOUNDS = 6,
    SET_C_LEVEL = 7,
    TRAIN_DICT = 8,
    FINALIZE_DICT = 9
}

glob:priv ERROR_FORMATS: list[str] = [
         "Unable to decompress Zstandard data: %s",
         "Unable to compress Zstandard data: %s",
         "Unable to set pledged uncompressed content size: %s",
         "Unable to load Zstandard dictionary or prefix for decompression: %s",
         "Unable to load Zstandard dictionary or prefix for compression: %s",
         "Unable to get zstd compression parameter bounds: %s",
         "Unable to get zstd decompression parameter bounds: %s",
         "Unable to set zstd compression level: %s",
         "Unable to train the Zstandard dictionary: %s",
         "Unable to finalize the Zstandard dictionary: %s"
     ],
     # ParameterInfo lists: (parameter, name) for the error messages.
     CP_LIST: list[tuple[i32, str]] = [
         (ZSTD_c_compressionLevel, "compression_level"),
         (ZSTD_c_windowLog, "window_log"),
         (ZSTD_c_hashLog, "hash_log"),
         (ZSTD_c_chainLog, "chain_log"),
         (ZSTD_c_searchLog, "search_log"),
         (ZSTD_c_minMatch, "min_match"),
         (ZSTD_c_targetLength, "target_length"),
         (ZSTD_c_strategy, "strategy"),
         (ZSTD_c_enableLongDistanceMatching, "enable_long_distance_matching"),
         (ZSTD_c_ldmHashLog, "ldm_hash_log"),
         (ZSTD_c_ldmMinMatch, "ldm_min_match"),
         (ZSTD_c_ldmBucketSizeLog, "ldm_bucket_size_log"),
         (ZSTD_c_ldmHashRateLog, "ldm_hash_rate_log"),
         (ZSTD_c_contentSizeFlag, "content_size_flag"),
         (ZSTD_c_checksumFlag, "checksum_flag"),
         (ZSTD_c_dictIDFlag, "dict_id_flag"),
         (ZSTD_c_nbWorkers, "nb_workers"),
         (ZSTD_c_jobSize, "job_size"),
         (ZSTD_c_overlapLog, "overlap_log")
     ],
     DP_LIST: list[tuple[i32, str]] = [(ZSTD_d_windowLogMax, "window_log_max")];

def:priv is_error(code: u64) -> bool {
    return ZSTD_isError(code) != 0;
}

# The module a type of this module belongs to (PyType_GetModuleState).
def:priv module_of(instance: ptr[PyObject]) -> ptr[PyObject] {
    return PyType_GetModule(Py_TYPE(instance));
}

# set_zstd_error(): format the message and set ZstdError.
def:priv set_zstd_error(module: ptr[PyObject], kind: ZstdErrorKind, zstd_ret: u64) {
    if not module {
        return;
    }
    PyErr_Format(
        jacpy_binding_state_get(module, i64(ZSTD_ERROR)),
        ERROR_FORMATS[kind.value],
        ZSTD_getErrorName(zstd_ret)
    );
}

def:priv set_zstd_error_of(
    instance: ptr[PyObject], kind: ZstdErrorKind, zstd_ret: u64
) {
    set_zstd_error(module_of(instance), kind, zstd_ret);
}

def:priv set_zstd_message(instance: ptr[PyObject], message: str) {
    module = module_of(instance);
    if module {
        PyErr_SetString(jacpy_binding_state_get(module, i64(ZSTD_ERROR)), message);
    }
}

def:priv set_parameter_error(is_compress: bool, key_v: i32, value_v: i32) {
    entries = CP_LIST if is_compress else DP_LIST;
    kind = "compression" if is_compress else "decompression";
    name = f"unknown parameter (key {key_v})";
    for (parameter, parameter_name) in entries {
        if key_v == parameter {
            name = parameter_name;
            break;
        }
    }
    bounds = ZSTD_cParam_getBounds(key_v)
        if is_compress
        else ZSTD_dParam_getBounds(key_v);
    if is_error(bounds.error) {
        object_error(PyExc_ValueError, f"invalid {kind} parameter '{name}'");
        return;
    }
    object_error(
        PyExc_ValueError,
        f"{kind} parameter '{name}' received an illegal value {value_v}; "
            + f"the valid range is [{bounds.lowerBound}, {bounds.upperBound}]"
    );
}

# A PyMutex in raw memory, so its address stays put while threads park on it.
def:priv new_mutex -> ptr[PyMutex] {
    return ptr[PyMutex](PyMem_RawCalloc(1, 1));
}

# The output window of the blocks buffer as a ZSTD_outBuffer (buffer.h).
def:priv window(cursor: Cursor, out: &mut ZSTD_outBuffer) {
    out.dst = ptr(cursor.next_out);
    out.size = u64(cursor.avail_out);
    out.pos = 0;
}

def:priv output_init_and_grow(
    buffer: BlocksOutputBuffer, out: &mut ZSTD_outBuffer, max_length: i64
) -> bool {
    cursor = Cursor();
    if buffer.init_and_grow(max_length, cursor) < 0 {
        return False;
    }
    window(cursor, out);
    return True;
}

def:priv output_init_with_size(
    buffer: BlocksOutputBuffer,
    out: &mut ZSTD_outBuffer,
    max_length: i64,
    init_size: i64
) -> bool {
    block_size = init_size;
    if 0 <= max_length and max_length < init_size {
        block_size = max_length;
    }
    cursor = Cursor();
    if buffer.init_with_size(block_size, cursor) < 0 {
        return False;
    }
    buffer.max_length = max_length;
    window(cursor, out);
    return True;
}

def:priv output_grow(buffer: BlocksOutputBuffer, out: &mut ZSTD_outBuffer) -> bool {
    cursor = Cursor(avail_out=0);
    if buffer.grow(cursor) < 0 {
        return False;
    }
    window(cursor, out);
    return True;
}

def:priv output_finish(
    buffer: BlocksOutputBuffer, out: &mut ZSTD_outBuffer
) -> ptr[PyObject] {
    result = buffer.finish(i64(out.size - out.pos));
    if not result {
        buffer.discard();
    }
    return result;
}

# ----------------------------------------------------------------- ZstdDict

obj ZstdDictState(NativeState) {
    has d_dict: ptr = ptr(),
        # int(compressionLevel) -> ZSTD_CDict*
        c_dicts: dict[int, ptr] = {},
        dict_buffer: ptr = ptr(),
        dict_len: i64 = 0,
        dict_id: u32 = 0,
        lock: ptr[PyMutex] = ptr[PyMutex]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.d_dict {
            ZSTD_freeDDict(self.d_dict);
        }
        for cdict in self.c_dicts.values() {
            ZSTD_freeCDict(cdict);
        }
        PyMem_Free(self.dict_buffer);
        PyMem_RawFree(self.lock);
    }
}

def dict_of(instance: ptr[PyObject]) -> ZstdDictState | None {
    if jacpy_binding_native_present(instance, ZstdDict_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZstdDict_token.handle);
        if isinstance(state, ZstdDictState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "ZstdDict state is unavailable");
    return None;
}

def _zstd_ZstdDict_new_impl(
    type: ptr[PyObject], dict_content: BufferArgument, is_raw: bool
) -> ptr[PyObject] {
    # All dictionaries must be at least 8 bytes
    if dict_content.size() < 8 {
        object_error(
            PyExc_ValueError,
            "Zstandard dictionary content too short (must have at least eight bytes)"
        );
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = ZstdDictState(lock=new_mutex());
    if not state.lock {
        jacpy_release(instance);
        PyErr_NoMemory();
        return NULL;
    }
    if jacpy_binding_native_set(instance, ZstdDict_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    length = dict_content.size();
    state.dict_buffer = PyMem_Malloc(u64(length));
    if not state.dict_buffer {
        jacpy_release(instance);
        PyErr_NoMemory();
        return NULL;
    }
    jacpy_memory_copy(state.dict_buffer, dict_content.address(), length);
    state.dict_len = length;
    # Get dict_id, 0 means "raw content" dictionary.
    state.dict_id = ZSTD_getDictID_fromDict(state.dict_buffer, u64(length));
    # Check validity for ordinary dictionary
    if not is_raw and state.dict_id == 0 {
        jacpy_release(instance);
        object_error(PyExc_ValueError, "invalid Zstandard dictionary");
        return NULL;
    }
    return instance;
}

def zstd_dict_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = dict_of(instance);
    if state is None {
        return NULL;
    }
    return PyUnicode_FromFormat(
        "<ZstdDict dict_id=%u dict_size=%zd>", state.dict_id, state.dict_len
    );
}

def zstd_dict_length(instance: ptr[PyObject]) -> i64 {
    state = dict_of(instance);
    return state.dict_len if state is not None else -1;
}

def zstd_dict_id(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = dict_of(instance);
    return PyLong_FromSize_t(u64(state.dict_id)) if state is not None else NULL;
}

def _zstd_ZstdDict_dict_content_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = dict_of(receiver);
    if state is None {
        return NULL;
    }
    return jacpy_bytes_from_memory(state.dict_buffer, state.dict_len);
}

def _zstd_ZstdDict_as_digested_dict_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("Oi", receiver, DICT_TYPE_DIGESTED);
}

def _zstd_ZstdDict_as_undigested_dict_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_BuildValue("Oi", receiver, DICT_TYPE_UNDIGESTED);
}

def _zstd_ZstdDict_as_prefix_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue("Oi", receiver, DICT_TYPE_PREFIX);
}

# _Py_parse_zstd_dict(): the ZstdDict of a zstd_dict argument (borrowed) and
# its load type, which a (ZstdDict, type) pair selects; NULL with an error set.
def:priv parse_zstd_dict(
    module: ptr[PyObject], zstd_dict: ptr[PyObject], default_type: i32
) -> tuple[ptr[PyObject], i32] {
    if not module {
        return (NULL, default_type);
    }
    dict_type = jacpy_binding_state_get(module, i64(ZSTD_DICT_TYPE));
    if jacpy_type_check(zstd_dict, dict_type) != 0 {
        return (zstd_dict, default_type);
    }
    if Py_TYPE(zstd_dict) == addressof(PyTuple_Type)
        and PyTuple_Size(zstd_dict) == 2
        and jacpy_type_check(PyTuple_GetItem(zstd_dict, 0), dict_type) != 0
        and jacpy_is_long(PyTuple_GetItem(zstd_dict, 1)) != 0 {
        load_type = PyLong_AsInt(PyTuple_GetItem(zstd_dict, 1));
        if load_type == -1 and PyErr_Occurred() {
            return (NULL, default_type);
        }
        if load_type == DICT_TYPE_DIGESTED
            or load_type == DICT_TYPE_UNDIGESTED
            or load_type == DICT_TYPE_PREFIX {
            return (PyTuple_GetItem(zstd_dict, 0), load_type);
        }
    }
    object_error(PyExc_TypeError, "zstd_dict argument should be a ZstdDict object.");
    return (NULL, default_type);
}

# _get_CDict(): the digested compression dictionary for a level, created once
# and cached. The dictionary's lock is held.
def:priv get_cdict(
    instance: ptr[PyObject], zd: ZstdDictState, compression_level: i32
) -> ptr {
    level = int(compression_level);
    if level in zd.c_dicts {
        return zd.c_dicts[level];
    }
    content = zd.dict_buffer;
    length = u64(zd.dict_len);
    thread = PyEval_SaveThread();
    cdict = ZSTD_createCDict(content, length, compression_level);
    PyEval_RestoreThread(thread);
    if not cdict {
        set_zstd_message(
            instance,
            "Failed to create a ZSTD_CDict instance from Zstandard dictionary content."
        );
        return ptr();
    }
    zd.c_dicts[level] = cdict;
    return cdict;
}

# _get_DDict(): the digested decompression dictionary, created once. The
# dictionary's lock is held.
def:priv get_ddict(instance: ptr[PyObject], zd: ZstdDictState) -> ptr {
    if not zd.d_dict {
        content = zd.dict_buffer;
        length = u64(zd.dict_len);
        thread = PyEval_SaveThread();
        ddict = ZSTD_createDDict(content, length);
        PyEval_RestoreThread(thread);
        zd.d_dict = ddict;
        if not zd.d_dict {
            set_zstd_message(
                instance,
                "Failed to create a ZSTD_DDict instance from Zstandard dictionary content."
            );
        }
    }
    return zd.d_dict;
}

# ----------------------------------------------------------- ZstdCompressor

obj CompressorState(NativeState) {
    has cctx: ptr = ptr(),
        # ZstdDict object in use
        dict: ptr[PyObject] = NULL,
        # Last mode, initialized to ZSTD_e_end
        last_mode: i32 = ZSTD_e_end,
        use_multithread: bool = False,
        compression_level: i32 = 0,
        lock: ptr[PyMutex] = ptr[PyMutex]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.dict, visitor, context);
    }

    def clear {
        previous = self.dict;
        self.dict = NULL;
        jacpy_release(previous);
    }

    # The context may reference the dictionary's digested form, so it is
    # freed before the dictionary is released.
    def free_context {
        if self.cctx {
            ZSTD_freeCCtx(self.cctx);
            self.cctx = ptr();
        }
    }

    def drop {
        self.free_context();
        jacpy_release(self.dict);
        PyMem_RawFree(self.lock);
    }
}

def compressor_of(instance: ptr[PyObject]) -> CompressorState | None {
    if jacpy_binding_native_present(instance, ZstdCompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZstdCompressor_token.handle);
        if isinstance(state, CompressorState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "ZstdCompressor state is unavailable");
    return None;
}

# Free the context ahead of the payload's release, the dealloc order of
# compressor.c; no error when the state was never set.
def release_compressor_context(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, ZstdCompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZstdCompressor_token.handle);
        if isinstance(state, CompressorState) {
            state.free_context();
        }
    }
}

# zstd_contentsize_converter: None is an unknown size.
def convert_zstd_contentsize_converter(
    size: ptr[PyObject], fname: str, label: str
) -> u64 {
    if size == Py_None {
        return ZSTD_CONTENTSIZE_UNKNOWN;
    }
    pledged_size = PyLong_AsUnsignedLongLong(size);
    if pledged_size == SIZE_MAX and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            PyErr_Format(
                PyExc_ValueError,
                "size argument should be a positive int less than %llu",
                ZSTD_CONTENTSIZE_ERROR
            );
        }
        raise boundary_failure();
    }
    if pledged_size >= ZSTD_CONTENTSIZE_ERROR {
        PyErr_Format(
            PyExc_ValueError,
            "size argument should be a positive int less than %llu",
            ZSTD_CONTENTSIZE_ERROR
        );
        raise boundary_failure();
    }
    return pledged_size;
}

def:priv set_c_level(
    instance: ptr[PyObject], state: CompressorState, level: i32
) -> bool {
    min_level = ZSTD_minCLevel();
    max_level = ZSTD_maxCLevel();
    if level < min_level or level > max_level {
        object_error(
            PyExc_ValueError,
            f"illegal compression level {level}; the valid range is [{min_level}, {max_level}]"
        );
        return False;
    }
    # Save for generating ZSTD_CDICT
    state.compression_level = level;
    zstd_ret = ZSTD_CCtx_setParameter(state.cctx, ZSTD_c_compressionLevel, level);
    if is_error(zstd_ret) {
        set_zstd_error_of(instance, ZstdErrorKind.SET_C_LEVEL, zstd_ret);
        return False;
    }
    return True;
}

# Read one options entry as (key, value) C ints; the pair is retained while
# converting, since __index__ may mutate the dictionary.
def:priv option_values(
    key: ptr[PyObject], value: ptr[PyObject]
) -> tuple[bool, i32, i32] {
    Py_NewRef(key);
    Py_NewRef(value);
    key_v = PyLong_AsInt(key);
    jacpy_release(key);
    if key_v == -1 and PyErr_Occurred() {
        jacpy_release(value);
        return (False, key_v, i32(0));
    }
    value_v = PyLong_AsInt(value);
    jacpy_release(value);
    if value_v == -1 and PyErr_Occurred() {
        return (False, key_v, value_v);
    }
    return (True, key_v, value_v);
}

def:priv set_c_parameters(
    instance: ptr[PyObject], state: CompressorState, options: ptr[PyObject]
) -> bool {
    module = module_of(instance);
    if not module {
        return False;
    }
    if jacpy_is_dict(options) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "ZstdCompressor() argument 'options' must be dict, not %T",
            options
        );
        return False;
    }
    pos: i64 = 0;
    key = NULL;
    value = NULL;
    while PyDict_Next(options, &mut pos, &mut key, &mut value) != 0 {
        # Check key type
        if Py_TYPE(key) == jacpy_binding_state_get(module, i64(D_PARAMETER_TYPE)) {
            object_error(
                PyExc_TypeError,
                "compression options dictionary key must not be a DecompressionParameter attribute"
            );
            return False;
        }
        (ok, key_v, value_v) = option_values(key, value);
        if not ok {
            return False;
        }
        if key_v == ZSTD_c_compressionLevel {
            if not set_c_level(instance, state, value_v) {
                return False;
            }
            continue;
        }
        # nbWorkers >= 1 makes ZSTD_compressStream2() asynchronous.
        if key_v == ZSTD_c_nbWorkers and value_v != 0 {
            state.use_multithread = True;
        }
        zstd_ret = ZSTD_CCtx_setParameter(state.cctx, key_v, value_v);
        if is_error(zstd_ret) {
            set_parameter_error(True, key_v, value_v);
            return False;
        }
    }
    return True;
}

def:priv load_c_impl(
    instance: ptr[PyObject],
    state: CompressorState,
    zd_object: ptr[PyObject],
    zd: ZstdDictState,
    load_type: i32
) -> bool {
    zstd_ret: u64 = 0;
    if load_type == DICT_TYPE_DIGESTED {
        # Reference a prepared dictionary; it overrides some of the
        # context's parameters.
        c_dict = get_cdict(zd_object, zd, state.compression_level);
        if not c_dict {
            return False;
        }
        zstd_ret = ZSTD_CCtx_refCDict(state.cctx, c_dict);
    } elif load_type == DICT_TYPE_UNDIGESTED {
        zstd_ret = ZSTD_CCtx_loadDictionary(
            state.cctx, zd.dict_buffer, u64(zd.dict_len)
        );
    } else {
        zstd_ret = ZSTD_CCtx_refPrefix(state.cctx, zd.dict_buffer, u64(zd.dict_len));
    }
    if is_error(zstd_ret) {
        set_zstd_error_of(instance, ZstdErrorKind.LOAD_C_DICT, zstd_ret);
        return False;
    }
    return True;
}

def:priv load_c_dict(
    instance: ptr[PyObject], state: CompressorState, zstd_dict: ptr[PyObject]
) -> bool {
    # When compressing, use undigested dictionary by default.
    (zd_object, load_type) = parse_zstd_dict(
        module_of(instance), zstd_dict, DICT_TYPE_UNDIGESTED
    );
    if not zd_object {
        return False;
    }
    zd = dict_of(zd_object);
    if zd is None {
        return False;
    }
    PyMutex_Lock(zd.lock);
    ok = load_c_impl(instance, state, zd_object, zd, load_type);
    PyMutex_Unlock(zd.lock);
    return ok;
}

def _zstd_ZstdCompressor_new_impl(
    type: ptr[PyObject],
    level: ptr[PyObject],
    options: ptr[PyObject],
    zstd_dict: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = CompressorState(lock=new_mutex());
    if not state.lock {
        jacpy_release(instance);
        PyErr_NoMemory();
        return NULL;
    }
    if jacpy_binding_native_set(instance, ZstdCompressor_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    # Compression context
    state.cctx = ZSTD_createCCtx();
    if not state.cctx {
        set_zstd_message(instance, "Unable to create ZSTD_CCtx instance.");
        jacpy_release(instance);
        return NULL;
    }
    if level != Py_None and options != Py_None {
        object_error(PyExc_TypeError, "Only one of level or options should be used.");
        jacpy_release(instance);
        return NULL;
    }
    # Set compression level
    if level != Py_None {
        if jacpy_is_long(level) == 0 {
            object_error(PyExc_TypeError, "invalid type for level, expected int");
            jacpy_release(instance);
            return NULL;
        }
        level_v = PyLong_AsInt(level);
        if level_v == -1 and PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
                object_error(
                    PyExc_ValueError,
                    f"illegal compression level; the valid range is [{ZSTD_minCLevel()}, {ZSTD_maxCLevel()}]"
                );
            }
            jacpy_release(instance);
            return NULL;
        }
        if not set_c_level(instance, state, level_v) {
            jacpy_release(instance);
            return NULL;
        }
    }
    # Set options dictionary
    if options != Py_None and not set_c_parameters(instance, state, options) {
        jacpy_release(instance);
        return NULL;
    }
    # Load Zstandard dictionary to compression context
    if zstd_dict != Py_None {
        if not load_c_dict(instance, state, zstd_dict) {
            jacpy_release(instance);
            return NULL;
        }
        state.dict = Py_NewRef(zstd_dict);
    }
    return instance;
}

# The data a compress call reads: a buffer, or nothing when flushing.
obj CompressInput {
    has address: ptr = ptr(),
        size: i64 = 0,
        present: bool = False;
}

def:priv compress_lock_held(
    instance: ptr[PyObject],
    state: CompressorState,
    data: CompressInput,
    end_directive: i32
) -> ptr[PyObject] {
    source = ZSTD_inBuffer(src=data.address, size=u64(data.size), pos=0);
    out = ZSTD_outBuffer();
    buffer = BlocksOutputBuffer();
    # Calculate output buffer's size
    output_buffer_size = ZSTD_compressBound(source.size);
    if output_buffer_size > SSIZE_MAX {
        PyErr_NoMemory();
        return NULL;
    }
    if not output_init_with_size(buffer, &mut out, -1, i64(output_buffer_size)) {
        buffer.discard();
        return NULL;
    }
    # Without data the input is empty but not NULL.
    if not data.present {
        source.src = out.dst;
    }
    cctx = state.cctx;
    while True {
        thread = PyEval_SaveThread();
        zstd_ret = ZSTD_compressStream2(cctx, &mut out, &mut source, end_directive);
        PyEval_RestoreThread(thread);
        if is_error(zstd_ret) {
            set_zstd_error_of(instance, ZstdErrorKind.COMPRESS, zstd_ret);
            buffer.discard();
            return NULL;
        }
        # Finished
        if zstd_ret == 0 {
            break;
        }
        # Output buffer should be exhausted, grow the buffer.
        if out.pos == out.size and not output_grow(buffer, &mut out) {
            buffer.discard();
            return NULL;
        }
    }
    return output_finish(buffer, &mut out);
}

def:priv compress_mt_continue_lock_held(
    instance: ptr[PyObject], state: CompressorState, data: CompressInput
) -> ptr[PyObject] {
    source = ZSTD_inBuffer(src=data.address, size=u64(data.size), pos=0);
    out = ZSTD_outBuffer();
    buffer = BlocksOutputBuffer();
    if not output_init_and_grow(buffer, &mut out, -1) {
        buffer.discard();
        return NULL;
    }
    cctx = state.cctx;
    while True {
        thread = PyEval_SaveThread();
        zstd_ret = ZSTD_compressStream2(cctx, &mut out, &mut source, ZSTD_e_continue);
        while out.pos != out.size
            and source.pos != source.size
            and not is_error(zstd_ret) {
            zstd_ret = ZSTD_compressStream2(
                cctx, &mut out, &mut source, ZSTD_e_continue
            );
        }
        PyEval_RestoreThread(thread);
        if is_error(zstd_ret) {
            set_zstd_error_of(instance, ZstdErrorKind.COMPRESS, zstd_ret);
            buffer.discard();
            return NULL;
        }
        # Like compress_lock_held(), output as much as possible.
        if out.pos == out.size {
            if not output_grow(buffer, &mut out) {
                buffer.discard();
                return NULL;
            }
        } elif source.pos == source.size {
            break;
        }
    }
    return output_finish(buffer, &mut out);
}

# Record the mode after a compress or flush; a failure ends the frame and
# resets the session, which never fails.
def:priv settle_mode(state: CompressorState, result: ptr[PyObject], mode: i32) {
    if result {
        state.last_mode = mode;
    } else {
        state.last_mode = ZSTD_e_end;
        ZSTD_CCtx_reset(state.cctx, ZSTD_reset_session_only);
    }
}

def _zstd_ZstdCompressor_compress_impl(
    receiver: ptr[PyObject], data: BufferArgument, mode: i32
) -> ptr[PyObject] {
    if mode != ZSTD_e_continue and mode != ZSTD_e_flush and mode != ZSTD_e_end {
        object_error(
            PyExc_ValueError,
            "mode argument wrong value, it should be one of ZstdCompressor.CONTINUE, ZstdCompressor.FLUSH_BLOCK, ZstdCompressor.FLUSH_FRAME."
        );
        return NULL;
    }
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    source = CompressInput(address=data.address(), size=data.size(), present=True);
    PyMutex_Lock(state.lock);
    result = NULL;
    if state.use_multithread and mode == ZSTD_e_continue {
        result = compress_mt_continue_lock_held(receiver, state, source);
    } else {
        result = compress_lock_held(receiver, state, source, mode);
    }
    settle_mode(state, result, mode);
    PyMutex_Unlock(state.lock);
    return result;
}

def _zstd_ZstdCompressor_flush_impl(
    receiver: ptr[PyObject], mode: i32
) -> ptr[PyObject] {
    if mode != ZSTD_e_end and mode != ZSTD_e_flush {
        object_error(
            PyExc_ValueError,
            "mode argument wrong value, it should be ZstdCompressor.FLUSH_FRAME or ZstdCompressor.FLUSH_BLOCK."
        );
        return NULL;
    }
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    PyMutex_Lock(state.lock);
    result = compress_lock_held(receiver, state, CompressInput(), mode);
    settle_mode(state, result, mode);
    PyMutex_Unlock(state.lock);
    return result;
}

def _zstd_ZstdCompressor_set_pledged_input_size_impl(
    receiver: ptr[PyObject], size: u64
) -> ptr[PyObject] {
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    PyMutex_Lock(state.lock);
    # Check the current mode
    if state.last_mode != ZSTD_e_end {
        object_error(
            PyExc_ValueError,
            "set_pledged_input_size() method must be called when last_mode == FLUSH_FRAME"
        );
        PyMutex_Unlock(state.lock);
        return NULL;
    }
    zstd_ret = ZSTD_CCtx_setPledgedSrcSize(state.cctx, size);
    PyMutex_Unlock(state.lock);
    if is_error(zstd_ret) {
        set_zstd_error_of(receiver, ZstdErrorKind.SET_PLEDGED_INPUT_SIZE, zstd_ret);
        return NULL;
    }
    return Py_NewRef(Py_None);
}

# --------------------------------------------------------- ZstdDecompressor

obj DecompressorState(NativeState) {
    has dctx: ptr = ptr(),
        # ZstdDict object in use
        dict: ptr[PyObject] = NULL,
        # Unconsumed input data
        input_buffer: ptr = ptr(),
        input_buffer_size: u64 = 0,
        in_begin: u64 = 0,
        in_end: u64 = 0,
        # Unused data, made on first read after the end of a frame
        unused_data: ptr[PyObject] = NULL,
        # False if the decompressor has (or may have) unconsumed input data
        needs_input: bool = True,
        # True when the end of the first frame has been reached
        eof: bool = False,
        lock: ptr[PyMutex] = ptr[PyMutex]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.dict, visitor, context);
    }

    def clear {
        previous = self.dict;
        self.dict = NULL;
        jacpy_release(previous);
        previous = self.unused_data;
        self.unused_data = NULL;
        jacpy_release(previous);
    }

    # The context may reference the dictionary's digested form, so it is
    # freed before the dictionary is released.
    def free_context {
        if self.dctx {
            ZSTD_freeDCtx(self.dctx);
            self.dctx = ptr();
        }
    }

    def drop {
        self.free_context();
        jacpy_release(self.dict);
        PyMem_Free(self.input_buffer);
        jacpy_release(self.unused_data);
        PyMem_RawFree(self.lock);
    }
}

def decompressor_of(instance: ptr[PyObject]) -> DecompressorState | None {
    if jacpy_binding_native_present(instance, ZstdDecompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZstdDecompressor_token.handle);
        if isinstance(state, DecompressorState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "ZstdDecompressor state is unavailable");
    return None;
}

# Free the context ahead of the payload's release, the dealloc order of
# decompressor.c; no error when the state was never set.
def release_decompressor_context(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, ZstdDecompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZstdDecompressor_token.handle);
        if isinstance(state, DecompressorState) {
            state.free_context();
        }
    }
}

def:priv set_d_parameters(
    instance: ptr[PyObject], state: DecompressorState, options: ptr[PyObject]
) -> bool {
    module = module_of(instance);
    if not module {
        return False;
    }
    if jacpy_is_dict(options) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "ZstdDecompressor() argument 'options' must be dict, not %T",
            options
        );
        return False;
    }
    pos: i64 = 0;
    key = NULL;
    value = NULL;
    while PyDict_Next(options, &mut pos, &mut key, &mut value) != 0 {
        # Check key type
        if Py_TYPE(key) == jacpy_binding_state_get(module, i64(C_PARAMETER_TYPE)) {
            object_error(
                PyExc_TypeError,
                "decompression options dictionary key must not be a CompressionParameter attribute"
            );
            return False;
        }
        (ok, key_v, value_v) = option_values(key, value);
        if not ok {
            return False;
        }
        zstd_ret = ZSTD_DCtx_setParameter(state.dctx, key_v, value_v);
        if is_error(zstd_ret) {
            set_parameter_error(False, key_v, value_v);
            return False;
        }
    }
    return True;
}

def:priv load_d_impl(
    instance: ptr[PyObject],
    state: DecompressorState,
    zd_object: ptr[PyObject],
    zd: ZstdDictState,
    load_type: i32
) -> bool {
    zstd_ret: u64 = 0;
    if load_type == DICT_TYPE_DIGESTED {
        d_dict = get_ddict(zd_object, zd);
        if not d_dict {
            return False;
        }
        zstd_ret = ZSTD_DCtx_refDDict(state.dctx, d_dict);
    } elif load_type == DICT_TYPE_UNDIGESTED {
        zstd_ret = ZSTD_DCtx_loadDictionary(
            state.dctx, zd.dict_buffer, u64(zd.dict_len)
        );
    } else {
        zstd_ret = ZSTD_DCtx_refPrefix(state.dctx, zd.dict_buffer, u64(zd.dict_len));
    }
    if is_error(zstd_ret) {
        set_zstd_error_of(instance, ZstdErrorKind.LOAD_D_DICT, zstd_ret);
        return False;
    }
    return True;
}

# Load dictionary or prefix to decompression context
def:priv load_d_dict(
    instance: ptr[PyObject], state: DecompressorState, zstd_dict: ptr[PyObject]
) -> bool {
    # When decompressing, use digested dictionary by default.
    (zd_object, load_type) = parse_zstd_dict(
        module_of(instance), zstd_dict, DICT_TYPE_DIGESTED
    );
    if not zd_object {
        return False;
    }
    zd = dict_of(zd_object);
    if zd is None {
        return False;
    }
    PyMutex_Lock(zd.lock);
    ok = load_d_impl(instance, state, zd_object, zd, load_type);
    PyMutex_Unlock(zd.lock);
    return ok;
}

# ZSTD_decompressStream() returns 0 when a frame is completely decoded and
# flushed, an error code, or a positive count of work left in the frame.
def:priv decompress_lock_held(
    instance: ptr[PyObject],
    state: DecompressorState,
    source: &mut ZSTD_inBuffer,
    max_length: i64
) -> ptr[PyObject] {
    out = ZSTD_outBuffer();
    buffer = BlocksOutputBuffer();
    if not output_init_and_grow(buffer, &mut out, max_length) {
        buffer.discard();
        return NULL;
    }
    dctx = state.dctx;
    while True {
        thread = PyEval_SaveThread();
        zstd_ret = ZSTD_decompressStream(dctx, &mut out, source);
        PyEval_RestoreThread(thread);
        if is_error(zstd_ret) {
            set_zstd_error_of(instance, ZstdErrorKind.DECOMPRESS, zstd_ret);
            buffer.discard();
            return NULL;
        }
        # Stop when a frame is decompressed
        if zstd_ret == 0 {
            state.eof = True;
            break;
        }
        # Check the output before the input: zstd's internal buffer may still
        # hold output.
        if out.pos == out.size {
            if buffer.allocated == buffer.max_length {
                break;
            }
            if not output_grow(buffer, &mut out) {
                buffer.discard();
                return NULL;
            }
        } elif source.pos == source.size {
            break;
        }
    }
    return output_finish(buffer, &mut out);
}

def:priv reset_session_lock_held(state: DecompressorState) {
    state.in_begin = 0;
    state.in_end = 0;
    previous = state.unused_data;
    state.unused_data = NULL;
    jacpy_release(previous);
    state.needs_input = True;
    state.eof = False;
    # Resetting the session never fails
    ZSTD_DCtx_reset(state.dctx, ZSTD_reset_session_only);
}

def:priv stream_decompress_lock_held(
    instance: ptr[PyObject],
    state: DecompressorState,
    data: BufferArgument,
    max_length: i64
) -> ptr[PyObject] {
    if state.eof {
        object_error(PyExc_EOFError, "Already at the end of a Zstandard frame.");
        return NULL;
    }
    data_len = u64(data.size());
    source = ZSTD_inBuffer();
    use_input_buffer = False;
    if state.in_begin == state.in_end {
        # No unconsumed data
        source.src = data.address();
        source.size = data_len;
    } elif data_len == 0 {
        # Unconsumed data, fast path for b''
        use_input_buffer = True;
        source.src = state.input_buffer + i64(state.in_begin);
        source.size = state.in_end - state.in_begin;
    } else {
        use_input_buffer = True;
        # Unconsumed data size in input_buffer
        used_now = state.in_end - state.in_begin;
        # Bytes that can be appended to the input buffer
        avail_now = state.input_buffer_size - state.in_end;
        # Bytes that can be appended after moving the contents to the start
        avail_total = state.input_buffer_size - used_now;
        if avail_total < data_len {
            new_size = used_now + data_len;
            grown = PyMem_Malloc(new_size);
            if not grown {
                PyErr_NoMemory();
                reset_session_lock_held(state);
                return NULL;
            }
            jacpy_memory_copy(
                grown, state.input_buffer + i64(state.in_begin), i64(used_now)
            );
            PyMem_Free(state.input_buffer);
            state.input_buffer = grown;
            state.input_buffer_size = new_size;
            state.in_begin = 0;
            state.in_end = used_now;
        } elif avail_now < data_len {
            # Move unconsumed data to the beginning; the ranges may overlap.
            jacpy_memory_move(
                state.input_buffer,
                state.input_buffer + i64(state.in_begin),
                i64(used_now)
            );
            state.in_begin = 0;
            state.in_end = used_now;
        }
        jacpy_memory_copy(
            state.input_buffer + i64(state.in_end), data.address(), i64(data_len)
        );
        state.in_end += data_len;
        source.src = state.input_buffer + i64(state.in_begin);
        source.size = used_now + data_len;
    }
    result = decompress_lock_held(instance, state, &mut source, max_length);
    if not result {
        reset_session_lock_held(state);
        return NULL;
    }
    if source.pos == source.size {
        # All input consumed
        state.needs_input = not (PyBytes_Size(result) == max_length or state.eof);
        if use_input_buffer {
            state.in_begin = 0;
            state.in_end = 0;
        }
    } else {
        data_size = source.size - source.pos;
        state.needs_input = False;
        if not use_input_buffer {
            # Discard a buffer too small for the rest (resizing it may copy
            # its contents needlessly)
            if state.input_buffer and state.input_buffer_size < data_size {
                PyMem_Free(state.input_buffer);
                state.input_buffer = ptr();
                state.input_buffer_size = 0;
            }
            if not state.input_buffer {
                state.input_buffer = PyMem_Malloc(data_size);
                if not state.input_buffer {
                    PyErr_NoMemory();
                    reset_session_lock_held(state);
                    jacpy_release(result);
                    return NULL;
                }
                state.input_buffer_size = data_size;
            }
            jacpy_memory_copy(
                state.input_buffer, source.src + i64(source.pos), i64(data_size)
            );
            state.in_begin = 0;
            state.in_end = data_size;
        } else {
            state.in_begin += source.pos;
        }
    }
    return result;
}

def _zstd_ZstdDecompressor_new_impl(
    type: ptr[PyObject], zstd_dict: ptr[PyObject], options: ptr[PyObject]
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = DecompressorState(lock=new_mutex());
    if not state.lock {
        jacpy_release(instance);
        PyErr_NoMemory();
        return NULL;
    }
    if jacpy_binding_native_set(instance, ZstdDecompressor_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    # Decompression context
    state.dctx = ZSTD_createDCtx();
    if not state.dctx {
        set_zstd_message(instance, "Unable to create ZSTD_DCtx instance.");
        jacpy_release(instance);
        return NULL;
    }
    # Load Zstandard dictionary to decompression context
    if zstd_dict != Py_None {
        if not load_d_dict(instance, state, zstd_dict) {
            jacpy_release(instance);
            return NULL;
        }
        state.dict = Py_NewRef(zstd_dict);
    }
    # Set options dictionary
    if options != Py_None and not set_d_parameters(instance, state, options) {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def _zstd_ZstdDecompressor_unused_data_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    state = decompressor_of(receiver);
    if state is None {
        return NULL;
    }
    PyMutex_Lock(state.lock);
    if not state.eof {
        PyMutex_Unlock(state.lock);
        return Py_GetConstant(EMPTY_BYTES);
    }
    if not state.unused_data {
        state.unused_data = jacpy_bytes_from_memory(
            state.input_buffer + i64(state.in_begin), i64(state.in_end - state.in_begin)
        );
    }
    result = state.unused_data;
    if result {
        Py_NewRef(result);
    }
    PyMutex_Unlock(state.lock);
    return result;
}

def _zstd_ZstdDecompressor_decompress_impl(
    receiver: ptr[PyObject], data: BufferArgument, max_length: i64
) -> ptr[PyObject] {
    state = decompressor_of(receiver);
    if state is None {
        return NULL;
    }
    PyMutex_Lock(state.lock);
    result = stream_decompress_lock_held(receiver, state, data, max_length);
    PyMutex_Unlock(state.lock);
    return result;
}

# --------------------------------------------------------- module functions

# calculate_samples_stats(): the sample count and a PyMem array of the sample
# sizes (NULL on failure, else the caller frees it), or -1 with an error set.
def:priv samples_stats(
    samples_bytes: ptr[PyObject], samples_sizes: ptr[PyObject]
) -> tuple[i64, ptr[u64]] {
    chunks_number = PyTuple_Size(samples_sizes);
    if u64(chunks_number) > UINT32_MAX {
        PyErr_Format(
            PyExc_ValueError, "The number of samples should be <= %u.", u32(UINT32_MAX)
        );
        return (-1, ptr[u64]());
    }
    # PyMem_New(size_t, chunks_number)
    chunk_sizes = ptr[u64]();
    if chunks_number <= i64(SSIZE_MAX // 8) {
        chunk_sizes = ptr[u64](PyMem_Malloc(u64(chunks_number) * 8));
    }
    if not chunk_sizes {
        PyErr_NoMemory();
        return (-1, chunk_sizes);
    }
    sizes_sum = u64(PyBytes_Size(samples_bytes));
    mismatch = False;
    for index in range(int(chunks_number)) {
        size = PyLong_AsSize_t(PyTuple_GetItem(samples_sizes, i64(index)));
        (chunk_sizes + index).view(1)[0] = size;
        if size == SIZE_MAX and PyErr_Occurred() {
            if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
                mismatch = True;
                break;
            }
            return (-1, chunk_sizes);
        }
        if sizes_sum < size {
            mismatch = True;
            break;
        }
        sizes_sum -= size;
    }
    if mismatch or sizes_sum != 0 {
        object_error(
            PyExc_ValueError,
            "The samples size tuple doesn't match the concatenation's size."
        );
        return (-1, chunk_sizes);
    }
    return (chunks_number, chunk_sizes);
}

def _zstd_train_dict_impl(
    module: ptr[PyObject],
    samples_bytes: ptr[PyObject],
    samples_sizes: ptr[PyObject],
    dict_size: i64
) -> ptr[PyObject] {
    if dict_size <= 0 {
        object_error(PyExc_ValueError, "dict_size argument should be positive number.");
        return NULL;
    }
    (chunks_number, chunk_sizes) = samples_stats(samples_bytes, samples_sizes);
    if chunks_number < 0 {
        PyMem_Free(chunk_sizes);
        return NULL;
    }
    dst_dict_bytes = jacpy_buffer_new(dict_size);
    if not dst_dict_bytes {
        PyMem_Free(chunk_sizes);
        return NULL;
    }
    dst_dict_buffer = PyBytes_AsString(dst_dict_bytes);
    samples_buffer = PyBytes_AsString(samples_bytes);
    thread = PyEval_SaveThread();
    zstd_ret = ZDICT_trainFromBuffer(
        dst_dict_buffer, u64(dict_size), samples_buffer, chunk_sizes, u32(chunks_number)
    );
    PyEval_RestoreThread(thread);
    PyMem_Free(chunk_sizes);
    if ZDICT_isError(zstd_ret) != 0 {
        set_zstd_error(module, ZstdErrorKind.TRAIN_DICT, zstd_ret);
        jacpy_release(dst_dict_bytes);
        return NULL;
    }
    # Resize dict_buffer
    if _PyBytes_Resize(&mut dst_dict_bytes, i64(zstd_ret)) < 0 {
        return NULL;
    }
    return dst_dict_bytes;
}

def _zstd_finalize_dict_impl(
    module: ptr[PyObject],
    custom_dict_bytes: ptr[PyObject],
    samples_bytes: ptr[PyObject],
    samples_sizes: ptr[PyObject],
    dict_size: i64,
    compression_level: i32
) -> ptr[PyObject] {
    if dict_size <= 0 {
        object_error(PyExc_ValueError, "dict_size argument should be positive number.");
        return NULL;
    }
    (chunks_number, chunk_sizes) = samples_stats(samples_bytes, samples_sizes);
    if chunks_number < 0 {
        PyMem_Free(chunk_sizes);
        return NULL;
    }
    dst_dict_bytes = jacpy_buffer_new(dict_size);
    if not dst_dict_bytes {
        PyMem_Free(chunk_sizes);
        return NULL;
    }
    # Optimize for a specific level (0 is the default), no notifications,
    # and an automatic (random) dictionary id.
    params = ZDICT_params_t(
        compressionLevel=compression_level, notificationLevel=0, dictID=0
    );
    dst_dict_buffer = PyBytes_AsString(dst_dict_bytes);
    custom_buffer = PyBytes_AsString(custom_dict_bytes);
    custom_size = u64(PyBytes_Size(custom_dict_bytes));
    samples_buffer = PyBytes_AsString(samples_bytes);
    thread = PyEval_SaveThread();
    zstd_ret = ZDICT_finalizeDictionary(
        dst_dict_buffer,
        u64(dict_size),
        custom_buffer,
        custom_size,
        samples_buffer,
        chunk_sizes,
        u32(chunks_number),
        params
    );
    PyEval_RestoreThread(thread);
    PyMem_Free(chunk_sizes);
    if ZDICT_isError(zstd_ret) != 0 {
        set_zstd_error(module, ZstdErrorKind.FINALIZE_DICT, zstd_ret);
        jacpy_release(dst_dict_bytes);
        return NULL;
    }
    # Resize dict_buffer
    if _PyBytes_Resize(&mut dst_dict_bytes, i64(zstd_ret)) < 0 {
        return NULL;
    }
    return dst_dict_bytes;
}

def _zstd_get_param_bounds_impl(
    module: ptr[PyObject], parameter: i32, is_compress: bool
) -> ptr[PyObject] {
    bound = ZSTD_bounds();
    if is_compress {
        bound = ZSTD_cParam_getBounds(parameter);
        if is_error(bound.error) {
            set_zstd_error(module, ZstdErrorKind.GET_C_BOUNDS, bound.error);
            return NULL;
        }
    } else {
        bound = ZSTD_dParam_getBounds(parameter);
        if is_error(bound.error) {
            set_zstd_error(module, ZstdErrorKind.GET_D_BOUNDS, bound.error);
            return NULL;
        }
    }
    return Py_BuildValue("ii", bound.lowerBound, bound.upperBound);
}

def _zstd_get_frame_size_impl(
    module: ptr[PyObject], frame_buffer: BufferArgument
) -> ptr[PyObject] {
    frame_size = ZSTD_findFrameCompressedSize(
        frame_buffer.address(), u64(frame_buffer.size())
    );
    if is_error(frame_size) {
        PyErr_Format(
            jacpy_binding_state_get(module, i64(ZSTD_ERROR)),
            "Error when finding the compressed size of a Zstandard frame. Ensure the frame_buffer argument starts from the beginning of a frame, and its length is not less than this complete frame. Zstd error message: %s.",
            ZSTD_getErrorName(frame_size)
        );
        return NULL;
    }
    return PyLong_FromSize_t(frame_size);
}

def _zstd_get_frame_info_impl(
    module: ptr[PyObject], frame_buffer: BufferArgument
) -> ptr[PyObject] {
    decompressed_size = ZSTD_getFrameContentSize(
        frame_buffer.address(), u64(frame_buffer.size())
    );
    if decompressed_size == ZSTD_CONTENTSIZE_ERROR {
        PyErr_SetString(
            jacpy_binding_state_get(module, i64(ZSTD_ERROR)),
            "Error when getting information from the header of a Zstandard frame. Ensure the frame_buffer argument starts from the beginning of a frame, and its length is not less than the frame header (6~18 bytes)."
        );
        return NULL;
    }
    dict_id = ZSTD_getDictID_fromFrame(
        frame_buffer.address(), u64(frame_buffer.size())
    );
    if decompressed_size == ZSTD_CONTENTSIZE_UNKNOWN {
        return Py_BuildValue("OI", Py_None, dict_id);
    }
    return Py_BuildValue("KI", decompressed_size, dict_id);
}

def _zstd_set_parameter_types_impl(
    module: ptr[PyObject],
    c_parameter_type: ptr[PyObject],
    d_parameter_type: ptr[PyObject]
) -> ptr[PyObject] {
    jacpy_binding_state_set(module, i64(C_PARAMETER_TYPE), c_parameter_type);
    jacpy_binding_state_set(module, i64(D_PARAMETER_TYPE), d_parameter_type);
    return Py_NewRef(Py_None);
}

# The library's version and defaults, for the module constants.
def zstd_version_number -> i64 {
    return i64(ZSTD_versionNumber());
}

def zstd_version -> ptr[u8] {
    return ZSTD_versionString();
}

def zstd_default_level -> i64 {
    return i64(ZSTD_defaultCLevel());
}

def zstd_dstream_out_size -> u64 {
    return ZSTD_DStreamOutSize();
}
