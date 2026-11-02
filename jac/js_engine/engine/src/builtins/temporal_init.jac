"""Temporal global namespace wiring for init_global."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    jsv_from_string_id,
    js_undefined
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject {
    JSProperty,
    js_object_create_null,
    js_object_set,
    js_object_create,
    js_object_define_property,
    js_object_set_accessor_getter,
    js_object_set_prototype,
    js_object_get_ordinary_proto,
    js_object_set_accessor_enumerable,
    js_object_set_accessor_configurable
}
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jssymbol { SYMBOL_TO_STRING_TAG }
import from engine.src.builtins.native_registry { js_native_create, js_callable_create }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_TEMPORAL_DURATION,
    NATIVE_KIND_TEMPORAL_DURATION_FROM,
    NATIVE_KIND_TEMPORAL_DURATION_COMPARE,
    NATIVE_KIND_TEMPORAL_DURATION_MAX,
    NATIVE_KIND_TEMPORAL_DURATION_ADD,
    NATIVE_KIND_TEMPORAL_DURATION_SUBTRACT,
    NATIVE_KIND_TEMPORAL_DURATION_NEGATED,
    NATIVE_KIND_TEMPORAL_DURATION_ABS,
    NATIVE_KIND_TEMPORAL_DURATION_ROUND,
    NATIVE_KIND_TEMPORAL_DURATION_TOTAL,
    NATIVE_KIND_TEMPORAL_DURATION_WITH,
    NATIVE_KIND_TEMPORAL_DURATION_TOSTRING,
    NATIVE_KIND_TEMPORAL_DURATION_TOJSON,
    NATIVE_KIND_TEMPORAL_DURATION_TOLOCALE,
    NATIVE_KIND_TEMPORAL_DURATION_VALUEOF,
    NATIVE_KIND_TEMPORAL_DURATION_GETTER,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_FROM,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_COMPARE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_ADD,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_SUBTRACT,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_WITH,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_WITH_CAL,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_UNTIL,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_SINCE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_EQUALS,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TOSTRING,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TOJSON,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TOLOCALE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_VALUEOF,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_PLAIN_DATETIME,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_ZONED_DATETIME,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_PLAIN_YEAR_MONTH,
    NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_PLAIN_MONTH_DAY,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_FROM,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_COMPARE,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_ADD,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_SUBTRACT,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_WITH,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_UNTIL,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_SINCE,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_EQUALS,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_ROUND,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_TOSTRING,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_TOJSON,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_TOLOCALE,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_VALUEOF,
    NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_FROM,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_COMPARE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_ADD,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_SUB,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_WITH,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_ROUND,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_EQUALS,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_UNTIL,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_SINCE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TOLOCALE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TO_PLAIN_DATE,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TO_PLAIN_TIME,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_WITH_CAL,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TO_ZONED,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TOSTRING,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_FROM,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_ADD,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_SUB,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_WITH,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_UNTIL,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_SINCE,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_ADD,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_SUB,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_WITH,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_UNTIL,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_SINCE,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_COMPARE,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_EQUALS,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TOSTRING,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TOJSON,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_VALUEOF,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_FROM,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_COMPARE,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_EQUALS,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TOSTRING,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TOJSON,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_VALUEOF,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_GETTER,
    NATIVE_KIND_TEMPORAL_INSTANT,
    NATIVE_KIND_TEMPORAL_INSTANT_FROM,
    NATIVE_KIND_TEMPORAL_INSTANT_FROM_MS,
    NATIVE_KIND_TEMPORAL_INSTANT_FROM_NS,
    NATIVE_KIND_TEMPORAL_INSTANT_COMPARE,
    NATIVE_KIND_TEMPORAL_INSTANT_ADD,
    NATIVE_KIND_TEMPORAL_INSTANT_SUBTRACT,
    NATIVE_KIND_TEMPORAL_INSTANT_TOSTRING,
    NATIVE_KIND_TEMPORAL_INSTANT_TOJSON,
    NATIVE_KIND_TEMPORAL_INSTANT_GETTER,
    NATIVE_KIND_TEMPORAL_INSTANT_VALUEOF,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_FROM,
    NATIVE_KIND_TEMPORAL_INSTANT_UNTIL,
    NATIVE_KIND_TEMPORAL_INSTANT_SINCE,
    NATIVE_KIND_TEMPORAL_INSTANT_ROUND,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_ADD,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_SUB,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_EQUALS,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_COMPARE,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_UNTIL,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_SINCE,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOINSTANT,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TO_PLAIN_DATE,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TO_PLAIN_TIME,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TO_PLAIN_DATETIME,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOLOCALE,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOSTRING,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOJSON,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_VALUEOF,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_ROUND,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH_CAL,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH_TZ,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH_PLAIN_TIME,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GET_TZ_TRANSITION,
    NATIVE_KIND_TEMPORAL_ZONED_DATETIME_START_OF_DAY,
    NATIVE_KIND_TEMPORAL_NOW_INSTANT,
    NATIVE_KIND_TEMPORAL_NOW_PLAIN_DATE_ISO,
    NATIVE_KIND_TEMPORAL_NOW_PLAIN_TIME_ISO,
    NATIVE_KIND_TEMPORAL_NOW_PLAIN_DATETIME_ISO,
    NATIVE_KIND_TEMPORAL_NOW_TIMEZONE_ID,
    NATIVE_KIND_TEMPORAL_NOW_ZONED_DATETIME_ISO,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TOJSON,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_VALUEOF,
    NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_WITH_PLAIN_TIME,
    NATIVE_KIND_TEMPORAL_INSTANT_EQUALS,
    NATIVE_KIND_TEMPORAL_INSTANT_TO_ZONED_DATETIME_ISO,
    NATIVE_KIND_TEMPORAL_INSTANT_TOLOCALE,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TO_PLAIN_DATE,
    NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TOLOCALE,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TO_PLAIN_DATE,
    NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TOLOCALE
}
import from engine.src.builtins.temporal {
    temporal_init_keys,
    temporal_set_plain_date_proto,
    temporal_set_duration_proto,
    temporal_set_plain_time_proto,
    temporal_set_plain_datetime_proto,
    temporal_set_plain_year_month_proto,
    temporal_set_plain_month_day_proto,
    temporal_set_instant_proto,
    temporal_set_zoned_datetime_proto
}

def _ti_define_prop(jobj: JSValue, key: int, val: JSValue, w: bool, e: bool, c: bool) {
    p: JSProperty = JSProperty(
        key=key, value=val, writable=w, enumerable=e, configurable=c, deleted=False
    );
    js_object_define_property(jobj, key, p);
}

def _ti_define_proto_method(jobj: JSValue, key: int, val: JSValue) {
    _ti_define_prop(jobj, key, val, True, False, True);
}

def _ti_define_static_method(jobj: JSValue, key: int, val: JSValue) {
    _ti_define_prop(jobj, key, val, True, False, True);
}

def _wire_ctor(ctor: JSValue, proto: JSValue) {
    _ti_define_prop(ctor, str_intern("prototype"), proto, False, False, False);
    _ti_define_prop(proto, str_intern("constructor"), ctor, True, False, True);
}

def _install_getter(proto: JSValue, key: int, name: str, kind: int) {
    # A Temporal prototype accessor is { enumerable:false, configurable:true } with no
    # setter (§Temporal). Set the accessor's own flags directly — a data-descriptor
    # define would not update the accessor entry's enumerable bit (it defaults to true
    # in _register_accessor_key), leaving the getter wrongly enumerable (*/prop-desc).
    getter_fn: JSValue = js_native_create(name, 0, kind);
    js_object_set_accessor_getter(proto, key, getter_fn);
    js_object_set_accessor_enumerable(proto, key, False);
    js_object_set_accessor_configurable(proto, key, True);
}

def _ti_set_ns(target: JSValue, key: int, val: JSValue) {
    _ti_define_prop(target, key, val, True, False, True);
}

def _tag_proto(proto: JSValue, tag: str) {
    _ti_define_prop(
        proto,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern(tag)),
        False,
        False,
        True
    );
}

def:pub js_temporal_wire_global(gv: JSValue) {
    temporal_init_keys();
    k_temporal: int = str_intern("Temporal");
    temporal: JSValue = js_object_create_null();
    js_object_set_prototype(temporal, js_object_get_ordinary_proto());

    # ── Duration ──────────────────────────────────────────────────────────────
    dur_proto: JSValue = js_object_create_null();
    dur_ctor: JSValue = js_callable_create(
        "Duration", 0, NATIVE_KIND_TEMPORAL_DURATION
    );
    _ti_define_static_method(
        dur_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_DURATION_FROM)
    );
    _ti_define_static_method(
        dur_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_DURATION_COMPARE)
    );
    _ti_define_static_method(
        dur_ctor,
        str_intern("max"),
        js_native_create("max", 2, NATIVE_KIND_TEMPORAL_DURATION_MAX)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_DURATION_ADD)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_DURATION_SUBTRACT)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("negated"),
        js_native_create("negated", 0, NATIVE_KIND_TEMPORAL_DURATION_NEGATED)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("abs"),
        js_native_create("abs", 0, NATIVE_KIND_TEMPORAL_DURATION_ABS)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("round"),
        js_native_create("round", 1, NATIVE_KIND_TEMPORAL_DURATION_ROUND)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("total"),
        js_native_create("total", 1, NATIVE_KIND_TEMPORAL_DURATION_TOTAL)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_DURATION_WITH)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_DURATION_TOSTRING)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_DURATION_TOJSON)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_TEMPORAL_DURATION_TOLOCALE)
    );
    _ti_define_proto_method(
        dur_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_DURATION_VALUEOF)
    );
    _install_getter(
        dur_proto, str_intern("years"), "years", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto, str_intern("months"), "months", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto, str_intern("weeks"), "weeks", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto, str_intern("days"), "days", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto, str_intern("hours"), "hours", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto,
        str_intern("minutes"),
        "minutes",
        NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto,
        str_intern("seconds"),
        "seconds",
        NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto,
        str_intern("milliseconds"),
        "milliseconds",
        NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto,
        str_intern("microseconds"),
        "microseconds",
        NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto,
        str_intern("nanoseconds"),
        "nanoseconds",
        NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto, str_intern("sign"), "sign", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _install_getter(
        dur_proto, str_intern("blank"), "blank", NATIVE_KIND_TEMPORAL_DURATION_GETTER
    );
    _tag_proto(dur_proto, "Temporal.Duration");
    _wire_ctor(dur_ctor, dur_proto);
    temporal_set_duration_proto(dur_proto);
    _ti_set_ns(temporal, str_intern("Duration"), dur_ctor);

    # ── PlainDate ─────────────────────────────────────────────────────────────
    pd_proto: JSValue = js_object_create_null();
    pd_ctor: JSValue = js_callable_create(
        "PlainDate", 3, NATIVE_KIND_TEMPORAL_PLAIN_DATE
    );
    _ti_define_static_method(
        pd_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_FROM)
    );
    _ti_define_static_method(
        pd_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_PLAIN_DATE_COMPARE)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_ADD)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_SUBTRACT)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_WITH)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("withCalendar"),
        js_native_create("withCalendar", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_WITH_CAL)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_UNTIL)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_SINCE)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_EQUALS)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toPlainDateTime"),
        js_native_create(
            "toPlainDateTime", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_PLAIN_DATETIME
        )
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toZonedDateTime"),
        js_native_create(
            "toZonedDateTime", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_ZONED_DATETIME
        )
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toPlainYearMonth"),
        js_native_create(
            "toPlainYearMonth", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_PLAIN_YEAR_MONTH
        )
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toPlainMonthDay"),
        js_native_create(
            "toPlainMonthDay", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TO_PLAIN_MONTH_DAY
        )
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TOSTRING)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TOJSON)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATE_TOLOCALE)
    );
    _ti_define_proto_method(
        pd_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATE_VALUEOF)
    );
    _install_getter(
        pd_proto,
        str_intern("calendarId"),
        "calendarId",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto, str_intern("year"), "year", NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto, str_intern("month"), "month", NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("monthCode"),
        "monthCode",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto, str_intern("day"), "day", NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("dayOfWeek"),
        "dayOfWeek",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("dayOfYear"),
        "dayOfYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("weekOfYear"),
        "weekOfYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("yearOfWeek"),
        "yearOfWeek",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("daysInMonth"),
        "daysInMonth",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("daysInYear"),
        "daysInYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("monthsInYear"),
        "monthsInYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("inLeapYear"),
        "inLeapYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("daysInWeek"),
        "daysInWeek",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto, str_intern("era"), "era", NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _install_getter(
        pd_proto,
        str_intern("eraYear"),
        "eraYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATE_GETTER
    );
    _tag_proto(pd_proto, "Temporal.PlainDate");
    _wire_ctor(pd_ctor, pd_proto);
    temporal_set_plain_date_proto(pd_proto);
    _ti_set_ns(temporal, str_intern("PlainDate"), pd_ctor);

    # ── PlainTime ─────────────────────────────────────────────────────────────
    pt_proto: JSValue = js_object_create_null();
    pt_ctor: JSValue = js_callable_create(
        "PlainTime", 0, NATIVE_KIND_TEMPORAL_PLAIN_TIME
    );
    _ti_define_static_method(
        pt_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_FROM)
    );
    _ti_define_static_method(
        pt_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_PLAIN_TIME_COMPARE)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_ADD)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_SUBTRACT)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_WITH)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_EQUALS)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("round"),
        js_native_create("round", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_ROUND)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_UNTIL)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_PLAIN_TIME_SINCE)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_PLAIN_TIME_TOSTRING)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_PLAIN_TIME_TOJSON)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_TEMPORAL_PLAIN_TIME_TOLOCALE)
    );
    _ti_define_proto_method(
        pt_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_PLAIN_TIME_VALUEOF)
    );
    _install_getter(
        pt_proto, str_intern("hour"), "hour", NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER
    );
    _install_getter(
        pt_proto, str_intern("minute"), "minute", NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER
    );
    _install_getter(
        pt_proto, str_intern("second"), "second", NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER
    );
    _install_getter(
        pt_proto,
        str_intern("millisecond"),
        "millisecond",
        NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER
    );
    _install_getter(
        pt_proto,
        str_intern("microsecond"),
        "microsecond",
        NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER
    );
    _install_getter(
        pt_proto,
        str_intern("nanosecond"),
        "nanosecond",
        NATIVE_KIND_TEMPORAL_PLAIN_TIME_GETTER
    );
    _tag_proto(pt_proto, "Temporal.PlainTime");
    _wire_ctor(pt_ctor, pt_proto);
    temporal_set_plain_time_proto(pt_proto);
    _ti_set_ns(temporal, str_intern("PlainTime"), pt_ctor);

    # ── PlainDateTime ─────────────────────────────────────────────────────────
    pdt_proto: JSValue = js_object_create_null();
    pdt_ctor: JSValue = js_callable_create(
        "PlainDateTime", 3, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME
    );
    _ti_define_static_method(
        pdt_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_FROM)
    );
    _ti_define_static_method(
        pdt_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_COMPARE)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_ADD)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_SUB)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_WITH)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_UNTIL)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_SINCE)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_EQUALS)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("round"),
        js_native_create("round", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_ROUND)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("toPlainDate"),
        js_native_create(
            "toPlainDate", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TO_PLAIN_DATE
        )
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("withPlainTime"),
        js_native_create(
            "withPlainTime", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_WITH_PLAIN_TIME
        )
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("toPlainTime"),
        js_native_create(
            "toPlainTime", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TO_PLAIN_TIME
        )
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("withCalendar"),
        js_native_create(
            "withCalendar", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_WITH_CAL
        )
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("toZonedDateTime"),
        js_native_create(
            "toZonedDateTime", 1, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TO_ZONED
        )
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TOSTRING)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TOJSON)
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("toLocaleString"),
        js_native_create(
            "toLocaleString", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_TOLOCALE
        )
    );
    _ti_define_proto_method(
        pdt_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_VALUEOF)
    );
    _install_getter(
        pdt_proto,
        str_intern("calendarId"),
        "calendarId",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("year"),
        "year",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("month"),
        "month",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("monthCode"),
        "monthCode",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto, str_intern("day"), "day", NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("dayOfWeek"),
        "dayOfWeek",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("dayOfYear"),
        "dayOfYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("weekOfYear"),
        "weekOfYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("yearOfWeek"),
        "yearOfWeek",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("daysInMonth"),
        "daysInMonth",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("daysInYear"),
        "daysInYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("monthsInYear"),
        "monthsInYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("inLeapYear"),
        "inLeapYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("daysInWeek"),
        "daysInWeek",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto, str_intern("era"), "era", NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("eraYear"),
        "eraYear",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("hour"),
        "hour",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("minute"),
        "minute",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("second"),
        "second",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("millisecond"),
        "millisecond",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("microsecond"),
        "microsecond",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _install_getter(
        pdt_proto,
        str_intern("nanosecond"),
        "nanosecond",
        NATIVE_KIND_TEMPORAL_PLAIN_DATETIME_GETTER
    );
    _tag_proto(pdt_proto, "Temporal.PlainDateTime");
    _wire_ctor(pdt_ctor, pdt_proto);
    temporal_set_plain_datetime_proto(pdt_proto);
    _ti_set_ns(temporal, str_intern("PlainDateTime"), pdt_ctor);

    # ── PlainYearMonth ────────────────────────────────────────────────────────
    pym_proto: JSValue = js_object_create_null();
    pym_ctor: JSValue = js_callable_create(
        "PlainYearMonth", 2, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH
    );
    _ti_define_static_method(
        pym_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_FROM)
    );
    _ti_define_static_method(
        pym_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_COMPARE)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_EQUALS)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_ADD)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_SUB)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_WITH)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_UNTIL)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_SINCE)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TOSTRING)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TOJSON)
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("toPlainDate"),
        js_native_create(
            "toPlainDate", 1, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TO_PLAIN_DATE
        )
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("toLocaleString"),
        js_native_create(
            "toLocaleString", 0, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_TOLOCALE
        )
    );
    _ti_define_proto_method(
        pym_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_VALUEOF)
    );
    _install_getter(
        pym_proto,
        str_intern("calendarId"),
        "calendarId",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("year"),
        "year",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("month"),
        "month",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("monthCode"),
        "monthCode",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("daysInMonth"),
        "daysInMonth",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("daysInYear"),
        "daysInYear",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("monthsInYear"),
        "monthsInYear",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("inLeapYear"),
        "inLeapYear",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("era"),
        "era",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _install_getter(
        pym_proto,
        str_intern("eraYear"),
        "eraYear",
        NATIVE_KIND_TEMPORAL_PLAIN_YEAR_MONTH_GETTER
    );
    _tag_proto(pym_proto, "Temporal.PlainYearMonth");
    _wire_ctor(pym_ctor, pym_proto);
    temporal_set_plain_year_month_proto(pym_proto);
    _ti_set_ns(temporal, str_intern("PlainYearMonth"), pym_ctor);

    # ── PlainMonthDay ─────────────────────────────────────────────────────────
    pmd_proto: JSValue = js_object_create_null();
    pmd_ctor: JSValue = js_callable_create(
        "PlainMonthDay", 2, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY
    );
    _ti_define_static_method(
        pmd_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_FROM)
    );
    _ti_define_static_method(
        pmd_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_COMPARE)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_EQUALS)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_ADD)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_SUB)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_WITH)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_UNTIL)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_SINCE)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TOSTRING)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TOJSON)
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("toPlainDate"),
        js_native_create(
            "toPlainDate", 1, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TO_PLAIN_DATE
        )
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("toLocaleString"),
        js_native_create(
            "toLocaleString", 0, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_TOLOCALE
        )
    );
    _ti_define_proto_method(
        pmd_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_VALUEOF)
    );
    _install_getter(
        pmd_proto,
        str_intern("calendarId"),
        "calendarId",
        NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_GETTER
    );
    _install_getter(
        pmd_proto,
        str_intern("monthCode"),
        "monthCode",
        NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_GETTER
    );
    _install_getter(
        pmd_proto, str_intern("day"), "day", NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_GETTER
    );
    _install_getter(
        pmd_proto,
        str_intern("referenceISOYear"),
        "referenceISOYear",
        NATIVE_KIND_TEMPORAL_PLAIN_MONTH_DAY_GETTER
    );
    _tag_proto(pmd_proto, "Temporal.PlainMonthDay");
    _wire_ctor(pmd_ctor, pmd_proto);
    temporal_set_plain_month_day_proto(pmd_proto);
    _ti_set_ns(temporal, str_intern("PlainMonthDay"), pmd_ctor);

    # ── Instant ───────────────────────────────────────────────────────────────
    ins_proto: JSValue = js_object_create_null();
    ins_ctor: JSValue = js_callable_create("Instant", 1, NATIVE_KIND_TEMPORAL_INSTANT);
    _ti_define_static_method(
        ins_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_INSTANT_FROM)
    );
    _ti_define_static_method(
        ins_ctor,
        str_intern("fromEpochMilliseconds"),
        js_native_create(
            "fromEpochMilliseconds", 1, NATIVE_KIND_TEMPORAL_INSTANT_FROM_MS
        )
    );
    _ti_define_static_method(
        ins_ctor,
        str_intern("fromEpochNanoseconds"),
        js_native_create(
            "fromEpochNanoseconds", 1, NATIVE_KIND_TEMPORAL_INSTANT_FROM_NS
        )
    );
    _ti_define_static_method(
        ins_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_INSTANT_COMPARE)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_INSTANT_ADD)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_INSTANT_SUBTRACT)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_INSTANT_UNTIL)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_INSTANT_SINCE)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("round"),
        js_native_create("round", 1, NATIVE_KIND_TEMPORAL_INSTANT_ROUND)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_INSTANT_EQUALS)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("toZonedDateTimeISO"),
        js_native_create(
            "toZonedDateTimeISO", 1, NATIVE_KIND_TEMPORAL_INSTANT_TO_ZONED_DATETIME_ISO
        )
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_INSTANT_TOSTRING)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_INSTANT_TOJSON)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("toLocaleString"),
        js_native_create("toLocaleString", 0, NATIVE_KIND_TEMPORAL_INSTANT_TOLOCALE)
    );
    _ti_define_proto_method(
        ins_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_INSTANT_VALUEOF)
    );
    _install_getter(
        ins_proto,
        str_intern("epochMilliseconds"),
        "epochMilliseconds",
        NATIVE_KIND_TEMPORAL_INSTANT_GETTER
    );
    _install_getter(
        ins_proto,
        str_intern("epochNanoseconds"),
        "epochNanoseconds",
        NATIVE_KIND_TEMPORAL_INSTANT_GETTER
    );
    _tag_proto(ins_proto, "Temporal.Instant");
    _wire_ctor(ins_ctor, ins_proto);
    temporal_set_instant_proto(ins_proto);
    _ti_set_ns(temporal, str_intern("Instant"), ins_ctor);

    # ── ZonedDateTime ─────────────────────────────────────────────────────────
    zdt_proto: JSValue = js_object_create_null();
    zdt_ctor: JSValue = js_callable_create(
        "ZonedDateTime", 2, NATIVE_KIND_TEMPORAL_ZONED_DATETIME
    );
    _ti_define_static_method(
        zdt_ctor,
        str_intern("from"),
        js_native_create("from", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_FROM)
    );
    _ti_define_static_method(
        zdt_ctor,
        str_intern("compare"),
        js_native_create("compare", 2, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_COMPARE)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("add"),
        js_native_create("add", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_ADD)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("subtract"),
        js_native_create("subtract", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_SUB)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("equals"),
        js_native_create("equals", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_EQUALS)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("until"),
        js_native_create("until", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_UNTIL)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("since"),
        js_native_create("since", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_SINCE)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toInstant"),
        js_native_create("toInstant", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOINSTANT)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toPlainDate"),
        js_native_create(
            "toPlainDate", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TO_PLAIN_DATE
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toPlainTime"),
        js_native_create(
            "toPlainTime", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TO_PLAIN_TIME
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toPlainDateTime"),
        js_native_create(
            "toPlainDateTime", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TO_PLAIN_DATETIME
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toLocaleString"),
        js_native_create(
            "toLocaleString", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOLOCALE
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("round"),
        js_native_create("round", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_ROUND)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("with"),
        js_native_create("with", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("withCalendar"),
        js_native_create(
            "withCalendar", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH_CAL
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("withTimeZone"),
        js_native_create("withTimeZone", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH_TZ)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("withPlainTime"),
        js_native_create(
            "withPlainTime", 1, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_WITH_PLAIN_TIME
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("getTimeZoneTransition"),
        js_native_create(
            "getTimeZoneTransition",
            1,
            NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GET_TZ_TRANSITION
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("startOfDay"),
        js_native_create(
            "startOfDay", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_START_OF_DAY
        )
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toString"),
        js_native_create("toString", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOSTRING)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("toJSON"),
        js_native_create("toJSON", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_TOJSON)
    );
    _ti_define_proto_method(
        zdt_proto,
        str_intern("valueOf"),
        js_native_create("valueOf", 0, NATIVE_KIND_TEMPORAL_ZONED_DATETIME_VALUEOF)
    );
    _install_getter(
        zdt_proto,
        str_intern("timeZoneId"),
        "timeZoneId",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("calendarId"),
        "calendarId",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("offset"),
        "offset",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("offsetNanoseconds"),
        "offsetNanoseconds",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("epochNanoseconds"),
        "epochNanoseconds",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("epochMilliseconds"),
        "epochMilliseconds",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("year"),
        "year",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("month"),
        "month",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("monthCode"),
        "monthCode",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto, str_intern("day"), "day", NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("hour"),
        "hour",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("minute"),
        "minute",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("second"),
        "second",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("millisecond"),
        "millisecond",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("microsecond"),
        "microsecond",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("nanosecond"),
        "nanosecond",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("dayOfWeek"),
        "dayOfWeek",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("dayOfYear"),
        "dayOfYear",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("weekOfYear"),
        "weekOfYear",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("yearOfWeek"),
        "yearOfWeek",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("daysInMonth"),
        "daysInMonth",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("daysInYear"),
        "daysInYear",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("monthsInYear"),
        "monthsInYear",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("inLeapYear"),
        "inLeapYear",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("daysInWeek"),
        "daysInWeek",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto, str_intern("era"), "era", NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("eraYear"),
        "eraYear",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _install_getter(
        zdt_proto,
        str_intern("hoursInDay"),
        "hoursInDay",
        NATIVE_KIND_TEMPORAL_ZONED_DATETIME_GETTER
    );
    _tag_proto(zdt_proto, "Temporal.ZonedDateTime");
    _wire_ctor(zdt_ctor, zdt_proto);
    temporal_set_zoned_datetime_proto(zdt_proto);
    _ti_set_ns(temporal, str_intern("ZonedDateTime"), zdt_ctor);

    # ── Temporal.Now ──────────────────────────────────────────────────────────
    now_obj: JSValue = js_object_create_null();
    _ti_define_static_method(
        now_obj,
        str_intern("instant"),
        js_native_create("instant", 0, NATIVE_KIND_TEMPORAL_NOW_INSTANT)
    );
    _ti_define_static_method(
        now_obj,
        str_intern("plainDateISO"),
        js_native_create("plainDateISO", 0, NATIVE_KIND_TEMPORAL_NOW_PLAIN_DATE_ISO)
    );
    _ti_define_static_method(
        now_obj,
        str_intern("plainTimeISO"),
        js_native_create("plainTimeISO", 0, NATIVE_KIND_TEMPORAL_NOW_PLAIN_TIME_ISO)
    );
    _ti_define_static_method(
        now_obj,
        str_intern("plainDateTimeISO"),
        js_native_create(
            "plainDateTimeISO", 0, NATIVE_KIND_TEMPORAL_NOW_PLAIN_DATETIME_ISO
        )
    );
    _ti_define_static_method(
        now_obj,
        str_intern("timeZoneId"),
        js_native_create("timeZoneId", 0, NATIVE_KIND_TEMPORAL_NOW_TIMEZONE_ID)
    );
    _ti_define_static_method(
        now_obj,
        str_intern("zonedDateTimeISO"),
        js_native_create(
            "zonedDateTimeISO", 0, NATIVE_KIND_TEMPORAL_NOW_ZONED_DATETIME_ISO
        )
    );
    _ti_set_ns(temporal, str_intern("Now"), now_obj);

    _ti_define_prop(
        temporal,
        SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG,
        jsv_from_string_id(str_intern("Temporal")),
        False,
        False,
        True
    );
    _ti_define_prop(gv, k_temporal, temporal, True, False, True);
}
