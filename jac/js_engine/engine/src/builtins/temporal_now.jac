"""Temporal.Now static methods."""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    jsv_is_int32,
    jsv_to_int32,
    js_undefined
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.bignat { bn_from_int, bn_mul_small, bn_to_string }
import from engine.src.ffi.libuv { uvhrtime }
import from engine.src.ffi.libc { time, getenv }
import from engine.src.builtins.temporal {
    js_instant_create,
    js_instant_read_ns,
    js_plain_date_create,
    js_plain_time_create,
    js_plain_datetime_create,
    js_zoned_datetime_create,
    temporal_to_string,
    temporal_offset_ns_for_zone,
    ToTemporalTimeZoneIdentifier,
    KEY_ISO_YEAR,
    KEY_ISO_MONTH,
    KEY_ISO_DAY,
    KEY_ISO_HOUR,
    KEY_ISO_MINUTE,
    KEY_ISO_SECOND,
    KEY_ISO_NANOSECOND
}
import from engine.src.builtins.temporal_zoneddatetime {
    temporal_zoned_from_epoch_ns_string
}
import from engine.src.builtins.date {
    js_date_create,
    js_Date_getFullYear,
    js_Date_getMonth,
    js_Date_getDate
}

glob _NOW_ANCHORED: bool = False,
     _NOW_EPOCH_MS: int = 0,
     _NOW_HR_MS: int = 0;

def _now_epoch_ms -> int {
    hr_ms: int = uvhrtime() // 1000000;
    if not _NOW_ANCHORED {
        _NOW_ANCHORED = True;
        _NOW_EPOCH_MS = time(0) * 1000;
        _NOW_HR_MS = hr_ms;
    }
    return _NOW_EPOCH_MS + (hr_ms - _NOW_HR_MS);
}

def _slot_int(o: JSValue, key: int) -> int {
    v: JSValue = js_object_get(o, key);
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    return 0;
}

def:pub js_Temporal_Now_instant(args: list[JSValue]) -> JSValue {
    ms: int = _now_epoch_ms();
    ns: list[int] = bn_mul_small(bn_from_int(ms), 1000000);
    return js_instant_create(ns);
}

def:pub js_Temporal_Now_plainDateISO(args: list[JSValue]) -> JSValue {
    # A provided timeZone argument is validated via ToTemporalTimeZoneIdentifier: a
    # wrong type throws TypeError and an invalid identifier (e.g. a leap second in the
    # offset "[+23:59:60]") throws RangeError — even though this engine still reports
    # the local wall-clock date.
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        _ = ToTemporalTimeZoneIdentifier(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    ms: int = _now_epoch_ms();
    d: JSValue = js_date_create(float(ms));
    yv: JSValue = js_Date_getFullYear(d);
    mv: JSValue = js_Date_getMonth(d);
    dv: JSValue = js_Date_getDate(d);
    yr2: int = 0;
    mo: int = 0;
    day: int = 0;
    if jsv_is_int32(yv) {
        yr2 = jsv_to_int32(yv);
    }
    if jsv_is_int32(mv) {
        mo = jsv_to_int32(mv) + 1;
    }
    if jsv_is_int32(dv) {
        day = jsv_to_int32(dv);
    }
    return js_plain_date_create(yr2, mo, day, "iso8601");
}

def:pub js_Temporal_Now_plainTimeISO(args: list[JSValue]) -> JSValue {
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        _ = ToTemporalTimeZoneIdentifier(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    ms: int = _now_epoch_ms();
    sec: int = (ms // 1000) % 86400;
    h: int = sec // 3600;
    mi: int = (sec % 3600) // 60;
    s: int = sec % 60;
    ns: int = (ms % 1000) * 1000000;
    return js_plain_time_create(h, mi, s, ns, "iso8601");
}

def:pub js_Temporal_Now_plainDateTimeISO(args: list[JSValue]) -> JSValue {
    if len(args) > 0 and not jsv_is_undefined(args[0]) {
        _ = ToTemporalTimeZoneIdentifier(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    pd: JSValue = js_Temporal_Now_plainDateISO([]);
    pt: JSValue = js_Temporal_Now_plainTimeISO([]);
    return js_plain_datetime_create(
        _slot_int(pd, KEY_ISO_YEAR),
        _slot_int(pd, KEY_ISO_MONTH),
        _slot_int(pd, KEY_ISO_DAY),
        _slot_int(pt, KEY_ISO_HOUR),
        _slot_int(pt, KEY_ISO_MINUTE),
        _slot_int(pt, KEY_ISO_SECOND),
        _slot_int(pt, KEY_ISO_NANOSECOND),
        "iso8601"
    );
}

def _now_timezone_id -> str {
    tz: str = getenv("TZ");
    if tz == None or tz == "" {
        return "UTC";
    }
    return tz;
}

def:pub js_Temporal_Now_timeZoneId(args: list[JSValue]) -> JSValue {
    return jsv_from_string_id(str_intern(_now_timezone_id()));
}

def:pub js_Temporal_Now_zonedDateTimeISO(args: list[JSValue]) -> JSValue {
    tz: str = _now_timezone_id();
    if len(args) > 0 {
        tz = ToTemporalTimeZoneIdentifier(args[0]);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }
    ins: JSValue = js_Temporal_Now_instant([]);
    ns: list[int] = js_instant_read_ns(ins);
    return temporal_zoned_from_epoch_ns_string(bn_to_string(ns, 10), tz, "iso8601");
}
