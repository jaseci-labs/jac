"""Intl global wiring — installs private __icu bridge for the JS Intl bootstrap.

js_intl_wire_global(gv) exposes ICU helpers on globalThis.__icu.  The full
Intl object (constructors, getCanonicalLocales, …) is installed later by
engine/src/builtins/js/intl.js via bootstrap_js_globals.
"""

import from engine.src.runtime.jsvalue { JSValue }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject { js_object_create_null, js_object_set }
import from engine.src.builtins.native_registry { js_native_create }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_ICU_CANONICAL_LOCALE,
    NATIVE_KIND_ICU_GET_DEFAULT_LOCALE,
    NATIVE_KIND_ICU_FORMAT_NUMBER,
    NATIVE_KIND_ICU_FORMAT_DATETIME,
    NATIVE_KIND_ICU_PLURAL_SELECT,
    NATIVE_KIND_ICU_COMPARE,
    NATIVE_KIND_ICU_DISPLAY_NAME,
    NATIVE_KIND_ICU_LIST_FORMAT,
    NATIVE_KIND_ICU_RELATIVE_TIME,
    NATIVE_KIND_ICU_SEGMENTER_BREAK,
    NATIVE_KIND_ICU_MAXIMIZE_LOCALE,
    NATIVE_KIND_ICU_MINIMIZE_LOCALE,
    NATIVE_KIND_ICU_LOCALE_INFO,
    NATIVE_KIND_ICU_FORMAT_NUMBER_PARTS,
    NATIVE_KIND_ICU_FORMAT_DATETIME_PARTS,
    NATIVE_KIND_ICU_FORMAT_NUMBER_RANGE,
    NATIVE_KIND_ICU_FORMAT_DATETIME_RANGE,
    NATIVE_KIND_ICU_SET_DEFAULT_TZ
}

"""Install globalThis.__icu with ICU shim entry points."""
def:pub js_intl_wire_global(gv: JSValue) {
    icu_obj: JSValue = js_object_create_null();
    js_object_set(
        icu_obj,
        str_intern("canonicalLocale"),
        js_native_create("canonicalLocale", 1, NATIVE_KIND_ICU_CANONICAL_LOCALE)
    );
    js_object_set(
        icu_obj,
        str_intern("getDefaultLocale"),
        js_native_create("getDefaultLocale", 0, NATIVE_KIND_ICU_GET_DEFAULT_LOCALE)
    );
    js_object_set(
        icu_obj,
        str_intern("formatNumber"),
        js_native_create("formatNumber", 3, NATIVE_KIND_ICU_FORMAT_NUMBER)
    );
    js_object_set(
        icu_obj,
        str_intern("formatDateTime"),
        js_native_create("formatDateTime", 4, NATIVE_KIND_ICU_FORMAT_DATETIME)
    );
    js_object_set(
        icu_obj,
        str_intern("setDefaultTimeZone"),
        js_native_create("setDefaultTimeZone", 1, NATIVE_KIND_ICU_SET_DEFAULT_TZ)
    );
    js_object_set(
        icu_obj,
        str_intern("pluralSelect"),
        js_native_create("pluralSelect", 3, NATIVE_KIND_ICU_PLURAL_SELECT)
    );
    js_object_set(
        icu_obj,
        str_intern("compare"),
        js_native_create("compare", 4, NATIVE_KIND_ICU_COMPARE)
    );
    js_object_set(
        icu_obj,
        str_intern("displayName"),
        js_native_create("displayName", 4, NATIVE_KIND_ICU_DISPLAY_NAME)
    );
    js_object_set(
        icu_obj,
        str_intern("listFormat"),
        js_native_create("listFormat", 4, NATIVE_KIND_ICU_LIST_FORMAT)
    );
    js_object_set(
        icu_obj,
        str_intern("relativeTime"),
        js_native_create("relativeTime", 4, NATIVE_KIND_ICU_RELATIVE_TIME)
    );
    js_object_set(
        icu_obj,
        str_intern("segmenterBreak"),
        js_native_create("segmenterBreak", 3, NATIVE_KIND_ICU_SEGMENTER_BREAK)
    );
    js_object_set(
        icu_obj,
        str_intern("maximizeLocale"),
        js_native_create("maximizeLocale", 1, NATIVE_KIND_ICU_MAXIMIZE_LOCALE)
    );
    js_object_set(
        icu_obj,
        str_intern("minimizeLocale"),
        js_native_create("minimizeLocale", 1, NATIVE_KIND_ICU_MINIMIZE_LOCALE)
    );
    js_object_set(
        icu_obj,
        str_intern("localeInfo"),
        js_native_create("localeInfo", 2, NATIVE_KIND_ICU_LOCALE_INFO)
    );
    js_object_set(
        icu_obj,
        str_intern("formatNumberParts"),
        js_native_create("formatNumberParts", 3, NATIVE_KIND_ICU_FORMAT_NUMBER_PARTS)
    );
    js_object_set(
        icu_obj,
        str_intern("formatDateTimeParts"),
        js_native_create(
            "formatDateTimeParts", 4, NATIVE_KIND_ICU_FORMAT_DATETIME_PARTS
        )
    );
    js_object_set(
        icu_obj,
        str_intern("formatNumberRange"),
        js_native_create("formatNumberRange", 4, NATIVE_KIND_ICU_FORMAT_NUMBER_RANGE)
    );
    js_object_set(
        icu_obj,
        str_intern("formatDateTimeRange"),
        js_native_create(
            "formatDateTimeRange", 5, NATIVE_KIND_ICU_FORMAT_DATETIME_RANGE
        )
    );
    js_object_set(gv, str_intern("__icu"), icu_obj);
}
