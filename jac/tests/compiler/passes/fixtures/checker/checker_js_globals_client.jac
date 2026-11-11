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

# One use per member added for #10693, so a dropped name fails this check.
def math_surface(x: float) -> float {
    trig = Math.asin(x) + Math.acos(x) + Math.atan(x) + Math.atan2(x, 1.0);
    hyper = Math.sinh(x) + Math.cosh(x) + Math.tanh(x);
    inverse = Math.asinh(x) + Math.acosh(1.5) + Math.atanh(x);
    rest = Math.expm1(x) + Math.log1p(x) + Math.fround(x) + Math.imul(3.0, 4.0);
    return trig + hyper + inverse + rest + Math.clz32(1.0);
}

def object_reflect(target: object, items: list[str]) -> bool {
    locked = Object.seal(Object.preventExtensions(Object.setPrototypeOf(target, None)));
    Object.defineProperties(Object.defineProperty(locked, "k", {}), {});
    Reflect.apply(console.log, None, Object.getOwnPropertyNames(target));
    console.log(
        Object.getOwnPropertySymbols(target),
        Object.getOwnPropertyDescriptors(target),
        Object.getOwnPropertyDescriptor(target, "k"),
        Reflect.getOwnPropertyDescriptor(target, "k"),
        Reflect.getPrototypeOf(target),
        Object.groupBy(items, lambda (s: str) -> str { s[0]; }),
        Map.groupBy(items, lambda (s: str) -> int { len(s); }).size
    );
    states = Object.isFrozen(target)
        and Object.isSealed(target)
        and Object.hasOwn(target, "k");
    reflected = Reflect.defineProperty(target, "k", {})
        and Reflect.setPrototypeOf(target, None);
    return states
        and reflected
        and Reflect.preventExtensions(target)
        and Reflect.isExtensible(target)
        and Object.isExtensible(target);
}

async def promise_array(sources: list[Promise[object]]) -> object {
    pending = Promise.withResolvers();
    pending.resolve(await Promise.any(sources));
    copied: list[object] = await Array.fromAsync(sources);
    return [copied, await pending.promise];
}

def date_regexp(stamp: str) -> str {
    d = new(Date, stamp);
    ms = d.setMilliseconds(0.0) + d.setUTCMilliseconds(0.0) + d.getUTCMilliseconds();
    day = d.setUTCFullYear(0.0) + d.setUTCMonth(0.0) + d.setUTCDate(1.0);
    clock = d.setUTCHours(0.0) + d.setUTCMinutes(0.0) + d.setUTCSeconds(0.0);
    pattern = new(RegExp, String.raw({"raw": ["a", "b"]}, 1), "gimsuy");
    flags = [pattern.multiline, pattern.dotAll, pattern.unicode, pattern.unicodeSets];
    ok = all(flags) and pattern.sticky and pattern.hasIndices;
    return f"{d.toUTCString()} {ms + day + clock + d.getUTCDay()} {ok}";
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
