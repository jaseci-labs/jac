"""Date built-in — ECMAScript §21.4

Pure arithmetic implementation using Howard Hinnant's civil date algorithms.
Only libc dependency: time(0) for current epoch seconds.
"""

import from engine.src.ffi.libc { time }
import from engine.src.ffi.libuv { uvhrtime }

import from engine.src.runtime.jsvalue {
    JSValue,
    MATH_NAN,
    MATH_INF,
    MATH_NEG_INF,
    js_null,
    js_true,
    js_int,
    js_nan,
    js_number,
    jsv_undefined,
    jsv_from_string_id,
    jsv_coerce_to_number,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_heap, str_from_id }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_set,
    js_object_get,
    js_object_has_own,
    js_object_define_nonenum,
    JSProperty,
    js_object_define_property
}

import from engine.src.runtime.error {
    make_type_error,
    make_range_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.vm.vm_obs {
    js_to_number_observable,
    js_to_primitive_observable,
    OBS_HINT_DEFAULT
}

def _date_js_str(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));  # G1.5: date toString is a transient value
}

import from engine.src.builtins.markers { _KEY_IS_DATE }
import from engine.src.runtime.gc_pin { gc_pin_value }
glob _DATE_NOW_ANCHORED: bool = False,
     _DATE_NOW_EPOCH_MS_BASE: int = 0,
     _DATE_NOW_HR_MS_BASE: int = 0;

"""Internal: Date.prototype object, wired by init_global."""
glob _DATE_PROTO: JSValue = jsv_undefined();

def:pub js_date_set_proto(proto: JSValue) {
    _DATE_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

# ── Field indices for _utc_field ─────────────────────────────────────────────
glob _F_YEAR: int = 0,
     _F_MONTH: int = 1,
     _F_DATE: int = 2,
     _F_DAY: int = 3,
     _F_HOUR: int = 4,
     _F_MIN: int = 5,
     _F_SEC: int = 6,
     _F_MS: int = 7;

# ── Date object creation / detection ─────────────────────────────────────────

def:pub js_is_date(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) or jsv_to_table_id(v) <= 0 {
        return False;
    }
    return js_object_has_own(v, _KEY_IS_DATE);
}

def:pub js_date_create(ms: float) -> JSValue {
    d: JSValue = js_object_create(_DATE_PROTO)
        if jsv_is_object_cell(_DATE_PROTO)
        else js_object_create_null();
    # Internal slots must not be enumerable — Object.create(PropertiesObject) would
    # otherwise treat them as property descriptors.
    js_object_define_nonenum(d, _KEY_IS_DATE, js_true());
    js_object_define_nonenum(d, str_intern("__ms"), js_number(ms));
    return d;
}

def _get_ms(d: JSValue) -> float {
    v: JSValue = js_object_get(d, str_intern("__ms"));
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    return MATH_NAN;
}

def _set_ms(d: JSValue, ms: float) {
    js_object_define_nonenum(d, str_intern("__ms"), js_number(ms));
}

def _this_time_value_ms(this_val: JSValue) -> float {
    if not js_is_date(this_val) {
        vm_throw_native(
            make_type_error("Method Date.prototype called on incompatible receiver")
        );
        return MATH_NAN;
    }
    return _get_ms(this_val);
}

def _is_nan(v: float) -> bool {
    return v != v;
}

"""True for a finite number (not NaN, not ±Infinity). MakeTime/MakeDay yield NaN
when any component is non-finite (§21.4.1.11 / §21.4.1.12)."""
def _is_finite(v: float) -> bool {
    if v != v {
        return False;
    }
    if v == MATH_INF {
        return False;
    }
    if v == MATH_NEG_INF {
        return False;
    }
    return True;
}

# ── Pure-arithmetic civil ↔ days (Howard Hinnant) ────────────────────────────

"""y=year, m=month 1-based, d=day 1-based → days since 1970-01-01."""
def _days_from_civil(y: int, m: int, d: int) -> int {
    adj_y: int = y;
    if m <= 2 {
        adj_y = adj_y - 1;
    }
    # Hinnant's algorithm biases negative years by -399 to emulate FLOOR division on
    # top of C++ TRUNCATING division. Jac `//` already floors, so `adj_y // 400`
    # gives the floored era directly for both signs — applying the -399 bias here
    # would double-adjust and shift every pre-1BC date one day early.
    era: int = adj_y // 400;
    yoe: int = adj_y - era * 400;
    mp: int = m - 3;
    if m <= 2 {
        mp = m + 9;
    }
    doy: int = (153 * mp + 2) // 5 + d - 1;
    doe: int = yoe * 365 + yoe // 4 - yoe // 100 + doy;
    return era * 146097 + doe - 719468;
}

