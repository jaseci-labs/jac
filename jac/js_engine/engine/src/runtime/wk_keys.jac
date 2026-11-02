"""
Well-known interned property-key integer IDs.

All str_intern() comparison targets from vm.na.jac are pre-computed here
so the hot GET_PROP/SET_PROP/CALL_PROP dispatch chains do integer comparisons
instead of dict[str,int] lookups (strcmp) on every property access.

Call init_wk_keys() once after str_intern_seed_well_known() in init_global().
"""

import from engine.src.runtime.jsstring { str_intern }

glob:pub WK_0: int = -1,
     WK_ADD: int = -1,
     WK_APPLY: int = -1,
     WK_ASYNC_ITER: int = -1,
     WK_AT: int = -1,
     WK_BIND: int = -1,
     WK_BOOLEAN: int = -1,
     WK_CALL: int = -1,
     WK_CALLEE: int = -1,
     WK_CALLER: int = -1,
     WK_ARGUMENTS: int = -1,
     WK_DEFER_PENDING: int = -1,
     WK_CATCH: int = -1,
     WK_CHARAT: int = -1,
     WK_CHARCODEAT: int = -1,
     WK_CLASS_NAME: int = -1,
     WK_CLEAR: int = -1,
     WK_CODEPOINTAT: int = -1,
     WK_CONCAT: int = -1,
     WK_CONSTRUCTOR: int = -1,
     WK_COPYWITHIN: int = -1,
     WK_CTOR: int = -1,
     WK_CUSTOM: int = -1,
     WK_DEFAULT: int = -1,
     WK_DELETE: int = -1,
     WK_DESCRIPTION: int = -1,
     WK_DONE: int = -1,
     WK_ENDSWITH: int = -1,
     WK_ENTRIES: int = -1,
     WK_EPSILON: int = -1,
     WK_EVERY: int = -1,
     WK_EXEC: int = -1,
     WK_EXPORTS: int = -1,
     WK_JAC_ESM_EXPORTS: int = -1,
     WK_JAC_MODULE: int = -1,
     WK_FIELDS: int = -1,
     WK_CF_FN: int = -1,
     WK_CF_KEY: int = -1,
     WK_FILL: int = -1,
     WK_FILTER: int = -1,
     WK_FINALLY: int = -1,
     WK_FIND: int = -1,
     WK_FINDINDEX: int = -1,
     WK_FINDLAST: int = -1,
     WK_FINDLASTINDEX: int = -1,
     WK_FLAT: int = -1,
     WK_FLATMAP: int = -1,
     WK_FOREACH: int = -1,
     WK_FROMCHARCODE: int = -1,
     WK_FROMCODEPOINT: int = -1,
     WK_GEN: int = -1,
     WK_ITERDONE: int = -1,
     WK_ITER_NEXT_FN: int = -1,
     WK_GET: int = -1,
     WK_GETDATE: int = -1,
     WK_GETDAY: int = -1,
     WK_GETFULLYEAR: int = -1,
     WK_GETHOURS: int = -1,
     WK_GETMILLISECONDS: int = -1,
     WK_GETMINUTES: int = -1,
     WK_GETMONTH: int = -1,
     WK_GETSECONDS: int = -1,
     WK_GETTIME: int = -1,
     WK_GETTIMEZONEOFFSET: int = -1,
     WK_GETUTCDATE: int = -1,
     WK_GETUTCDAY: int = -1,
     WK_GETUTCFULLYEAR: int = -1,
     WK_GETUTCHOURS: int = -1,
     WK_GETUTCMILLISECONDS: int = -1,
     WK_GETUTCMINUTES: int = -1,
     WK_GETUTCMONTH: int = -1,
     WK_GETUTCSECONDS: int = -1,
     WK_GLOBAL: int = -1,
     WK_GROUPS: int = -1,
     WK_HAS: int = -1,
     WK_I: int = -1,
     WK_ID: int = -1,
     WK_INCLUDES: int = -1,
     WK_INDEX: int = -1,
     WK_INDEXOF: int = -1,
     WK_INTERNAL: int = -1,
     WK_FROM_SYNC: int = -1,
     WK_IS_CLASS: int = -1,
     WK_NOT_CTOR: int = -1,
     WK_ISFINITE: int = -1,
     WK_ISINTEGER: int = -1,
     WK_ISNAN: int = -1,
     WK_ISSAFEINTEGER: int = -1,
     WK_J: int = -1,
     WK_JOIN: int = -1,
     WK_KEYS: int = -1,
     WK_LASTINDEX: int = -1,
     WK_LASTINDEXOF: int = -1,
     WK_LENGTH: int = -1,
     WK_BYTELENGTH: int = -1,
     WK_BYTEOFFSET: int = -1,
     WK_BUFFER: int = -1,
     WK_LOCALECOMPARE: int = -1,
     WK_MAP: int = -1,
     WK_MATCH: int = -1,
     WK_MATCHALL: int = -1,
     WK_MAX_SAFE_INTEGER: int = -1,
     WK_MAX_VALUE: int = -1,
     WK_MIN_SAFE_INTEGER: int = -1,
     WK_MIN_VALUE: int = -1,
     WK_NAME: int = -1,
     WK_NAN: int = -1,
     WK_NEGATIVE_INFINITY: int = -1,
     WK_NEXT: int = -1,
     WK_NORMALIZE: int = -1,
     WK_PADEND: int = -1,
     WK_PADSTART: int = -1,
     WK_PARSEFLOAT: int = -1,
     WK_PARSEINT: int = -1,
     WK_POP: int = -1,
     WK_POSITIVE_INFINITY: int = -1,
     WK_PROMISES: int = -1,
     WK_PROTOTYPE: int = -1,
     WK_PUSH: int = -1,
     WK_RAW: int = -1,
     WK_REDUCE: int = -1,
     WK_REDUCERIGHT: int = -1,
     WK_REF: int = -1,
     WK_REPEAT: int = -1,
     WK_REPLACE: int = -1,
     WK_REPLACEALL: int = -1,
     WK_RESOLVE: int = -1,
     WK_RETURN: int = -1,
     WK_REVERSE: int = -1,
     WK_CACHE: int = -1,
     WK_COMPILE: int = -1,
     WK_CHILDREN: int = -1,
     WK_EXTENSIONS: int = -1,
     WK_LOADED: int = -1,
     WK_MAIN: int = -1,
     WK_PARENT: int = -1,
     WK_PATHS: int = -1,
     WK_SEARCH: int = -1,
     WK_SET: int = -1,
     WK_SETDATE: int = -1,
     WK_SETFULLYEAR: int = -1,
     WK_SETHOURS: int = -1,
     WK_SETMILLISECONDS: int = -1,
     WK_SETMINUTES: int = -1,
     WK_SETMONTH: int = -1,
     WK_SETSECONDS: int = -1,
     WK_SETTIME: int = -1,
     WK_SETUTCDATE: int = -1,
     WK_SETUTCFULLYEAR: int = -1,
     WK_SETUTCHOURS: int = -1,
     WK_SETUTCMILLISECONDS: int = -1,
     WK_SETUTCMINUTES: int = -1,
     WK_SETUTCMONTH: int = -1,
     WK_SETUTCSECONDS: int = -1,
     WK_TOTEMPORALINSTANT: int = -1,
     WK_SHIFT: int = -1,
     WK_SIZE: int = -1,
     WK_SLICE: int = -1,
     WK_SOME: int = -1,
     WK_SORT: int = -1,
     WK_SPLICE: int = -1,
     WK_SPLIT: int = -1,
     WK_STARTSWITH: int = -1,
     WK_SUBSTR: int = -1,
     WK_SUBSTRING: int = -1,
     WK_SUPER: int = -1,
     WK_THEN: int = -1,
     WK_THROW: int = -1,
     WK_TIMER_ID: int = -1,
     WK_TODATESTRING: int = -1,
     WK_TOEXPONENTIAL: int = -1,
     WK_TOFIXED: int = -1,
     WK_TOISOSTRING: int = -1,
     WK_TOJSON: int = -1,
     WK_TOLOCALEDATESTRING: int = -1,
     WK_TOLOCALELOWERCASE: int = -1,
     WK_TOLOCALESTRING: int = -1,
     WK_TOLOCALETIMESTRING: int = -1,
     WK_TOLOCALEUPPERCASE: int = -1,
     WK_TOLOWERCASE: int = -1,
     WK_TOPRECISION: int = -1,
     WK_TOREVERSED: int = -1,
     WK_TOSORTED: int = -1,
     WK_TOSPLICED: int = -1,
     WK_TOSTRING: int = -1,
     WK_TOTIMESTRING: int = -1,
     WK_TOUPPERCASE: int = -1,
     WK_TOUTCSTRING: int = -1,
     WK_TRIM: int = -1,
     WK_TRIMEND: int = -1,
     WK_TRIMLEFT: int = -1,
     WK_TRIMRIGHT: int = -1,
     WK_TRIMSTART: int = -1,
     WK_UNSHIFT: int = -1,
     WK_UNREF: int = -1,
     WK_VALUE: int = -1,
     WK_VALUEOF: int = -1,
     WK_VALUES: int = -1,
     WK_WITH: int = -1,
     WK_WRITABLE: int = -1,
     WK_ENUMERABLE: int = -1,
     WK_CONFIGURABLE: int = -1;  # "0"

