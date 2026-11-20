// Python's copy module on a JS host (rt/copy.jac's names): a shallow copy of
// a container or an object, and a deep one. A compiled module imports it as
// it uses it.
import { Obj, Dict, PySet, FrozenSet, Tuple, ByteArray, id } from "../core.js";

// An object's own copy: a new one of its class, its fields `fill`ed.
function remake(x, fill) {
    const o = Object.create(Object.getPrototypeOf(x));
    for (const k of Object.keys(x)) o[k] = fill(x[k]);
    return o;
}

// A shallow copy: a new list, dict, set or object holding what `x` holds.
export function copy(x) {
    if (x instanceof Obj && typeof x.__copy__ === "function") return x.__copy__();
    if (x instanceof Tuple || x instanceof FrozenSet || typeof x !== "object" || x === null) return x;
    if (Array.isArray(x)) return x.slice();
    if (x instanceof Dict) return new Dict(x);
    if (x instanceof PySet) return new PySet(x);
    if (x instanceof ByteArray) return new ByteArray(x.b);
    if (x instanceof Obj) return remake(x, (v) => v);
    return x;
}

// A deep copy: each container and object copied, once however often it's
// reached, what's immutable kept. `memo` is Python's: a dict of the id of
// each one copied to its copy, which a class's __deepcopy__ is given (and
// passes on to the copies it makes) and which then has what it returns.
export function deepcopy(x, memo) {
    if (typeof x !== "object" || x === null) return x;
    if (memo === undefined || memo === null) memo = new Dict();
    const key = id(x);
    if (memo.has(key)) return memo.get(key);
    let out;
    if (x instanceof Obj && typeof x.__deepcopy__ === "function") { out = x.__deepcopy__(memo); }
    else if (x instanceof Tuple) { out = Tuple.from(x, (v) => deepcopy(v, memo)); }
    else if (Array.isArray(x)) { out = []; memo.set(key, out); for (const v of x) out.push(deepcopy(v, memo)); return out; }
    else if (x instanceof Dict) { out = new Dict(); memo.set(key, out); for (const [k, v] of x) out.set(deepcopy(k, memo), deepcopy(v, memo)); return out; }
    else if (x instanceof FrozenSet) { out = new FrozenSet(Array.from(x, (v) => deepcopy(v, memo))); }
    else if (x instanceof PySet) { out = new PySet(Array.from(x, (v) => deepcopy(v, memo))); }
    else if (x instanceof ByteArray) { out = new ByteArray(x.b); }
    else if (x instanceof Obj) {
        out = Object.create(Object.getPrototypeOf(x));
        memo.set(key, out);
        for (const k of Object.keys(x)) out[k] = deepcopy(x[k], memo);
        return out;
    } else return x;
    memo.set(key, out);
    return out;
}