"""Decompose epoch_ms into a date/time field (UTC).
field: 0=year, 1=month(0-based), 2=date, 3=weekday(0=Sun), 4=hour, 5=min, 6=sec, 7=ms."""
def _utc_field(epoch_ms: float, field: int) -> int {
    t: int = int(epoch_ms);

    ms_r: int = t % 1000;
    if ms_r < 0 {
        ms_r = ms_r + 1000;
    }
    if field == _F_MS {
        return ms_r;
    }

    total_s: int = (t - ms_r) // 1000;
    time_s: int = total_s % 86400;
    if time_s < 0 {
        time_s = time_s + 86400;
    }

    if field == _F_HOUR {
        return time_s // 3600;
    }
    if field == _F_MIN {
        return (time_s % 3600) // 60;
    }
    if field == _F_SEC {
        return time_s % 60;
    }

    days: int = (total_s - time_s) // 86400;

    if field == _F_DAY {
        wd: int = (days % 7 + 11) % 7;
        return wd;
    }

    z: int = days + 719468;
    # Jac `//` floors, so z // 146097 is the floored era for both signs; the
    # -146096 bias (a truncating-division floor emulation) would double-adjust.
    era: int = z // 146097;
    doe: int = z - era * 146097;
    yoe: int = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365;
    y: int = yoe + era * 400;
    doy: int = doe - (365 * yoe + yoe // 4 - yoe // 100);
    mp: int = (5 * doy + 2) // 153;
    d: int = doy - (153 * mp + 2) // 5 + 1;
    m: int = mp + 3;
    if mp >= 10 {
        m = mp - 9;
    }
    if m <= 2 {
        y = y + 1;
    }

    if field == _F_YEAR {
        return y;
    }
    if field == _F_MONTH {
        return m - 1;
    }
    if field == _F_DATE {
        return d;
    }
    return 0;
}

"""Compose epoch ms from components. m0 is 0-based (JS convention)."""
def _make_date(y: int, m0: int, d: int, hr: int, mn: int, sc: int, ms: int) -> float {
    adj_m: int = m0 % 12;
    if adj_m < 0 {
        adj_m = adj_m + 12;
    }
    adj_y: int = y + (m0 - adj_m) // 12;
    civil_m: int = adj_m + 1;
    days: int = _days_from_civil(adj_y, civil_m, d);
    return float(days) * 86400000.0
        + float(hr) * 3600000.0
        + float(mn) * 60000.0
        + float(sc) * 1000.0
        + float(ms);
}

def _to_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

"""TimeClip — ECMAScript §21.4.1.31. NaN if non-finite or abs > 8.64e15;
normalizes -0 to +0 (step 3 adds +0, so the result is never negative zero)."""
def _time_clip(t: float) -> float {
    if _is_finite(t) == False {
        return MATH_NAN;
    }
    if t > 8.64e15 {
        return MATH_NAN;
    }
    if t < -8.64e15 {
        return MATH_NAN;
    }
    if t == 0.0 {
        return 0.0;
    }
    # TimeClip returns an integral Number: ToIntegerOrInfinity truncates the
    # fractional part toward zero.
    return float(int(t));
}

"""ECMAScript ToNumber of a Date-setter argument (observable — runs valueOf /
toString, so abrupt completions propagate via vm_has_native_exc). Callers must
coerce every present argument up front, left-to-right, before touching the time
value (§21.4.4 setters read all args before the NaN check)."""
def _to_num_arg(v: JSValue) -> float {
    return js_to_number_observable(v);
}

"""Truncate a finite coerced float toward zero for _make_date. Non-finite inputs
are filtered by the caller (they force a NaN result), so this only sees finite
values."""
def _num_to_int(f: float) -> int {
    return int(f);
}

# ── Date.now() ───────────────────────────────────────────────────────────────

def:pub js_Date_now -> JSValue {
    # Compose epoch milliseconds from:
    # - a one-time wall-clock anchor (time(0) * 1000), and
    # - monotonic elapsed time from uv_hrtime().
    # This avoids jitter/step artifacts from mixing wall-clock seconds and
    # unrelated monotonic sub-milliseconds on every call.
    now_hr_ms: int = uvhrtime() // 1000000;
    if not _DATE_NOW_ANCHORED {
        _DATE_NOW_ANCHORED = True;
        _DATE_NOW_EPOCH_MS_BASE = time(0) * 1000;
        _DATE_NOW_HR_MS_BASE = now_hr_ms;
    }
    return js_number(
        float(_DATE_NOW_EPOCH_MS_BASE + (now_hr_ms - _DATE_NOW_HR_MS_BASE))
    );
}

# ── Date.UTC(...) ────────────────────────────────────────────────────────────

def:pub js_Date_UTC(args: list[JSValue]) -> JSValue {
    # §21.4.3.4: ToNumber every supplied argument left-to-right (observable),
    # then TimeClip(MakeDate(MakeDay(...), MakeTime(...))). Missing year is
    # ToNumber(undefined) = NaN → result NaN. Any non-finite component → NaN.
    yr_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        yr_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(yr_f) == False;
    }
    mo_f: float = 0.0;
    if len(args) > 1 {
        mo_f = _to_num_arg(args[1]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(mo_f) == False {
            bad = True;
        }
    }
    dy_f: float = 1.0;
    if len(args) > 2 {
        dy_f = _to_num_arg(args[2]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(dy_f) == False {
            bad = True;
        }
    }
    hr_f: float = 0.0;
    if len(args) > 3 {
        hr_f = _to_num_arg(args[3]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(hr_f) == False {
            bad = True;
        }
    }
    mn_f: float = 0.0;
    if len(args) > 4 {
        mn_f = _to_num_arg(args[4]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(mn_f) == False {
            bad = True;
        }
    }
    sc_f: float = 0.0;
    if len(args) > 5 {
        sc_f = _to_num_arg(args[5]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(sc_f) == False {
            bad = True;
        }
    }
    ms_f: float = 0.0;
    if len(args) > 6 {
        ms_f = _to_num_arg(args[6]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(ms_f) == False {
            bad = True;
        }
    }
    if bad {
        return js_nan();
    }
    yr: int = _num_to_int(yr_f);
    if yr >= 0 and yr <= 99 {
        yr = yr + 1900;
    }
    result: float = _time_clip(
        _make_date(
            yr,
            _num_to_int(mo_f),
            _num_to_int(dy_f),
            _num_to_int(hr_f),
            _num_to_int(mn_f),
            _num_to_int(sc_f),
            _num_to_int(ms_f)
        )
    );
    return js_number(result);
}

# ── Date.parse(str) ─────────────────────────────────────────────────────────

def:pub js_Date_parse(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        return js_nan();
    }
    a0: JSValue = args[0];
    if not jsv_is_string_cell(a0) {
        return js_nan();
    }
    s: str = str_from_id(jsv_to_table_id(a0));
    result: float = _time_clip(_parse_iso(s));
    return js_number(result);
}

"""Parse ISO 8601: YYYY-MM-DDTHH:mm:ss.sssZ or YYYY-MM-DD."""
def _parse_iso(s: str) -> float {
    n: int = len(s);
    if n < 4 {
        return MATH_NAN;
    }

    # Expanded years (ISO-8601 §21.4.1.33): an optional leading "+"/"-" followed
    # by a 6-digit year. Otherwise a plain 4-digit year at offset 0. `off` is the
    # index just past the year field so the fixed offsets below can shift.
    yr: int = 0;
    off: int = 4;
    yr_sign: int = 1;
    c0: str = s[0:1];
    if c0 == "+" or c0 == "-" {
        if n < 7 {
            return MATH_NAN;
        }
        yr = _parse_digits(s, 1, 7);
        if yr < 0 {
            return MATH_NAN;
        }
        # "-000000" (negative year zero) is not a valid expanded year (§21.4.3.2).
        if c0 == "-" and yr == 0 {
            return MATH_NAN;
        }
        if c0 == "-" {
            yr_sign = -1;
        }
        off = 7;
    } else {
        yr = _parse_digits(s, 0, 4);
        if yr < 0 {
            return MATH_NAN;
        }
    }
    yr = yr * yr_sign;

    mo: int = 1;
    dy: int = 1;
    hr: int = 0;
    mn: int = 0;
    sc: int = 0;
    ms: int = 0;

    if n >= off + 3 {
        if s[off:off + 1] != "-" {
            return MATH_NAN;
        }
        mo = _parse_digits(s, off + 1, off + 3);
        if mo < 0 {
            return MATH_NAN;
        }
    }
    if n >= off + 6 {
        if s[off + 3:off + 4] != "-" {
            return MATH_NAN;
        }
        dy = _parse_digits(s, off + 4, off + 6);
        if dy < 0 {
            return MATH_NAN;
        }
    }
    if n >= off + 9 {
        if s[off + 6:off + 7] != "T" and s[off + 6:off + 7] != "t" {
            return MATH_NAN;
        }
        hr = _parse_digits(s, off + 7, off + 9);
        if hr < 0 {
            return MATH_NAN;
        }
    }
    if n >= off + 12 {
        if s[off + 9:off + 10] != ":" {
            return MATH_NAN;
        }
        mn = _parse_digits(s, off + 10, off + 12);
        if mn < 0 {
            return MATH_NAN;
        }
    }
    if n >= off + 15 {
        if s[off + 12:off + 13] != ":" {
            return MATH_NAN;
        }
        sc = _parse_digits(s, off + 13, off + 15);
        if sc < 0 {
            return MATH_NAN;
        }
    }
    if n >= off + 19 {
        if s[off + 15:off + 16] == "." {
            ms = _parse_digits(s, off + 16, off + 19);
            if ms < 0 {
                return MATH_NAN;
            }
        }
    }

    return _make_date(yr, mo - 1, dy, hr, mn, sc, ms);
}

def _char_digit(c: str) -> int {
    if c == "0" {
        return 0;
    }
    if c == "1" {
        return 1;
    }
    if c == "2" {
        return 2;
    }
    if c == "3" {
        return 3;
    }
    if c == "4" {
        return 4;
    }
    if c == "5" {
        return 5;
    }
    if c == "6" {
        return 6;
    }
    if c == "7" {
        return 7;
    }
    if c == "8" {
        return 8;
    }
    if c == "9" {
        return 9;
    }
    return -1;
}

def _parse_digits(s: str, start: int, end_: int) -> int {
    result: int = 0;
    i: int = start;
    while i < end_ {
        d: int = _char_digit(s[i:i + 1]);
        if d < 0 {
            return -1;
        }
        result = result * 10 + d;
        i = i + 1;
    }
    return result;
}

# ── Constructor: new Date(...) ───────────────────────────────────────────────

"""Date() called as a function (NewTarget undefined) — §21.4.2.1 step 2: ignore
arguments and return a String equal to `new Date().toString()` for the moment of
the call."""
def:pub js_Date_now_string -> JSValue {
    now_v: JSValue = js_Date_now();
    return js_Date_toString(js_date_create(jsv_to_double(now_v)));
}

def:pub js_Date_construct(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        now_v: JSValue = js_Date_now();
        return js_date_create(jsv_to_double(now_v));
    }
    if len(args) == 1 {
        a0: JSValue = args[0];
        # §21.4.2.1 step 3.a: an argument that is already a Date copies its time
        # value directly, with no ToPrimitive/ToNumber observation.
        if js_is_date(a0) {
            return js_date_create(_get_ms(a0));
        }
        # step 3.b: v = ToPrimitive(value) (hint default — runs @@toPrimitive /
        # valueOf / toString observably). If v is a String, parse it; otherwise
        # ToNumber(v). Abrupt completions propagate via vm_has_native_exc.
        prim: JSValue = js_to_primitive_observable(a0, OBS_HINT_DEFAULT);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        if jsv_is_string_cell(prim) {
            parsed: float = _time_clip(_parse_iso(str_from_id(jsv_to_table_id(prim))));
            return js_date_create(parsed);
        }
        n: float = js_to_number_observable(prim);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        return js_date_create(_time_clip(n));
    }
    # §21.4.2.1 step 3 (2+ args): ToNumber every supplied component left-to-right
    # (observable — valueOf/toString throws propagate via vm_has_native_exc); any
    # non-finite component makes the whole date NaN, then TimeClip. On an abrupt
    # completion we return an Invalid Date; the VM re-raises the pending throw.
    yr_f: float = _to_num_arg(args[0]);
    if vm_has_native_exc() {
        return js_date_create(MATH_NAN);
    }
    bad: bool = _is_finite(yr_f) == False;
    mo_f: float = _to_num_arg(args[1]);
    if vm_has_native_exc() {
        return js_date_create(MATH_NAN);
    }
    if _is_finite(mo_f) == False {
        bad = True;
    }
    dy_f: float = 1.0;
    if len(args) > 2 {
        dy_f = _to_num_arg(args[2]);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        if _is_finite(dy_f) == False {
            bad = True;
        }
    }
    hr_f: float = 0.0;
    if len(args) > 3 {
        hr_f = _to_num_arg(args[3]);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        if _is_finite(hr_f) == False {
            bad = True;
        }
    }
    mn_f: float = 0.0;
    if len(args) > 4 {
        mn_f = _to_num_arg(args[4]);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        if _is_finite(mn_f) == False {
            bad = True;
        }
    }
    sc_f: float = 0.0;
    if len(args) > 5 {
        sc_f = _to_num_arg(args[5]);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        if _is_finite(sc_f) == False {
            bad = True;
        }
    }
    ms_f: float = 0.0;
    if len(args) > 6 {
        ms_f = _to_num_arg(args[6]);
        if vm_has_native_exc() {
            return js_date_create(MATH_NAN);
        }
        if _is_finite(ms_f) == False {
            bad = True;
        }
    }
    if bad {
        return js_date_create(MATH_NAN);
    }
    yr: int = _num_to_int(yr_f);
    if yr >= 0 and yr <= 99 {
        yr = yr + 1900;
    }
    return js_date_create(
        _time_clip(
            _make_date(
                yr,
                _num_to_int(mo_f),
                _num_to_int(dy_f),
                _num_to_int(hr_f),
                _num_to_int(mn_f),
                _num_to_int(sc_f),
                _num_to_int(ms_f)
            )
        )
    );
}

# ── Getters ──────────────────────────────────────────────────────────────────

def:pub js_Date_getTime(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_number(ms);
}

def:pub js_Date_getFullYear(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_YEAR));
}

def:pub js_Date_getMonth(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_MONTH));
}

