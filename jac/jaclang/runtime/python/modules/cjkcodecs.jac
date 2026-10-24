import from c {
    obj MultibyteCodec_State {
        has c: u64;
    }  obj DecodeWriter {
        has writer: ptr[PyUnicodeWriter],
            written: i64;
    }  obj MultibyteCodec {
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
    }  obj DbcsMap {
        has charset: ptr[u8],
            encindex: ptr[u32],
            encdata: ptr,
            decindex: ptr[u32],
            decdata: ptr;
    }  obj PairEncodeMap {
        has uniseq: u32,
            code: u16;
    }  obj Gb18030Range {
        has first: u32,
            last: u32,
            base: u16;
    }  obj CodecCapsule {
        has codec: ptr[MultibyteCodec],
            cjk_module: ptr[PyObject];
    }
}

glob UNIINV: int = 0xFFFE,
     NOCHAR: int = 0xFFFF,
     MULTIC: int = 0xFFFE,
     DBCINV: int = 0xFFFD,
     MBERR_TOOSMALL: i64 = -1,
     MBERR_TOOFEW: i64 = -2,
     MBERR_INTERNAL: i64 = -3,
     MBERR_EXCEPTION: i64 = -4,
     MBENC_FLUSH: i32 = 1,
     MBENC_MAX: i32 = 1;

def no_codec_init(codec: ptr[MultibyteCodec]) -> i32;

def no_state_init(state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]) -> i32;

def no_encode_reset(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    outbuf: ptr[ptr[u8]],
    outleft: i64
) -> i64;

def no_decode_reset(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i64;

def unicode_read(kind: int, data: ptr, index: int) -> int;

def inchar(kind: i32, data: ptr, inpos: ptr[i64], offset: int) -> int;

def next_inchar(inpos: ptr[i64], count: int);

def outbyte(outbuf: ptr[ptr[u8]], index: int, value: int);

def next_out(outbuf: ptr[ptr[u8]], count: int);

def inbyte(inbuf: ptr[ptr[u8]], index: int) -> int;

def next_in(inbuf: ptr[ptr[u8]], count: int);

def outchar(writer: ptr[DecodeWriter], c: int) -> bool;

def outchar2(writer: ptr[DecodeWriter], c1: int, c2: int) -> bool;

def state_byte(state: ptr[MultibyteCodec_State], index: int) -> int;

def set_state_byte(state: ptr[MultibyteCodec_State], index: int, value: int);

def index_lookup(
    index: ptr[u32], codes: ptr[u16], row: int, column: int, missing: int
) -> int;

def map_encode(map: ptr[DbcsMap], uni: int) -> int;

def map_decode(map: ptr[DbcsMap], c1: int, c2: int) -> int;

def map_decode_wide(map: ptr[DbcsMap], c1: int, c2: int) -> int;

def find_pairencmap(
    body: int, modifier: int, haystack: ptr[PairEncodeMap], size: int
) -> int;

def c_string_equal(a: ptr[u8], b: ptr[u8]) -> bool;

def importmap(modname: str, symbol: str) -> ptr[DbcsMap];

def register_maps(module: ptr[PyObject], maps: ptr[ptr[DbcsMap]], count: int) -> i32;

def destroy_codec_capsule(capsule: ptr[PyObject]);

def create_codec(module: ptr[PyObject], codec: ptr[MultibyteCodec]) -> ptr[PyObject];

def getcodec(
    module: ptr[PyObject],
    codecs: ptr[MultibyteCodec],
    count: int,
    encoding: ptr[PyObject]
) -> ptr[PyObject];

impl no_codec_init(codec: ptr[MultibyteCodec]) -> i32 {
    return i32(0);
}

impl no_state_init(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i32 {
    return i32(0);
}

impl no_encode_reset(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    outbuf: ptr[ptr[u8]],
    outleft: i64
) -> i64 {
    return 0;
}

impl no_decode_reset(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i64 {
    return 0;
}

impl unicode_read(kind: int, data: ptr, index: int) -> int {
    if kind == 1 {
        return int((ptr[u8](data) + index).view(1)[0]);
    }
    if kind == 2 {
        return int((ptr[u16](data) + index).view(1)[0]);
    }
    return int((ptr[u32](data) + index).view(1)[0]);
}

impl inchar(kind: i32, data: ptr, inpos: ptr[i64], offset: int) -> int {
    return unicode_read(int(kind), data, int(inpos.view(1)[0]) + offset);
}

impl next_inchar(inpos: ptr[i64], count: int) {
    inpos.view(1)[0] = inpos.view(1)[0] + count;
}

impl outbyte(outbuf: ptr[ptr[u8]], index: int, value: int) {
    (outbuf.view(1)[0] + index).view(1)[0] = u8(value & 0xFF);
}

impl next_out(outbuf: ptr[ptr[u8]], count: int) {
    outbuf.view(1)[0] = outbuf.view(1)[0] + count;
}

impl inbyte(inbuf: ptr[ptr[u8]], index: int) -> int {
    return int((inbuf.view(1)[0] + index).view(1)[0]);
}

impl next_in(inbuf: ptr[ptr[u8]], count: int) {
    inbuf.view(1)[0] = inbuf.view(1)[0] + count;
}

impl outchar(writer: ptr[DecodeWriter], c: int) -> bool {
    if PyUnicodeWriter_WriteChar(writer.view(1)[0].writer, u32(c)) < 0 {
        return False;
    }
    writer.view(1)[0].written = writer.view(1)[0].written + 1;
    return True;
}

impl outchar2(writer: ptr[DecodeWriter], c1: int, c2: int) -> bool {
    return outchar(writer, c1) and outchar(writer, c2);
}

impl state_byte(state: ptr[MultibyteCodec_State], index: int) -> int {
    return int((ptr[u8](state) + index).view(1)[0]);
}

impl set_state_byte(state: ptr[MultibyteCodec_State], index: int, value: int) {
    (ptr[u8](state) + index).view(1)[0] = u8(value & 0xFF);
}

impl index_lookup(
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

impl map_encode(map: ptr[DbcsMap], uni: int) -> int {
    record = map.view(1)[0];
    return index_lookup(
        record.encindex, ptr[u16](record.encdata), uni >> 8, uni & 0xFF, NOCHAR
    );
}

impl map_decode(map: ptr[DbcsMap], c1: int, c2: int) -> int {
    record = map.view(1)[0];
    return index_lookup(record.decindex, ptr[u16](record.decdata), c1, c2, UNIINV);
}

impl map_decode_wide(map: ptr[DbcsMap], c1: int, c2: int) -> int {
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

impl find_pairencmap(
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

impl c_string_equal(a: ptr[u8], b: ptr[u8]) -> bool {
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

impl importmap(modname: str, symbol: str) -> ptr[DbcsMap] {
    mod = PyImport_ImportModule(modname);
    if not mod {
        return ptr[DbcsMap]();
    }
    o = jacpy_object_getattr_text(mod, symbol);
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

impl register_maps(module: ptr[PyObject], maps: ptr[ptr[DbcsMap]], count: int) -> i32 {
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

impl destroy_codec_capsule(capsule: ptr[PyObject]) {
    data = ptr[CodecCapsule](
        PyCapsule_GetPointer(capsule, ptr[u8]("multibytecodec.codec"))
    );
    jacpy_release(data.view(1)[0].cjk_module);
    PyMem_Free(ptr(data));
}

impl create_codec(module: ptr[PyObject], codec: ptr[MultibyteCodec]) -> ptr[PyObject] {
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

impl getcodec(
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
