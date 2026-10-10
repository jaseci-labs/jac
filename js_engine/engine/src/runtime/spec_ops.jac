"""
Shared ECMAScript specification operations — descriptor records, SameValue,
and descriptor compatibility checks.

Centralizes logic previously duplicated across object.na.jac and vm.na.jac.
Observable ToPropertyDescriptor with getters remains in vm_obs / vm paths;
this module owns the record shape and ValidateAndApply compatibility rules.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_false,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_bigint_cell,
    jsv_is_any_object,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_is_htmldda,
    JS_CELL_KIND_NATIVE,
    jsv_coerce_to_bool,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    js_strict_equal,
    __float_bits,
    jsv_from_object_id
}
import from engine.src.runtime.jsobj_type {
    JSProperty,
    PropertyDescriptorRecord,
    PROP_WRITABLE,
    PROP_ENUMERABLE,
    PROP_CONFIGURABLE,
    proto_epoch
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jssymbol { js_symbol_get_proto }
import from engine.src.runtime.js_bigint { js_bigint_cells_equal }
import from engine.src.runtime.fn_meta { fn_meta_is_closure }
import from engine.src.runtime.jsobject {
    js_object_has_own,
    KEY_CTOR_KIND,
    js_object_is_plain_ordinary,
    js_object_proto_idx_id
}
import from engine.src.runtime.proxy { js_is_proxy, js_proxy_is_callable }
import from engine.src.runtime.wk_keys {
    WK_IS_CLASS,
    WK_VALUE,
    WK_WRITABLE,
    WK_ENUMERABLE,
    WK_CONFIGURABLE,
    WK_GET,
    WK_SET
}
import from engine.src.vm.vm_obs { js_object_get_observable, js_object_has_observable }
import from engine.src.builtins.markers {
    _KEY_IS_RESOLVE,
    _KEY_IS_REJECT,
    _KEY_IS_PROMISE_ALL_RESOLVE,
    _KEY_IS_PROMISE_ALL_REJECT,
    _KEY_IS_PROMISE_ALLSETTLED_RESOLVE,
    _KEY_IS_PROMISE_ALLSETTLED_REJECT,
    _KEY_IS_PROMISE_ANY_REJECT
}
import from engine.src.runtime.error {
    make_type_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.builtins.native_registry { is_native_val }

"""Return True when Desc is a JS Object suitable for ToPropertyDescriptor."""
def:pub spec_is_desc_object(desc: JSValue) -> bool {
    if jsv_is_object_cell(desc) {
        return True;
    }
    if is_native_val(desc) {
        return True;
    }
    if jsv_is_cell(desc) and jsv_cell_kind(desc) == JS_CELL_KIND_NATIVE {
        return True;
    }
    return False;
}

"""True iff v is a promise's resolve / reject function or a Promise.all /
allSettled / any element function — marker objects (builtins/promise.jac) that
the VM runs specially; they are functions to JS (typeof, IsCallable)."""
def:pub spec_is_promise_fn_marker(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_RESOLVE)
        or js_object_has_own(v, _KEY_IS_REJECT)
        or js_object_has_own(v, _KEY_IS_PROMISE_ALL_RESOLVE)
        or js_object_has_own(v, _KEY_IS_PROMISE_ALL_REJECT)
        or js_object_has_own(v, _KEY_IS_PROMISE_ALLSETTLED_RESOLVE)
        or js_object_has_own(v, _KEY_IS_PROMISE_ALLSETTLED_REJECT)
        or js_object_has_own(v, _KEY_IS_PROMISE_ANY_REJECT);
}

"""Shared IsCallable predicate used by descriptor and callback validation."""
def:pub spec_is_callable(v: JSValue) -> bool {
    if jsv_is_htmldda(v) {
        return True;
    }
    if fn_meta_is_closure(v) {
        return True;
    }
    if is_native_val(v) {
        return True;
    }
    if js_is_proxy(v) {
        return js_proxy_is_callable(v);
    }
    if jsv_is_object_cell(v) and jsv_to_table_id(v) > 0 {
        return (
            js_object_has_own(v, KEY_CTOR_KIND)
            or js_object_has_own(v, WK_IS_CLASS)
            or spec_is_promise_fn_marker(v)
        );
    }
    return False;
}

"""ES §7.2.14 SameValue."""
def:pub spec_same_value(a: JSValue, b: JSValue) -> bool {
    a_num: bool = jsv_is_int32(a) or jsv_is_double(a);
    b_num: bool = jsv_is_int32(b) or jsv_is_double(b);
    if a_num and b_num {
        da: float = 0.0;
        db: float = 0.0;
        if jsv_is_int32(a) {
            da = float(jsv_to_int32(a));
        } else {
            da = jsv_to_double(a);
        }
        if jsv_is_int32(b) {
            db = float(jsv_to_int32(b));
        } else {
            db = jsv_to_double(b);
        }
        if da != da and db != db {
            return True;
        }
        if da != da or db != db {
            return False;
        }
        # +0 and -0 are distinct under SameValue (unlike ===).
        # Use IEEE sign bit — avoid 1.0/0.0 which can SIGFPE under Jac.
        if da == 0.0 and db == 0.0 {
            a_neg: bool = jsv_is_double(a) and __float_bits(da) < 0;
            b_neg: bool = jsv_is_double(b) and __float_bits(db) < 0;
            return a_neg == b_neg;
        }
        return da == db;
    }
    if jsv_is_bigint_cell(a) and jsv_is_bigint_cell(b) {
        return js_bigint_cells_equal(a, b);
    }
    # Heap strings: equal content, different ids — compare text (see js_strict_equal).
    if jsv_is_string_cell(a) and jsv_is_string_cell(b) {
        if a == b {
            return True;
        }
        ssv_sa: str = str_from_id(jsv_to_table_id(a));
        ssv_sb: str = str_from_id(jsv_to_table_id(b));
        return ssv_sa == ssv_sb;
    }
    return js_strict_equal(a, b);
}

"""
From an observable Attributes object, build a PropertyDescriptorRecord.
Each field is read at most once via js_object_has_observable / get_observable.
Returns is_invalid=True when data and accessor fields are mixed.
"""
# Object.prototype as last seen without any descriptor key (see _desc_own_only),
# valid while the proto epoch is unchanged (any change to a prototype object,
# including adding such a key, bumps it).
glob _TPD_PROTO_ID: int = -1;
glob _TPD_PROTO_EPOCH: int = -1;

"""True when HasProperty(desc, k) for the six descriptor keys is just the own
lookup: `desc` is an ordinary object whose [[Prototype]] is null, or a
null-prototype ordinary object (Object.prototype) that has none of them."""
def _desc_own_only(desc: JSValue) -> bool {
    if not js_object_is_plain_ordinary(desc) {
        return False;
    }
    dp: int = js_object_proto_idx_id(jsv_to_table_id(desc));
    if dp <= 0 {
        return True;
    }
    if dp == _TPD_PROTO_ID and _TPD_PROTO_EPOCH == proto_epoch() {
        return True;
    }
    dpv: JSValue = jsv_from_object_id(dp);
    if not js_object_is_plain_ordinary(dpv) or js_object_proto_idx_id(dp) > 0 {
        return False;
    }
    for dk in [WK_VALUE, WK_WRITABLE, WK_ENUMERABLE, WK_CONFIGURABLE, WK_GET, WK_SET] {
        if js_object_has_own(dpv, dk) {
            return False;
        }
    }
    _TPD_PROTO_ID = dp;
    _TPD_PROTO_EPOCH = proto_epoch();
    return True;
}

def:pub spec_to_property_descriptor(desc: JSValue) -> PropertyDescriptorRecord {
    rec: PropertyDescriptorRecord = PropertyDescriptorRecord();
    if not spec_is_desc_object(desc) {
        vm_throw_native(make_type_error("Property description must be an object"));
        return rec;
    }
    vk: int = WK_VALUE;
    wk: int = WK_WRITABLE;
    ek: int = WK_ENUMERABLE;
    ck: int = WK_CONFIGURABLE;
    gk: int = WK_GET;
    sk: int = WK_SET;

    # ES ToPropertyDescriptor (§6.2.6.5) uses HasProperty (includes inherited).
    # Prefer has_own so own undefined fields still count; else has_observable
    # — unless nothing up the chain can have the key (_desc_own_only).
    # Never call user `.hasOwnProperty`.
    own_only: bool = _desc_own_only(desc);
    if js_object_has_own(desc, ek)
        or (not own_only and js_object_has_observable(desc, ek)) {
        rec.has_enumerable = True;
        rec.enumerable = jsv_coerce_to_bool(js_object_get_observable(desc, ek, desc));
        if vm_has_native_exc() {
            return rec;
        }
    }
    if js_object_has_own(desc, ck)
        or (not own_only and js_object_has_observable(desc, ck)) {
        rec.has_configurable = True;
        rec.configurable = jsv_coerce_to_bool(js_object_get_observable(desc, ck, desc));
        if vm_has_native_exc() {
            return rec;
        }
    }
    if js_object_has_own(desc, vk)
        or (not own_only and js_object_has_observable(desc, vk)) {
        rec.has_value = True;
        rec.value = js_object_get_observable(desc, vk, desc);
        if vm_has_native_exc() {
            return rec;
        }
    }
    if js_object_has_own(desc, wk)
        or (not own_only and js_object_has_observable(desc, wk)) {
        rec.has_writable = True;
        rec.writable = jsv_coerce_to_bool(js_object_get_observable(desc, wk, desc));
        if vm_has_native_exc() {
            return rec;
        }
    }
    if js_object_has_own(desc, gk)
        or (not own_only and js_object_has_observable(desc, gk)) {
        rec.has_get = True;
        rec.get = js_object_get_observable(desc, gk, desc);
        if vm_has_native_exc() {
            return rec;
        }
        if not jsv_is_undefined(rec.get) and not spec_is_callable(rec.get) {
            vm_throw_native(make_type_error("Getter must be a function"));
            rec.is_invalid = True;
            return rec;
        }
    }
    if js_object_has_own(desc, sk)
        or (not own_only and js_object_has_observable(desc, sk)) {
        rec.has_set = True;
        rec.set = js_object_get_observable(desc, sk, desc);
        if vm_has_native_exc() {
            return rec;
        }
        if not jsv_is_undefined(rec.set) and not spec_is_callable(rec.set) {
            vm_throw_native(make_type_error("Setter must be a function"));
            rec.is_invalid = True;
            return rec;
        }
    }

    rec.is_accessor = rec.has_get or rec.has_set;
    if rec.is_accessor and (rec.has_value or rec.has_writable) {
        rec.is_invalid = True;
    }
    return rec;
}

"""
CompletePropertyDescriptor — fill omitted boolean fields with false for new
descriptors; when updating, callers merge with existing before apply.
"""
def:pub spec_complete_property_descriptor(
    rec: PropertyDescriptorRecord, is_new: bool
) -> PropertyDescriptorRecord {
    out: PropertyDescriptorRecord = PropertyDescriptorRecord(
        has_value=rec.has_value,
        has_writable=rec.has_writable,
        has_get=rec.has_get,
        has_set=rec.has_set,
        has_enumerable=rec.has_enumerable,
        has_configurable=rec.has_configurable,
        value=rec.value,
        writable=rec.writable,
        get=rec.get,
        set=rec.set,
        enumerable=rec.enumerable,
        configurable=rec.configurable,
        is_invalid=rec.is_invalid,
        is_accessor=rec.is_accessor
    );
    if is_new {
        if not out.has_enumerable {
            out.enumerable = False;
            out.has_enumerable = True;
        }
        if not out.has_configurable {
            out.configurable = False;
            out.has_configurable = True;
        }
        if out.is_accessor {
            if not out.has_get {
                out.get = js_undefined();
                out.has_get = True;
            }
            if not out.has_set {
                out.set = js_undefined();
                out.has_set = True;
            }
        } else {
            if not out.has_value {
                out.value = js_undefined();
                out.has_value = True;
            }
            if not out.has_writable {
                out.writable = False;
                out.has_writable = True;
            }
        }
    }
    return out;
}

"""True when Desc is a data descriptor (as distinct from generic/accessor)."""
def:pub spec_is_data_descriptor(rec: PropertyDescriptorRecord) -> bool {
    return rec.has_value or rec.has_writable;
}

"""Complete IsCompatiblePropertyDescriptor over descriptor records."""
def:pub spec_are_descriptor_records_compatible(
    extensible: bool,
    rec: PropertyDescriptorRecord,
    current: PropertyDescriptorRecord,
    current_exists: bool
) -> bool {
    if rec.is_invalid {
        return False;
    }
    if not current_exists {
        return extensible;
    }
    if (
        not rec.has_value
        and not rec.has_writable
        and not rec.has_get
        and not rec.has_set
        and not rec.has_enumerable
        and not rec.has_configurable
    ) {
        return True;
    }
    if current.configurable {
        return True;
    }
    if rec.has_configurable and rec.configurable {
        return False;
    }
    if rec.has_enumerable and rec.enumerable != current.enumerable {
        return False;
    }

    rec_accessor: bool = rec.has_get or rec.has_set;
    rec_data: bool = spec_is_data_descriptor(rec);
    current_accessor: bool = current.has_get or current.has_set;
    current_data: bool = spec_is_data_descriptor(current);
    if (rec_accessor and current_data) or (rec_data and current_accessor) {
        return False;
    }
    if current_data and rec_data and not current.writable {
        if rec.has_writable and rec.writable {
            return False;
        }
        if rec.has_value and not spec_same_value(rec.value, current.value) {
            return False;
        }
    }
    if current_accessor and rec_accessor {
        # Only fields present on Desc are compared; omitted get/set keep current (§10.1.6.3).
        if rec.has_get and not spec_same_value(rec.get, current.get) {
            return False;
        }
        if rec.has_set and not spec_same_value(rec.set, current.set) {
            return False;
        }
    }
    return True;
}

"""
ValidateAndApplyPropertyDescriptor record core.

