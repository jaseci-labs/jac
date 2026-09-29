"""liblzma compressor and decompressor objects and filter specifiers.

Derived from CPython 3.14.6 Modules/_lzmamodule.c; see ../LICENSE.cpython.
liblzma keeps pointers into each lzma_stream between calls, so every stream is
pinned. lzma_code() runs with the GIL released, so the streams allocate through
one allocator record over PyMem_RawMalloc()/PyMem_RawFree().
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_None,
    Py_TYPE,
    PyBytes_AsString,
    PyDict_Keys,
    PyDict_New,
    PyDict_SetItem,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetNone,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_EOFError,
    PyExc_MemoryError,
    PyExc_OverflowError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyLong_AsNativeBytes,
    PyLong_FromUnsignedLongLong,
    PyList_GetItem,
    PyList_Size,
    PyMapping_Check,
    PyMapping_GetOptionalItemString,
    PyMem_Calloc,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyMem_RawMalloc,
    PyMem_Realloc,
    PyObject,
    PySequence_GetItem,
    PySequence_Size,
    PyThread_acquire_lock,
    PyThread_allocate_lock,
    PyThread_free_lock,
    PyThread_release_lock,
    PyType_GetModule,
    PyUnicode_EqualToUTF8,
    PyUnicode_InternFromString,
    _PyLong_UInt32_Converter,
    _PyLong_UInt64_Converter,
    jacpy_buffer_new,
    jacpy_is_dict,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_memory_move,
    jacpy_release
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.capi { boundary_failure, object_error }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_state_get }
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.output_buffer { BlocksOutputBuffer, Cursor }
import from lzma {
    obj lzma_allocator {
        has alloc: Callable[[ptr, u64, u64], ptr] = 0,
            free: Callable[[ptr, ptr], None] = 0,
            opaque: ptr = ptr();
    }  obj lzma_stream {
        has next_in: ptr[u8] = ptr[u8](),
            avail_in: u64 = 0,
            total_in: u64 = 0,
            next_out: ptr[u8] = ptr[u8](),
            avail_out: u64 = 0,
            total_out: u64 = 0,
            allocator: ptr[lzma_allocator] = ptr[lzma_allocator](),
            internal: ptr = ptr(),
            reserved_ptr1: ptr = ptr(),
            reserved_ptr2: ptr = ptr(),
            reserved_ptr3: ptr = ptr(),
            reserved_ptr4: ptr = ptr(),
            seek_pos: u64 = 0,
            reserved_int2: u64 = 0,
            reserved_int3: u64 = 0,
            reserved_int4: u64 = 0,
            reserved_enum1: u32 = 0,
            reserved_enum2: u32 = 0;
    }  obj lzma_filter {
        has id: u64 = 0,
            options: ptr = ptr();
    }  obj lzma_options_lzma {
        has dict_size: u32 = 0,
            preset_dict: ptr[u8] = ptr[u8](),
            preset_dict_size: u32 = 0,
            lc: u32 = 0,
            lp: u32 = 0,
            pb: u32 = 0,
            mode: u32 = 0,
            nice_len: u32 = 0,
            mf: u32 = 0,
            depth: u32 = 0,
            ext_flags: u32 = 0,
            ext_size_low: u32 = 0,
            ext_size_high: u32 = 0,
            reserved_int4: u32 = 0,
            reserved_int5: u32 = 0,
            reserved_int6: u32 = 0,
            reserved_int7: u32 = 0,
            reserved_int8: u32 = 0,
            reserved_enum1: u32 = 0,
            reserved_enum2: u32 = 0,
            reserved_enum3: u32 = 0,
            reserved_enum4: u32 = 0,
            reserved_ptr1: ptr = ptr(),
            reserved_ptr2: ptr = ptr();
    }  obj lzma_options_delta {
        has type: u32 = 0,
            dist: u32 = 0,
            reserved_int1: u32 = 0,
            reserved_int2: u32 = 0,
            reserved_int3: u32 = 0,
            reserved_int4: u32 = 0,
            reserved_ptr1: ptr = ptr(),
            reserved_ptr2: ptr = ptr();
    }  obj lzma_options_bcj {
        has start_offset: u32 = 0;
    }  def lzma_code(strm: &mut Pinned[lzma_stream], action: i32) -> i32;  def lzma_end(
        strm: &mut Pinned[lzma_stream]
    );  def lzma_get_check(strm: &mut Pinned[lzma_stream]) -> i32;  def lzma_easy_encoder(
        strm: &mut Pinned[lzma_stream], preset: u32, check: i32
    ) -> i32;  def lzma_stream_encoder(
        strm: &mut Pinned[lzma_stream], filters: ptr[lzma_filter], check: i32
    ) -> i32;  def lzma_alone_encoder(
        strm: &mut Pinned[lzma_stream], options: ptr[lzma_options_lzma]
    ) -> i32;  def lzma_raw_encoder(
        strm: &mut Pinned[lzma_stream], filters: ptr[lzma_filter]
    ) -> i32;  def lzma_raw_decoder(
        strm: &mut Pinned[lzma_stream], filters: ptr[lzma_filter]
    ) -> i32;  def lzma_auto_decoder(
        strm: &mut Pinned[lzma_stream], memlimit: u64, flags: u32
    ) -> i32;  def lzma_stream_decoder(
        strm: &mut Pinned[lzma_stream], memlimit: u64, flags: u32
    ) -> i32;  def lzma_alone_decoder(
        strm: &mut Pinned[lzma_stream], memlimit: u64
    ) -> i32;  def lzma_lzma_preset(
        options: ptr[lzma_options_lzma], preset: u32
    ) -> u8;  def lzma_check_is_supported(check: i32) -> u8;  def lzma_properties_size(
        size: &mut u32, filter: ptr[lzma_filter]
    ) -> i32;  def lzma_properties_encode(
        filter: ptr[lzma_filter], props: ptr[u8]
    ) -> i32;  def lzma_properties_decode(
        filter: ptr[lzma_filter], allocator: ptr, props: ptr, props_size: u64
    ) -> i32;
}

import from c { def free(address: ptr);  }

# Container formats.
glob FORMAT_AUTO: i32 = 0,
     FORMAT_XZ: i32 = 1,
     FORMAT_ALONE: i32 = 2,
     FORMAT_RAW: i32 = 3;

# lzma.h (xz 5.8.1) constants the module publishes.
glob LZMA_CHECK_NONE: i32 = 0,
     LZMA_CHECK_CRC32: i32 = 1,
     LZMA_CHECK_CRC64: i32 = 4,
     LZMA_CHECK_SHA256: i32 = 10,
     LZMA_CHECK_ID_MAX: i32 = 15,
     LZMA_CHECK_UNKNOWN: i32 = 16,
     LZMA_FILTER_LZMA1: u64 = 0x4000000000000001,
     LZMA_FILTER_LZMA2: u64 = 0x21,
     LZMA_FILTER_DELTA: u64 = 0x03,
     LZMA_FILTER_X86: u64 = 0x04,
     LZMA_FILTER_POWERPC: u64 = 0x05,
     LZMA_FILTER_IA64: u64 = 0x06,
     LZMA_FILTER_ARM: u64 = 0x07,
     LZMA_FILTER_ARMTHUMB: u64 = 0x08,
     LZMA_FILTER_SPARC: u64 = 0x09,
     LZMA_MF_HC3: i64 = 0x03,
     LZMA_MF_HC4: i64 = 0x04,
     LZMA_MF_BT2: i64 = 0x12,
     LZMA_MF_BT3: i64 = 0x13,
     LZMA_MF_BT4: i64 = 0x14,
     LZMA_MODE_FAST: i64 = 1,
     LZMA_MODE_NORMAL: i64 = 2,
     LZMA_PRESET_DEFAULT: u32 = 6,
     LZMA_PRESET_EXTREME: u32 = 0x80000000;

# Module state slots, in the order the binding fills them.
glob COMPRESSOR_TYPE: int = 0,
     DECOMPRESSOR_TYPE: int = 1,
     LZMA_ERROR: int = 2,
     EMPTY_TUPLE: int = 3;

glob LZMACompressor_token = ClassToken(),
     LZMADecompressor_token = ClassToken();

glob:priv LZMA_OK: i32 = 0,
     LZMA_STREAM_END: i32 = 1,
     LZMA_NO_CHECK: i32 = 2,
     LZMA_UNSUPPORTED_CHECK: i32 = 3,
     LZMA_GET_CHECK: i32 = 4,
     LZMA_MEM_ERROR: i32 = 5,
     LZMA_MEMLIMIT_ERROR: i32 = 6,
     LZMA_FORMAT_ERROR: i32 = 7,
     LZMA_OPTIONS_ERROR: i32 = 8,
     LZMA_DATA_ERROR: i32 = 9,
     LZMA_BUF_ERROR: i32 = 10,
     LZMA_PROG_ERROR: i32 = 11,
     LZMA_RUN: i32 = 0,
     LZMA_FINISH: i32 = 3,
     LZMA_VLI_UNKNOWN: u64 = 0xFFFFFFFFFFFFFFFF,
     LZMA_FILTERS_MAX: int = 4,
     LZMA_DELTA_TYPE_BYTE: u32 = 0,
     LZMA_TELL_NO_CHECK: u32 = 0x01,
     LZMA_TELL_ANY_CHECK: u32 = 0x04,
     LZMA_FILTER_SIZE: u64 = 16,
     LZMA_OPTIONS_LZMA_SIZE: u64 = 112,
     LZMA_OPTIONS_DELTA_SIZE: u64 = 40,
     LZMA_OPTIONS_BCJ_SIZE: u64 = 4,
     UINT64_MAX: u64 = 0xFFFFFFFFFFFFFFFF,
     SSIZE_MAX: u64 = 0x7FFFFFFFFFFFFFFF,
     # Py_ASNATIVEBYTES_NATIVE_ENDIAN | UNSIGNED_BUFFER | REJECT_NEGATIVE
     # | ALLOW_INDEX
     NATIVE_UNSIGNED: i32 = 31;

# PyLzma_Malloc() / PyLzma_Free(): PyMem_Malloc() cannot be used, because the
# GIL is not held when lzma_code() is called.
def:priv lzma_malloc(opaque: ptr, items: u64, size: u64) -> ptr {
    if size != 0 and items > SSIZE_MAX // size {
        return ptr();
    }
    return PyMem_RawMalloc(items * size);
}

def:priv lzma_free(opaque: ptr, address: ptr) {
    PyMem_RawFree(address);
}

import from c {
    glob:priv lzma_allocator_record: lzma_allocator = lzma_allocator(
             alloc=lzma_malloc, free=lzma_free
         );
}
import from jaclang.runtime.python.bindings.members {
    record_set_byte,
    record_set_int,
    record_set_object
}

def:priv new_stream -> Pinned[lzma_stream] {
    return pin(lzma_stream(allocator=addressof(lzma_allocator_record)));
}

def:priv error_of(module: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, LZMA_ERROR);
}

# The LZMAError of the module that defines `instance`'s type.
def:priv instance_error(instance: ptr[PyObject]) -> ptr[PyObject] {
    return error_of(PyType_GetModule(Py_TYPE(instance)));
}

# catch_lzma_error(): True when `lzret` is a failure, with the error set.
def:priv catch_lzma_error(error: ptr[PyObject], lzret: i32) -> bool {
    if lzret == LZMA_OK
        or lzret == LZMA_GET_CHECK
        or lzret == LZMA_NO_CHECK
        or lzret == LZMA_STREAM_END {
        return False;
    }
    if lzret == LZMA_UNSUPPORTED_CHECK {
        object_error(error, "Unsupported integrity check");
    } elif lzret == LZMA_MEM_ERROR {
        PyErr_NoMemory();
    } elif lzret == LZMA_MEMLIMIT_ERROR {
        object_error(error, "Memory usage limit exceeded");
    } elif lzret == LZMA_FORMAT_ERROR {
        object_error(error, "Input format not supported by decoder");
    } elif lzret == LZMA_OPTIONS_ERROR {
        object_error(error, "Invalid or unsupported options");
    } elif lzret == LZMA_DATA_ERROR {
        object_error(error, "Corrupt input data");
    } elif lzret == LZMA_BUF_ERROR {
        object_error(error, "Insufficient buffer space");
    } elif lzret == LZMA_PROG_ERROR {
        object_error(error, "Internal error");
    } else {
        object_error(error, f"Unrecognized error from liblzma: {lzret}");
    }
    return True;
}

def:priv lock_acquire(lock: ptr) {
    if PyThread_acquire_lock(lock, 0) == 0 {
        thread = PyEval_SaveThread();
        PyThread_acquire_lock(lock, 1);
        PyEval_RestoreThread(thread);
    }
}

# INT_TYPE_CONVERTER_FUNC(): an unsigned C integer of `size` bytes at
# `target`, rejecting negative values and values wider than the C type.
def:priv native_unsigned(
    value: ptr[PyObject], target: ptr, size: i64, kind: str
) -> bool {
    written = PyLong_AsNativeBytes(value, target, size, NATIVE_UNSIGNED);
    if written < 0 {
        return False;
    }
    if written > size {
        object_error(PyExc_OverflowError, f"Python int too large for C {kind}");
        return False;
    }
    return True;
}

def:priv lzma_vli_converter(value: ptr[PyObject], target: ptr[u64]) -> bool {
    return native_unsigned(value, target, 8, "lzma_vli");
}

def:priv lzma_mode_converter(value: ptr[PyObject], target: ptr[u32]) -> bool {
    return native_unsigned(value, target, 4, "lzma_mode");
}

def:priv lzma_mf_converter(value: ptr[PyObject], target: ptr[u32]) -> bool {
    return native_unsigned(value, target, 4, "lzma_match_finder");
}

# The clinic converter for `lzma_vli` parameters.
def convert_lzma_vli_converter(value: ptr[PyObject], fname: str, label: str) -> u64 {
    cell = ptr[u64](PyMem_Calloc(1, 8));
    if cell.is_null() {
        PyErr_NoMemory();
        raise boundary_failure();
    }
    ok = lzma_vli_converter(value, cell);
    result = cell.view(1)[0];
    PyMem_Free(cell);
    if not ok {
        raise boundary_failure();
    }
    return result;
}

def:priv uint32_option(value: ptr[PyObject], target: ptr[u32]) -> bool {
    if value.is_null() {
        return True;
    }
    converted: u32 = 0;
    if _PyLong_UInt32_Converter(value, &mut converted) == 0 {
        return False;
    }
    target.view(1)[0] = converted;
    return True;
}

# The keyword arguments of `spec` for PyArg_ParseTupleAndKeywords(), as the
# object format units see them; None when parsing failed.
# Whether every key of the dict `spec` is a str naming one of `names`, so
# parsing it cannot fail; the caller replaces any failure with its own error.
def:priv known_keywords(spec: ptr[PyObject], names: list[str]) -> bool {
    keys = PyDict_Keys(spec);
    if not keys {
        return False;
    }
    known = True;
    for index in range(int(PyList_Size(keys))) {
        key = PyList_GetItem(keys, i64(index));
        found = False;
        if jacpy_is_unicode(key) != 0 {
            for name in names {
                if PyUnicode_EqualToUTF8(key, name) != 0 {
                    found = True;
                    break;
                }
            }
        }
        if not found {
            known = False;
            break;
        }
    }
    jacpy_release(keys);
    return known;
}

def:priv spec_arguments(
    empty_tuple: ptr[PyObject], spec: ptr[PyObject], units: str, names: list[str]
) -> (list[ptr[PyObject]] | None) {
    if jacpy_is_dict(spec) == 0 or not known_keywords(spec, names) {
        return None;
    }
    try {
        values = ArgumentFormat().parse_keywords(empty_tuple, spec, units, names);
    } except boundary_failure {
        return None;
    }
    return [value.object if value.given else NULL for value in values];
}

# Filter specifier parsing: Python dicts into the lzma_filter records
# liblzma expects.
def:priv parse_filter_spec_lzma(
    error: ptr[PyObject], empty_tuple: ptr[PyObject], spec: ptr[PyObject]
) -> ptr {
    preset: u32 = LZMA_PRESET_DEFAULT;
    # First, fill in default values for all the options using a preset.
    # Then, override the defaults with any values given by the caller.
    preset_obj = NULL;
    if PyMapping_GetOptionalItemString(spec, "preset", &mut preset_obj) < 0 {
        return ptr();
    }
    if preset_obj {
        ok = _PyLong_UInt32_Converter(preset_obj, &mut preset);
        jacpy_release(preset_obj);
        if ok == 0 {
            return ptr();
        }
    }
    options = ptr[lzma_options_lzma](PyMem_Calloc(1, LZMA_OPTIONS_LZMA_SIZE));
    if options.is_null() {
        PyErr_NoMemory();
        return ptr();
    }
    if lzma_lzma_preset(options, preset) != 0 {
        PyMem_Free(options);
        object_error(error, f"Invalid compression preset: {preset}");
        return ptr();
    }
    values = spec_arguments(
        empty_tuple,
        spec,
        "|OOOOOOOOOO",
        [
            "id",
            "preset",
            "dict_size",
            "lc",
            "lp",
            "pb",
            "mode",
            "nice_len",
            "mf",
            "depth"
        ]
    );
    record = options.view(1);
    parsed = values is not None;
    if parsed {
        dict_size = record[0].dict_size;
        lc = record[0].lc;
        lp = record[0].lp;
        pb = record[0].pb;
        mode = record[0].mode;
        nice_len = record[0].nice_len;
        mf = record[0].mf;
        depth = record[0].depth;
        fields = ptr[u32](PyMem_Calloc(8, 4));
        if fields.is_null() {
            PyMem_Free(options);
            PyErr_NoMemory();
            return ptr();
        }
        cells = fields.view(8);
        cells[0] = dict_size;
        cells[1] = lc;
        cells[2] = lp;
        cells[3] = pb;
        cells[4] = mode;
        cells[5] = nice_len;
        cells[6] = mf;
        cells[7] = depth;
        parsed = uint32_option(values[2], fields)
            and uint32_option(values[3], fields + 1)
            and uint32_option(values[4], fields + 2)
            and uint32_option(values[5], fields + 3)
            and (values[6].is_null() or lzma_mode_converter(values[6], fields + 4))
            and uint32_option(values[7], fields + 5)
            and (values[8].is_null() or lzma_mf_converter(values[8], fields + 6))
            and uint32_option(values[9], fields + 7);
        record[0].dict_size = cells[0];
        record[0].lc = cells[1];
        record[0].lp = cells[2];
        record[0].pb = cells[3];
        record[0].mode = cells[4];
        record[0].nice_len = cells[5];
        record[0].mf = cells[6];
        record[0].depth = cells[7];
        PyMem_Free(fields);
    }
    if not parsed {
        object_error(PyExc_ValueError, "Invalid filter specifier for LZMA filter");
        PyMem_Free(options);
        return ptr();
    }
    return options;
}

def:priv parse_filter_spec_delta(
    error: ptr[PyObject], empty_tuple: ptr[PyObject], spec: ptr[PyObject]
) -> ptr {
    dist: u32 = 1;
    values = spec_arguments(empty_tuple, spec, "|OO", ["id", "dist"]);
    if values is None
        or (
            not values[1].is_null()
            and _PyLong_UInt32_Converter(values[1], &mut dist) == 0
        ) {
        object_error(PyExc_ValueError, "Invalid filter specifier for delta filter");
        return ptr();
    }
    options = ptr[lzma_options_delta](PyMem_Calloc(1, LZMA_OPTIONS_DELTA_SIZE));
    if options.is_null() {
        PyErr_NoMemory();
        return ptr();
    }
    options.view(1)[0].type = LZMA_DELTA_TYPE_BYTE;
    options.view(1)[0].dist = dist;
    return options;
}

def:priv parse_filter_spec_bcj(
    error: ptr[PyObject], empty_tuple: ptr[PyObject], spec: ptr[PyObject]
) -> ptr {
    start_offset: u32 = 0;
    values = spec_arguments(empty_tuple, spec, "|OO", ["id", "start_offset"]);
    if values is None
        or (
            not values[1].is_null()
            and _PyLong_UInt32_Converter(values[1], &mut start_offset) == 0
        ) {
        object_error(PyExc_ValueError, "Invalid filter specifier for BCJ filter");
        return ptr();
    }
    options = ptr[lzma_options_bcj](PyMem_Calloc(1, LZMA_OPTIONS_BCJ_SIZE));
    if options.is_null() {
        PyErr_NoMemory();
        return ptr();
    }
    options.view(1)[0].start_offset = start_offset;
    return options;
}

def:priv is_bcj(id: u64) -> bool {
    return id == LZMA_FILTER_X86
        or id == LZMA_FILTER_POWERPC
        or id == LZMA_FILTER_IA64
        or id == LZMA_FILTER_ARM
        or id == LZMA_FILTER_ARMTHUMB
        or id == LZMA_FILTER_SPARC;
}

# lzma_filter_converter(): one filter specifier into the record at `filter`.
def lzma_filter_converter(
    module: ptr[PyObject], spec: ptr[PyObject], filter: ptr[lzma_filter]
) -> bool {
    if PyMapping_Check(spec) == 0 {
        object_error(
            PyExc_TypeError, "Filter specifier must be a dict or dict-like object"
        );
        return False;
    }
    id_obj = NULL;
    if PyMapping_GetOptionalItemString(spec, "id", &mut id_obj) < 0 {
        return False;
    }
    if not id_obj {
        object_error(PyExc_ValueError, "Filter specifier must have an \"id\" entry");
        return False;
    }
    cell = ptr[u64](PyMem_Calloc(1, 8));
    if cell.is_null() {
        jacpy_release(id_obj);
        PyErr_NoMemory();
        return False;
    }
    ok = lzma_vli_converter(id_obj, cell);
    id = cell.view(1)[0];
    PyMem_Free(cell);
    jacpy_release(id_obj);
    if not ok {
        return False;
    }
    filter.view(1)[0].id = id;
    error = error_of(module);
    empty_tuple = jacpy_binding_state_get(module, EMPTY_TUPLE);
    options = ptr();
    if id == LZMA_FILTER_LZMA1 or id == LZMA_FILTER_LZMA2 {
        options = parse_filter_spec_lzma(error, empty_tuple, spec);
    } elif id == LZMA_FILTER_DELTA {
        options = parse_filter_spec_delta(error, empty_tuple, spec);
    } elif is_bcj(id) {
        options = parse_filter_spec_bcj(error, empty_tuple, spec);
    } else {
        object_error(PyExc_ValueError, f"Invalid filter ID: {id}");
        return False;
    }
    filter.view(1)[0].options = options;
    return not options.is_null();
}

def:priv free_filter_chain(filters: ptr[lzma_filter]) {
    chain = filters.view(LZMA_FILTERS_MAX + 1);
    index = 0;
    while chain[index].id != LZMA_VLI_UNKNOWN {
        PyMem_Free(chain[index].options);
        index += 1;
    }
}

# A filter array of LZMA_FILTERS_MAX + 1 records; the caller frees it.
def:priv new_filter_chain -> ptr[lzma_filter] {
    filters = ptr[lzma_filter](
        PyMem_Calloc(u64(LZMA_FILTERS_MAX + 1), LZMA_FILTER_SIZE)
    );
    if filters.is_null() {
        PyErr_NoMemory();
    }
    return filters;
}

def:priv parse_filter_chain_spec(
    module: ptr[PyObject], filters: ptr[lzma_filter], filterspecs: ptr[PyObject]
) -> bool {
    num_filters = PySequence_Size(filterspecs);
    if num_filters == -1 {
        return False;
    }
    if num_filters > LZMA_FILTERS_MAX {
        object_error(
            PyExc_ValueError,
            f"Too many filters - liblzma supports a maximum of {LZMA_FILTERS_MAX}"
        );
        return False;
    }
    chain = filters.view(LZMA_FILTERS_MAX + 1);
    for index in range(int(num_filters)) {
        spec = PySequence_GetItem(filterspecs, i64(index));
        ok = not spec.is_null()
            and lzma_filter_converter(module, spec, filters + index);
        jacpy_release(spec);
        if not ok {
            chain[index].id = LZMA_VLI_UNKNOWN;
            free_filter_chain(filters);
            return False;
        }
    }
    chain[int(num_filters)].id = LZMA_VLI_UNKNOWN;
    return True;
}

def:priv spec_add_field(spec: ptr[PyObject], key: str, value: u64) -> bool {
    value_object = PyLong_FromUnsignedLongLong(value);
    if not value_object {
        return False;
    }
    key_object = PyUnicode_InternFromString(key);
    if not key_object {
        jacpy_release(value_object);
        return False;
    }
    status = PyDict_SetItem(spec, key_object, value_object);
    jacpy_release(key_object);
    jacpy_release(value_object);
    return status == 0;
}

# build_filter_spec(): the Python filter specifier of the record at `filter`.
def:priv build_filter_spec(filter: ptr[lzma_filter]) -> ptr[PyObject] {
    spec = PyDict_New();
    if not spec {
        return NULL;
    }
    id = filter.view(1)[0].id;
    options = filter.view(1)[0].options;
    ok = spec_add_field(spec, "id", id);
    # For LZMA1 filters, lzma_properties_{encode,decode}() only look at the
    # lc, lp, pb, and dict_size fields. For LZMA2 filters, only the
    # dict_size field is used.
    if ok and id == LZMA_FILTER_LZMA1 {
        record = ptr[lzma_options_lzma](options).view(1);
        ok = spec_add_field(spec, "lc", u64(record[0].lc))
            and spec_add_field(spec, "lp", u64(record[0].lp))
            and spec_add_field(spec, "pb", u64(record[0].pb))
            and spec_add_field(spec, "dict_size", u64(record[0].dict_size));
    } elif ok and id == LZMA_FILTER_LZMA2 {
        record = ptr[lzma_options_lzma](options).view(1);
        ok = spec_add_field(spec, "dict_size", u64(record[0].dict_size));
    } elif ok and id == LZMA_FILTER_DELTA {
        delta = ptr[lzma_options_delta](options).view(1);
        ok = spec_add_field(spec, "dist", u64(delta[0].dist));
    } elif ok and is_bcj(id) {
        if not options.is_null() {
            bcj = ptr[lzma_options_bcj](options).view(1);
            ok = spec_add_field(spec, "start_offset", u64(bcj[0].start_offset));
        }
    } elif ok {
        object_error(PyExc_ValueError, f"Invalid filter ID: {id}");
        ok = False;
    }
    if not ok {
        jacpy_release(spec);
        return NULL;
    }
    return spec;
}

# LZMACompressor class.

obj CompressorState(NativeState) {
    has lzs: Pinned[lzma_stream],
        flushed: bool = False,
        lock: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        lzma_end(&mut self.lzs);
        if self.lock {
            PyThread_free_lock(self.lock);
        }
    }
}

def:priv sync_out(lzs: &mut Pinned[lzma_stream], cursor: Cursor) {
    lzs.value.next_out = cursor.next_out;
    lzs.value.avail_out = u64(cursor.avail_out);
}

def:priv compress(
    receiver: ptr[PyObject], state: CompressorState, data: ptr, length: i64, action: i32
) -> ptr[PyObject] {
    error = instance_error(receiver);
    buffer = BlocksOutputBuffer();
    cursor = Cursor();
    if buffer.init_and_grow(-1, cursor) < 0 {
        buffer.discard();
        return NULL;
    }
    sync_out(&mut state.lzs, cursor);
    state.lzs.value.next_in = ptr[u8](data);
    state.lzs.value.avail_in = u64(length);
    while True {
        thread = PyEval_SaveThread();
        lzret = lzma_code(&mut state.lzs, action);
        PyEval_RestoreThread(thread);
        if lzret == LZMA_BUF_ERROR and length == 0 and state.lzs.value.avail_out > 0 {
            # That wasn't a real error.
            lzret = LZMA_OK;
        }
        if catch_lzma_error(error, lzret) {
            buffer.discard();
            return NULL;
        }
        if (action == LZMA_RUN and state.lzs.value.avail_in == 0)
            or (action == LZMA_FINISH and lzret == LZMA_STREAM_END) {
            break;
        } elif state.lzs.value.avail_out == 0 {
            cursor = Cursor(avail_out=0);
            if buffer.grow(cursor) < 0 {
                buffer.discard();
                return NULL;
            }
            sync_out(&mut state.lzs, cursor);
        }
    }
    result = buffer.finish(i64(state.lzs.value.avail_out));
    if not result {
        buffer.discard();
    }
    return result;
}

def:priv compressor_of(instance: ptr[PyObject]) -> CompressorState | None {
    if jacpy_binding_native_present(instance, LZMACompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, LZMACompressor_token.handle);
        if isinstance(state, CompressorState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "LZMACompressor state is unavailable");
    return None;
}

def _lzma_LZMACompressor_compress_impl(
    receiver: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject] {
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    result = NULL;
    lock_acquire(state.lock);
    if state.flushed {
        object_error(PyExc_ValueError, "Compressor has been flushed");
    } else {
        result = compress(receiver, state, data.address(), data.size(), LZMA_RUN);
    }
    PyThread_release_lock(state.lock);
    return result;
}

def _lzma_LZMACompressor_flush_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    result = NULL;
    lock_acquire(state.lock);
    if state.flushed {
        object_error(PyExc_ValueError, "Repeated call to flush()");
    } else {
        state.flushed = True;
        result = compress(receiver, state, ptr(), 0, LZMA_FINISH);
    }
    PyThread_release_lock(state.lock);
    return result;
}

def:priv compressor_init_xz(
    module: ptr[PyObject],
    lzs: &mut Pinned[lzma_stream],
    check: i32,
    preset: u32,
    filterspecs: ptr[PyObject]
) -> bool {
    lzret = LZMA_OK;
    if filterspecs == Py_None {
        lzret = lzma_easy_encoder(lzs, preset, check);
    } else {
        filters = new_filter_chain();
        if filters.is_null() {
            return False;
        }
        if not parse_filter_chain_spec(module, filters, filterspecs) {
            PyMem_Free(filters);
            return False;
        }
        lzret = lzma_stream_encoder(lzs, filters, check);
        free_filter_chain(filters);
        PyMem_Free(filters);
    }
    return not catch_lzma_error(error_of(module), lzret);
}

def:priv compressor_init_alone(
    module: ptr[PyObject],
    lzs: &mut Pinned[lzma_stream],
    preset: u32,
    filterspecs: ptr[PyObject]
) -> bool {
    error = error_of(module);
    lzret = LZMA_OK;
    if filterspecs == Py_None {
        options = ptr[lzma_options_lzma](PyMem_Calloc(1, LZMA_OPTIONS_LZMA_SIZE));
        if options.is_null() {
            PyErr_NoMemory();
            return False;
        }
        if lzma_lzma_preset(options, preset) != 0 {
            PyMem_Free(options);
            object_error(error, f"Invalid compression preset: {preset}");
            return False;
        }
        lzret = lzma_alone_encoder(lzs, options);
        PyMem_Free(options);
    } else {
        filters = new_filter_chain();
        if filters.is_null() {
            return False;
        }
        if not parse_filter_chain_spec(module, filters, filterspecs) {
            PyMem_Free(filters);
            return False;
        }
        chain = filters.view(2);
        if chain[0].id == LZMA_FILTER_LZMA1 and chain[1].id == LZMA_VLI_UNKNOWN {
            lzret = lzma_alone_encoder(lzs, ptr[lzma_options_lzma](chain[0].options));
        } else {
            object_error(
                PyExc_ValueError,
                "Invalid filter chain for FORMAT_ALONE - must be a single LZMA1 filter"
            );
            lzret = LZMA_PROG_ERROR;
        }
        free_filter_chain(filters);
        PyMem_Free(filters);
    }
    return PyErr_Occurred().is_null() and not catch_lzma_error(error, lzret);
}

def:priv compressor_init_raw(
    module: ptr[PyObject], lzs: &mut Pinned[lzma_stream], filterspecs: ptr[PyObject]
) -> bool {
    if filterspecs == Py_None {
        object_error(PyExc_ValueError, "Must specify filters for FORMAT_RAW");
        return False;
    }
    filters = new_filter_chain();
    if filters.is_null() {
        return False;
    }
    if not parse_filter_chain_spec(module, filters, filterspecs) {
        PyMem_Free(filters);
        return False;
    }
    lzret = lzma_raw_encoder(lzs, filters);
    free_filter_chain(filters);
    PyMem_Free(filters);
    return not catch_lzma_error(error_of(module), lzret);
}

# Compressor_new(): PyArg_ParseTupleAndKeywords(args, kwargs,
# "|iiOO:LZMACompressor", ...), then the stream for the container format.
def lzma_compressor_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    format_ = FORMAT_XZ;
    check = i32(-1);
    preset: u32 = LZMA_PRESET_DEFAULT;
    preset_obj = Py_None;
    filterspecs = Py_None;
    try {
        values = ArgumentFormat(name="LZMACompressor").parse_keywords(
            args, kwargs, "|iiOO", ["format", "check", "preset", "filters"]
        );
    } except boundary_failure {
        return NULL;
    }
    if values[0].given {
        format_ = i32(values[0].signed);
    }
    if values[1].given {
        check = i32(values[1].signed);
    }
    if values[2].given {
        preset_obj = values[2].object;
    }
    if values[3].given {
        filterspecs = values[3].object;
    }
    if format_ != FORMAT_XZ and check != -1 and check != LZMA_CHECK_NONE {
        object_error(
            PyExc_ValueError, "Integrity checks are only supported by FORMAT_XZ"
        );
        return NULL;
    }
    if preset_obj != Py_None and filterspecs != Py_None {
        object_error(PyExc_ValueError, "Cannot specify both preset and filter chain");
        return NULL;
    }
    if preset_obj != Py_None
        and _PyLong_UInt32_Converter(preset_obj, &mut preset) == 0 {
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    lock = PyThread_allocate_lock();
    if not lock {
        jacpy_release(instance);
        object_error(PyExc_MemoryError, "Unable to allocate lock");
        return NULL;
    }
    state = CompressorState(lzs=new_stream(), lock=lock);
    if jacpy_binding_native_set(instance, LZMACompressor_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    module = PyType_GetModule(type);
    ok = False;
    if format_ == FORMAT_XZ {
        if check == -1 {
            check = LZMA_CHECK_CRC64;
        }
        ok = compressor_init_xz(module, &mut state.lzs, check, preset, filterspecs);
    } elif format_ == FORMAT_ALONE {
        ok = compressor_init_alone(module, &mut state.lzs, preset, filterspecs);
    } elif format_ == FORMAT_RAW {
        ok = compressor_init_raw(module, &mut state.lzs, filterspecs);
    } else {
        object_error(PyExc_ValueError, f"Invalid container format: {format_}");
    }
    if not ok {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

# LZMADecompressor class.

obj DecompressorState(NativeState) {
    has lzs: Pinned[lzma_stream],
        check: i32 = 0,
        eof: bool = False,
        unused_data: ptr[PyObject] = NULL,
        needs_input: bool = True,
        input_buffer: ptr = ptr(),
        input_buffer_size: u64 = 0,
        lock: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.input_buffer {
            PyMem_Free(self.input_buffer);
        }
        lzma_end(&mut self.lzs);
        jacpy_release(self.unused_data);
        if self.lock {
            PyThread_free_lock(self.lock);
        }
    }
}

# Decompressor_members[]: check (Py_T_INT), eof and needs_input (Py_T_BOOL)
# and unused_data (Py_T_OBJECT_EX) read the record, which mirrors the state
# after every change and holds unused_data borrowed.
def mirror_decompressor(instance: ptr[PyObject], state: DecompressorState) {
    record = jacpy_binding_record(instance, LZMADecompressor_token.handle);
    record_set_int(record, 0, int(state.check));
    record_set_byte(record, 4, 1 if state.eof else 0);
    record_set_byte(record, 5, 1 if state.needs_input else 0);
    record_set_object(record, 8, state.unused_data);
}

def decompressor_of(instance: ptr[PyObject]) -> DecompressorState | None {
    if jacpy_binding_native_present(instance, LZMADecompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, LZMADecompressor_token.handle);
        if isinstance(state, DecompressorState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "LZMADecompressor state is unavailable");
    return None;
}

# Decompress the stream's pending input; at most max_length bytes are
# returned, so some of the input may not be consumed.
def:priv decompress_buf(
    receiver: ptr[PyObject], state: DecompressorState, max_length: i64
) -> ptr[PyObject] {
    error = instance_error(receiver);
    buffer = BlocksOutputBuffer();
    cursor = Cursor();
    if buffer.init_and_grow(max_length, cursor) < 0 {
        buffer.discard();
        return NULL;
    }
    sync_out(&mut state.lzs, cursor);
    while True {
        thread = PyEval_SaveThread();
        lzret = lzma_code(&mut state.lzs, LZMA_RUN);
        PyEval_RestoreThread(thread);
        if lzret == LZMA_BUF_ERROR
            and state.lzs.value.avail_in == 0
            and state.lzs.value.avail_out > 0 {
            # That wasn't a real error.
            lzret = LZMA_OK;
        }
        if catch_lzma_error(error, lzret) {
            buffer.discard();
            return NULL;
        }
        if lzret == LZMA_GET_CHECK or lzret == LZMA_NO_CHECK {
            state.check = lzma_get_check(&mut state.lzs);
        }
        if lzret == LZMA_STREAM_END {
            state.eof = True;
            break;
        } elif state.lzs.value.avail_out == 0 {
            # Check avail_out before avail_in: the stream's internal state
            # may still hold output, so grow the buffer and continue when
            # max_length allows.
            if buffer.data_size(0) == max_length {
                break;
            }
            cursor = Cursor(avail_out=0);
            if buffer.grow(cursor) < 0 {
                buffer.discard();
                return NULL;
            }
            sync_out(&mut state.lzs, cursor);
        } elif state.lzs.value.avail_in == 0 {
            break;
        }
    }
    result = buffer.finish(i64(state.lzs.value.avail_out));
    if not result {
        buffer.discard();
    }
    return result;
}

def:priv decompress(
    receiver: ptr[PyObject],
    state: DecompressorState,
    data: ptr,
    length: u64,
    max_length: i64
) -> ptr[PyObject] {
    in_use = False;
    # Prepend unconsumed input if necessary.
    if not state.lzs.value.next_in.is_null() {
        # Bytes that can be appended to the input buffer, and the bytes
        # available once the existing contents move to its start.
        buffer_end = int(state.input_buffer) + int(state.input_buffer_size);
        pending_end = int(state.lzs.value.next_in) + int(state.lzs.value.avail_in);
        avail_now = u64(buffer_end - pending_end);
        avail_total = state.input_buffer_size - state.lzs.value.avail_in;
        if avail_total < length {
            offset = int(state.lzs.value.next_in) - int(state.input_buffer);
            new_size = state.input_buffer_size + length - avail_now;
            grown = PyMem_Realloc(state.input_buffer, new_size);
            if not grown {
                PyErr_SetNone(PyExc_MemoryError);
                return NULL;
            }
            state.input_buffer = grown;
            state.input_buffer_size = new_size;
            state.lzs.value.next_in = ptr[u8](grown + offset);
        } elif avail_now < length {
            jacpy_memory_move(
                state.input_buffer,
                state.lzs.value.next_in,
                i64(state.lzs.value.avail_in)
            );
            state.lzs.value.next_in = ptr[u8](state.input_buffer);
        }
        jacpy_memory_copy(
            state.lzs.value.next_in + i64(state.lzs.value.avail_in), data, i64(length)
        );
        state.lzs.value.avail_in += length;
        in_use = True;
    } else {
        state.lzs.value.next_in = ptr[u8](data);
        state.lzs.value.avail_in = length;
    }
    result = decompress_buf(receiver, state, max_length);
    if not result {
        state.lzs.value.next_in = ptr[u8]();
        return NULL;
    }
    if state.eof {
        state.needs_input = False;
        if state.lzs.value.avail_in > 0 {
            unused = jacpy_buffer_new(i64(state.lzs.value.avail_in));
            if not unused {
                state.lzs.value.next_in = ptr[u8]();
                jacpy_release(result);
                return NULL;
            }
            jacpy_memory_copy(
                PyBytes_AsString(unused),
                state.lzs.value.next_in,
                i64(state.lzs.value.avail_in)
            );
            jacpy_release(state.unused_data);
            state.unused_data = unused;
        }
    } elif state.lzs.value.avail_in == 0 {
        state.lzs.value.next_in = ptr[u8]();
        # With avail_out also 0 the stream may still hold output for the next
        # call (max_length >= 0 then); otherwise the input is exhausted.
        state.needs_input = state.lzs.value.avail_out != 0;
    } else {
        state.needs_input = False;
        # Without the input buffer in use, copy the tail of the caller's
        # buffer into it.
        if not in_use {
            # Discard the buffer if it is too small; resizing it may
            # needlessly copy the current contents.
            if state.input_buffer
                and state.input_buffer_size < state.lzs.value.avail_in {
                PyMem_Free(state.input_buffer);
                state.input_buffer = ptr();
            }
            if not state.input_buffer {
                state.input_buffer = PyMem_Malloc(state.lzs.value.avail_in);
                if not state.input_buffer {
                    PyErr_SetNone(PyExc_MemoryError);
                    state.lzs.value.next_in = ptr[u8]();
                    jacpy_release(result);
                    return NULL;
                }
                state.input_buffer_size = state.lzs.value.avail_in;
            }
            jacpy_memory_copy(
                state.input_buffer,
                state.lzs.value.next_in,
                i64(state.lzs.value.avail_in)
            );
            state.lzs.value.next_in = ptr[u8](state.input_buffer);
        }
    }
    return result;
}

def _lzma_LZMADecompressor_decompress_impl(
    receiver: ptr[PyObject], data: BufferArgument, max_length: i64
) -> ptr[PyObject] {
    state = decompressor_of(receiver);
    if state is None {
        return NULL;
    }
    result = NULL;
    lock_acquire(state.lock);
    if state.eof {
        object_error(PyExc_EOFError, "Already at end of stream");
    } else {
        result = decompress(
            receiver, state, data.address(), u64(data.size()), max_length
        );
    }
    mirror_decompressor(receiver, state);
    PyThread_release_lock(state.lock);
    return result;
}

def:priv decompressor_init_raw(
    module: ptr[PyObject], lzs: &mut Pinned[lzma_stream], filterspecs: ptr[PyObject]
) -> bool {
    filters = new_filter_chain();
    if filters.is_null() {
        return False;
    }
    if not parse_filter_chain_spec(module, filters, filterspecs) {
        PyMem_Free(filters);
        return False;
    }
    lzret = lzma_raw_decoder(lzs, filters);
    free_filter_chain(filters);
    PyMem_Free(filters);
    return not catch_lzma_error(error_of(module), lzret);
}

def _lzma_LZMADecompressor_impl(
    type: ptr[PyObject], format_: i32, memlimit: ptr[PyObject], filters: ptr[PyObject]
) -> ptr[PyObject] {
    decoder_flags = LZMA_TELL_ANY_CHECK | LZMA_TELL_NO_CHECK;
    memlimit_: u64 = UINT64_MAX;
    module = PyType_GetModule(type);
    error = error_of(module);
    if memlimit != Py_None {
        if format_ == FORMAT_RAW {
            object_error(
                PyExc_ValueError, "Cannot specify memory limit with FORMAT_RAW"
            );
            return NULL;
        }
        if _PyLong_UInt64_Converter(memlimit, &mut memlimit_) == 0 {
            return NULL;
        }
    }
    if format_ == FORMAT_RAW and filters == Py_None {
        object_error(PyExc_ValueError, "Must specify filters for FORMAT_RAW");
        return NULL;
    } elif format_ != FORMAT_RAW and filters != Py_None {
        object_error(PyExc_ValueError, "Cannot specify filters except with FORMAT_RAW");
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    lock = PyThread_allocate_lock();
    if not lock {
        jacpy_release(instance);
        object_error(PyExc_MemoryError, "Unable to allocate lock");
        return NULL;
    }
    state = DecompressorState(
        lzs=new_stream(),
        lock=lock,
        check=LZMA_CHECK_UNKNOWN,
        unused_data=jacpy_buffer_new(0)
    );
    if not state.unused_data
        or jacpy_binding_native_set(instance, LZMADecompressor_token.handle, state)
            < 0 {
        jacpy_release(instance);
        return NULL;
    }
    ok = False;
    if format_ == FORMAT_AUTO {
        ok = not catch_lzma_error(
            error, lzma_auto_decoder(&mut state.lzs, memlimit_, decoder_flags)
        );
    } elif format_ == FORMAT_XZ {
        ok = not catch_lzma_error(
            error, lzma_stream_decoder(&mut state.lzs, memlimit_, decoder_flags)
        );
    } elif format_ == FORMAT_ALONE {
        state.check = LZMA_CHECK_NONE;
        ok = not catch_lzma_error(error, lzma_alone_decoder(&mut state.lzs, memlimit_));
    } elif format_ == FORMAT_RAW {
        state.check = LZMA_CHECK_NONE;
        ok = decompressor_init_raw(module, &mut state.lzs, filters);
    } else {
        object_error(PyExc_ValueError, f"Invalid container format: {format_}");
    }
    if not ok {
        jacpy_release(instance);
        return NULL;
    }
    mirror_decompressor(instance, state);
    return instance;
}

# Module-level functions.

def _lzma_is_check_supported_impl(
    module: ptr[PyObject], check_id: i32
) -> ptr[PyObject] {
    return PyBool_FromLong(i64(lzma_check_is_supported(check_id)));
}

# _encode_filter_properties(filter, /): the lzma_filter converter, then
# the encoded properties; the converted options are freed on every path.
def lzma_encode_filter_properties(
    module: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    filter = ptr[lzma_filter](PyMem_Calloc(1, LZMA_FILTER_SIZE));
    if filter.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    filter.view(1)[0].id = LZMA_VLI_UNKNOWN;
    result = NULL;
    if lzma_filter_converter(module, arg, filter) {
        result = encode_filter_properties(module, filter);
    }
    if filter.view(1)[0].id != LZMA_VLI_UNKNOWN {
        PyMem_Free(filter.view(1)[0].options);
    }
    PyMem_Free(filter);
    return result;
}

def:priv encode_filter_properties(
    module: ptr[PyObject], filter: ptr[lzma_filter]
) -> ptr[PyObject] {
    error = error_of(module);
    encoded_size: u32 = 0;
    if catch_lzma_error(error, lzma_properties_size(&mut encoded_size, filter)) {
        return NULL;
    }
    result = jacpy_buffer_new(i64(encoded_size));
    if not result {
        return NULL;
    }
    if catch_lzma_error(
        error, lzma_properties_encode(filter, ptr[u8](PyBytes_AsString(result)))
    ) {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def _lzma__decode_filter_properties_impl(
    module: ptr[PyObject], filter_id: u64, encoded_props: BufferArgument
) -> ptr[PyObject] {
    filter = ptr[lzma_filter](PyMem_Calloc(1, LZMA_FILTER_SIZE));
    if filter.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    filter.view(1)[0].id = filter_id;
    lzret = lzma_properties_decode(
        filter, ptr(), encoded_props.address(), u64(encoded_props.size())
    );
    if catch_lzma_error(error_of(module), lzret) {
        PyMem_Free(filter);
        return NULL;
    }
    result = build_filter_spec(filter);
    # filter.options was allocated by lzma_properties_decode() with the
    # default allocator, so it is released with free().
    free(filter.view(1)[0].options);
    PyMem_Free(filter);
    return result;
}
