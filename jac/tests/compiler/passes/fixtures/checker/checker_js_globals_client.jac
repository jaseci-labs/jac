"""Client-context fixture: ECMAScript / browser globals must resolve.

Mirrors the real-world failure from littleX TweetCard.jac line 25:
`Date.now() - new(Date, created_at).getTime()` plus a few other standard
JS globals. All of this must type-check cleanly in client context.
"""

def now_diff(created_at: str) -> int {
    diff_ms = Date.now() - new(Date, created_at).getTime();
    return int(diff_ms / 1000);
}

def math_json(seed: float) -> str {
    floored: float = Math.floor(Math.random() * 100.0);
    bounded: float = Math.max(floored, seed);
    console.log("bounded", bounded);
    return JSON.stringify({"value": bounded});
}

# Every built-in lists its whole standard surface: a scientific-calculator
# app reaching for inverse trig failed the build on `Math.asin` while the
# browser had it. One use per member keeps a dropped name from going unseen.
def math_surface(x: float) -> float {
    trig = Math.asin(x) + Math.acos(x) + Math.atan(x) + Math.atan2(x, 1.0);
    hyper = Math.sinh(x) + Math.cosh(x) + Math.tanh(x);
    inverse = Math.asinh(x) + Math.acosh(1.5) + Math.atanh(x);
    logs = Math.expm1(x) + Math.log1p(x) + Math.fround(x);
    bits = Math.imul(3.0, 4.0) + Math.clz32(1.0);
    return trig + hyper + inverse + logs + bits;
}

def builtin_statics(target: object, items: list[str]) -> bool {
    names: list[str] = Object.getOwnPropertyNames(target);
    symbols = Object.getOwnPropertySymbols(target);
    sealed = Object.seal(Object.preventExtensions(target));
    Object.defineProperty(sealed, "k", {"value": 1});
    Object.defineProperties(Object.setPrototypeOf(target, None), {});
    console.log(
        Object.getOwnPropertyDescriptor(target, "k"),
        Object.getOwnPropertyDescriptors(target),
        Object.groupBy(items, lambda (s: str) -> str { s[0]; }),
        Map.groupBy(items, lambda (s: str) -> int { len(s); }).size,
        symbols
    );
    Reflect.apply(console.log, None, names);
    Reflect.defineProperty(target, "k", {"value": 2});
    console.log(
        Reflect.getOwnPropertyDescriptor(target, "k"),
        Reflect.getPrototypeOf(target),
        Reflect.setPrototypeOf(target, None),
        Reflect.isExtensible(target),
        Reflect.preventExtensions(target)
    );
    raw: str = String.raw({"raw": ["a", "b"]}, 1);
    pattern = new(RegExp, raw, "gimsuy");
    flags = [
        pattern.multiline,
        pattern.dotAll,
        pattern.unicode,
        pattern.unicodeSets,
        pattern.sticky,
        pattern.hasIndices
    ];
    return Object.hasOwn(target, "k")
        and Object.isFrozen(target)
        and Object.isSealed(target)
        and Object.isExtensible(target)
        and all(flags);
}

async def builtin_async(sources: list[Promise[object]]) -> object {
    first = await Promise.any(sources);
    pending = Promise.withResolvers();
    pending.resolve(first);
    copied: list[object] = await Array.fromAsync(sources);
    console.log(copied);
    return await pending.promise;
}

def utc_parts(stamp: str) -> str {
    d = new(Date, stamp);
    d.setMilliseconds(0.0);
    d.setUTCFullYear(2026.0);
    d.setUTCMonth(0.0);
    d.setUTCDate(1.0);
    d.setUTCHours(12.0);
    d.setUTCMinutes(30.0);
    d.setUTCSeconds(15.0);
    d.setUTCMilliseconds(250.0);
    day: float = d.getUTCDay() + d.getUTCMilliseconds();
    return f"{d.toUTCString()} {day}";
}

def parse_and_format(raw: str) -> int {
    n = parseInt(raw, 10);
    return int(n);
}

# Mirrors the this_is_jac frontend.jac:61 failure: `document`'s
# always-present root elements (documentElement/body/head) must carry the
# real HTMLElement type so `.classList` (and other element members) resolve
# instead of erroring E1030 off the bare `object` placeholder.
def toggle_dark(dark: bool) -> bool {
    if dark {
        document.documentElement.classList.add("dark");
    } else {
        document.documentElement.classList.remove("dark");
    }
    document.body.classList.toggle("ready");
    return document.head.classList.contains("loaded");
}

def typing_into(e: KeyboardEvent) -> bool {
    tag = str(e.target.tagName).lower();
    return tag == "input" or e.target.isContentEditable;
}