The operation is deliberately storage-neutral: it returns the fully merged
descriptor for the object's [[DefineOwnProperty]] implementation to commit.
"""
def:pub spec_validate_and_apply_descriptor(
    extensible: bool,
    rec: PropertyDescriptorRecord,
    current: PropertyDescriptorRecord,
    current_exists: bool
) -> tuple[bool, PropertyDescriptorRecord] {
    empty: PropertyDescriptorRecord = PropertyDescriptorRecord();
    if not spec_are_descriptor_records_compatible(
        extensible, rec, current, current_exists
    ) {
        return (False, empty);
    }
    rec_accessor0: bool = rec.has_get or rec.has_set;
    rec_data0: bool = spec_is_data_descriptor(rec);
    current_accessor0: bool = current.has_get or current.has_set;
    current_data0: bool = spec_is_data_descriptor(current);
    # ES §10.1.6.3: non-configurable own properties reject accessor↔data redefinition.
    if (
        current_exists
        and not current.configurable
        and ((rec_accessor0 and current_data0) or (rec_data0 and current_accessor0))
    ) {
        return (False, empty);
    }
    if not current_exists {
        return (True, spec_complete_property_descriptor(rec, True));
    }

    # Copy fields into a fresh record so merges never mutate the caller's
    # `current` snapshot (PropertyDescriptorRecord is a reference obj).
    out: PropertyDescriptorRecord = PropertyDescriptorRecord(
        has_value=current.has_value,
        has_writable=current.has_writable,
        has_get=current.has_get,
        has_set=current.has_set,
        has_enumerable=current.has_enumerable,
        has_configurable=current.has_configurable,
        value=current.value,
        writable=current.writable,
        get=current.get,
        set=current.set,
        enumerable=current.enumerable,
        configurable=current.configurable,
        is_invalid=False,
        is_accessor=current.is_accessor
    );
    rec_accessor: bool = rec.has_get or rec.has_set;
    rec_data: bool = spec_is_data_descriptor(rec);
    current_accessor: bool = current.has_get or current.has_set;
    current_data: bool = spec_is_data_descriptor(current);
    if current.configurable
        and ((rec_accessor and current_data) or (rec_data and current_accessor)) {
        # ES §10.1.6.3 steps 6–7: switching kind preserves [[Enumerable]] /
        # [[Configurable]] from current when Desc omits them.
        out = PropertyDescriptorRecord(
            has_value=rec_data,
            has_writable=rec_data,
            has_get=rec_accessor,
            has_set=rec_accessor,
            has_enumerable=True,
            has_configurable=True,
            value=js_undefined(),
            writable=False,
            get=js_undefined(),
            set=js_undefined(),
            enumerable=current.enumerable,
            configurable=current.configurable,
            is_invalid=False,
            is_accessor=rec_accessor
        );
    }
    if rec.has_value {
        out.has_value = True;
        out.value = rec.value;
    }
    if rec.has_writable {
        out.has_writable = True;
        out.writable = rec.writable;
    }
    # ES §10.1.6.3 step 6.i: non-configurable writable data may only downgrade [[Writable]].
    if (
        current_data
        and not current.configurable
        and current.writable
        and rec_data
        and rec.has_writable
        and not rec.writable
    ) {
        out.writable = False;
    }
    if rec.has_get {
        out.has_get = True;
        out.get = rec.get;
    }
    if rec.has_set {
        out.has_set = True;
        out.set = rec.set;
    }
    # Omitted enumerable/configurable on reconfigure keep current values
    # (already copied into `out` above).
    if rec.has_enumerable {
        out.has_enumerable = True;
        out.enumerable = rec.enumerable;
    }
    if rec.has_configurable {
        out.has_configurable = True;
        out.configurable = rec.configurable;
    }
    out.is_accessor = out.has_get or out.has_set;
    out.is_invalid = False;
    return (True, out);
}

"""Convert a completed data PropertyDescriptorRecord to JSProperty."""
def:pub spec_data_record_to_jsproperty(rec: PropertyDescriptorRecord) -> JSProperty {
    return JSProperty(
        key=0,
        value=rec.value,
        writable=rec.writable,
        enumerable=rec.enumerable,
        configurable=rec.configurable,
        deleted=False
    );
}

"""Bitmask for js_object_define_property / properties.set."""
def:pub spec_record_data_flags(rec: PropertyDescriptorRecord) -> int {
    flags: int = 0;
    if rec.writable {
        flags = flags | PROP_WRITABLE;
    }
    if rec.enumerable {
        flags = flags | PROP_ENUMERABLE;
    }
    if rec.configurable {
        flags = flags | PROP_CONFIGURABLE;
    }
    return flags;
}