def:pub js_Date_getDate(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_DATE));
}

def:pub js_Date_getDay(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_DAY));
}

def:pub js_Date_getHours(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_HOUR));
}

def:pub js_Date_getMinutes(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_MIN));
}

def:pub js_Date_getSeconds(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_SEC));
}

def:pub js_Date_getMilliseconds(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(_utc_field(ms, _F_MS));
}

def:pub js_Date_getTimezoneOffset(this_val: JSValue) -> JSValue {
    # §21.4.4.7: thisTimeValue brand check, then NaN for an invalid date.
    # The engine models local time as UTC, so the offset is always 0.
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    if _is_nan(ms) {
        return js_nan();
    }
    return js_int(0);
}

def:pub js_Date_getUTCFullYear(this_val: JSValue) -> JSValue {
    return js_Date_getFullYear(this_val);
}

def:pub js_Date_getUTCMonth(this_val: JSValue) -> JSValue {
    return js_Date_getMonth(this_val);
}

def:pub js_Date_getUTCDate(this_val: JSValue) -> JSValue {
    return js_Date_getDate(this_val);
}

def:pub js_Date_getUTCDay(this_val: JSValue) -> JSValue {
    return js_Date_getDay(this_val);
}

def:pub js_Date_getUTCHours(this_val: JSValue) -> JSValue {
    return js_Date_getHours(this_val);
}

