"""The codec interface of the CJK codec modules: Modules/cjkcodecs/cjkcodecs.h
and multibytecodec.h in native Jac.

A codec is a C-layout MultibyteCodec record whose encode/decode entry points
are named Jac functions, as C's function pointers are; _multibytecodec drives
them and the _codecs_<locale> modules define them over the mapping tables
scripts/jacpython/gen_cjkcodecs.jac generates. The macros of cjkcodecs.h
(TRYMAP_ENC/DEC, OUTCHAR, NEXT, REQUIRE_*) are the helpers here. A module's
codecs and maps are process-lifetime C data, so the per-module lists C
allocates are the static arrays themselves. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    jacpy_is_unicode,
    NULL,
    Py_NewRef,
    PyErr_NoMemory,
    PyExc_LookupError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyImport_ImportModule,
    PyImport_ImportModuleAttrString,
    PyMem_Free,
    PyMem_Malloc,
    PyModule_Add,
    PyObject,
    PyObject_CallOneArg,
    PyObject_GetAttrString,
    PyUnicode_AsUTF8,
    PyUnicodeWriter,
    PyUnicodeWriter_WriteChar
}
import from jaclang.runtime.python.object_model.capsule {
    PyCapsule_GetPointer,
    PyCapsule_IsValid,
    PyCapsule_New
}
import from jaclang.runtime.python.capi { object_error }

import from c {
    # multibytecodec.h: 8 bytes of state a codec uses as it wants, read and
    # written bytewise so getstate() is independent of byte order.
    obj MultibyteCodec_State {
        has c: u64;
    }
    # The str a decoder writes and how many code points it holds so far (C
    # reads _PyUnicodeWriter.pos).
    obj DecodeWriter {
        has writer: ptr[PyUnicodeWriter],
            written: i64;
    }
    # struct _multibyte_codec. A stateless codec's init and reset entries
    # are the no-op functions below where C has NULL; calling them is what
    # skipping a NULL entry does.
    obj MultibyteCodec {
        has encoding: ptr[u8],
            config: ptr,
            codecinit: Callable[[ptr[MultibyteCodec]], i32],
            encode:
                Callable[
                    [
                        ptr[MultibyteCodec_State],
                        ptr[MultibyteCodec],
                        i32,
                        ptr,
                        ptr[i64],
                        i64,
                        ptr[ptr[u8]],
                        i64,
                        i32
                    ],
                    i64
                ],
            encinit: Callable[[ptr[MultibyteCodec_State], ptr[MultibyteCodec]], i32],
            encreset:
                Callable[
                    [ptr[MultibyteCodec_State], ptr[MultibyteCodec], ptr[ptr[u8]], i64],
                    i64
                ],
            decode:
                Callable[
                    [
                        ptr[MultibyteCodec_State],
                        ptr[MultibyteCodec],
                        ptr[ptr[u8]],
                        i64,
                        ptr[DecodeWriter]
                    ],
                    i64
                ],
            decinit: Callable[[ptr[MultibyteCodec_State], ptr[MultibyteCodec]], i32],
            decreset: Callable[[ptr[MultibyteCodec_State], ptr[MultibyteCodec]], i64];
    }
    # struct dbcs_map: a charset's encode and decode maps. An index has one
    # u32 entry per high byte packing (offset + 1) << 16 | bottom << 8 | top
    # (0: no row) over its code array.
    obj DbcsMap {
        has charset: ptr[u8],
            encindex: ptr[u32],
            encdata: ptr,
            decindex: ptr[u32],
            decdata: ptr;
    }
    # struct pair_encodemap.
    obj PairEncodeMap {
        has uniseq: u32,
            code: u16;
    }
    # struct _gb18030_to_unibmp_ranges.
    obj Gb18030Range {
        has first: u32,
            last: u32,
            base: u16;
    }
    # codec_capsule: a codec and the module that defines it.
    obj CodecCapsule {
        has codec: ptr[MultibyteCodec],
            cjk_module: ptr[PyObject];
    }
}

# a unicode "undefined" code point
glob UNIINV: int = 0xFFFE,
     # internal-use DBCS code points which aren't used by any charsets
     NOCHAR: int = 0xFFFF,
     MULTIC: int = 0xFFFE,
     DBCINV: int = 0xFFFD,
     # positive values for illegal sequences
     MBERR_TOOSMALL: i64 = -1,
     MBERR_TOOFEW: i64 = -2,
     MBERR_INTERNAL: i64 = -3,
     MBERR_EXCEPTION: i64 = -4,
     MBENC_FLUSH: i32 = 1,
     MBENC_MAX: i32 = 1;

# The entries a stateless codec has as NULL in C.
def no_codec_init(codec: ptr[MultibyteCodec]) -> i32 {
    return i32(0);
}

def no_state_init(state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]) -> i32 {
    return i32(0);
}

def no_encode_reset(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    outbuf: ptr[ptr[u8]],
    outleft: i64
) -> i64 {
    return 0;
}

def no_decode_reset(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i64 {
    return 0;
}

# PyUnicode_READ over a str's kind and data.
def unicode_read(kind: int, data: ptr, index: int) -> int {
    if kind == 1 {
        return int((ptr[u8](data) + index).view(1)[0]);
    }
    if kind == 2 {
        return int((ptr[u16](data) + index).view(1)[0]);
    }
    return int((ptr[u32](data) + index).view(1)[0]);
}

# INCHAR1 / INCHAR2: the code point `offset` past the encoder's position.
def inchar(kind: i32, data: ptr, inpos: ptr[i64], offset: int) -> int {
    return unicode_read(int(kind), data, int(inpos.view(1)[0]) + offset);
}

# NEXT_INCHAR.
def next_inchar(inpos: ptr[i64], count: int) {
    inpos.view(1)[0] = inpos.view(1)[0] + count;
}

# OUTBYTEI: the low byte of `value` at the output cursor plus `index`.
def outbyte(outbuf: ptr[ptr[u8]], index: int, value: int) {
    (outbuf.view(1)[0] + index).view(1)[0] = u8(value & 0xFF);
}

# The output cursor advance of NEXT_OUT (the caller keeps outleft).
def next_out(outbuf: ptr[ptr[u8]], count: int) {
    outbuf.view(1)[0] = outbuf.view(1)[0] + count;
}

# INBYTE1..4: the input byte `index` past the decoder's position.
def inbyte(inbuf: ptr[ptr[u8]], index: int) -> int {
    return int((inbuf.view(1)[0] + index).view(1)[0]);
}

# The input cursor advance of NEXT_IN (the caller keeps inleft).
def next_in(inbuf: ptr[ptr[u8]], count: int) {
    inbuf.view(1)[0] = inbuf.view(1)[0] + count;
}

# OUTCHAR: False when writing failed with the exception set (the caller
# returns MBERR_EXCEPTION).
def outchar(writer: ptr[DecodeWriter], c: int) -> bool {
    if PyUnicodeWriter_WriteChar(writer.view(1)[0].writer, u32(c)) < 0 {
        return False;
    }
    writer.view(1)[0].written = writer.view(1)[0].written + 1;
    return True;
}

# OUTCHAR2.
def outchar2(writer: ptr[DecodeWriter], c1: int, c2: int) -> bool {
    return outchar(writer, c1) and outchar(writer, c2);
}

# state->c[index].
def state_byte(state: ptr[MultibyteCodec_State], index: int) -> int {
    return int((ptr[u8](state) + index).view(1)[0]);
}

def set_state_byte(state: ptr[MultibyteCodec_State], index: int, value: int) {
    (ptr[u8](state) + index).view(1)[0] = u8(value & 0xFF);
}

# The code at `row`, `column` of a packed index over `codes` (u16 codes),
# or `missing` where the row has no map or the column is outside it.
def index_lookup(
    index: ptr[u32], codes: ptr[u16], row: int, column: int, missing: int
) -> int {
    if index.is_null() {
        return missing;
    }
    item = int((index + row).view(1)[0]);
    if item == 0 or column < ((item >> 8) & 0xFF) or column > (item & 0xFF) {
        return missing;
    }
    return int((codes + ((item >> 16) - 1 + column - ((item >> 8) & 0xFF))).view(1)[0]);
}

# TRYMAP_ENC: the code of `uni` (below 0x10000) in `map`, NOCHAR if unmapped.
def map_encode(map: ptr[DbcsMap], uni: int) -> int {
    record = map.view(1)[0];
    return index_lookup(
        record.encindex, ptr[u16](record.encdata), uni >> 8, uni & 0xFF, NOCHAR
    );
}

# TRYMAP_DEC: the code point of `c1`, `c2` in `map`, UNIINV if unmapped.
def map_decode(map: ptr[DbcsMap], c1: int, c2: int) -> int {
    record = map.view(1)[0];
    return index_lookup(record.decindex, ptr[u16](record.decdata), c1, c2, UNIINV);
}

# TRYMAP_DEC over a wide (UCS-4) decode map: jisx0213_pair.
def map_decode_wide(map: ptr[DbcsMap], c1: int, c2: int) -> int {
    record = map.view(1)[0];
    index = record.decindex;
    if index.is_null() {
        return UNIINV;
    }
    item = int((index + c1).view(1)[0]);
    if item == 0 or c2 < ((item >> 8) & 0xFF) or c2 > (item & 0xFF) {
        return UNIINV;
    }
    codes = ptr[u32](record.decdata);
    return int((codes + ((item >> 16) - 1 + c2 - ((item >> 8) & 0xFF))).view(1)[0]);
}

# find_pairencmap: the code of the pair `body`, `modifier` in the sorted
# `haystack` of `size` entries, DBCINV if absent.
def find_pairencmap(
    body: int, modifier: int, haystack: ptr[PairEncodeMap], size: int
) -> int {
    value = ((body & 0xFFFF) << 16) | (modifier & 0xFFFF);
    min = 0;
    max = size;
    pos = size >> 1;
    while min != max {
        uniseq = int((haystack + pos).view(1)[0].uniseq);
        if value < uniseq {
            if max != pos {
                max = pos;
                pos = (min + max) >> 1;
                continue;
            }
        } elif value > uniseq {
            if min != pos {
                min = pos;
                pos = (min + max) >> 1;
                continue;
            }
        }
        break;
    }
    if value == int((haystack + pos).view(1)[0].uniseq) {
        return int((haystack + pos).view(1)[0].code);
    }
    return DBCINV;
}

# strcmp() == 0.
def c_string_equal(a: ptr[u8], b: ptr[u8]) -> bool {
    i = 0;
    while True {
        x = (a + i).view(1)[0];
        if x != (b + i).view(1)[0] {
            return False;
        }
        if x == 0 {
            return True;
        }
        i += 1;
    }
    return False;
}

# importmap: the DbcsMap `symbol` of module `modname` (an attribute holding
# its map capsule); NULL with the exception set on failure.
def importmap(modname: str, symbol: str) -> ptr[DbcsMap] {
    mod = PyImport_ImportModule(modname);
    if not mod {
        return ptr[DbcsMap]();
    }
    o = PyObject_GetAttrString(mod, symbol);
    jacpy_release(mod);
    if not o {
        return ptr[DbcsMap]();
    }
    if PyCapsule_IsValid(o, ptr[u8]("multibytecodec.map")) == 0 {
        object_error(PyExc_ValueError, "map data must be a Capsule.");
        jacpy_release(o);
        return ptr[DbcsMap]();
    }
    map = ptr[DbcsMap](PyCapsule_GetPointer(o, ptr[u8]("multibytecodec.map")));
    jacpy_release(o);
    return map;
}

# register_maps: a `__map_<charset>` capsule for each of the module's maps.
def register_maps(module: ptr[PyObject], maps: ptr[ptr[DbcsMap]], count: int) -> i32 {
    for i in range(count) {
        map = (maps + i).view(1)[0];
        size = 0;
        while (map.view(1)[0].charset + size).view(1)[0] != 0 {
            size += 1;
        }
        charset = bytes(
            [int((map.view(1)[0].charset + j).view(1)[0]) for j in range(size)]
        ).decode(
            "ascii"
        );
        capsule = PyCapsule_New(ptr(map), ptr[u8]("multibytecodec.map"), ptr());
        if PyModule_Add(module, "__map_" + charset, capsule) < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

def destroy_codec_capsule(capsule: ptr[PyObject]) {
    data = ptr[CodecCapsule](
        PyCapsule_GetPointer(capsule, ptr[u8]("multibytecodec.codec"))
    );
    jacpy_release(data.view(1)[0].cjk_module);
    PyMem_Free(ptr(data));
}

# _getcodec: _multibytecodec.__create_codec() over a capsule of `codec`.
def create_codec(module: ptr[PyObject], codec: ptr[MultibyteCodec]) -> ptr[PyObject] {
    cofunc = PyImport_ImportModuleAttrString("_multibytecodec", "__create_codec");
    if not cofunc {
        return NULL;
    }
    data = ptr[CodecCapsule](PyMem_Malloc(u64(16)));
    if data.is_null() {
        PyErr_NoMemory();
        jacpy_release(cofunc);
        return NULL;
    }
    data.view(1)[0].codec = codec;
    data.view(1)[0].cjk_module = Py_NewRef(module);
    codecobj = PyCapsule_New(
        ptr(data), ptr[u8]("multibytecodec.codec"), ptr(destroy_codec_capsule)
    );
    if not codecobj {
        jacpy_release(data.view(1)[0].cjk_module);
        PyMem_Free(ptr(data));
        jacpy_release(cofunc);
        return NULL;
    }
    res = PyObject_CallOneArg(cofunc, codecobj);
    jacpy_release(codecobj);
    jacpy_release(cofunc);
    return res;
}

# getcodec(encoding): the module's codec of that name.
def getcodec(
    module: ptr[PyObject],
    codecs: ptr[MultibyteCodec],
    count: int,
    encoding: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_unicode(encoding) == 0 {
        object_error(PyExc_TypeError, "encoding name must be a string.");
        return NULL;
    }
    enc = PyUnicode_AsUTF8(encoding);
    if enc.is_null() {
        return NULL;
    }
    for i in range(count) {
        codec = codecs + i;
        if c_string_equal(codec.view(1)[0].encoding, enc) {
            return create_codec(module, codec);
        }
    }
    object_error(PyExc_LookupError, "no such codec is supported.");
    return NULL;
}