# "add"
# "apply"
# "__ASYNC_ITER"
# "at"
# "bind"
# "Boolean"
# "call"
# "callee"
# "caller"
# "arguments"
# "__DEFER_PENDING" (deferred-module-ns marker, not user-visible)
# "catch"
# "charAt"
# "charCodeAt"
# "__CLASS_NAME__"
# "clear"
# "codePointAt"
# "concat"
# "constructor"
# "copyWithin"
# "__CTOR__"
# "__CUSTOM"
# "default"
# "delete"
# "description"
# "done"
# "endsWith"
# "entries"
# "EPSILON"
# "every"
# "exec"
# "exports"
# "__jac_esm_exports" (compiler ESM surface, not user-visible)
# "__jacModule" (CJS closure→module binding, not user-visible)
# "__FIELDS__"
# "__cf_fn" — computed-field init fn (wrapper entry)
# "__cf_key" — computed-field captured key (wrapper entry)
# "fill"
# "filter"
# "finally"
# "find"
# "findIndex"
# "findLast"
# "findLastIndex"
# "flat"
# "flatMap"
# "forEach"
# "fromCharCode"
# "fromCodePoint"
# "__GEN"
# "__ITERDONE" (iterator-record [[done]] flag for IteratorClose)
# "__ITERNEXTFN" (cached iterator `next` method — GetIterator reads it once, §7.4.1)
# "get"
# "getDate"
# "getDay"
# "getFullYear"
# "getHours"
# "getMilliseconds"
# "getMinutes"
# "getMonth"
# "getSeconds"
# "getTime"
# "getTimezoneOffset"
# "getUTCDate"
# "getUTCDay"
# "getUTCFullYear"
# "getUTCHours"
# "getUTCMilliseconds"
# "getUTCMinutes"
# "getUTCMonth"
# "getUTCSeconds"
# "global"
# "groups"
# "has"
# "__I"
# "id"
# "includes"
# "index"
# "indexOf"
# "__INTERNAL"
# "__FROM_SYNC" (async-from-sync iterator wrapper marker)
# "__IS_CLASS__"
# "__NOT_CTOR__"
# "isFinite"
# "isInteger"
# "isNaN"
# "isSafeInteger"
# "__J"
# "join"
# "keys"
# "lastIndex"
# "lastIndexOf"
# "length"
# "byteLength"
# "byteOffset"
# "buffer"
# "localeCompare"
# "map"
# "match"
# "matchAll"
# "MAX_SAFE_INTEGER"
# "MAX_VALUE"
# "MIN_SAFE_INTEGER"
# "MIN_VALUE"
# "name"
# "NaN"
# "NEGATIVE_INFINITY"
# "next"
# "normalize"
# "padEnd"
# "padStart"
# "parseFloat"
# "parseInt"
# "pop"
# "POSITIVE_INFINITY"
# "promises"
# "prototype"
# "push"
# "raw"
# "reduce"
# "reduceRight"
# "ref"
# "repeat"
# "replace"
# "replaceAll"
# "resolve"
# "return"
# "reverse"
# "cache"
# "_compile"
# "children"
# "extensions"
# "loaded"
# "main"
# "parent"
# "paths"
# "search"
# "set"
# "setDate"
# "setFullYear"
# "setHours"
# "setMilliseconds"
# "setMinutes"
# "setMonth"
# "setSeconds"
# "setTime"
# "setUTCDate"
# "setUTCFullYear"
# "setUTCHours"
# "setUTCMilliseconds"
# "setUTCMinutes"
# "setUTCMonth"
# "setUTCSeconds"
# "toTemporalInstant"
# "shift"
# "size"
# "slice"
# "some"
# "sort"
# "splice"
# "split"
# "startsWith"
# "substr"
# "substring"
# "__SUPER__"
# "then"
# "throw"
# "_timerId"
# "toDateString"
# "toExponential"
# "toFixed"
# "toISOString"
# "toJSON"
# "toLocaleDateString"
# "toLocaleLowerCase"
# "toLocaleString"
# "toLocaleTimeString"
# "toLocaleUpperCase"
# "toLowerCase"
# "toPrecision"
# "toReversed"
# "toSorted"
# "toSpliced"
# "toString"
# "toTimeString"
# "toUpperCase"
# "toUTCString"
# "trim"
# "trimEnd"
# "trimLeft"
# "trimRight"
# "trimStart"
# "unshift"
# "unref"
# "value"
# "valueOf"
# "values"
# "with"
# "writable"
# "enumerable"
# "configurable"
"""Initialize all well-known key IDs.  Must be called after str_intern_seed_well_known()."""
def:pub init_wk_keys {
    WK_0 = str_intern("0");
    WK_ADD = str_intern("add");
    WK_APPLY = str_intern("apply");
    WK_ASYNC_ITER = str_intern("__ASYNC_ITER");
    WK_AT = str_intern("at");
    WK_BIND = str_intern("bind");
    WK_BOOLEAN = str_intern("Boolean");
    WK_CALL = str_intern("call");
    WK_CALLEE = str_intern("callee");
    WK_CALLER = str_intern("caller");
    WK_ARGUMENTS = str_intern("arguments");
    WK_DEFER_PENDING = str_intern("__DEFER_PENDING");
    WK_CATCH = str_intern("catch");
    WK_CHARAT = str_intern("charAt");
    WK_CHARCODEAT = str_intern("charCodeAt");
    WK_CLASS_NAME = str_intern("__CLASS_NAME__");
    WK_CLEAR = str_intern("clear");
    WK_CODEPOINTAT = str_intern("codePointAt");
    WK_CONCAT = str_intern("concat");
    WK_CONSTRUCTOR = str_intern("constructor");
    WK_COPYWITHIN = str_intern("copyWithin");
    WK_CTOR = str_intern("__CTOR__");
    WK_CUSTOM = str_intern("__CUSTOM");
    WK_DEFAULT = str_intern("default");
    WK_DELETE = str_intern("delete");
    WK_DESCRIPTION = str_intern("description");
    WK_DONE = str_intern("done");
    WK_ENDSWITH = str_intern("endsWith");
    WK_ENTRIES = str_intern("entries");
    WK_EPSILON = str_intern("EPSILON");
    WK_EVERY = str_intern("every");
    WK_EXEC = str_intern("exec");
    WK_EXPORTS = str_intern("exports");
    WK_JAC_ESM_EXPORTS = str_intern("__jac_esm_exports");
    WK_JAC_MODULE = str_intern("__jacModule");
    WK_FIELDS = str_intern("__FIELDS__");
    WK_CF_FN = str_intern("__cf_fn");
    WK_CF_KEY = str_intern("__cf_key");
    WK_FILL = str_intern("fill");
    WK_FILTER = str_intern("filter");
    WK_FINALLY = str_intern("finally");
    WK_FIND = str_intern("find");
    WK_FINDINDEX = str_intern("findIndex");
    WK_FINDLAST = str_intern("findLast");
    WK_FINDLASTINDEX = str_intern("findLastIndex");
    WK_FLAT = str_intern("flat");
    WK_FLATMAP = str_intern("flatMap");
    WK_FOREACH = str_intern("forEach");
    WK_FROMCHARCODE = str_intern("fromCharCode");
    WK_FROMCODEPOINT = str_intern("fromCodePoint");
    WK_GEN = str_intern("__GEN");
    WK_GET = str_intern("get");
    WK_GETDATE = str_intern("getDate");
    WK_GETDAY = str_intern("getDay");
    WK_GETFULLYEAR = str_intern("getFullYear");
    WK_GETHOURS = str_intern("getHours");
    WK_GETMILLISECONDS = str_intern("getMilliseconds");
    WK_GETMINUTES = str_intern("getMinutes");
    WK_GETMONTH = str_intern("getMonth");
    WK_GETSECONDS = str_intern("getSeconds");
    WK_GETTIME = str_intern("getTime");
    WK_GETTIMEZONEOFFSET = str_intern("getTimezoneOffset");
    WK_GETUTCDATE = str_intern("getUTCDate");
    WK_GETUTCDAY = str_intern("getUTCDay");
    WK_GETUTCFULLYEAR = str_intern("getUTCFullYear");
    WK_GETUTCHOURS = str_intern("getUTCHours");
    WK_GETUTCMILLISECONDS = str_intern("getUTCMilliseconds");
    WK_GETUTCMINUTES = str_intern("getUTCMinutes");
    WK_GETUTCMONTH = str_intern("getUTCMonth");
    WK_GETUTCSECONDS = str_intern("getUTCSeconds");
    WK_GLOBAL = str_intern("global");
    WK_GROUPS = str_intern("groups");
    WK_HAS = str_intern("has");
    WK_I = str_intern("__I");
    WK_ID = str_intern("id");
    WK_INCLUDES = str_intern("includes");
    WK_INDEX = str_intern("index");
    WK_INDEXOF = str_intern("indexOf");
    WK_INTERNAL = str_intern("__INTERNAL");
    WK_FROM_SYNC = str_intern("__FROM_SYNC");
    WK_ITERDONE = str_intern("__ITERDONE");
    WK_ITER_NEXT_FN = str_intern("__ITERNEXTFN");
    WK_IS_CLASS = str_intern("__IS_CLASS__");
    WK_NOT_CTOR = str_intern("__NOT_CTOR__");
    WK_ISFINITE = str_intern("isFinite");
    WK_ISINTEGER = str_intern("isInteger");
    WK_ISNAN = str_intern("isNaN");
    WK_ISSAFEINTEGER = str_intern("isSafeInteger");
    WK_J = str_intern("__J");
    WK_JOIN = str_intern("join");
    WK_KEYS = str_intern("keys");
    WK_LASTINDEX = str_intern("lastIndex");
    WK_LASTINDEXOF = str_intern("lastIndexOf");
    WK_LENGTH = str_intern("length");
    WK_BYTELENGTH = str_intern("byteLength");
    WK_BYTEOFFSET = str_intern("byteOffset");
    WK_BUFFER = str_intern("buffer");
    WK_LOCALECOMPARE = str_intern("localeCompare");
    WK_MAP = str_intern("map");
    WK_MATCH = str_intern("match");
    WK_MATCHALL = str_intern("matchAll");
    WK_MAX_SAFE_INTEGER = str_intern("MAX_SAFE_INTEGER");
    WK_MAX_VALUE = str_intern("MAX_VALUE");
    WK_MIN_SAFE_INTEGER = str_intern("MIN_SAFE_INTEGER");
    WK_MIN_VALUE = str_intern("MIN_VALUE");
    WK_NAME = str_intern("name");
    WK_NAN = str_intern("NaN");
    WK_NEGATIVE_INFINITY = str_intern("NEGATIVE_INFINITY");
    WK_NEXT = str_intern("next");
    WK_NORMALIZE = str_intern("normalize");
    WK_PADEND = str_intern("padEnd");
    WK_PADSTART = str_intern("padStart");
    WK_PARSEFLOAT = str_intern("parseFloat");
    WK_PARSEINT = str_intern("parseInt");
    WK_POP = str_intern("pop");
    WK_POSITIVE_INFINITY = str_intern("POSITIVE_INFINITY");
    WK_PROMISES = str_intern("promises");
    WK_PROTOTYPE = str_intern("prototype");
    WK_PUSH = str_intern("push");
    WK_RAW = str_intern("raw");
    WK_REDUCE = str_intern("reduce");
    WK_REDUCERIGHT = str_intern("reduceRight");
    WK_REF = str_intern("ref");
    WK_REPEAT = str_intern("repeat");
    WK_REPLACE = str_intern("replace");
    WK_REPLACEALL = str_intern("replaceAll");
    WK_RESOLVE = str_intern("resolve");
    WK_RETURN = str_intern("return");
    WK_REVERSE = str_intern("reverse");
    WK_CACHE = str_intern("cache");
    WK_COMPILE = str_intern("_compile");
    WK_CHILDREN = str_intern("children");
    WK_EXTENSIONS = str_intern("extensions");
    WK_LOADED = str_intern("loaded");
    WK_MAIN = str_intern("main");
    WK_PARENT = str_intern("parent");
    WK_PATHS = str_intern("paths");
    WK_SEARCH = str_intern("search");
    WK_SET = str_intern("set");
    WK_SETDATE = str_intern("setDate");
    WK_SETFULLYEAR = str_intern("setFullYear");
    WK_SETHOURS = str_intern("setHours");
    WK_SETMILLISECONDS = str_intern("setMilliseconds");
    WK_SETMINUTES = str_intern("setMinutes");
    WK_SETMONTH = str_intern("setMonth");
    WK_SETSECONDS = str_intern("setSeconds");
    WK_SETTIME = str_intern("setTime");
    WK_SETUTCDATE = str_intern("setUTCDate");
    WK_SETUTCFULLYEAR = str_intern("setUTCFullYear");
    WK_SETUTCHOURS = str_intern("setUTCHours");
    WK_SETUTCMILLISECONDS = str_intern("setUTCMilliseconds");
    WK_SETUTCMINUTES = str_intern("setUTCMinutes");
    WK_SETUTCMONTH = str_intern("setUTCMonth");
    WK_SETUTCSECONDS = str_intern("setUTCSeconds");
    WK_TOTEMPORALINSTANT = str_intern("toTemporalInstant");
    WK_SHIFT = str_intern("shift");
    WK_SIZE = str_intern("size");
    WK_SLICE = str_intern("slice");
    WK_SOME = str_intern("some");
    WK_SORT = str_intern("sort");
    WK_SPLICE = str_intern("splice");
    WK_SPLIT = str_intern("split");
    WK_STARTSWITH = str_intern("startsWith");
    WK_SUBSTR = str_intern("substr");
    WK_SUBSTRING = str_intern("substring");
    WK_SUPER = str_intern("__SUPER__");
    WK_THEN = str_intern("then");
    WK_THROW = str_intern("throw");
    WK_TIMER_ID = str_intern("_timerId");
    WK_TODATESTRING = str_intern("toDateString");
    WK_TOEXPONENTIAL = str_intern("toExponential");
    WK_TOFIXED = str_intern("toFixed");
    WK_TOISOSTRING = str_intern("toISOString");
    WK_TOJSON = str_intern("toJSON");
    WK_TOLOCALEDATESTRING = str_intern("toLocaleDateString");
    WK_TOLOCALELOWERCASE = str_intern("toLocaleLowerCase");
    WK_TOLOCALESTRING = str_intern("toLocaleString");
    WK_TOLOCALETIMESTRING = str_intern("toLocaleTimeString");
    WK_TOLOCALEUPPERCASE = str_intern("toLocaleUpperCase");
    WK_TOLOWERCASE = str_intern("toLowerCase");
    WK_TOPRECISION = str_intern("toPrecision");
    WK_TOREVERSED = str_intern("toReversed");
    WK_TOSORTED = str_intern("toSorted");
    WK_TOSPLICED = str_intern("toSpliced");
    WK_TOSTRING = str_intern("toString");
    WK_TOTIMESTRING = str_intern("toTimeString");
    WK_TOUPPERCASE = str_intern("toUpperCase");
    WK_TOUTCSTRING = str_intern("toUTCString");
    WK_TRIM = str_intern("trim");
    WK_TRIMEND = str_intern("trimEnd");
    WK_TRIMLEFT = str_intern("trimLeft");
    WK_TRIMRIGHT = str_intern("trimRight");
    WK_TRIMSTART = str_intern("trimStart");
    WK_UNSHIFT = str_intern("unshift");
    WK_UNREF = str_intern("unref");
    WK_VALUE = str_intern("value");
    WK_VALUEOF = str_intern("valueOf");
    WK_VALUES = str_intern("values");
    WK_WITH = str_intern("with");
    WK_WRITABLE = str_intern("writable");
    WK_ENUMERABLE = str_intern("enumerable");
    WK_CONFIGURABLE = str_intern("configurable");
}