def:pub js_Date_getUTCMinutes(this_val: JSValue) -> JSValue {
    return js_Date_getMinutes(this_val);
}

def:pub js_Date_getUTCSeconds(this_val: JSValue) -> JSValue {
    return js_Date_getSeconds(this_val);
}

def:pub js_Date_getUTCMilliseconds(this_val: JSValue) -> JSValue {
    return js_Date_getMilliseconds(this_val);
}

# ── Setters ──────────────────────────────────────────────────────────────────

def:pub js_Date_setTime(this_val: JSValue, args: list[JSValue]) -> JSValue {
    # §21.4.4.27: brand check, ToNumber(time), then TimeClip. setTime does not
    # read the prior time value, so there is no NaN-time short-circuit.
    _brand: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    new_ms: float = MATH_NAN;
    if len(args) > 0 {
        new_ms = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
    }
    clipped: float = _time_clip(new_ms);
    _set_ms(this_val, clipped);
    return js_number(clipped);
}

def:pub js_Date_setMilliseconds(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.23: ToNumber(ms) runs before the NaN check on the time value.
    if len(args) == 0 {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    new_ms_f: float = _to_num_arg(args[0]);
    if vm_has_native_exc() {
        return js_nan();
    }
    # NaN time value: return NaN WITHOUT writing the slot (valueOf may have
    # legitimately updated it — §21.4.4.23 step 5 returns before the store).
    if _is_nan(ms) {
        return js_nan();
    }
    if _is_finite(new_ms_f) == False {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    result: float = _time_clip(
        _make_date(yr, mo, dy, hr, mn, sc, _num_to_int(new_ms_f))
    );
    _set_ms(this_val, result);
    return js_number(result);
}

def:pub js_Date_setSeconds(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.28: ToNumber(sec), then ToNumber(ms) if present — left-to-right,
    # all before the NaN check on the time value. A missing arg is ToNumber
    # (undefined) = NaN, which taints the result.
    sec_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        sec_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(sec_f) == False;
    }
    ms_f: float = 0.0;
    have_ms: bool = len(args) > 1;
    if have_ms {
        ms_f = _to_num_arg(args[1]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(ms_f) == False {
            bad = True;
        }
    }
    # NaN time value: return NaN WITHOUT writing the slot (valueOf may have
    # updated it). This check follows all coercions.
    if _is_nan(ms) {
        return js_nan();
    }
    if bad {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    ms_r: int = _utc_field(ms, _F_MS);
    if have_ms {
        ms_r = _num_to_int(ms_f);
    }
    result: float = _time_clip(
        _make_date(yr, mo, dy, hr, mn, _num_to_int(sec_f), ms_r)
    );
    _set_ms(this_val, result);
    return js_number(result);
}

def:pub js_Date_setMinutes(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.24: ToNumber(min), then sec, then ms — left-to-right, all before
    # the NaN check on the time value.
    min_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        min_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(min_f) == False;
    }
    sec_f: float = 0.0;
    have_sec: bool = len(args) > 1;
    if have_sec {
        sec_f = _to_num_arg(args[1]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(sec_f) == False {
            bad = True;
        }
    }
    ms_f: float = 0.0;
    have_ms: bool = len(args) > 2;
    if have_ms {
        ms_f = _to_num_arg(args[2]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(ms_f) == False {
            bad = True;
        }
    }
    if _is_nan(ms) {
        return js_nan();
    }
    if bad {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    hr: int = _utc_field(ms, _F_HOUR);
    sc: int = _utc_field(ms, _F_SEC);
    ms_r: int = _utc_field(ms, _F_MS);
    if have_sec {
        sc = _num_to_int(sec_f);
    }
    if have_ms {
        ms_r = _num_to_int(ms_f);
    }
    result: float = _time_clip(
        _make_date(yr, mo, dy, hr, _num_to_int(min_f), sc, ms_r)
    );
    _set_ms(this_val, result);
    return js_number(result);
}

def:pub js_Date_setHours(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.22: ToNumber(hour), then min, sec, ms — left-to-right, all before
    # the NaN check on the time value.
    hr_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        hr_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(hr_f) == False;
    }
    min_f: float = 0.0;
    have_min: bool = len(args) > 1;
    if have_min {
        min_f = _to_num_arg(args[1]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(min_f) == False {
            bad = True;
        }
    }
    sec_f: float = 0.0;
    have_sec: bool = len(args) > 2;
    if have_sec {
        sec_f = _to_num_arg(args[2]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(sec_f) == False {
            bad = True;
        }
    }
    ms_f: float = 0.0;
    have_ms: bool = len(args) > 3;
    if have_ms {
        ms_f = _to_num_arg(args[3]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(ms_f) == False {
            bad = True;
        }
    }
    if _is_nan(ms) {
        return js_nan();
    }
    if bad {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    ms_r: int = _utc_field(ms, _F_MS);
    if have_min {
        mn = _num_to_int(min_f);
    }
    if have_sec {
        sc = _num_to_int(sec_f);
    }
    if have_ms {
        ms_r = _num_to_int(ms_f);
    }
    result: float = _time_clip(_make_date(yr, mo, dy, _num_to_int(hr_f), mn, sc, ms_r));
    _set_ms(this_val, result);
    return js_number(result);
}

def:pub js_Date_setDate(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.20: ToNumber(date) runs before the NaN check on the time value.
    dy_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        dy_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(dy_f) == False;
    }
    if _is_nan(ms) {
        return js_nan();
    }
    if bad {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    ms_r: int = _utc_field(ms, _F_MS);
    result: float = _time_clip(_make_date(yr, mo, _num_to_int(dy_f), hr, mn, sc, ms_r));
    _set_ms(this_val, result);
    return js_number(result);
}

def:pub js_Date_setMonth(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.25: ToNumber(month), then date if present — left-to-right, all
    # before the NaN check on the time value.
    mo_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        mo_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(mo_f) == False;
    }
    dy_f: float = 0.0;
    have_dy: bool = len(args) > 1;
    if have_dy {
        dy_f = _to_num_arg(args[1]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(dy_f) == False {
            bad = True;
        }
    }
    if _is_nan(ms) {
        return js_nan();
    }
    if bad {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    dy: int = _utc_field(ms, _F_DATE);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    ms_r: int = _utc_field(ms, _F_MS);
    if have_dy {
        dy = _num_to_int(dy_f);
    }
    result: float = _time_clip(_make_date(yr, _num_to_int(mo_f), dy, hr, mn, sc, ms_r));
    _set_ms(this_val, result);
    return js_number(result);
}

def:pub js_Date_setFullYear(this_val: JSValue, args: list[JSValue]) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.21: if t is NaN, set it to +0 (but still coerce the args first).
    if _is_nan(ms) {
        ms = 0.0;
    }
    # ToNumber(year), then month, then date — left-to-right. A missing year is
    # ToNumber(undefined) = NaN, which taints the result.
    yr_f: float = MATH_NAN;
    bad: bool = True;
    if len(args) > 0 {
        yr_f = _to_num_arg(args[0]);
        if vm_has_native_exc() {
            return js_nan();
        }
        bad = _is_finite(yr_f) == False;
    }
    mo_f: float = 0.0;
    have_mo: bool = len(args) > 1;
    if have_mo {
        mo_f = _to_num_arg(args[1]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(mo_f) == False {
            bad = True;
        }
    }
    dy_f: float = 0.0;
    have_dy: bool = len(args) > 2;
    if have_dy {
        dy_f = _to_num_arg(args[2]);
        if vm_has_native_exc() {
            return js_nan();
        }
        if _is_finite(dy_f) == False {
            bad = True;
        }
    }
    if bad {
        _set_ms(this_val, MATH_NAN);
        return js_nan();
    }
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    ms_r: int = _utc_field(ms, _F_MS);
    if have_mo {
        mo = _num_to_int(mo_f);
    }
    if have_dy {
        dy = _num_to_int(dy_f);
    }
    result: float = _time_clip(_make_date(_num_to_int(yr_f), mo, dy, hr, mn, sc, ms_r));
    _set_ms(this_val, result);
    return js_number(result);
}

# The engine currently represents local time as UTC, so these entry points use
# the same UTC field decomposition and date construction as the local setters.
def:pub js_Date_setUTCDate(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setDate(this_val, args);
}

def:pub js_Date_setUTCFullYear(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setFullYear(this_val, args);
}

def:pub js_Date_setUTCMonth(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setMonth(this_val, args);
}

def:pub js_Date_setUTCHours(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setHours(this_val, args);
}

def:pub js_Date_setUTCMinutes(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setMinutes(this_val, args);
}

def:pub js_Date_setUTCSeconds(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setSeconds(this_val, args);
}

def:pub js_Date_setUTCMilliseconds(this_val: JSValue, args: list[JSValue]) -> JSValue {
    return js_Date_setMilliseconds(this_val, args);
}

# ── Formatters ───────────────────────────────────────────────────────────────

def _pad2(n: int) -> str {
    if n < 0 {
        n = -n;
    }
    if n < 10 {
        return "0" + str(n);
    }
    return str(n);
}

def _pad3(n: int) -> str {
    if n < 0 {
        n = -n;
    }
    if n < 10 {
        return "00" + str(n);
    }
    if n < 100 {
        return "0" + str(n);
    }
    return str(n);
}

def _pad4(n: int) -> str {
    if n < 0 {
        return "-" + _pad4(-n);
    }
    if n < 10 {
        return "000" + str(n);
    }
    if n < 100 {
        return "00" + str(n);
    }
    if n < 1000 {
        return "0" + str(n);
    }
    return str(n);
}

def _pad6(n: int) -> str {
    an: int = n;
    if an < 0 {
        an = -an;
    }
    s: str = str(an);
    while len(s) < 6 {
        s = "0" + s;
    }
    return s;
}

"""ISO-8601 year field (§21.4.1.33 DateTimeString): 4-digit for 0..9999,
otherwise a sign followed by a 6-digit expanded year."""
def _iso_year(yr: int) -> str {
    if yr >= 0 and yr <= 9999 {
        return _pad4(yr);
    }
    if yr < 0 {
        return "-" + _pad6(yr);
    }
    return "+" + _pad6(yr);
}

def _day_name(wd: int) -> str {
    if wd == 0 {
        return "Sun";
    }
    if wd == 1 {
        return "Mon";
    }
    if wd == 2 {
        return "Tue";
    }
    if wd == 3 {
        return "Wed";
    }
    if wd == 4 {
        return "Thu";
    }
    if wd == 5 {
        return "Fri";
    }
    return "Sat";
}

def _month_name(m: int) -> str {
    if m == 0 {
        return "Jan";
    }
    if m == 1 {
        return "Feb";
    }
    if m == 2 {
        return "Mar";
    }
    if m == 3 {
        return "Apr";
    }
    if m == 4 {
        return "May";
    }
    if m == 5 {
        return "Jun";
    }
    if m == 6 {
        return "Jul";
    }
    if m == 7 {
        return "Aug";
    }
    if m == 8 {
        return "Sep";
    }
    if m == 9 {
        return "Oct";
    }
    if m == 10 {
        return "Nov";
    }
    return "Dec";
}

def:pub js_Date_toISOString(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if vm_has_native_exc() {
        return js_nan();
    }
    # §21.4.4.36: throw a RangeError when the time value is not a finite Number.
    if _is_finite(ms) == False {
        vm_throw_native(make_range_error("Invalid time value"));
        return js_nan();
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH) + 1;
    dy: int = _utc_field(ms, _F_DATE);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    ms_r: int = _utc_field(ms, _F_MS);
    return _date_js_str(
        _iso_year(yr)
            + "-"
            + _pad2(mo)
            + "-"
            + _pad2(dy)
            + "T"
            + _pad2(hr)
            + ":"
            + _pad2(mn)
            + ":"
            + _pad2(sc)
            + "."
            + _pad3(ms_r)
            + "Z"
    );
}

def:pub js_Date_toJSON(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return js_null();
    }
    return js_Date_toISOString(this_val);
}

def:pub js_Date_toString(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return _date_js_str("Invalid Date");
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    wd: int = _utc_field(ms, _F_DAY);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    return _date_js_str(
        _day_name(wd)
            + " "
            + _month_name(mo)
            + " "
            + _pad2(dy)
            + " "
            + _pad4(yr)
            + " "
            + _pad2(hr)
            + ":"
            + _pad2(mn)
            + ":"
            + _pad2(sc)
            + " GMT+0000"
    );
}

def:pub js_Date_toDateString(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return _date_js_str("Invalid Date");
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    wd: int = _utc_field(ms, _F_DAY);
    return _date_js_str(
        _day_name(wd) + " " + _month_name(mo) + " " + _pad2(dy) + " " + _pad4(yr)
    );
}

def:pub js_Date_toTimeString(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return _date_js_str("Invalid Date");
    }
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    return _date_js_str(_pad2(hr) + ":" + _pad2(mn) + ":" + _pad2(sc) + " GMT+0000");
}

def:pub js_Date_toUTCString(this_val: JSValue) -> JSValue {
    ms: float = _this_time_value_ms(this_val);
    if _is_nan(ms) {
        return _date_js_str("Invalid Date");
    }
    yr: int = _utc_field(ms, _F_YEAR);
    mo: int = _utc_field(ms, _F_MONTH);
    dy: int = _utc_field(ms, _F_DATE);
    wd: int = _utc_field(ms, _F_DAY);
    hr: int = _utc_field(ms, _F_HOUR);
    mn: int = _utc_field(ms, _F_MIN);
    sc: int = _utc_field(ms, _F_SEC);
    return _date_js_str(
        _day_name(wd)
            + ", "
            + _pad2(dy)
            + " "
            + _month_name(mo)
            + " "
            + _pad4(yr)
            + " "
            + _pad2(hr)
            + ":"
            + _pad2(mn)
            + ":"
            + _pad2(sc)
            + " GMT"
    );
}

def:pub js_Date_toLocaleString(this_val: JSValue) -> JSValue {
    return js_Date_toString(this_val);
}

def:pub js_Date_toLocaleDateString(this_val: JSValue) -> JSValue {
    return js_Date_toDateString(this_val);
}

def:pub js_Date_toLocaleTimeString(this_val: JSValue) -> JSValue {
    return js_Date_toTimeString(this_val);
}

def:pub js_Date_valueOf(this_val: JSValue) -> JSValue {
    return js_Date_getTime(this_val);
}
