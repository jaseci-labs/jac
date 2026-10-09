"""Opaque native ArrayBuffer, TypedArray, and DataView internal state."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    js_number,
    js_true,
    js_false,
    js_nan,
    jsv_is_object_cell,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_bool,
    jsv_to_table_id,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_bool,
    jsv_from_object_id,
    jsv_hole,
    jsv_double_from_bits,
    jsv_double_bits,
    f32_bits_to_double,
    double_to_f32_bits
}
import from engine.src.runtime.jsobj_type { JSObject }
import from engine.src.runtime.jsobject {
    js_object_table_get,
    js_object_binary_kind_id,
    js_object_binary_slot_id
}
import from engine.src.runtime.mem {
    read_byte,
    write_byte,
    read_u16,
    read_u32,
    read_i32,
    read_u64,
    write_i32,
    write_i64
}

glob:pub BINARY_KIND_NONE: int = 0,
     BINARY_KIND_ARRAY_BUFFER: int = 1,
     BINARY_KIND_TYPED_ARRAY: int = 2,
     BINARY_KIND_DATA_VIEW: int = 3,
     BINARY_KIND_SHARED_ARRAY_BUFFER: int = 4;

obj:pub BackingStore {
    has ptr: int = 0,
        byte_length: int = 0,
        max_byte_length: int = 0,
        generation: int = 0,
        shared: bool = False,
        immutable: bool = False,
        detached: bool = False,
        resizable: bool = False;
}

obj:pub ArrayBufferData {
    has store_id: int = -1;
}

obj:pub TypedArrayData {
    has buffer_id: int = 0,
        byte_offset: int = 0,
        fixed_length: int = 0,
        bytes_per_element: int = 1,
        element_kind: int = 0,
        length_tracking: bool = False;
}

obj:pub DataViewData {
    has buffer_id: int = 0,
        byte_offset: int = 0,
        fixed_byte_length: int = 0,
        length_tracking: bool = False;
}

obj:pub BinaryViewWitness {
    has valid: bool = False,
        detached: bool = True,
        oob: bool = False,
        generation: int = -1,
        byte_length: int = 0,
        length: int = 0,
        byte_offset: int = 0,
        bytes_per_element: int = 1;
}

# True when fixed-length view spans past buffer (IsTypedArrayOutOfBounds).
glob _BACKING_STORES: list[BackingStore] = [],
     _ARRAY_BUFFERS: list[ArrayBufferData] = [],
     _TYPED_ARRAYS: list[TypedArrayData] = [],
     _DATA_VIEWS: list[DataViewData] = [];

def _binary_arg_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

def _binary_raw(v: JSValue) -> JSObject {
    return js_object_table_get(jsv_to_table_id(v));
}

def _buffer_data(buffer: JSValue) -> ArrayBufferData {
    raw: JSObject = _binary_raw(buffer);
    return _ARRAY_BUFFERS[raw.bslot()];
}

def:pub binary_backing_store(buffer: JSValue) -> BackingStore {
    data: ArrayBufferData = _buffer_data(buffer);
    return _BACKING_STORES[data.store_id];
}

# The kind predicates read binary_kind as a scalar (js_object_binary_kind_id)
# rather than through a JSObject reference: they run tens of millions of
# times in a vite build (every Buffer / typed-array check).
def:pub binary_is_array_buffer(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return False;
    }
    kind: int = js_object_binary_kind_id(jsv_to_table_id(v));
    return kind == BINARY_KIND_ARRAY_BUFFER or kind == BINARY_KIND_SHARED_ARRAY_BUFFER;
}

def:pub binary_is_typed_array(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return False;
    }
    return js_object_binary_kind_id(jsv_to_table_id(v)) == BINARY_KIND_TYPED_ARRAY;
}

def:pub binary_is_data_view(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return False;
    }
    return js_object_binary_kind_id(jsv_to_table_id(v)) == BINARY_KIND_DATA_VIEW;
}

def:pub binary_kind_of(v: JSValue) -> int {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return BINARY_KIND_NONE;
    }
    return js_object_binary_kind_id(jsv_to_table_id(v));
}

"""Backing-store data pointer for an ArrayBuffer's binary_slot.
For GC-sweep callers that hold the raw JSObject fields (the JSValue handle
is already unreachable at sweep time). Returns 0 when out of range."""
def:pub binary_store_ptr_for_slot(binary_slot: int) -> int {
    if binary_slot < 0 or binary_slot >= len(_ARRAY_BUFFERS) {
        return 0;
    }
    store_id: int = _ARRAY_BUFFERS[binary_slot].store_id;
    if store_id < 0 or store_id >= len(_BACKING_STORES) {
        return 0;
    }
    return _BACKING_STORES[store_id].ptr;
}

"""view→buffer strong GC edge: the backing ArrayBuffer's 1-based table id for a
TypedArray/DataView view (binary_kind 2/3), else 0 (no edge). Replaces the former
inline JSObject.binary_buffer field — GC traces this from gc.jac's mark loop
(jsobject cannot import binary_state; docs/OBJECT_FOOTPRINT_PLAN.md Phase 1)."""
def:pub binary_view_buffer_id(kind: int, slot: int) -> int {
    if kind == BINARY_KIND_TYPED_ARRAY {
        if slot < 0 or slot >= len(_TYPED_ARRAYS) {
            return 0;
        }
        return _TYPED_ARRAYS[slot].buffer_id;
    }
    if kind == BINARY_KIND_DATA_VIEW {
        if slot < 0 or slot >= len(_DATA_VIEWS) {
            return 0;
        }
        return _DATA_VIEWS[slot].buffer_id;
    }
    return 0;
}

"""Register or synchronize a buffer. flags: detached/shared/immutable/resizable."""
def:pub binary_register_buffer(args: list[JSValue]) -> JSValue {
    if len(args) < 6 or not jsv_is_object_cell(args[0]) {
        return js_false();
    }
    buffer: JSValue = args[0];
    raw: JSObject = _binary_raw(buffer);
    ptr: int = _binary_arg_int(args[1]);
    byte_length: int = _binary_arg_int(args[2]);
    max_byte_length: int = _binary_arg_int(args[3]);
    generation: int = _binary_arg_int(args[4]);
    flags: int = _binary_arg_int(args[5]);
    store_id: int = -1;
    if binary_is_array_buffer(buffer) and raw.bslot() >= 0 {
        store_id = _ARRAY_BUFFERS[raw.bslot()].store_id;
    } else {
        store_id = len(_BACKING_STORES);
        _BACKING_STORES.append(BackingStore());
        raw.set_bslot(len(_ARRAY_BUFFERS));
        _ARRAY_BUFFERS.append(ArrayBufferData(store_id=store_id));
    }
    store: BackingStore = _BACKING_STORES[store_id];
    store.ptr = ptr;
    store.byte_length = byte_length;
    store.max_byte_length = max_byte_length;
    if generation < 0 {
        store.generation = store.generation + 1;
    } else {
        store.generation = generation;
    }
    store.detached = (flags & 1) != 0;
    store.shared = (flags & 2) != 0;
    store.immutable = (flags & 4) != 0;
    store.resizable = (flags & 8) != 0;
    ab_kind: int = (
        BINARY_KIND_SHARED_ARRAY_BUFFER if store.shared else BINARY_KIND_ARRAY_BUFFER
    );
    raw.set_bkind(ab_kind);
    return js_true();
}

"""Register a TypedArray native view record."""
def:pub binary_register_typed_array(args: list[JSValue]) -> JSValue {
    if len(args) < 7 {
        return js_false();
    }
    view: JSValue = args[0];
    buffer: JSValue = args[1];
    if (not jsv_is_object_cell(view) or not binary_is_array_buffer(buffer)) {
        return js_false();
    }
    raw: JSObject = _binary_raw(view);
    data: TypedArrayData = TypedArrayData(
        buffer_id=jsv_to_table_id(buffer),
        byte_offset=_binary_arg_int(args[2]),
        fixed_length=_binary_arg_int(args[3]),
        bytes_per_element=_binary_arg_int(args[4]),
        element_kind=_binary_arg_int(args[5]),
        length_tracking=jsv_is_bool(args[6]) and jsv_to_bool(args[6])
    );
    raw.set_bkind(BINARY_KIND_TYPED_ARRAY);
    raw.set_bslot(len(_TYPED_ARRAYS));
    # view→buffer edge lives in data.buffer_id (set above); no inline field.
    _TYPED_ARRAYS.append(data);
    return js_true();
}

"""Register a DataView native view record."""
def:pub binary_register_data_view(args: list[JSValue]) -> JSValue {
    if len(args) < 5 {
        return js_false();
    }
    view: JSValue = args[0];
    buffer: JSValue = args[1];
    if (not jsv_is_object_cell(view) or not binary_is_array_buffer(buffer)) {
        return js_false();
    }
    raw: JSObject = _binary_raw(view);
    raw.set_bkind(BINARY_KIND_DATA_VIEW);
    raw.set_bslot(len(_DATA_VIEWS));
    # view→buffer edge lives in DataViewData.buffer_id (set below); no inline field.
    _DATA_VIEWS.append(
        DataViewData(
            buffer_id=jsv_to_table_id(buffer),
            byte_offset=_binary_arg_int(args[2]),
            fixed_byte_length=_binary_arg_int(args[3]),
            length_tracking=jsv_is_bool(args[4]) and jsv_to_bool(args[4])
        )
    );
    return js_true();
}

def:pub binary_view_witness(view: JSValue) -> BinaryViewWitness {
    witness: BinaryViewWitness = BinaryViewWitness();
    if not jsv_is_object_cell(view) or jsv_to_table_id(view) <= 0 {
        return witness;
    }
    raw: JSObject = _binary_raw(view);
    if raw.bkind() == BINARY_KIND_TYPED_ARRAY {
        data: TypedArrayData = _TYPED_ARRAYS[raw.bslot()];
        buffer: JSValue = jsv_from_object_id(data.buffer_id);
        if not binary_is_array_buffer(buffer) {
            return witness;
        }
        store: BackingStore = binary_backing_store(buffer);
        witness.valid = True;
        witness.detached = store.detached;
        witness.generation = store.generation;
        witness.byte_offset = data.byte_offset;
        witness.bytes_per_element = data.bytes_per_element;
        if store.detached {
            witness.oob = True;
            return witness;
        }
        if data.byte_offset > store.byte_length {
            # Length-tracking and fixed-length: byteOffset past buffer → OOB.
            witness.oob = True;
            return witness;
        }
        if data.length_tracking {
            witness.length = int(
                (store.byte_length - data.byte_offset) / data.bytes_per_element
            );
        } elif data.byte_offset + data.fixed_length * data.bytes_per_element
            <= store.byte_length {
            witness.length = data.fixed_length;
        } else {
            # Fixed-length span past buffer → OOB with length 0.
            witness.oob = True;
        }
        witness.byte_length = witness.length * data.bytes_per_element;
        return witness;
    }
    if raw.bkind() == BINARY_KIND_DATA_VIEW {
        dv: DataViewData = _DATA_VIEWS[raw.bslot()];
        buffer_dv: JSValue = jsv_from_object_id(dv.buffer_id);
        if not binary_is_array_buffer(buffer_dv) {
            return witness;
        }
        store_dv: BackingStore = binary_backing_store(buffer_dv);
        witness.valid = True;
        witness.detached = store_dv.detached;
        witness.generation = store_dv.generation;
        witness.byte_offset = dv.byte_offset;
        if store_dv.detached or dv.byte_offset > store_dv.byte_length {
            return witness;
        }
        if dv.length_tracking {
            witness.byte_length = store_dv.byte_length - dv.byte_offset;
        } elif dv.byte_offset + dv.fixed_byte_length <= store_dv.byte_length {
            witness.byte_length = dv.fixed_byte_length;
        }
        return witness;
    }
    return witness;
}

def:pub binary_typed_array_element_kind(view: JSValue) -> int {
    ek_ts: int = _ta_slot(view);
    if ek_ts < 0 {
        return 0;
    }
    return _TYPED_ARRAYS[ek_ts].element_kind;
}

def:pub binary_typed_array_buffer(view: JSValue) -> JSValue {
    if not binary_is_typed_array(view) {
        return js_undefined();
    }
    return jsv_from_object_id(_TYPED_ARRAYS[_binary_raw(view).bslot()].buffer_id);
}

def:pub binary_data_view_buffer(view: JSValue) -> JSValue {
    if not binary_is_data_view(view) {
        return js_undefined();
    }
    return jsv_from_object_id(_DATA_VIEWS[_binary_raw(view).bslot()].buffer_id);
}

"""Allocation-free TypedArrayLength for the `.length` / `.byteLength` getter fast
paths: the element count of a typed-array view, or 0 when the receiver is not a
typed array, its buffer is detached, or the view is out of bounds (same rules
as the TYPED_ARRAY branch of binary_view_witness, without building a witness)."""
def:pub binary_typed_array_length(view: JSValue) -> int {
    if not jsv_is_object_cell(view) or jsv_to_table_id(view) <= 0 {
        return 0;
    }
    raw: JSObject = _binary_raw(view);
    if raw.bkind() != BINARY_KIND_TYPED_ARRAY {
        return 0;
    }
    data: TypedArrayData = _TYPED_ARRAYS[raw.bslot()];
    tl_buf: JSValue = jsv_from_object_id(data.buffer_id);
    if not binary_is_array_buffer(tl_buf) {
        return 0;
    }
    store: BackingStore = binary_backing_store(tl_buf);
    if store.detached {
        return 0;
    }
    if data.byte_offset > store.byte_length {
        return 0;
    }
    if data.length_tracking {
        return int((store.byte_length - data.byte_offset) / data.bytes_per_element);
    }
    if data.byte_offset + data.fixed_length * data.bytes_per_element
        <= store.byte_length {
        return data.fixed_length;
    }
    return 0;
}

"""Allocation-free `.byteOffset` getter value: the view's byte offset, or 0 when
the receiver is not a typed array, detached, or out of bounds (ES §23.2.3.3)."""
def:pub binary_typed_array_byte_offset(view: JSValue) -> int {
    if not jsv_is_object_cell(view) or jsv_to_table_id(view) <= 0 {
        return 0;
    }
    raw: JSObject = _binary_raw(view);
    if raw.bkind() != BINARY_KIND_TYPED_ARRAY {
        return 0;
    }
    data: TypedArrayData = _TYPED_ARRAYS[raw.bslot()];
    bo_buf: JSValue = jsv_from_object_id(data.buffer_id);
    if not binary_is_array_buffer(bo_buf) {
        return 0;
    }
    store: BackingStore = binary_backing_store(bo_buf);
    if store.detached {
        return 0;
    }
    if data.byte_offset > store.byte_length {
        return 0;
    }
    if not data.length_tracking
        and data.byte_offset + data.fixed_length * data.bytes_per_element
            > store.byte_length {
        return 0;
    }
    return data.byte_offset;
}

def:pub binary_typed_array_is_length_tracking(view: JSValue) -> bool {
    if not binary_is_typed_array(view) {
        return False;
    }
    return _TYPED_ARRAYS[_binary_raw(view).bslot()].length_tracking;
}

def:pub binary_typed_array_bytes_per_element(view: JSValue) -> int {
    if not binary_is_typed_array(view) {
        return 1;
    }
    return _TYPED_ARRAYS[_binary_raw(view).bslot()].bytes_per_element;
}

"""
TypedArray [[PreventExtensions]] (resizable / length-tracking staging tests).
Length-tracking views and fixed-length views on resizable ArrayBuffers cannot be
made non-extensible; fixed-length views on SharedArrayBuffer may be.
"""
def:pub binary_typed_array_prevent_extensions_allowed(view: JSValue) -> bool {
    if not binary_is_typed_array(view) {
        return True;
    }
    data: TypedArrayData = _TYPED_ARRAYS[_binary_raw(view).bslot()];
    if data.length_tracking {
        return False;
    }
    buffer: JSValue = jsv_from_object_id(data.buffer_id);
    if not binary_is_array_buffer(buffer) {
        return False;
    }
    store: BackingStore = binary_backing_store(buffer);
    if store.shared {
        return True;
    }
    if store.resizable {
        return False;
    }
    return True;
}

# Element access (HOT: one call per `view[i]` read or write). Everything is
# addressed by int slot indices and read through borrowed list elements:
# binding the view's JSObject / TypedArrayData / BackingStore records to
# locals took a retain/release pair each, ~500 instructions per element on
# vite's sourcemap codec (Uint8Array lookups per base64 digit). No allocation
# either (the old BinaryViewWitness per read built GBs of garbage).

"""_TYPED_ARRAYS slot of `view`, or -1 when it is not a typed array."""
def _ta_slot(view: JSValue) -> int {
    if not jsv_is_object_cell(view) {
        return -1;
    }
    tv_id: int = jsv_to_table_id(view);
    if tv_id <= 0 or js_object_binary_kind_id(tv_id) != BINARY_KIND_TYPED_ARRAY {
        return -1;
    }
    return js_object_binary_slot_id(tv_id);
}

"""_BACKING_STORES index behind typed-array slot `ts`, or -1 when its buffer
is not an ArrayBuffer / SharedArrayBuffer."""
def _ta_store(ts: int) -> int {
    tb_id: int = _TYPED_ARRAYS[ts].buffer_id;
    if tb_id <= 0 {
        return -1;
    }
    tb_kind: int = js_object_binary_kind_id(tb_id);
    if tb_kind != BINARY_KIND_ARRAY_BUFFER
        and tb_kind != BINARY_KIND_SHARED_ARRAY_BUFFER {
        return -1;
    }
    return _ARRAY_BUFFERS[js_object_binary_slot_id(tb_id)].store_id;
}

"""TypedArrayLength of slot `ts` over store `sid`: 0 when the buffer is
detached or the view is out of bounds (same rules as binary_view_witness)."""
def _ta_len(ts: int, sid: int) -> int {
    if _BACKING_STORES[sid].detached {
        return 0;
    }
    tl_bo: int = _TYPED_ARRAYS[ts].byte_offset;
    tl_blen: int = _BACKING_STORES[sid].byte_length;
    if tl_bo > tl_blen {
        return 0;
    }
    tl_bpe: int = _TYPED_ARRAYS[ts].bytes_per_element;
    if _TYPED_ARRAYS[ts].length_tracking {
        return int((tl_blen - tl_bo) / tl_bpe);
    }
    if tl_bo + _TYPED_ARRAYS[ts].fixed_length * tl_bpe <= tl_blen {
        return _TYPED_ARRAYS[ts].fixed_length;
    }
    return 0;
}

"""A Float32/Float64 element as the JS number the float kinds' reads
produce: int32 when integral and in range, else a double (-0 stays -0, as
the VM's float_to_jsval keeps it)."""
def _ta_num(f: float) -> JSValue {
    if f != f {
        return js_nan();
    }
    if f == 0.0 {
        if jsv_double_bits(f) < 0 {
            return js_number(f);
        }
        return js_int(0);
    }
    if f >= -2147483648.0 and f <= 2147483647.0 {
        tn_i: int = int(f);
        if float(tn_i) == f {
            return js_int(tn_i);
        }
    }
    return js_number(f);
}

"""Element `index` (>= 0) of typed-array slot `ts` for the Number kinds
(1..9: one little-endian load, floats decoded natively); undefined when
out of bounds or detached. (BigInt kinds keep the byte loop.)"""
def _ta_load_slot(ts: int, index: int) -> JSValue {
    ld_sid: int = _ta_store(ts);
    if ld_sid < 0 {
        return js_undefined();
    }
    if index >= _ta_len(ts, ld_sid) {
        return js_undefined();
    }
    ld_kind: int = _TYPED_ARRAYS[ts].element_kind;
    ld_bpe: int = _TYPED_ARRAYS[ts].bytes_per_element;
    ld_off: int = _TYPED_ARRAYS[ts].byte_offset + index * ld_bpe;
    ld_ptr: int = _BACKING_STORES[ld_sid].ptr;
    if ld_kind == 9 {
        return _ta_num(jsv_double_from_bits(read_u64(ld_ptr, ld_off)));
    }
    if ld_kind == 8 {
        return _ta_num(f32_bits_to_double(read_u32(ld_ptr, ld_off)));
    }
    value: int = 0;
    if ld_bpe == 1 {
        value = read_byte(ld_ptr, ld_off);
        if ld_kind == 1 and value >= 128 {
            value = value - 256;
        }
    } elif ld_bpe == 2 {
        value = read_u16(ld_ptr, ld_off);
        if ld_kind == 4 and value >= 32768 {
            value = value - 65536;
        }
    } elif ld_bpe == 4 {
        if ld_kind == 6 {
            value = read_i32(ld_ptr, ld_off);
        } else {
            value = read_u32(ld_ptr, ld_off);
            if value > 2147483647 {
                return js_number(float(value));
            }
        }
    } else {
        shift: int = 0;
        bi: int = 0;
        while bi < ld_bpe {
            value = value | (read_byte(ld_ptr, ld_off + bi) << shift);
            shift = shift + 8;
            bi = bi + 1;
        }
    }
    return js_int(value);
}

def:pub binary_typed_array_load(view: JSValue, index: int) -> JSValue {
    if index < 0 {
        return js_undefined();
    }
    ld_ts: int = _ta_slot(view);
    if ld_ts < 0 {
        return js_undefined();
    }
    return _ta_load_slot(ld_ts, index);
}

"""GET_INDEX fast path: `view[index]` (index >= 0) for a Number-kind
(1..9) typed array; the hole sentinel when `view` is anything else (BigInt
kinds, non-views), which the caller sends down the general path."""
def:pub binary_ta_int_get(view: JSValue, index: int) -> JSValue {
    ig_ts: int = _ta_slot(view);
    if ig_ts < 0 {
        return jsv_hole();
    }
    ig_kind: int = _TYPED_ARRAYS[ig_ts].element_kind;
    if ig_kind < 1 or ig_kind > 9 {
        return jsv_hole();
    }
    return _ta_load_slot(ig_ts, index);
}

"""Store `number` (already a Number: ToNumber was the identity) at integer
element `index` (>= 0) of typed-array slot `ts`. False when out of bounds,
detached or immutable (nothing written)."""
def _ta_store_slot(ts: int, index: int, number: float) -> bool {
    st_sid: int = _ta_store(ts);
    if st_sid < 0 {
        return False;
    }
    if _BACKING_STORES[st_sid].immutable {
        return False;
    }
    if index >= _ta_len(ts, st_sid) {
        return False;
    }
    st_kind: int = _TYPED_ARRAYS[ts].element_kind;
    if st_kind == 9 {
        write_i64(
            _BACKING_STORES[st_sid].ptr,
            _TYPED_ARRAYS[ts].byte_offset + index * 8,
            jsv_double_bits(number)
        );
        return True;
    }
    if st_kind == 8 {
        write_i32(
            _BACKING_STORES[st_sid].ptr,
            _TYPED_ARRAYS[ts].byte_offset + index * 4,
            double_to_f32_bits(number)
        );
        return True;
    }
    # ToInt8..ToUint32 keep the low bits of the truncated value: NaN and
    # ±Infinity are 0, and a magnitude past int64 (1e20) is reduced mod 2^32
    # first (exact for an integral double) — int() of it is not defined.
    value: int = 0;
    if number - number == 0.0 {
        if number < 9.0e15 and number > -9.0e15 {
            value = int(number);
        } else {
            value = int(number % 4294967296.0);
        }
    }
    if _TYPED_ARRAYS[ts].element_kind == 3 {
        # ToUint8Clamp — IEEE round half to even (ties-to-even).
        if number != number or number <= 0.0 {
            value = 0;
        } elif number >= 255.0 {
            value = 255;
        } else {
            f: int = int(number);  # truncate toward 0 == floor for number in (0, 255)
            frac: float = number - float(f);
            if frac > 0.5 {
                value = f + 1;
            } elif frac < 0.5 {
                value = f;
            } elif (f % 2) == 0 {
                value = f;
            } else {
                value = f + 1;
            }
        }
    }
    st_bpe: int = _TYPED_ARRAYS[ts].bytes_per_element;
    st_off: int = _TYPED_ARRAYS[ts].byte_offset + index * st_bpe;
    st_ptr: int = _BACKING_STORES[st_sid].ptr;
    if st_bpe == 1 {
        write_byte(st_ptr, st_off, value & 255);
        return True;
    }
    if st_bpe == 4 {
        write_i32(st_ptr, st_off, value & 4294967295);
        return True;
    }
    bi: int = 0;
    while bi < st_bpe {
        write_byte(st_ptr, st_off + bi, value & 255);
        value = value >> 8;
        bi = bi + 1;
    }
    return True;
}

def:pub binary_typed_array_store_number(
    view: JSValue, index: int, number: float
) -> bool {
    if index < 0 {
        return False;
    }
    sn_ts: int = _ta_slot(view);
    if sn_ts < 0 {
        return False;
    }
    return _ta_store_slot(sn_ts, index, number);
}

"""SET_INDEX fast path: `view[index] = number` (index >= 0, number already a
Number) for a Number-kind (1..9) typed array. True when handled — including
an out-of-bounds or detached write, which integer-indexed [[Set]] ignores —
and False when `view` is anything else (general path)."""
def:pub binary_ta_int_set(view: JSValue, index: int, number: float) -> bool {
    is_ts: int = _ta_slot(view);
    if is_ts < 0 {
        return False;
    }
    is_kind: int = _TYPED_ARRAYS[is_ts].element_kind;
    if is_kind < 1 or is_kind > 9 {
        return False;
    }
    _ = _ta_store_slot(is_ts, index, number);
    return True;
}

"""GetViewValue for integer widths 1/2/4. `rel_offset` is already ToIndex'd.
Returns undefined if witness invalid/detached/OOB (JS maps to TypeError/RangeError)."""
def:pub binary_data_view_get_int(
    view: JSValue, rel_offset: int, size: int, little_endian: bool, signed: bool
) -> JSValue {
    if not binary_is_data_view(view) {
        return js_undefined();
    }
    witness: BinaryViewWitness = binary_view_witness(view);
    if not witness.valid or witness.detached {
        return js_undefined();
    }
    if rel_offset < 0 or size <= 0 or rel_offset + size > witness.byte_length {
        return js_undefined();
    }
    raw: JSObject = _binary_raw(view);
    store: BackingStore = binary_backing_store(
        jsv_from_object_id(_DATA_VIEWS[raw.bslot()].buffer_id)
    );
    abs_off: int = witness.byte_offset + rel_offset;
    value: int = 0;
    if little_endian {
        bi: int = 0;
        shift: int = 0;
        while bi < size {
            value = value | (read_byte(store.ptr, abs_off + bi) << shift);
            shift = shift + 8;
            bi = bi + 1;
        }
    } else {
        bi2: int = 0;
        while bi2 < size {
            value = (value << 8) | read_byte(store.ptr, abs_off + bi2);
            bi2 = bi2 + 1;
        }
    }
    if signed {
        if size == 1 and value >= 128 {
            value = value - 256;
        } elif size == 2 and value >= 32768 {
            value = value - 65536;
        } elif size == 4 and value >= 2147483648 {
            value = value - 4294967296;
        }
    } elif size == 4 and value > 2147483647 {
        return js_number(float(value));
    }
    return js_int(value);
}

"""SetViewValue for integer widths 1/2/4 after ToNumber. Returns 0 ok, 1 fail."""
def:pub binary_data_view_set_int(
    view: JSValue, rel_offset: int, size: int, little_endian: bool, number: float
) -> int {
    if not binary_is_data_view(view) {
        return 1;
    }
    witness: BinaryViewWitness = binary_view_witness(view);
    if not witness.valid or witness.detached {
        return 1;
    }
    if rel_offset < 0 or size <= 0 or rel_offset + size > witness.byte_length {
        return 1;
    }
    raw: JSObject = _binary_raw(view);
    store: BackingStore = binary_backing_store(
        jsv_from_object_id(_DATA_VIEWS[raw.bslot()].buffer_id)
    );
    if store.immutable {
        return 1;
    }
    value: int = int(number);
    abs_off: int = witness.byte_offset + rel_offset;
    if little_endian {
        bi: int = 0;
        v: int = value;
        while bi < size {
            write_byte(store.ptr, abs_off + bi, v & 255);
            v = v >> 8;
            bi = bi + 1;
        }
    } else {
        bi2: int = size - 1;
        v2: int = value;
        while bi2 >= 0 {
            write_byte(store.ptr, abs_off + bi2, v2 & 255);
            v2 = v2 >> 8;
            bi2 = bi2 - 1;
        }
    }
    return 0;
}
