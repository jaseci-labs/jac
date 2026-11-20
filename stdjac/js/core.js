// Jac's values and operations on a JS host, which compiled modules
// import as `$j`. js_gen chooses each operation by the types check recorded,
// so a helper takes values of the types its name says; the few that look at
// what a value is (`str`, `eq`, `dyn`, `iter`, ...) serve what is typed `any`
// and what containers hold. None is undefined and JS null is JsNull; an int and
// a float are numbers, an int exact to 2**53 (OverflowError past it); a list is
// an Array, a tuple a Tuple, a dict a Dict (a Map) and a set a PySet (a Set),
// their keys and members compared by value.
const G = globalThis, MAX = 9007199254740991;
// JS's Math, which compiled code reaches here, as no program's name can be.
export const Math = G.Math;

// ---- objects and exceptions
// A Jac class's instance: made blank (`new C()`), then given its fields by
// `$init`, which js_gen writes for each class from its constructor's
// parameters.
export class Obj {
    $init(...a) { this.init(...a); return this; }
    static $new(...a) { return new this().$init(...a); }
    static get __name__() { return this.$name || this.name; }
    // An instance of a class whose later bases JS doesn't extend is still theirs.
    static [Symbol.hasInstance](x) {
        const own = G.Function.prototype[Symbol.hasInstance];
        return own.call(this, x) || (own.call(Obj, x) && !!x.constructor.$mro && x.constructor.$mro.includes(this));
    }
}
Obj.$cls = true;
// A Jac struct: a value held in place. Each variable and field holding
// one holds an instance of its own, so the compiler copies it (`copy`) where
// the language copies a value; what changes one changes that instance, the
// place itself. One an any holds is a copy behind `boxed` (`box`): its fields
// not set and its methods that change it (`$mut`) not found, as native code's.
// `==` compares fields, each as `eq` does (a NaN equal to nothing, itself
// among them), and `hash` hashes them as a tuple of them.
export class Struct extends Obj {
    __eq__(o) {
        if (!(o instanceof Struct) || o.constructor !== this.constructor) return false;
        return fieldsOf(this.constructor).every(([f]) => eq(this[f], o[f]));
    }
    __hash__() { return hash(Tuple.from(fieldsOf(this.constructor).map(([f]) => this[f]))); }
}
const absent = (t, k) => raise(AttributeError, "'" + typeName(t) + "' object has no attribute '" + String(k) + "'");
const mutating = (t, k) => typeof k === "string" && t.constructor.$mut.includes(k);
const boxed = {
    get(t, k, r) { return mutating(t, k) ? absent(t, k) : Reflect.get(t, k, r); },
    has(t, k) { return !mutating(t, k) && k in t; },
    set(t, k) { return absent(t, k); },
    deleteProperty(t, k) { return absent(t, k); },
    defineProperty(t, k) { return absent(t, k); },
};
// A Jac array: a value held in place, of a fixed length, as a
// list of its elements. Each variable, field and element holding one holds an
// instance of its own, so the compiler copies it (`copy`) where the language
// copies a value. An element is read and written at an index of the array's,
// from 0 (`arr_at`, `arr_set`: IndexError for any other, a negative one among
// them, as native code's); `==` compares elements, each as `eq` does (a NaN
// equal to nothing, itself among them), and `hash` hashes them as a tuple of
// them. An any holds a copy as a list (`box`), as native code boxes one.
export class JArray extends Array {
    __eq__(o) {
        if (!Array.isArray(o) || o instanceof Tuple || o.length !== this.length) return false;
        for (let i = 0; i < this.length; i++) if (!eq(this[i], o[i])) return false;
        return true;
    }
    __hash__() { return hash(Tuple.from(this)); }
}
const valued = (x) => x instanceof Struct || x instanceof JArray;
// `array[T, n](...)`: no value, each element `zero()`; one value, each element
// a copy of it; or n values, in order.
export function array(n, zero, ...vals) {
    if (vals.length === 0) return JArray.from({ length: n }, zero);
    if (vals.length === 1) return JArray.from({ length: n }, () => (valued(vals[0]) ? copy(vals[0]) : vals[0]));
    return JArray.from(vals);
}
const arrIndex = (a, i) => { if (!(i >= 0 && i < a.length)) raise(IndexError, "array index out of range"); return i; };
export const arr_at = (a, i) => a[arrIndex(a, i)];
export const arr_set = (a, i, v) => { a[arrIndex(a, i)] = v; };
export function copy(v) {
    if (v instanceof JArray) return JArray.from(v, (x) => (valued(x) ? copy(x) : x));
    const C = v.constructor, c = new C();
    for (const [f] of fieldsOf(C)) { const x = v[f]; c[f] = valued(x) ? copy(x) : x; }
    return c;
}
// A generic class's value going where it is held: a struct's record copied,
// anything else itself (the compiler's CV_TCOPY).
export function vcopy(v) { return v instanceof Struct ? copy(v) : v; }
const boxes = new WeakSet();
export function box(v) {
    if (v instanceof JArray) return Array.from(v, (x) => (valued(x) ? box(x) : x));
    const C = v.constructor, c = new C();
    for (const [f] of fieldsOf(C)) { const x = v[f]; c[f] = valued(x) ? box(x) : x; }
    const b = new Proxy(c, boxed);
    boxes.add(b);
    return b;
}
// What is read through an any (getattr, callattr, an item): a struct, a copy
// as an any holds it.
export const held = (v) => (valued(v) ? box(v) : v);
// Function `f`, given structs as the runtime's words (a key function's
// elements): each struct argument a copy of its own.
export const own_args = (f) => (...a) => f(...a.map((x) => (valued(x) ? copy(x) : x)));
// A new list of structs made of another's elements (a slice, a concatenation,
// a copy), or a new dict of struct values made of another's (a copy, a
// merge): each a copy of its own.
export function items(xs) {
    if (!(xs instanceof Map)) return xs.map(copy);
    const d = new Dict();
    for (const [k, v] of xs) d.set(k, copy(v));
    return d;
}
// A list of structs repeated `n` times in place (`xs *= n`), each repetition a copy.
export function repeat_in(xs, n) {
    const r = [];
    for (let k = 0; k < n; k++) for (const x of xs) r.push(copy(x));
    xs.length = 0;
    xs.push(...r);
    return xs;
}
// A struct parameter's argument: a copy of its own when it came as an any
// holds one (a call through an any, JavaScript's code); an array parameter's
// (of descriptor `k`), the array that list is made of.
export const own = (v, k) => (boxes.has(v) ? copy(v) : k !== undefined && !(v instanceof JArray) ? as_(v, k) : v);
// A struct written over the caller's a `&mut` parameter is, field by field.
export function overwrite(p, v) { for (const [f] of fieldsOf(p.constructor)) p[f] = v[f]; }
// A runtime class (an exception's) made with the fields a call gave, by name.
export function make(C, fields) { const o = new C(); for (const k of G.Object.keys(fields)) o[k] = fields[k]; return o; }
// A class of several bases: each method its method resolution order finds.
export function mro(C, order) {
    C.$mro = order;
    const seen = new Set(G.Object.getOwnPropertyNames(C.prototype));
    for (const B of order.slice(1)) {
        for (let p = B.prototype; p && p !== Obj.prototype && p !== G.Object.prototype; p = G.Object.getPrototypeOf(p)) {
            for (const k of G.Object.getOwnPropertyNames(p)) {
                if (k === "constructor" || seen.has(k)) continue;
                seen.add(k);
                G.Object.defineProperty(C.prototype, k, G.Object.getOwnPropertyDescriptor(p, k));
            }
        }
    }
}
// super in class C of an instance `o`: the method `name` of the class after
// C in o's class's method resolution order.
export function super_(o, C, name) {
    const order = o.constructor.$mro;
    if (order) { for (const B of order.slice(order.indexOf(C) + 1)) if (G.Object.prototype.hasOwnProperty.call(B.prototype, name)) return B.prototype[name]; }
    return G.Object.getPrototypeOf(C.prototype)[name];
}
// An argument a call through a value left out, before one it gave: its
// parameter takes its default.
export const NA = Symbol("no argument");
// A closure's defaults, made where it was made, its parameters (as `$p` is a
// def's) and the name its errors give it.
export function keep(f, d, names, q) { f.$d = d; f.$p = names; f.$q = q; return f; }
export function named(f, names, q) { f.$p = names; f.$q = q; return f; }
// A closure that is a method of the object it keeps last, read off an object
// whose class the program names (`o.m`): its errors count the object, as
// those of one read by name do (bound_method).
export function method(f, d, names, q) { keep(f, d, names, q); f.$self = d[d.length - 1]; f.$name = q.slice(q.lastIndexOf(".") + 1); return f; }
// A function value that takes more positional arguments than `f` has
// positional parameters (`k`): those past them are its *args. A call through
// an any binds by `f`'s own parameters.
export function packed(f, k) { const g = function (...a) { return f.call(this, ...a.slice(0, k), a.slice(k)); }; g.$p = f.$p; g.$q = f.$q; g.$b = f; return g; }
const nameList = (ns) => (ns.length === 1 ? "'" + ns[0] + "'" : ns.slice(0, -1).map((n) => "'" + n + "'").join(", ") + (ns.length > 2 ? "," : "") + " and '" + ns[ns.length - 1] + "'");
// A function called as a Callable, by position, whose keyword-only parameters
// `names` have no default: CPython's TypeError.
export function missing_kw(fname, names) { raise(TypeError, fname + "() missing " + names.length + " required keyword-only argument" + (names.length === 1 ? "" : "s") + ": " + nameList(names)); }
// A `**` spread's keys checked against the callee's parameters, as CPython's messages say.
export function rt_check_kwargs(keys, accepted, taken, need_pos, need_kw, open, fname) {
    for (const k of keys) {
        if (taken.includes(k)) raise(TypeError, fname + "() got multiple values for argument '" + k + "'");
        if (!open && !accepted.includes(k)) raise(TypeError, fname + "() got an unexpected keyword argument '" + k + "'");
    }
    for (const [need, kind] of [[need_pos, "positional"], [need_kw, "keyword-only"]]) {
        const missing = need.filter((n) => !keys.includes(n));
        if (missing.length) raise(TypeError, fname + "() missing " + missing.length + " required " + kind + " argument" + (missing.length === 1 ? "" : "s") + ": " + nameList(missing));
    }
}
// A `*` spread's count checked against the callee's parameters: `n` given,
// after `fixed` written ones, of `npos` positional parameters (`ndflt`
// defaulted) named `names`, the first `required` needing one; `cap` how many
// it may fill, -1 when *args takes the rest.
export function rt_check_args(n, fixed, npos, ndflt, names, required, cap, fname) {
    const given = fixed + n;
    if (cap >= 0 && n > cap) raise(TypeError, fname + "() takes " + (ndflt ? "from " + (npos - ndflt) + " to " + npos : npos) + " positional argument" + (npos === 1 && !ndflt ? "" : "s") + " but " + given + (given === 1 ? " was" : " were") + " given");
    const missing = names.slice(given, required);
    if (missing.length) raise(TypeError, fname + "() missing " + missing.length + " required positional argument" + (missing.length === 1 ? "" : "s") + ": " + nameList(missing));
}
// What `glob x: T;` holds until it's assigned; reading it then is a NameError.
export const UNBOUND = Symbol("unbound");
export function bound(v, name) { if (v === UNBOUND) raise(NameError, "name '" + name + "' is not defined"); return v; }
// A Jac exception: an Error, so a JS host gives it a stack. That stack is all
// a JS host keeps of the calls it passed through: its __traceback__ is None.
export class BaseException extends Error {
    constructor() { super(); this.message = ""; this.__cause__ = undefined; this.__traceback__ = undefined; this.args = new Tuple(); }
    static $new(...a) { return exc(this, ...a); }
    static get __name__() { return this.$name || this.name; }
    $init(...a) { this.init(...a); return this; }
    __str__() { return this.message; }
}
BaseException.$cls = true;
// Each of the runtime's exception classes (rt/core.jac), under its base.
const EXC = "Exception:BaseException ArithmeticError:Exception OverflowError:ArithmeticError ZeroDivisionError:ArithmeticError FloatingPointError:ArithmeticError AssertionError:Exception LookupError:Exception IndexError:LookupError KeyError:LookupError RuntimeError:Exception NotImplementedError:RuntimeError RecursionError:RuntimeError TypeError:Exception ValueError:Exception UnicodeError:ValueError UnicodeDecodeError:UnicodeError UnicodeEncodeError:UnicodeError StopIteration:Exception StopAsyncIteration:Exception EOFError:Exception SystemExit:BaseException KeyboardInterrupt:BaseException GeneratorExit:BaseException AttributeError:Exception ImportError:Exception ModuleNotFoundError:ImportError MemoryError:Exception NameError:Exception UnboundLocalError:NameError OSError:Exception FileNotFoundError:OSError FileExistsError:OSError PermissionError:OSError TimeoutError:OSError ConnectionError:OSError SystemError:Exception ReferenceError:Exception BufferError:Exception Warning:Exception UserWarning:Warning DeprecationWarning:Warning PendingDeprecationWarning:Warning SyntaxWarning:Warning RuntimeWarning:Warning FutureWarning:Warning ImportWarning:Warning UnicodeWarning:Warning BytesWarning:Warning ResourceWarning:Warning EncodingWarning:Warning";
const excs = { BaseException };
for (const pair of EXC.split(" ")) {
    const [name, base] = pair.split(":");
    excs[name] = { [name]: class extends excs[base] {} }[name];
}
export const { Exception, ArithmeticError, OverflowError, ZeroDivisionError, FloatingPointError, AssertionError, LookupError, IndexError, KeyError, RuntimeError, NotImplementedError, RecursionError, TypeError, ValueError, UnicodeError, UnicodeDecodeError, UnicodeEncodeError, StopIteration, StopAsyncIteration, EOFError, SystemExit, KeyboardInterrupt, GeneratorExit, AttributeError, ImportError, ModuleNotFoundError, MemoryError, NameError, UnboundLocalError, OSError, FileNotFoundError, FileExistsError, PermissionError, TimeoutError, ConnectionError, SystemError, ReferenceError, BufferError, Warning, UserWarning, DeprecationWarning, PendingDeprecationWarning, SyntaxWarning, RuntimeWarning, FutureWarning, ImportWarning, UnicodeWarning, BytesWarning, ResourceWarning, EncodingWarning } = excs;
// Several exceptions raised together, with a message.
export class ExceptionGroup extends Exception {
    init(message, exceptions) { this.message = message; this.exceptions = exceptions; this.args = tup(message, exceptions); }
    __str__() { const n = this.exceptions.length; return this.message + " (" + n + " sub-exception" + (n === 1 ? "" : "s") + ")"; }
}
ExceptionGroup.$name = "ExceptionGroup";
// An exception of class `C` made with `args`, its message their text, as
// Python's are.
export function exc(C, ...args) { const e = new C(); e.args = Tuple.from(args); return exc_args(e); }
// An exception's message from its args (check's construct, n.dk 16).
export function exc_args(e) {
    const a = e.args;
    if (e instanceof OSError && a.length >= 2 && a.length <= 5) {
        // As CPython's (and rt/core.jac's OSError.init): two to five are its
        // errno, strerror, filename, winerror (ignored off Windows) and
        // filename2, its args the first two and its message `[Errno e] s`,
        // with `: 'f'` for a filename and ` -> 'f2'` for a second.
        e.errno = a[0];
        e.strerror = a[1];
        let shown = "[Errno " + str(a[0]) + "] " + str(a[1]);
        if (a.length >= 3 && a[2] !== undefined) {
            e.filename = a[2];
            shown += ": " + repr(a[2]);
            if (a.length === 5 && a[4] !== undefined) {
                e.filename2 = a[4];
                shown += " -> " + repr(a[4]);
            }
        }
        e.args = Tuple.from([a[0], a[1]]);
        e.message = shown;
        return e;
    }
    e.message = a.length === 0 ? "" : a.length === 1 ? (e instanceof KeyError ? repr(a[0]) : str(a[0])) : repr(a);
    return e;
}
// One of the runtime's exceptions as a call makes it: its positional arguments
// its args, its message their text, and the fields the call named.
export function exc_made(C, args, fields) { const e = exc(C, ...args); for (const k of G.Object.keys(fields)) e[k] = fields[k]; return e; }
// `raise e from c`.
export function cause(e, c) { e.__cause__ = c; return e; }
// What a JS host threw, as the Jac exception a handler tests for.
export function caught(e) {
    if (e instanceof BaseException) return e;
    if (e instanceof G.RangeError && /call stack/.test(e.message)) return exc(RecursionError, "maximum recursion depth exceeded");
    const C = e instanceof G.TypeError ? TypeError : e instanceof G.RangeError ? ValueError : RuntimeError;
    const j = exc(C, e && e.message !== undefined ? e.message : String(e));
    j.js = e;
    return j;
}
const raise = (C, ...a) => { throw exc(C, ...a); };

// An obj's fields in order, each [name, its type's descriptor].
const fieldsOf = (c) => c.$fields || [];

// ---- numbers: an int is a safe integer, a float any number
export function ovf(r) { if (r > MAX || r < -MAX) raise(OverflowError, "integer overflow"); return r; }
export const add_i = (a, b) => ovf(a + b);
export const sub_i = (a, b) => ovf(a - b);
export const mul_i = (a, b) => ovf(a * b);
export function floordiv_i(a, b) {
    if (b === 0) raise(ZeroDivisionError, "integer division or modulo by zero");
    const r = a % b, q = (a - r) / b;
    return r !== 0 && (r < 0) !== (b < 0) ? q - 1 : q;
}
export function mod_i(a, b) {
    if (b === 0) raise(ZeroDivisionError, "integer modulo by zero");
    const r = a % b;
    return r !== 0 && (r < 0) !== (b < 0) ? r + b : r;
}
export function div(a, b) { if (b === 0) raise(ZeroDivisionError, "division by zero"); return a / b; }
export function floordiv_f(a, b) { if (b === 0) raise(ZeroDivisionError, "float floor division by zero"); return Math.floor(a / b); }
export function mod_f(a, b) {
    if (b === 0) raise(ZeroDivisionError, "float modulo");
    const r = a % b;
    return r !== 0 && (r < 0) !== (b < 0) ? r + b : r;
}
export function pow_i(a, b) {
    if (b < 0) { if (a === 0) raise(ZeroDivisionError, "0.0 cannot be raised to a negative power"); return a ** b; }
    let r = 1;
    for (;;) { if (b & 1) r = ovf(r * a); b = Math.floor(b / 2); if (!b) return r; a = ovf(a * a); }
}
export function pow_f(a, b) {
    if (a === 0 && b < 0) raise(ZeroDivisionError, "0.0 cannot be raised to a negative power");
    const r = a ** b;
    if (Number.isNaN(r) && !Number.isNaN(a) && !Number.isNaN(b)) raise(ValueError, "math domain error");
    return r;
}
// Bit operations on ints past 32 bits, through BigInt.
export const and_i = (a, b) => ((a | 0) === a && (b | 0) === b ? a & b : Number(BigInt(a) & BigInt(b)));
export const or_i = (a, b) => ((a | 0) === a && (b | 0) === b ? a | b : Number(BigInt(a) | BigInt(b)));
export const xor_i = (a, b) => ((a | 0) === a && (b | 0) === b ? a ^ b : Number(BigInt(a) ^ BigInt(b)));
export const inv_i = (a) => -a - 1;
export function shl_i(a, b) { if (b < 0) raise(ValueError, "negative shift count"); return b > 53 && a !== 0 ? raise(OverflowError, "integer overflow") : ovf(a * 2 ** b); }
export function shr_i(a, b) { if (b < 0) raise(ValueError, "negative shift count"); return b > 53 ? (a < 0 ? -1 : 0) : Math.floor(a / 2 ** b); }
// A sized int: `v` checked to fit `w` bits (OverflowError), or wrapped into them;
// an i64's or a u64's BigInt made a number of the narrower type.
export function fit(v, w, unsigned) {
    const lo = unsigned ? 0 : -(2 ** (w - 1)), hi = unsigned ? 2 ** w - 1 : 2 ** (w - 1) - 1;
    if (v < lo || v > hi) raise(OverflowError, "integer overflow");
    return typeof v === "bigint" ? Number(v) : v;
}
export function wrap(v, w, unsigned) { const b = unsigned ? BigInt.asUintN(w, BigInt(v)) : BigInt.asIntN(w, BigInt(v)); return Number(b); }
// `a op b` (op "+", "-", "*", "<<", or "neg" of `a`) of ints of `w` bits,
// wrapped into them: to 32 bits in a JS number's own arithmetic (exact, and
// Math.imul's low bits of a product), an int's 64 through BigInt.
export function wrap_op(op, a, b, w, unsigned) {
    if (w > 32) {
        const x = BigInt(a), y = op === "neg" ? 0n : BigInt(b);
        const r = op === "+" ? x + y : op === "-" ? x - y : op === "*" ? x * y : op === "<<" ? x << (y & 63n) : -x;
        return Number(unsigned ? BigInt.asUintN(w, r) : BigInt.asIntN(w, r));
    }
    const r = op === "+" ? a + b : op === "-" ? a - b : op === "*" ? Math.imul(a, b) : op === "<<" ? a << (b & (w - 1)) : -a;
    if (w === 32) return unsigned ? r >>> 0 : r | 0;
    const s = 32 - w;
    return unsigned ? r & ((1 << w) - 1) : (r << s) >> s;
}
// `a op b` (op "+", "-" or "*") of ints of `w` bits, stopped at their least
// and greatest: to 32 bits a JS number's result, exact where it is in the
// range and past the same end where it is not; an int's 64 through BigInt.
export function sat_op(op, a, b, w, unsigned) {
    if (w > 32) {
        const x = BigInt(a), y = BigInt(b), r = op === "+" ? x + y : op === "-" ? x - y : x * y;
        return Number(r < -W63 ? -W63 : r >= W63 ? W63 - 1n : r);
    }
    const lo = unsigned ? 0 : -(2 ** (w - 1)), hi = unsigned ? 2 ** w - 1 : 2 ** (w - 1) - 1;
    const r = op === "+" ? a + b : op === "-" ? a - b : a * b;
    return r < lo ? lo : r > hi ? hi : r;
}
// i64, u64, i128 and u128: BigInts, range-checked as every sized type is
//. Each helper takes the type by its name, `k`: its width and
// signedness, and so its least and greatest.
const WIDE = {};
for (const w of [64, 128]) {
    const half = 1n << BigInt(w - 1);
    WIDE["i" + w] = { w, u: false, lo: -half, hi: half - 1n };
    WIDE["u" + w] = { w, u: true, lo: 0n, hi: 2n * half - 1n };
}
export function fit_w(v, k) {
    const t = WIDE[k];
    if (v < t.lo || v > t.hi) raise(OverflowError, "integer overflow");
    return v;
}
// An int, a bool or a narrower sized int as a wide one (which it fits).
export const big = (x) => BigInt(x);
// A wide int as an int: exact to ±2**53, past which it traps.
export const small = (x) => ovf(Number(x));
// A wide int as a float, rounded to the nearest.
export const float_w = (x) => Number(x);
// A float truncated toward zero to wide type `k`, where the type holds it.
export function big_of_float(x, k) {
    if (Number.isNaN(x)) raise(ValueError, "cannot convert float NaN to integer");
    if (!Number.isFinite(x)) raise(OverflowError, "integer overflow");
    return fit_w(BigInt(Math.trunc(x)), k);
}
// A value taken out of an `any` as wide type `k`: an int, a bool or a wide int.
export function as_w(v, k) {
    if (typeof v === "bigint") return fit_w(v, k);
    return fit_w(BigInt(as_(v, "i")), k);
}
export const wrap_w = (v, k) => (WIDE[k].u ? BigInt.asUintN(WIDE[k].w, BigInt(v)) : BigInt.asIntN(WIDE[k].w, BigInt(v)));
export function wrap_op_w(op, a, b, k) {
    const x = BigInt(a), y = op === "neg" ? 0n : BigInt(b);
    const r = op === "+" ? x + y : op === "-" ? x - y : op === "*" ? x * y : op === "<<" ? x << (y & BigInt(WIDE[k].w - 1)) : -x;
    return wrap_w(r, k);
}
// `a op b` of two wide ints of type `k` stopped at its least and greatest.
export function sat_op_w(op, a, b, k) {
    const r = op === "+" ? a + b : op === "-" ? a - b : a * b, t = WIDE[k];
    return r < t.lo ? t.lo : r > t.hi ? t.hi : r;
}
// `a op b` of two wide ints of type `k`, as native code computes it.
export function word(op, a, b, k) {
    const w = BigInt(WIDE[k].w);
    switch (op) {
        case "+": return fit_w(a + b, k);
        case "-": return fit_w(a - b, k);
        case "*": return fit_w(a * b, k);
        case "//": case "%": {
            if (b === 0n) raise(ZeroDivisionError, op === "//" ? "integer division or modulo by zero" : "integer modulo by zero");
            let q = a / b, r = a % b;
            if (r !== 0n && (r < 0n) !== (b < 0n)) { q -= 1n; r += b; }
            return op === "//" ? fit_w(q, k) : r;
        }
        case "**":
            if (b < 0n) raise(ValueError, "int ** negative int is a float; convert the base with float()");
            // (Past the width for any base but 0, 1 and -1, before it is made.)
            if (b > w && (a > 1n || a < -1n)) raise(OverflowError, "integer overflow");
            return fit_w(a ** b, k);
        case "<<": case ">>":
            if (b < 0n || b >= w) raise(OverflowError, "integer overflow");
            return op === "<<" ? fit_w(a << b, k) : a >> b;
        case "&": return a & b;
        case "|": return a | b;
        case "^": return a ^ b;
    }
    raise(TypeError, "unsupported operand for a " + k + ": " + op);
}
export const neg_w = (a, k) => fit_w(-a, k);
export const abs_w = (a, k) => fit_w(a < 0n ? -a : a, k);
export const inv_w = (a, k) => wrap_w(~a, k);
// A value taken as type `k` wants it, as CPython's _jac.convert takes it (and
// native code's rt_convert): `k` is "i" int, "f" float, "s" str, "b" bool,
// "n" None, a class, a container's ["l", e], ["t", e1, ...], ["t*", e],
// ["d", kd, vd], ["set", e] or ["fs", e], or a union's ["|", k1, ...]; 0 is
// anything. A number widens, a bool counts as an int; a container is the
// same one when none of its items changes and a new one, of its kind, when
// any does: its operand never changes. Anything else is a TypeError, but a
// dynamic class's instance, which is taken as the value it stands for.
const MISS = Symbol("miss");
function fits(v, k) {
    if (!k) return v;
    if (typeof k === "string") {
        switch (k) {
            // (A u64 an any holds is a BigInt: an int of it traps past ±2**53.)
            case "i": return Number.isInteger(v) ? v : typeof v === "boolean" ? Number(v) : typeof v === "bigint" ? small(v) : v instanceof Obj && typeof v.__index__ === "function" ? v.__index__() : MISS;
            case "f": return typeof v === "number" ? v : typeof v === "boolean" || typeof v === "bigint" ? Number(v) : v instanceof Obj && typeof v.__float__ === "function" ? v.__float__() : MISS;
            case "s": return typeof v === "string" || v === undefined ? v : MISS;
            case "b": return typeof v === "boolean" ? v : MISS;
            case "n": return v === undefined ? v : MISS;
        }
        return MISS;
    }
    if (typeof k === "function") return v === undefined || v instanceof k ? v : MISS;
    const head = k[0];
    if (head === "|") {
        for (let n = 1; n < k.length; n++) { const got = fits(v, k[n]); if (got !== MISS) return got; }
        return MISS;
    }
    if (head === "z") { const x = fits(v, "i"); return x === MISS ? MISS : fit(x, k[1], k[2]); }
    if (head === "W") return as_w(v, k[1]);
    if (v === undefined) return v;
    if (head === "a") {
        // An array arriving from an any: a list of as many elements, each
        // converted to its element type, a copy of its own.
        if (!Array.isArray(v) || v instanceof Tuple) return MISS;
        if (v.length !== k[1]) raise(ValueError, "expected " + k[1] + " items, found " + v.length);
        return JArray.from(v, (x) => { const y = as_(x, k[2]); return y instanceof Struct ? copy(y) : y; });
    }
    if (head === "d") {
        if (!(v instanceof Map)) return MISS;
        let same = true;
        const pairs = Array.from(v, ([a, b]) => { const x = as_(a, k[1]), y = as_(b, k[2]); if (x !== a || y !== b) same = false; return [x, y]; });
        return same ? v : dict_of(pairs);
    }
    if (head === "set" || head === "fs") {
        if (!(v instanceof Set) || (head === "fs") !== (v instanceof FrozenSet)) return MISS;
        let same = true;
        const items = Array.from(v, (x) => { const y = as_(x, k[1]); if (y !== x) same = false; return y; });
        return same ? v : head === "fs" ? frozen_of(items) : set_of(items);
    }
    const tuple = head === "t" || head === "t*";
    if (!Array.isArray(v) || (v instanceof Tuple) !== tuple) return MISS;
    if (head === "t" && v.length !== k.length - 1) return MISS;
    let same = true;
    const items = v.map((x, n) => { const y = as_(x, head === "t" ? k[n + 1] : k[1]); if (y !== x) same = false; return y; });
    return same ? v : tuple ? Tuple.from(items) : items;
}
const kindName = (k) => (typeof k === "string" ? { i: "int", f: "float", s: "str", b: "bool", n: "None" }[k] : typeof k === "function" ? k.$name || k.name : k[0] === "|" ? k.slice(1).map(kindName).join(" | ") : { l: "list", a: "list", z: "int", W: "int", t: "tuple", "t*": "tuple", d: "dict", set: "set", fs: "frozenset" }[k[0]]);
export function as_(v, k) {
    const got = fits(v, k);
    if (got !== MISS) return got;
    if (v instanceof Obj && typeof v.__jac_value__ === "function") { const jv = v.__jac_value__(); if (jv !== v) return as_(jv, k); }
    raise(TypeError, "expected " + kindName(k) + ", found " + (v === undefined ? "None" : typeName(v)));
}
// A complex number.
export class Complex extends Obj {
    constructor(re = 0, im = 0) { super(); this.real = re; this.imag = im; }
    static $name = "complex";
    __add__(o) { const [a, b] = parts(o); return new Complex(this.real + a, this.imag + b); }
    __radd__(o) { return this.__add__(o); }
    __sub__(o) { const [a, b] = parts(o); return new Complex(this.real - a, this.imag - b); }
    __rsub__(o) { const [a, b] = parts(o); return new Complex(a - this.real, b - this.imag); }
    __mul__(o) { const [a, b] = parts(o); return new Complex(this.real * a - this.imag * b, this.real * b + this.imag * a); }
    __rmul__(o) { return this.__mul__(o); }
    __truediv__(o) { const [a, b] = parts(o), d = a * a + b * b; if (d === 0) raise(ZeroDivisionError, "division by zero"); return new Complex((this.real * a + this.imag * b) / d, (this.imag * a - this.real * b) / d); }
    __neg__() { return new Complex(-this.real, -this.imag); }
    __pos__() { return this; }
    __abs__() { return Math.hypot(this.real, this.imag); }
    __bool__() { return this.real !== 0 || this.imag !== 0; }
    __eq__(o) { const [a, b] = parts(o); return a === this.real && b === this.imag; }
    __hash__() { return this.imag === 0 ? hash(this.real) : hash(tup(this.real, this.imag)); }
    __repr__() { const f = (x) => fstr(x).replace(/\.0$/, ""); return this.real === 0 && !Object.is(this.real, -0) ? f(this.imag) + "j" : "(" + f(this.real) + (this.imag < 0 || Object.is(this.imag, -0) ? "" : "+") + f(this.imag) + "j)"; }
    conjugate() { return new Complex(this.real, -this.imag); }
}
const parts = (o) => (o instanceof Complex ? [o.real, o.imag] : [Number(o), 0]);
// complex() as CPython 3.15 makes it. Of one positional argument (core's
// rt_complex_of): a str parsed; a complex, what an object's __complex__
// gives, or a real number. Of `real` and `imag`, or `real` by name alone
// (`givenImag` false; core's rt_complex_parts): `real` a real number, a
// complex or an object with __complex__, `imag` a real number or a complex,
// made real + imag * 1j where a real number's part adds nothing (a -0.0
// imag stays one). Check lowers a call with an any to these, where None is
// undefined too; a typed call is complex()'s, its arguments as js_gen binds
// them.
export function rt_complex_of(real) {
    if (typeof real === "string") return complex_text(real);
    if (!(real instanceof Complex) && !has_hook(real, "__complex__") && !complex_real(real)) raise(TypeError, "complex() argument must be a string or a number, not " + typeName(real));
    return rt_complex_parts(real, 0, false);
}
export function rt_complex_parts(real, imag, givenImag) {
    let r = real;
    if (!(real instanceof Complex) && has_hook(real, "__complex__")) r = real.__complex__();
    if (!(r instanceof Complex) && !complex_real(r)) raise(TypeError, "complex() argument 'real' must be a real number, not " + typeName(r));
    if (givenImag && !(imag instanceof Complex) && !complex_real(imag)) raise(TypeError, "complex() argument 'imag' must be a real number, not " + typeName(imag));
    const whole = r instanceof Complex;
    let re = whole ? r.real : real_of(r);
    if (!givenImag) return new Complex(re, whole ? r.imag : 0);
    let im;
    if (imag instanceof Complex) { im = imag.real; re -= imag.imag; } else im = real_of(imag);
    return new Complex(re, whole ? im + r.imag : im);
}
export const complex = (...a) => (a.length === 0 ? new Complex(0, 0) : a.length === 1 ? rt_complex_of(a[0]) : rt_complex_parts(a[0], a[1], true));
const has_hook = (x, name) => x instanceof Obj && typeof x[name] === "function";
const complex_real = (x) => typeof x === "number" || typeof x === "boolean" || typeof x === "bigint" || has_hook(x, "__float__") || has_hook(x, "__index__");
const real_of = (x) => (typeof x === "bigint" ? Number(x) : float(x));
// A complex's text as complex() reads it, CPython's grammar: a real part, an
// imaginary one (j alone is 1j) or both, signed, in parentheses or not, with
// spaces only around them.
const CNUM = "(?:(?:\\d(?:_?\\d)*(?:\\.(?:\\d(?:_?\\d)*)?)?|\\.\\d(?:_?\\d)*)(?:e[+-]?\\d(?:_?\\d)*)?|inf(?:inity)?|nan)";
const COMPLEX_TEXT = new RegExp("^(?:([+-]?" + CNUM + ")|([+-]?)(" + CNUM + ")?j|([+-]?" + CNUM + ")([+-])(" + CNUM + ")?j)$", "i");
function complex_text(s) {
    let t = s.trim();
    if (t.startsWith("(") && t.endsWith(")")) t = t.slice(1, -1).trim();
    const m = COMPLEX_TEXT.exec(t);
    if (m === null) raise(ValueError, "complex() arg is a malformed string");
    const imag = (sign, digits) => (sign === "-" ? -1 : 1) * (digits === undefined ? 1 : float(digits));
    if (m[1] !== undefined) return new Complex(float(m[1]), 0);
    if (m[4] === undefined) return new Complex(0, imag(m[2], m[3]));
    return new Complex(float(m[4]), imag(m[5], m[6]));
}
// isinstance(x, T) of a builtin type, by check's ISA_* code.
export function isa(x, code) {
    switch (code) {
        case 1: return x === undefined;
        case 2: return Number.isInteger(x) || typeof x === "boolean" || typeof x === "bigint";
        case 3: return typeof x === "number" && !Number.isInteger(x);
        case 4: return typeof x === "string";
        case 5: return x instanceof Bytes;
        case 6: return typeof x === "boolean";
        case 7: return Array.isArray(x) && !(x instanceof Tuple);
        case 8: return x instanceof Map;
        case 9: return x instanceof Tuple;
        case 10: return x instanceof Set && !(x instanceof FrozenSet);
        case 11: return x instanceof ByteArray;
        case 12: return x instanceof Complex;
        case 13: return x instanceof FrozenSet;
    }
    return false;
}
export function unary(op, a) {
    if (op === "-") return neg(a);
    if (op === "+") { if (a instanceof Obj && typeof a.__pos__ === "function") return a.__pos__(); return +a; }
    if (a instanceof Obj && typeof a.__invert__ === "function") return a.__invert__();
    return inv_i(a);
}
// A rich comparison whose dunder may give NotImplemented: then identity, for
// == and !=, else a TypeError.
export function cmp_result(r, name, a, b) {
    if (r !== NotImplemented) return r;
    if (name === "__eq__") return a === b;
    if (name === "__ne__") return a !== b;
    raise(TypeError, "'" + name + "' not supported between instances of '" + typeName(a) + "' and '" + typeName(b) + "'");
}
export const abs_ = (x) => Math.abs(x);
export function int_of_float(x) { if (!Number.isFinite(x)) raise(Number.isNaN(x) ? ValueError : OverflowError, "cannot convert float " + fstr(x) + " to integer"); return ovf(Math.trunc(x)); }
// round(x) and round(x, n), halves to even as Python's are.
export function round_(x, n, isInt) {
    if (n === undefined) { if (isInt) return x; const r = Math.round(x); return (Math.abs(x % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r); }
    if (isInt) { if (n >= 0) return x; const f = 10 ** -n, q = x / f, r = Math.round(q); return (Math.abs(q % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r) * f; }
    return Number(x.toFixed(Math.max(0, Math.min(100, n))));
}
// abs(x), round(number) and round(number, ndigits) of a value typed any
// (check's lowering, as native code's rt_abs_of, rt_round_of and rt_round_to):
// a number's own, what an object's __abs__ or __round__ gives (round's of one
// argument an int), Python's TypeError for anything else.
export function rt_abs_of(x) {
    if (typeof x === "number") return Math.abs(x);
    if (typeof x === "boolean") return Number(x);
    if (typeof x === "bigint") return x < 0n ? -x : x;
    if (x instanceof Obj && typeof x.__abs__ === "function") return x.__abs__();
    raise(TypeError, "bad operand type for abs(): '" + typeName(x) + "'");
}
const unrounded = (x) => raise(TypeError, "type " + typeName(x) + " doesn't define __round__ method");
export function rt_round_of(number) {
    if (typeof number === "number") return round_(number, undefined, Number.isInteger(number));
    if (typeof number === "boolean" || typeof number === "bigint") return as_(number, "i");
    if (number instanceof Obj && typeof number.__round__ === "function") return as_(number.__round__(), "i");
    unrounded(number);
}
export function rt_round_to(number, ndigits) {
    if (typeof number === "boolean" || typeof number === "bigint") number = as_(number, "i");
    if (typeof number === "number") return round_(number, ndigits, Number.isInteger(number));
    if (number instanceof Obj && typeof number.__round__ === "function") return number.__round__(ndigits);
    unrounded(number);
}

// ---- the containers
// A tuple: an Array that prints, compares and hashes as a tuple.
export class Tuple extends Array { static get [Symbol.species]() { return Tuple; } }
export const tup = (...a) => Tuple.from(a);
// A dict: a Map whose keys compare by value (1, 1.0 and True are one key; a
// tuple is equal to an equal tuple).
export class Dict extends Map {
    // The key `k` is stored under: itself, unless an equal key is.
    $k(k) { const h = this.$h; if (h === undefined) { if (prim(k)) return k; this.$h = new Map(); return this.$k(k); } return slot(h, k); }
    get(k) { return super.get(this.$k(k)); }
    has(k) { return super.has(this.$k(k)); }
    set(k, v) { const s = this.$k(k); if (this.$h !== undefined) remember(this.$h, s); return super.set(s, v); }
    delete(k) { const s = this.$k(k); if (this.$h !== undefined) forget(this.$h, s); return super.delete(s); }
    clear() { if (this.$h !== undefined) this.$h.clear(); super.clear(); }
}
// A set: a Set whose members compare by value, as a Dict's keys do.
export class PySet extends Set {
    $k(k) { const h = this.$h; if (h === undefined) { if (prim(k)) return k; this.$h = new Map(); return this.$k(k); } return slot(h, k); }
    has(k) { return super.has(this.$k(k)); }
    add(k) { const s = this.$k(k); if (this.$h !== undefined) remember(this.$h, s); return super.add(s); }
    delete(k) { const s = this.$k(k); if (this.$h !== undefined) forget(this.$h, s); return super.delete(s); }
    clear() { if (this.$h !== undefined) this.$h.clear(); super.clear(); }
}
export class FrozenSet extends PySet {}
// A key that is its own: a str, an int or a float but -0, None.
const prim = (k) => typeof k === "string" || k === undefined || (typeof k === "number" && !Object.is(k, -0));
// `h` maps each stored key's hash to the stored keys with it.
function slot(h, k) { const c = h.get(hash(k)); if (c) for (const s of c) if (eq(s, k)) return s; return k; }
function remember(h, s) { const x = hash(s), c = h.get(x); if (!c) h.set(x, [s]); else if (!c.includes(s)) c.push(s); }
function forget(h, s) { const x = hash(s), c = h.get(x); if (c) { const i = c.indexOf(s); if (i >= 0) c.splice(i, 1); } }
export function dict_of(pairs) { const d = new Dict(); for (const [k, v] of pairs) d.set(k, v); return d; }
export function set_of(items) { const s = new PySet(); for (const x of items) s.add(x); return s; }
export function frozen_of(items) { const s = new FrozenSet(); for (const x of items) s.add(x); return s; }
// Python's rule: a dict or a set that grows or shrinks under a loop over it
// is not walked on, where JavaScript's iterator goes on into what the loop
// adds, without end. A `for` over one compares how many it holds as each
// turn begins and as the loop ends (js_gen's loop_over), and calls this when
// that changed. (One that keeps its size and changes its keys is walked as
// JavaScript walks it: on, past a key removed and through one added.)
export function resized(c) { raise(RuntimeError, (c instanceof Set ? "Set" : "dictionary") + " changed size during iteration"); }
// The same rule for an iterator held as a value (`iter(d)`, a view's): `it`,
// the container `c`'s own iterator, each step first comparing how many `c`
// holds with how many it held when the walk began. `of` makes each step's
// value of what `it` gives, when it is not that itself.
class Walk {
    constructor(c, it, of) { this.c = c; this.it = it; this.of = of; this.n = c.size; }
    next() {
        if (this.c.size !== this.n) resized(this.c);
        const r = this.it.next();
        return r.done || this.of === undefined ? r : { value: this.of(r.value), done: false };
    }
    [Symbol.iterator]() { return this; }
}
// bytes and bytearray: their bytes.
export class Bytes extends Uint8Array { static get [Symbol.species]() { return Bytes; } }
export class ByteArray { constructor(a) { this.b = Array.from(a || []); } [Symbol.iterator]() { return this.b[Symbol.iterator](); } get length() { return this.b.length; } }
export const bytes_lit = (s) => Bytes.from(s, (c) => c.charCodeAt(0));
const bytesOf = (x) => (x instanceof ByteArray ? x.b : x);
// A range: its start, stop and step, iterated lazily.
export class Range {
    constructor(a, b, s) { if (b === undefined) { b = a; a = 0; } if (s === undefined) s = 1; if (s === 0) raise(ValueError, "range() arg 3 must not be zero"); this.start = a; this.stop = b; this.step = s; }
    get length() { const { start: a, stop: b, step: s } = this; return Math.max(0, s > 0 ? Math.ceil((b - a) / s) : Math.ceil((a - b) / -s)); }
    *[Symbol.iterator]() { const { start: a, stop: b, step: s } = this; if (s > 0) for (let i = a; i < b; i += s) yield i; else for (let i = a; i > b; i += s) yield i; }
}
export const range = (a, b, s) => new Range(a, b, s);
// An enum's member: its name and value; an int enum's members are their ints.
export class Member { constructor(e, name, value) { this.$e = e; this.name = name; this.value = value; } toJSON() { return this.value; } }
export function enum_(E, name, members, intValued) {
    E.$name = name; E.$int = intValued; E.$members = [];
    for (const [k, v] of members) { const m = intValued ? v : new Member(E, k, v); E[k] = m; E.$members.push(m); }
    E[Symbol.iterator] = function* () { yield* E.$members; };
    return E;
}
export function enum_name(E, v) { for (const [k, m] of Object.entries(E)) if (m === v && E.$members.includes(m)) return k; raise(ValueError, repr(v) + " is not a valid " + E.$name); }
export function enum_of(E, v) { for (const m of E.$members) if (eq(E.$int ? m : m.value, v)) return m; raise(ValueError, repr(v) + " is not a valid " + E.$name); }
export function enum_at(E, k) { if (typeof k === "string" && Object.prototype.hasOwnProperty.call(E, k) && E.$members.includes(E[k])) return E[k]; raise(KeyError, k); }

// ---- truth, equality, hashing, order
export function truth(x) {
    if (x === undefined || x === null || x === false || x === 0 || x === 0n || x === "") return false;
    if (typeof x !== "object") return true;
    if (Array.isArray(x) || x instanceof Uint8Array || x instanceof ByteArray) return x.length > 0;
    if (x instanceof Map || x instanceof Set) return x.size > 0;
    if (x instanceof Range) return x.length > 0;
    if (typeof x.__bool__ === "function") return x.__bool__();
    if (typeof x.__len__ === "function") return x.__len__() > 0;
    return true;
}
const graphy = (x) => x instanceof Obj && x.constructor.$identity;
export function eq(a, b) {
    // (A struct equals itself only when its fields do: a NaN's equals nothing.)
    if (a === b && !valued(a)) return true;
    if (typeof a !== "object" || typeof b !== "object" || a === null || b === null) {
        // An i64 or a u64 equals a number or a bool of its value.
        const num = (v) => typeof v === "bigint" || typeof v === "number" || typeof v === "boolean";
        if (typeof a === "bigint" || typeof b === "bigint") return num(a) && num(b) && a == b;
        if (typeof a === "boolean" || typeof b === "boolean") return Number(a) === Number(b) && typeof a !== "string" && typeof b !== "string" && a !== undefined && b !== undefined;
        if (a instanceof Obj && typeof a.__eq__ === "function") return a.__eq__(b);
        if (b instanceof Obj && typeof b.__eq__ === "function") return b.__eq__(a);
        return false;
    }
    if (typeof a.__eq__ === "function") return truth(a.__eq__(b));
    if (typeof b.__eq__ === "function") return truth(b.__eq__(a));
    if (Array.isArray(a) && Array.isArray(b)) return (a instanceof Tuple) === (b instanceof Tuple) && a.length === b.length && a.every((x, i) => eq(x, b[i]));
    if (a instanceof Map && b instanceof Map) { if (a.size !== b.size) return false; for (const [k, v] of a) if (!b.has(k) || !eq(v, b.get(k))) return false; return true; }
    if (a instanceof Set && b instanceof Set) { if (a.size !== b.size) return false; for (const k of a) if (!b.has(k)) return false; return true; }
    if (a instanceof Uint8Array || a instanceof ByteArray) { const x = bytesOf(a), y = bytesOf(b); return y !== undefined && y.length === x.length && Array.prototype.every.call(x, (v, i) => v === y[i]); }
    if (a instanceof Range && b instanceof Range) return a.length === b.length && (a.length === 0 || (a.start === b.start && (a.length === 1 || a.step === b.step)));
    if (a instanceof Obj && b instanceof Obj && !graphy(a) && a.constructor === b.constructor) return fieldsOf(a.constructor).every(([f]) => eq(a[f], b[f]));
    return false;
}
const ids = new WeakMap();
let nextId = 1;
export function id(x) { if (typeof x !== "object" && typeof x !== "function" || x === null) return hash(x); let i = ids.get(x); if (i === undefined) ids.set(x, (i = nextId++)); return i; }
export function hash(x) {
    switch (typeof x) {
        case "undefined": return 0x5f3759df;
        case "boolean": return x ? 1 : 0;
        // An int is its own hash, as Python's is, but -1, which is -2; any other
        // number (an integral float past what an int holds among them), its text's.
        case "number": return Number.isInteger(x) && x <= MAX && x >= -MAX ? (x === -1 ? -2 : x) : hashText(String(x));
        case "string": return hashText(x);
        case "bigint": return hash_w(x);
    }
    if (x === null) return 0x1f3d;
    // An obj compared by its fields with no __hash__ (or whose __eq__ is nearer
    // than its __hash__) is unhashable, as CPython's is (Cls.unhashable); a
    // node, edge or walker, or any other object, is its identity.
    if (x instanceof Obj && x.constructor.$unhashable) raise(TypeError, "unhashable type: '" + typeName(x) + "'");
    if (typeof x.__hash__ === "function") return x.__hash__();
    if (x instanceof Tuple) { let h = 0x345678; for (const v of x) h = (Math.imul(h ^ hash(v), 1000003) | 0); return h; }
    if (x instanceof FrozenSet) { let h = 0; for (const v of x) h ^= hash(v); return h; }
    if (Array.isArray(x) || x instanceof Map || (x instanceof Set && !(x instanceof FrozenSet))) raise(TypeError, "unhashable type: '" + typeName(x) + "'");
    if (x instanceof Uint8Array) return hashText(String.fromCharCode(...x));
    if (x instanceof Member) return hashText(x.$e.$name + "." + x.name);
    return id(x);
}
// An i64's or a u64's: an int's where an int holds it, else Python's (its value
// modulo 2**61 - 1, its sign kept), or the host's own of that past an int.
function hash_w(x) {
    if (x <= BigInt(MAX) && x >= -BigInt(MAX)) return hash(Number(x));
    const M = (1n << 61n) - 1n;
    let h = (x < 0n ? -x : x) % M;
    if (x < 0n) h = h === 1n ? -2n : -h;
    return h <= BigInt(MAX) && h >= -BigInt(MAX) ? Number(h) : hashText(String(h));
}
function hashText(s) { let h = 0; for (let i = 0; i < s.length; i++) h = (Math.imul(h, 31) + s.charCodeAt(i)) | 0; return h; }
// Strings order by code point; JS's `<` orders UTF-16 units.
const unit = (u) => (u >= 0xd800 && u < 0xe000 ? u + 0x2800 : u);
export function cmp_s(a, b) {
    const n = Math.min(a.length, b.length);
    for (let i = 0; i < n; i++) { const x = a.charCodeAt(i), y = b.charCodeAt(i); if (x !== y) return unit(x) < unit(y) ? -1 : 1; }
    return a.length - b.length;
}
// -1, 0 or 1: how `a` orders against `b`, as Python's < does; NaN when they
// are not ordered (a NaN met before the order is decided, sets neither of
// which holds the other), which is neither less, equal nor greater.
export function cmp(a, b) {
    const num = (v) => typeof v === "number" || typeof v === "boolean" || typeof v === "bigint";
    if (num(a)) { if (num(b)) return a < b ? -1 : a > b ? 1 : a == b ? 0 : NaN; }
    else if (typeof a === "string" && typeof b === "string") return Math.sign(cmp_s(a, b));
    else if (Array.isArray(a) && Array.isArray(b) && (a instanceof Tuple) === (b instanceof Tuple)) {
        for (let i = 0; i < Math.min(a.length, b.length); i++) if (!eq(a[i], b[i])) return cmp(a[i], b[i]);
        return Math.sign(a.length - b.length);
    } else if (a instanceof Set && b instanceof Set) return eq(a, b) ? 0 : set_issubset(a, b) ? -1 : set_issubset(b, a) ? 1 : NaN;
    else if ((a instanceof Uint8Array || a instanceof ByteArray) && (b instanceof Uint8Array || b instanceof ByteArray)) return cmp(Array.from(bytesOf(a)), Array.from(bytesOf(b)));
    else if (a instanceof Obj && typeof a.__lt__ === "function") return truth(a.__lt__(b)) ? -1 : truth(b.__lt__(a)) ? 1 : 0;
    raise(TypeError, "'<' not supported between instances of '" + typeName(a) + "' and '" + typeName(b) + "'");
}
export const lt = (a, b) => cmp(a, b) < 0;
export const le = (a, b) => cmp(a, b) <= 0;
export const gt = (a, b) => cmp(a, b) > 0;
export const ge = (a, b) => cmp(a, b) >= 0;

// ---- text
export function fstr(x) {
    if (x !== x) return "nan";
    if (x === Infinity) return "inf";
    if (x === -Infinity) return "-inf";
    if (x === 0) return Object.is(x, -0) ? "-0.0" : "0.0";
    const a = Math.abs(x);
    if (a >= 1e16 || a < 1e-4) {
        const [m, e] = x.toExponential().split("e");
        return m + "e" + e[0] + (e.length < 3 ? "0" : "") + e.slice(1);
    }
    const s = String(x);
    return s.includes(".") ? s : s + ".0";
}
function quote(s) {
    const q = s.includes("'") && !s.includes('"') ? '"' : "'";
    let out = q;
    for (const c of s) {
        const u = c.codePointAt(0);
        if (c === q || c === "\\") out += "\\" + c;
        else if (c === "\n") out += "\\n";
        else if (c === "\r") out += "\\r";
        else if (c === "\t") out += "\\t";
        else if (u < 0x20 || u === 0x7f) out += "\\x" + u.toString(16).padStart(2, "0");
        else out += c;
    }
    return out + q;
}
function bytesRepr(b) {
    let out = "b'";
    for (const u of b) {
        const c = String.fromCharCode(u);
        if (c === "'" || c === "\\") out += "\\" + c;
        else if (c === "\n") out += "\\n";
        else if (c === "\r") out += "\\r";
        else if (c === "\t") out += "\\t";
        else if (u < 0x20 || u >= 0x7f) out += "\\x" + u.toString(16).padStart(2, "0");
        else out += c;
    }
    return out + "'";
}
export function typeName(x) {
    if (x === undefined) return "NoneType";
    if (x === null) return "JsNull";
    switch (typeof x) {
        case "boolean": return "bool";
        case "number": return Number.isInteger(x) ? "int" : "float";
        case "bigint": return "int";
        case "string": return "str";
        case "function": return x.$cls ? "type" : "function";
    }
    if (x instanceof Tuple) return "tuple";
    if (Array.isArray(x)) return "list";
    if (x instanceof Map) return "dict";
    if (x instanceof FrozenSet) return "frozenset";
    if (x instanceof Set) return "set";
    if (x instanceof Bytes) return "bytes";
    if (x instanceof ByteArray) return "bytearray";
    if (x instanceof Range) return "range";
    if (x instanceof Member) return x.$e.$name;
    if (x instanceof AsyncGen) return "async_generator";
    if (!(x instanceof Obj) && typeof x[Symbol.iterator] === "function" && typeof x.next === "function") return "generator";
    return x.constructor && x.constructor.$name ? x.constructor.$name : x.constructor ? x.constructor.name : "object";
}
// The text of `x`, `d` describing where its static type holds floats (or an
// int enum's members): "f" a float, ["l", d] a list, ["t", d...] a tuple,
// ["v", d] a tuple of any length, ["d", k, v] a dict, ["s", d] a set, ["e", E]
// an int enum's member; anything else is told by what it is (a whole number
// is an int).
export function str(x, d) {
    if (typeof x === "string") return x;
    if (x instanceof BaseException) return x.__str__();
    if (x instanceof Obj && typeof x.__str__ === "function") return x.__str__();
    // An enum's member: its enum's name and its own.
    if (x instanceof Member) return x.$e.$name + "." + x.name;
    // An int enum's member, a number: its int, as IntEnum's prints.
    if (typeof x === "number" && d && d[0] === "e") return String(x);
    return repr(x, d);
}
// The containers whose repr is being made, as CPython's Py_ReprEnter keeps
// them: one met again inside itself is written `[...]`, `{...}` or `(...)`.
const reprShowing = new Set();
function shown_once(x, again, made) {
    if (reprShowing.has(x)) return again;
    reprShowing.add(x);
    try { return made(); } finally { reprShowing.delete(x); }
}
export function repr(x, d) {
    switch (typeof x) {
        case "undefined": return "None";
        case "boolean": return x ? "True" : "False";
        case "number": return d === "f" || !Number.isInteger(x) ? fstr(x) : d && d[0] === "e" ? "<" + d[1].$name + "." + enum_name(d[1], x) + ": " + x + ">" : String(x);
        case "string": return d && d[0] === "e" ? "<" + d[1].$name + "." + enum_name(d[1], x) + ": " + quote(x) + ">" : quote(x);
        case "function": return x.$cls ? "<class '" + (x.$name || x.name) + "'>" : x.$self !== undefined ? "<bound method " + typeName(x.$self) + "." + x.$name + " of " + repr(x.$self) + ">" : "<function " + (x.$name || x.name || "<lambda>") + ">";
        case "bigint": return String(x);
    }
    if (x === null) return "null";
    if (x === Ellipsis || x === NotImplemented) return String(x);
    if ((x instanceof Obj || x instanceof BaseException) && typeof x.__repr__ === "function") return x.__repr__();
    const el = (i) => (d && typeof d === "object" ? (d[0] === "t" ? d[i + 1] : d[1]) : undefined);
    if (x instanceof Tuple) return shown_once(x, "(...)", () => (x.length === 1 ? "(" + repr(x[0], el(0)) + ",)" : "(" + x.map((v, i) => repr(v, el(i))).join(", ") + ")"));
    if (x instanceof View) return x.kind + "([" + Array.from(x, (v) => repr(v, el(0))).join(", ") + "])";
    if (Array.isArray(x)) return shown_once(x, "[...]", () => "[" + x.map((v) => repr(v, el(0))).join(", ") + "]");
    if (x instanceof Map) { const kd = d && d[0] === "d" ? d[1] : undefined, vd = d && d[0] === "d" ? d[2] : undefined; return shown_once(x, "{...}", () => "{" + Array.from(x, ([k, v]) => repr(k, kd) + ": " + repr(v, vd)).join(", ") + "}"); }
    if (x instanceof Set) { const body = "{" + Array.from(x, (v) => repr(v, el(0))).join(", ") + "}"; return x instanceof FrozenSet ? "frozenset(" + (x.size ? body : "") + ")" : x.size ? body : "set()"; }
    if (x instanceof Bytes) return bytesRepr(x);
    if (x instanceof ByteArray) return "bytearray(" + bytesRepr(x.b) + ")";
    if (x instanceof Range) return "range(" + x.start + ", " + x.stop + (x.step !== 1 ? ", " + x.step : "") + ")";
    if (x instanceof Member) return "<" + x.$e.$name + "." + x.name + ": " + repr(x.value) + ">";
    if (x instanceof BaseException) return typeName(x) + repr(x.args).replace(/,\)$/, ")");
    if (x instanceof Obj) return obj_repr(x);
    if (x instanceof Coroutine) return "<coroutine object>";
    if (x instanceof AsyncGen) return "<async_generator object>";
    if (x instanceof Task) return "<Task object>";
    if (typeof x[Symbol.iterator] === "function" && typeof x.next === "function") return "<generator object>";
    return String(x);
}
export const ascii = (x, d) => repr(x, d).replace(/[^\x00-\x7f]/gu, (c) => { const u = c.codePointAt(0); return u < 0x100 ? "\\x" + u.toString(16).padStart(2, "0") : u < 0x10000 ? "\\u" + u.toString(16).padStart(4, "0") : "\\U" + u.toString(16).padStart(8, "0"); });
// format(v, spec): Python's format specification mini-language.
export function format(v, spec, d) {
    if (v instanceof Obj && typeof v.__format__ === "function") return v.__format__(spec);
    const m = /^(?:(.)?([<>=^]))?([+\- ])?(z)?(#)?(0)?(\d+)?([,_])?(?:\.(\d+))?([bcdeEfFgGnosxX%])?$/su.exec(spec);
    if (!m) raise(ValueError, "Invalid format specifier '" + spec + "' for object of type '" + typeName(v) + "'");
    let [, fill, align, sign, , alt, zero, width, group, prec, type] = m;
    const isNum = typeof v === "number" || typeof v === "boolean" || typeof v === "bigint";
    const isFloat = d === "f" || (typeof v === "number" && !Number.isInteger(v));
    if (typeof v === "boolean" && type === undefined) v = v ? "True" : "False";
    let body, pre = "";
    if (typeof v === "string" || !isNum) {
        if (type !== undefined && type !== "s") raise(ValueError, "Unknown format code '" + type + "' for object of type '" + typeName(v) + "'");
        body = typeof v === "string" ? v : str(v, d);
        if (prec !== undefined) body = Array.from(body).slice(0, +prec).join("");
        align = align || "<";
    } else {
        // (An i64's or a u64's BigInt kept for an integer presentation.)
        let x = typeof v === "bigint" && (type === undefined || "dboxX".includes(type)) ? v : Number(v);
        const neg = x < 0 || Object.is(x, -0);
        x = typeof x === "bigint" ? (neg ? -x : x) : Math.abs(x);
        const p = prec === undefined ? 6 : +prec;
        if (type === undefined) type = isFloat ? "" : "d";
        if ("dbox".includes(type) && type !== "") { if (typeof x !== "bigint" && !Number.isInteger(x)) raise(ValueError, "Unknown format code '" + type + "' for object of type 'float'"); body = x.toString({ d: 10, b: 2, o: 8, x: 16 }[type]); if (alt && type !== "d") pre = "0" + type; }
        else if (type === "X") { body = x.toString(16).toUpperCase(); if (alt) pre = "0X"; }
        else if (type === "c") body = String.fromCodePoint(x);
        else if (type === "f" || type === "F") body = Number.isFinite(x) ? x.toFixed(p) : fstr(x);
        else if (type === "e" || type === "E") { const [mm, ee] = x.toExponential(p).split("e"); body = mm + "e" + ee[0] + (ee.length < 3 ? "0" : "") + ee.slice(1); }
        else if (type === "%") body = (x * 100).toFixed(p) + "%";
        else if (type === "g" || type === "G" || type === "n" || type === "") {
            if (type === "" && prec === undefined) body = isFloat ? fstr(x) : String(x);
            else {
                const P = p === 0 ? 1 : p, e = x === 0 ? 0 : Math.floor(Math.log10(Number(x.toExponential(P - 1))));
                body = e >= -4 && e < P ? x.toFixed(Math.max(0, P - 1 - e)) : (() => { const [mm, ee] = x.toExponential(P - 1).split("e"); return mm + "e" + ee[0] + (ee.length < 3 ? "0" : "") + ee.slice(1); })();
                if (!alt && body.includes(".")) body = body.replace(/\.?0+(?=e|$)/, "");
                if (type === "" && !body.includes(".") && !body.includes("e") && isFloat) body += ".0";
            }
        }
        if ("EFG".includes(type) && type !== "") body = body.toUpperCase();
        if (group) { const [ip, fp] = body.split("."); const every = "box".includes(type) && type !== "" ? 4 : 3; body = ip.replace(new RegExp("\\B(?=(\\d{" + every + "})+(?!\\d))", "g"), group) + (fp !== undefined ? "." + fp : ""); }
        pre = (neg ? "-" : sign === "+" ? "+" : sign === " " ? " " : "") + pre;
        align = align || (zero ? "=" : ">");
        if (zero && !fill) fill = "0";
    }
    fill = fill || " ";
    const w = width === undefined ? 0 : +width, len = Array.from(pre + body).length;
    if (len >= w) return pre + body;
    const pad = fill.repeat(w - len);
    if (align === "<") return pre + body + pad;
    if (align === ">") return pad + pre + body;
    if (align === "=") return pre + pad + body;
    const l = Math.floor((w - len) / 2);
    return fill.repeat(l) + pre + body + fill.repeat(w - len - l);
}
// `text % args`: printf-style formatting.
export function percent(text, args) {
    const items = args instanceof Tuple ? args : [args];
    let i = 0;
    const out = text.replace(/%(?:\(([^)]*)\))?([#0\- +]*)(\*|\d+)?(?:\.(\*|\d+))?([diouxXeEfFgGcrsa%])/g, (_, key, flags, width, prec, type) => {
        if (type === "%") return "%";
        const v = key !== undefined ? args.get(key) : items[i++];
        if (v === undefined && i > items.length) raise(TypeError, "not enough arguments for format string");
        const fl = (flags.includes("-") ? "<" : "") + (flags.includes("+") ? "+" : flags.includes(" ") ? " " : "") + (flags.includes("0") && !flags.includes("-") ? "0" : "");
        const spec = fl + (width || "") + (prec !== undefined ? "." + prec : "");
        if (type === "s") return format(str(v), spec);
        if (type === "r" || type === "a") return format(repr(v), spec);
        return format(v, spec + (type === "i" || type === "u" ? "d" : type));
    });
    if (key0(text) === false && i < items.length) raise(TypeError, "not all arguments converted during string formatting");
    return out;
}
const key0 = (t) => /%\(/.test(t);
// str.format(text, positional, keywords).
export function str_format(text, pos, kws) {
    let auto = 0;
    return text.replace(/\{\{|\}\}|\{([^{}!:]*)(?:!([rsa]))?(?::((?:\{[^{}]*\}|[^{}])*))?\}/g, (m, field, conv, spec) => {
        if (m === "{{") return "{";
        if (m === "}}") return "}";
        const [head, ...rest] = field.split(/(?=[.[])/);
        let v = head === "" ? pos[auto++] : /^\d+$/.test(head) ? pos[+head] : kws.get(head);
        if (v === undefined && head !== "" && !/^\d+$/.test(head) && !kws.has(head)) raise(KeyError, head);
        for (const r of rest) v = r[0] === "." ? v[r.slice(1)] : getitem(v, /^\[\d+\]$/.test(r) ? +r.slice(1, -1) : r.slice(1, -1));
        if (conv === "r") v = repr(v); else if (conv === "s") v = str(v); else if (conv === "a") v = ascii(v);
        if (spec) spec = str_format(spec, pos, kws);
        return format(v, spec || "");
    });
}

// ---- items, slices, membership, iteration
const index = (i, n, what) => { const k = i < 0 ? i + n : i; if (k < 0 || k >= n) raise(IndexError, what + " index out of range"); return k; };
// The code points of `s`, when it has any past U+FFFF; else undefined.
const wide = (s) => (/[\ud800-\udfff]/.test(s) ? Array.from(s) : undefined);
export function getitem(x, k) {
    // A slice object takes what its bounds and step do of a sequence.
    if (k instanceof slice && !(x instanceof Map) && !(x instanceof Obj && typeof x.__getitem__ === "function")) return cut(x, k.start, k.stop, k.step);
    if (Array.isArray(x)) return x[index(k, x.length, x instanceof Tuple ? "tuple" : "list")];
    if (x instanceof Map) { const v = x.get(k); if (v === undefined && !x.has(k)) raise(KeyError, k); return v; }
    if (typeof x === "string") { const w = wide(x); return w ? w[index(k, w.length, "string")] : x[index(k, x.length, "string")]; }
    if (x instanceof Uint8Array || x instanceof ByteArray) { const b = bytesOf(x); return b[index(k, b.length, typeName(x))]; }
    if (x instanceof Range) { const i = index(k, x.length, "range object"); return x.start + i * x.step; }
    if (x instanceof Obj && typeof x.__getitem__ === "function") return x.__getitem__(k);
    if (x === undefined) raise(TypeError, "'NoneType' object is not subscriptable");
    return x[k];
}
// A list's or tuple's item, and a dict's value: IndexError and KeyError as Jac's are.
export const at = (xs, i) => xs[index(i, xs.length, xs instanceof Tuple ? "tuple" : "list")];
export const set_at = (xs, i, v) => { xs[index(i, xs.length, "list assignment")] = v; };
export function dget(d, k) { const v = d.get(k); if (v === undefined && !d.has(k)) raise(KeyError, k); return v; }
export function seq_add(a, b) {
    if (a instanceof Uint8Array || a instanceof ByteArray) { const r = [...bytesOf(a), ...bytesOf(b)]; return a instanceof ByteArray ? new ByteArray(r) : Bytes.from(r); }
    return a.concat(b);
}
export function setitem(x, k, v) {
    if (Array.isArray(x)) x[index(k, x.length, "list assignment")] = v;
    else if (x instanceof Map) x.set(k, v);
    else if (x instanceof ByteArray) x.b[index(k, x.b.length, "bytearray")] = v;
    else if (x instanceof Obj && typeof x.__setitem__ === "function") x.__setitem__(k, v);
    else if (x instanceof Tuple || typeof x === "string") raise(TypeError, "'" + typeName(x) + "' object does not support item assignment");
    else x[k] = v;
}
export function delitem(x, k) {
    if (x instanceof Tuple || typeof x === "string" || x instanceof Bytes) raise(TypeError, "'" + typeName(x) + "' object doesn't support item deletion");
    if (Array.isArray(x)) x.splice(index(k, x.length, "list assignment"), 1);
    else if (x instanceof ByteArray) x.b.splice(index(k, x.b.length, "bytearray"), 1);
    else if (x instanceof Map) { if (!x.delete(k)) raise(KeyError, k); }
    else if (x instanceof Obj && typeof x.__delitem__ === "function") x.__delitem__(k);
    else delete x[k];
}
// The positions a slice takes of a sequence of length n.
function span(n, lo, hi, step) {
    if (step === undefined) step = 1;
    if (step === 0) raise(ValueError, "slice step cannot be zero");
    const cl = (i, d, lo2, hi2) => (i === undefined ? d : i < 0 ? Math.max(i + n, lo2) : Math.min(i, hi2));
    return step > 0 ? [cl(lo, 0, 0, n), cl(hi, n, 0, n), step] : [cl(lo, n - 1, -1, n - 1), cl(hi, -1, -1, n - 1), step];
}
function picks(n, lo, hi, step) {
    const [a, b, s] = span(n, lo, hi, step), out = [];
    if (s > 0) for (let i = a; i < b; i += s) out.push(i); else for (let i = a; i > b; i += s) out.push(i);
    return out;
}
// x[lo:hi:step].
export function cut(x, lo, hi, step) {
    if (typeof x === "string") { const w = wide(x); if (!w && (step === undefined || step === 1)) { const [a, b] = span(x.length, lo, hi, 1); return a < b ? x.slice(a, b) : ""; } const cs = w || x; return picks(cs.length, lo, hi, step).map((i) => cs[i]).join(""); }
    if (x instanceof ByteArray) return new ByteArray(picks(x.b.length, lo, hi, step).map((i) => x.b[i]));
    if (x instanceof Uint8Array) return Bytes.from(picks(x.length, lo, hi, step).map((i) => x[i]));
    if (x instanceof Range) { const [a, , s] = span(x.length, lo, hi, step), n = picks(x.length, lo, hi, step).length; return new Range(x.start + a * x.step, x.start + (a + n * s) * x.step, x.step * s); }
    if (x instanceof Obj && typeof x.__getitem__ === "function") return x.__getitem__(make(slice, { start: lo, stop: hi, step }));
    if (step === undefined || step === 1) { const [a, b] = span(x.length, lo, hi, 1); return x.slice(a, Math.max(a, b)); }
    const out = picks(x.length, lo, hi, step).map((i) => x[i]);
    return x instanceof Tuple ? Tuple.from(out) : out;
}
// reversed(x) of a value known only as the program runs: what an object's
// __reversed__() gives when its class has one, else its items from the last.
export function rt_reversed_of(x) { return x instanceof Obj && typeof x.__reversed__ === "function" ? x.__reversed__() : cut(x, undefined, undefined, -1); }
// A slice object: its bounds and step, and what they take of a sequence.
export class slice extends Obj {
    static $name = "slice";
    init(start, stop, step) { this.start = start; this.stop = stop; this.step = step; }
    indices(n) { const [a, b, s] = span(n, this.start, this.stop, this.step); return tup(a, b, s); }
    __repr__() { return "slice(" + repr(this.start) + ", " + repr(this.stop) + ", " + repr(this.step) + ")"; }
}
// A view of a bytes's or a bytearray's bytes, without copying them: its
// items `start`, `start + step`, ... of `length` of them (rt.core's
// memoryview, whose format is a byte's on a JS host).
export class memoryview extends Obj {
    static $name = "memoryview";
    init() {}
    $src() { if (this.released) raise(ValueError, "operation forbidden on released memoryview object"); return bytesOf(this.arr !== undefined ? this.arr : this.buf); }
    __len__() { this.$src(); return this.length; }
    __getitem__(k) {
        const b = this.$src();
        if (k instanceof slice) {
            const ix = picks(this.length, k.start, k.stop, k.step), [a, , s] = span(this.length, k.start, k.stop, k.step);
            return make(memoryview, { buf: this.buf, arr: this.arr, readonly: this.readonly, start: this.start + a * this.step, length: ix.length, step: this.step * s });
        }
        return b[this.start + index(k, this.length, "memoryview") * this.step];
    }
    __setitem__(k, v) {
        const b = this.$src();
        if (this.readonly) raise(TypeError, "cannot modify read-only memory");
        b[this.start + index(k, this.length, "memoryview") * this.step] = v;
    }
    tolist() { const b = this.$src(); return Array.from({ length: this.length }, (_, i) => b[this.start + i * this.step]); }
    tobytes() { return Bytes.from(this.tolist()); }
    __bytes__() { return this.tobytes(); }
    release() { this.released = true; }
    cast(format) { if (format !== "B") raise(NotImplementedError, "memoryview: format '" + format + "' on a JS host"); return this; }
}
export function rt_memoryview(data) {
    if (data instanceof ByteArray) return make(memoryview, { arr: data, readonly: false, start: 0, length: data.b.length, step: 1 });
    if (data instanceof Uint8Array) return make(memoryview, { buf: data, readonly: true, start: 0, length: data.length, step: 1 });
    if (data instanceof memoryview) return data;
    raise(TypeError, "memoryview: a bytes-like object is required, not '" + typeName(data) + "'");
}
export function set_slice(x, lo, hi, step, v) {
    const items = Array.from(iter(v));
    const xs = x instanceof ByteArray ? x.b : x;
    if (step === undefined || step === 1) { const [a, b] = span(xs.length, lo, hi, 1); xs.splice(a, Math.max(0, b - a), ...items); return; }
    const at = picks(xs.length, lo, hi, step);
    if (at.length !== items.length) raise(ValueError, "attempt to assign sequence of size " + items.length + " to extended slice of size " + at.length);
    at.forEach((i, k) => { xs[i] = items[k]; });
}
export function del_slice(x, lo, hi, step) {
    if (x instanceof Tuple || typeof x === "string" || x instanceof Bytes) raise(TypeError, "'" + typeName(x) + "' object doesn't support item deletion");
    const xs = x instanceof ByteArray ? x.b : x;
    const at = picks(xs.length, lo, hi, step).sort((a, b) => b - a);
    for (const i of at) xs.splice(i, 1);
}
// `del x[k]` of an any: an item, or the items a slice object takes.
export function rt_delitem(x, k) {
    if (k instanceof slice && (Array.isArray(x) || x instanceof ByteArray)) return del_slice(x, k.start, k.stop, k.step);
    return delitem(x, k);
}
export function contains(c, x) {
    if (typeof c === "string") return c.includes(x);
    if (c instanceof Map || c instanceof Set) return c.has(x);
    if (c instanceof View && c.kind === "dict_keys") return c.d.has(x);
    if (Array.isArray(c)) { for (const y of c) if (eq(y, x)) return true; return false; }
    if (c instanceof Range) return Number.isInteger(x) && (c.step > 0 ? x >= c.start && x < c.stop : x <= c.start && x > c.stop) && (x - c.start) % c.step === 0;
    if (c instanceof Uint8Array || c instanceof ByteArray) { const b = bytesOf(c); if (typeof x === "boolean") x = Number(x); if (typeof x === "number") { if (x < 0 || x > 255) raise(ValueError, "byte must be in range(0, 256)"); return b.includes(x); } const s = String.fromCharCode(...b), t = String.fromCharCode(...bytesOf(x)); return s.includes(t); }
    if (c instanceof Obj && typeof c.__contains__ === "function") return truth(c.__contains__(x));
    if (c === undefined) raise(TypeError, "argument of type 'NoneType' is not iterable");
    for (const y of iter(c)) if (eq(y, x)) return true;
    return false;
}
// What `for` iterates of `x`: a dict's keys, a str's characters, an object's __iter__.
export function iter(x) {
    if (x instanceof Map || x instanceof Set) return new Walk(x, x.keys());
    if (x instanceof ByteArray) return x.b[Symbol.iterator]();
    if (x instanceof Obj && typeof x.__iter__ === "function") {
        // What its __iter__ gives: a generator, or an object stepped by its __next__.
        const r = x.__iter__();
        return r instanceof Obj && typeof r.__next__ === "function" ? stepped(r) : r;
    }
    if (x !== undefined && x !== null && typeof x[Symbol.iterator] === "function") return x[Symbol.iterator]();
    if (x instanceof Obj && typeof x.__getitem__ === "function") return (function* () { for (let i = 0; ; i++) { let v; try { v = x.__getitem__(i); } catch (e) { if (e instanceof IndexError) return; throw e; } yield v; } })();
    raise(TypeError, "'" + typeName(x) + "' object is not iterable");
}
// An object whose class defines __next__, as a JS iterator: each step its
// __next__, done when that raises StopIteration.
function stepped(o) {
    return {
        next() { try { return { value: o.__next__(), done: false }; } catch (e) { if (e instanceof StopIteration) return { value: undefined, done: true }; throw e; } },
        [Symbol.iterator]() { return this; },
    };
}
export function next(it, ...d) {
    const r = it.next();
    if (r.done) { if (d.length) return d[0]; raise(StopIteration); }
    return r.value;
}
// next(o, default) of an object whose class defines __next__.
export function next_obj(o, d) {
    try { return o.__next__(); } catch (e) { if (e instanceof StopIteration) return d; throw e; }
}
// `(a, b) = x`: x's items, exactly `n` of them (or at least n with a star at `star`).
export function unpack(x, n, star) {
    const items = Array.isArray(x) ? x : Array.from(iter(x));
    if (star === undefined ? items.length !== n : items.length < n - 1) {
        if (items.length < n - (star === undefined ? 0 : 1)) raise(ValueError, "not enough values to unpack (expected " + (star === undefined ? "" : "at least ") + (star === undefined ? n : n - 1) + ", got " + items.length + ")");
        // CPython 3.14 gives the count when the value has a length (a list or a
        // tuple), not when it is an iterator it stopped reading.
        raise(ValueError, "too many values to unpack (expected " + n + (Array.isArray(x) ? ", got " + items.length : "") + ")");
    }
    if (star === undefined) return items;
    const tail = n - 1 - star;
    return [...items.slice(0, star), items.slice(star, items.length - tail), ...items.slice(items.length - tail)];
}

// ---- the builtins
// print(): to the host's standard output, or to what replaced sys.stdout.
let stdoutObj = undefined;
export function print(sep, end, ...parts) {
    if (stdoutObj !== undefined) print_to(stdoutObj, sep, end, ...parts);
    else out(parts.map(piece).join(sep === undefined ? " " : sep) + (end === undefined ? "\n" : end));
}
// One of print's pieces as text: text already, or a spread's item (`print(*xs)`).
const piece = (p) => (typeof p === "string" ? p : str(p));
// sys.stdout replaced (lib/sys.js): what print() writes to, undefined for the host's own.
export function rt_set_stdout(f) { stdoutObj = f; }
// print(..., file=f): written to `f` in pieces, each piece, each separator and
// the end a write of its own, as CPython's print makes them.
export function print_to(f, sep, end, ...parts) {
    parts.forEach((p, i) => { if (i > 0) f.write(sep === undefined ? " " : sep); f.write(piece(p)); });
    f.write(end === undefined ? "\n" : end);
}
let pending = "";
function out(s) {
    const proc = G.process;
    if (proc && proc.stdout && typeof proc.stdout.write === "function") { proc.stdout.write(s); return; }
    pending += s;
    const k = pending.lastIndexOf("\n");
    if (k >= 0) { for (const line of pending.slice(0, k).split("\n")) console.log(line); pending = pending.slice(k + 1); }
}
export function len(x) {
    if (typeof x === "string") { const w = wide(x); return w ? w.length : x.length; }
    if (Array.isArray(x) || x instanceof Uint8Array || x instanceof ByteArray || x instanceof Range || x instanceof View) return x.length;
    if (x instanceof Map || x instanceof Set) return x.size;
    if (x instanceof Obj && typeof x.__len__ === "function") return x.__len__();
    raise(TypeError, "object of type '" + typeName(x) + "' has no len()");
}
export const slen = (s) => { const w = wide(s); return w ? w.length : s.length; };
export function int(x, base) {
    if (typeof x === "number") return Number.isInteger(x) ? x : int_of_float(x);
    if (typeof x === "boolean") return x ? 1 : 0;
    if (typeof x === "string" || x instanceof Uint8Array) {
        const s = (typeof x === "string" ? x : String.fromCharCode(...x)).trim().replace(/_(?=\d)/g, "");
        let b = base === undefined ? 10 : base, t = s, neg = false;
        if (t[0] === "-" || t[0] === "+") { neg = t[0] === "-"; t = t.slice(1); }
        const pfx = /^0([xob])/i.exec(t);
        if (pfx && (b === 0 || b === { x: 16, o: 8, b: 2 }[pfx[1].toLowerCase()])) { b = { x: 16, o: 8, b: 2 }[pfx[1].toLowerCase()]; t = t.slice(2); }
        if (b === 0) b = 10;
        const digits = "0123456789abcdefghijklmnopqrstuvwxyz".slice(0, b);
        if (t === "" || ![...t.toLowerCase()].every((c) => digits.includes(c))) raise(ValueError, "invalid literal for int() with base " + (base === undefined ? 10 : base) + ": " + repr(typeof x === "string" ? x : x));
        const v = parseInt(t, b);
        return ovf(neg ? -v : v);
    }
    if (x instanceof Obj && typeof x.__int__ === "function") return x.__int__();
    if (x instanceof Obj && typeof x.__index__ === "function") return x.__index__();
    raise(TypeError, "int() argument must be a string, a bytes-like object or a real number, not '" + typeName(x) + "'");
}
export function float(x) {
    if (typeof x === "number") return x;
    if (typeof x === "boolean") return x ? 1 : 0;
    if (typeof x === "string") {
        const s = x.trim().toLowerCase().replace(/_(?=\d)/g, "");
        if (/^[+-]?(inf|infinity)$/.test(s)) return s[0] === "-" ? -Infinity : Infinity;
        if (/^[+-]?nan$/.test(s)) return NaN;
        if (!/^[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?$/.test(s)) raise(ValueError, "could not convert string to float: " + repr(x));
        return Number(s);
    }
    if (x instanceof Obj && typeof x.__float__ === "function") return x.__float__();
    if (x instanceof Obj && typeof x.__index__ === "function") return x.__index__();
    raise(TypeError, "float() argument must be a string or a real number, not '" + typeName(x) + "'");
}
export const bool = (x) => truth(x);
export const list = (x) => (x === undefined ? [] : Array.from(iter(x)));
export const tuple = (x) => (x === undefined ? new Tuple() : x instanceof Tuple ? x : Tuple.from(iter(x)));
export const set = (x) => (x === undefined ? new PySet() : set_of(iter(x)));
export const frozenset = (x) => (x === undefined ? new FrozenSet() : frozen_of(iter(x)));
// dict(x) as CPython's reads x: what a dict holds, else each key an object's
// keys() gives with what the object holds for it, else an iterable's pairs
// (the native runtime's _dict_of, rt/methods).
export function _dict_of(x) {
    const d = new Dict();
    if (x instanceof Map) { for (const [k, v] of x) d.set(k, v); return d; }
    if (x instanceof Obj && typeof x.keys === "function") { for (const k of iter(x.keys())) d.set(k, getitem(x, k)); return d; }
    let i = 0;
    for (const p of iter(x)) {
        let pair;
        try { pair = Array.isArray(p) ? p : Array.from(iter(p)); } catch (e) { if (!(e instanceof TypeError)) throw e; raise(TypeError, "cannot convert dictionary update sequence element #" + i + " to a sequence"); }
        if (pair.length !== 2) raise(ValueError, "dictionary update sequence element #" + i + " has length " + pair.length + "; 2 is required");
        d.set(pair[0], pair[1]);
        i++;
    }
    return d;
}
export function dict(x, kws) {
    const d = x === undefined ? new Dict() : _dict_of(x);
    if (kws) for (const [k, v] of kws) d.set(k, v);
    return d;
}
export function bytes(x) {
    if (x === undefined) return new Bytes(0);
    if (typeof x === "number") return new Bytes(x);
    if (typeof x === "string") return str_encode(x);
    if (x instanceof Obj && typeof x.__bytes__ === "function") return x.__bytes__();
    return Bytes.from(Array.from(iter(x)));
}
export const bytearray = (x) => new ByteArray(x === undefined ? [] : typeof x === "number" ? new Array(x).fill(0) : typeof x === "string" ? str_encode(x) : Array.from(iter(x)));
export const enumerate = function* (x, start = 0) { let i = start; for (const v of iter(x)) yield tup(i++, v); };
export const zip = function* (...xs) { const its = xs.map(iter); for (;;) { const r = its.map((i) => i.next()); if (r.some((y) => y.done)) return; yield Tuple.from(r, (y) => y.value); } };
export const map = function* (f, ...xs) { if (xs.length === 1) { for (const v of iter(xs[0])) yield f(v); return; } for (const t of zip(...xs)) yield f(...t); };
export const filter = function* (f, x) { for (const v of iter(x)) if (f === undefined ? truth(v) : truth(f(v))) yield v; };
export const reversed = (x) => (x instanceof Obj && typeof x.__reversed__ === "function" ? x.__reversed__() : Array.from(iter(x)).reverse()[Symbol.iterator]());
export function sorted(x, key, reverse) { const r = Array.from(iter(x)); list_sort(r, key, reverse); return r; }
export function list_sort(xs, key, reverse) {
    const keys = key ? xs.map((v) => key(v)) : xs;
    const order = xs.map((_, i) => i);
    order.sort((a, b) => (reverse ? cmp(keys[b], keys[a]) : cmp(keys[a], keys[b])) || a - b);
    const vs = order.map((i) => xs[i]);
    for (let i = 0; i < vs.length; i++) xs[i] = vs[i];
}
export function sum(x, start = 0) {
    let s = start;
    for (const v of iter(x)) s = dyn("+", s, v);
    return s;
}
// min and max of one iterable or of several values, by `key`, else `dflt`.
export function extreme(sign, items, key, hasDflt, dflt) {
    let best, bk, any = false;
    for (const v of items) { const k = key ? key(v) : v; if (!any || cmp(k, bk) * sign > 0) { best = v; bk = k; any = true; } }
    if (!any) { if (hasDflt) return dflt; raise(ValueError, (sign < 0 ? "min" : "max") + "() iterable argument is empty"); }
    return best;
}
export const all = (x) => { for (const v of iter(x)) if (!truth(v)) return false; return true; };
export const any = (x) => { for (const v of iter(x)) if (truth(v)) return true; return false; };
export const divmod = (a, b) => tup(floordiv_i(a, b), mod_i(a, b));
// pow(b, e, m): exact, through BigInt; a negative exponent its inverse's.
export function rt_pow_mod(b, e, m) {
    if (m === 0) raise(ValueError, "pow() 3rd argument cannot be 0");
    let B = ((BigInt(b) % BigInt(m)) + BigInt(m)) % BigInt(m), E = BigInt(e), M = BigInt(m), r = 1n;
    if (E < 0n) {
        let [g, x] = [M, 0n], [h, y] = [B, 1n];
        while (h !== 0n) { const q = g / h; [g, h] = [h, g - q * h]; [x, y] = [y, x - q * y]; }
        if (g !== 1n && g !== -1n) raise(ValueError, "base is not invertible for the given modulus");
        B = ((x % M) + M) % M; E = -E;
    }
    for (; E > 0n; E >>= 1n, B = (B * B) % M) if (E & 1n) r = (r * B) % M;
    const v = Number(r);
    return m < 0 && v > 0 ? v + m : v;
}
export const divmod_f = (a, b) => tup(floordiv_f(a, b), mod_f(a, b));
const radix = (pfx, b) => (x) => (x < 0 ? "-" : "") + pfx + Math.abs(x).toString(b);
export const bin = radix("0b", 2);
export const oct = radix("0o", 8);
export const hex = radix("0x", 16);

// A node's and an edge's id (jid), as native code's runtime makes it
// (rt_jid_new): this process's generation, 64 bits from the system's random
// source, drawn the first time an id is written out and never 0, then the
// id's number among those this process made, from 1, as 32 hex digits. Each
// node and edge takes one as it is made (graph.js's constructors), kept on
// it where nothing copies it; a store gives one back to what it loads.
const JID = Symbol("jid");
let jidNumbers = 0, jidGeneration = null;
export function jid_give(o) {
    G.Object.defineProperty(o, JID, { value: ++jidNumbers, writable: true });
}
export function jid_text(o) {
    const v = o[JID];
    if (typeof v === "string") return v;
    if (jidGeneration === null) {
        const w = new G.BigUint64Array(1);
        do G.crypto.getRandomValues(w); while (w[0] === 0n);
        jidGeneration = w[0].toString(16).padStart(16, "0");
    }
    return jidGeneration + v.toString(16).padStart(16, "0");
}
// Node or edge `x`, made from a store's row, takes back the id `text`: false,
// and `x` as it was, when `text` is not one.
export function rt_jid_restore(x, text) {
    if (!/^[0-9a-f]{32}$/.test(text) || text.startsWith("0000000000000000")) return false;
    x[JID] = text;
    return true;
}
// The node edge `e` leads to, as its arrow points.
export const rt_edge_dst = (e) => e.__dst__;
export function ord(c) { const cs = Array.from(typeof c === "string" ? c : bytesOf(c)); if (cs.length !== 1) raise(TypeError, "ord() expected a character, but string of length " + cs.length + " found"); return typeof cs[0] === "number" ? cs[0] : cs[0].codePointAt(0); }
export function chr(n) { if (n < 0 || n > 0x10ffff) raise(ValueError, "chr() arg not in range(0x110000)"); return String.fromCodePoint(n); }
export const callable = (x) => typeof x === "function" || (x instanceof Obj && typeof x.__call__ === "function");
export function isinstance(x, C) {
    if (C instanceof Tuple || Array.isArray(C)) return C.some((c) => isinstance(x, c));
    return C.$isa ? C.$isa(x) : x instanceof C;
}
// issubclass(a, B) of classes held as values (check decides those it names).
export function rt_issubclass(a, B) {
    if (typeof a !== "function") raise(TypeError, "issubclass() arg 1 must be a class");
    if (B instanceof Tuple || Array.isArray(B)) return B.some((b) => rt_issubclass(a, b));
    if (typeof B !== "function") raise(TypeError, "issubclass() arg 2 must be a class, a tuple of classes, or a union");
    return a === B || a.prototype instanceof B;
}
export function hasattr(o, k) { return o !== undefined && o !== null && (k in G.Object(o)); }
// hasattr(o, name) as Python asks it: whether getattr finds it.
export function rt_hasattr(o, k) { try { getattr(o, k); return true; } catch (e) { if (e instanceof AttributeError) return false; throw e; } }
export function getattr(o, k, ...d) {
    if (o !== undefined && o !== null && k in G.Object(o)) { const v = o[k]; return typeof v === "function" && !v.$cls && !(o instanceof Obj && G.Object.hasOwn(o, k)) ? bound_method(o, v, k) : held(v); }
    // An attribute its class lacks, as Python reads it: what __getattr__ gives.
    if (o instanceof Obj && typeof o.__getattr__ === "function") {
        try { return o.__getattr__(k); } catch (e) { if (!(e instanceof AttributeError) || !d.length) throw e; }
    }
    if (d.length) return d[0];
    raise(AttributeError, "'" + typeName(o) + "' object has no attribute '" + k + "'");
}
// setattr(o, name, v) of an object or an any, as native code's rt_setattr:
// through its class's __setattr__ where it has one.
export function setattr(o, k, v) { if (o instanceof Obj && typeof o.__setattr__ === "function") o.__setattr__(k, v); else o[k] = v; }
// A method read off its object: a function calling it on the object.
export function bound_method(o, f, name) {
    const m = f.bind(o);
    m.$self = o; m.$name = name; m.$p = f.$p; m.$q = f.$q;
    return m;
}
// dir(x): the names of its attributes, sorted: an object's fields and its
// class's methods; a class's methods and its fields with a default (its
// class attributes, as Python's); a builtin type's methods.
export function rt_dir_of(x) {
    const names = new Set();
    let start = x instanceof Obj ? G.Object.getPrototypeOf(x) : null;
    if (typeof x === "function" && x.prototype instanceof Obj) { for (const [f, , dflt] of fieldsOf(x)) if (dflt) names.add(f); start = x.prototype; }
    else if (x instanceof Obj) for (const [f] of fieldsOf(x.constructor)) if (f in x) names.add(f);
    const kind = typeof x === "string" ? "str_" : x instanceof Map ? "dict_" : x instanceof Set ? "set_" : Array.isArray(x) ? (x instanceof Tuple ? "tuple_" : "list_") : typeof x === "number" ? (Number.isInteger(x) ? "int_" : "float_") : "";
    if (kind !== "") { for (const k of G.Object.keys(METHODS)) if (k.startsWith(kind)) names.add(k.slice(kind.length)); if (kind === "list_") for (const k of G.Object.keys(LIST_M)) names.add(k); if (kind === "dict_") for (const k of G.Object.keys(DICT_M)) names.add(k); }
    // (A generated init, of a class with no init of its own, is no method of its.)
    for (let p = start; p && p !== Obj.prototype; p = G.Object.getPrototypeOf(p)) for (const k of G.Object.getOwnPropertyNames(p)) if (k !== "constructor" && k[0] !== "$" && !(k === "init" && p.constructor.$ctor)) names.add(k);
    return Array.from(names).sort();
}
// vars(x): an object's fields by name, as its own class declares them; one
// `del` removed is none of them.
export function rt_vars_of(x) { return dict_of(fieldsOf(x.constructor).filter(([f]) => f in x).map(([f]) => [f, held(x[f])])); }
// An obj's generated repr: its class's name and its fields'.
export function plain_repr(x) { return "<" + typeName(x) + " object>"; }
export function obj_repr(x) { return typeName(x) + "(" + fieldsOf(x.constructor).map(([f, fd]) => f + "=" + repr(x[f], fd)).join(", ") + ")"; }
// A property set whose class declares no setter for it: Python's AttributeError.
export function no_setter(o, k) { raise(AttributeError, "property '" + k + "' of '" + typeName(o) + "' object has no setter"); }
// A field a `del` may have removed.
export function field(o, k) { if (!(k in o)) raise(AttributeError, "'" + typeName(o) + "' object has no attribute '" + k + "'"); return o[k]; }
export const delattr = (o, k) => { if (!(k in o)) raise(AttributeError, k); delete o[k]; };
// delattr(o, name) where the name is known only at run time, or `o` is an any
// (check's lowering): its class's __delattr__, as native code's rt_delattr.
export function rt_delattr(o, k) {
    if (o === undefined || o === null || typeof o.__delattr__ !== "function") raise(AttributeError, "'" + typeName(o) + "' object has no attribute '" + k + "'");
    o.__delattr__(k);
}
export function type(x) { if (x === undefined || x === null) return NoneType; switch (typeof x) { case "boolean": return bool; case "number": return Number.isInteger(x) ? int : float; case "bigint": return int; case "string": return str; } if (x instanceof Tuple) return tuple; if (Array.isArray(x)) return list; if (x instanceof Map) return dict; if (x instanceof FrozenSet) return frozenset; if (x instanceof Set) return set; if (x instanceof Bytes) return bytes; if (x instanceof ByteArray) return bytearray; if (x instanceof Range) return range; if (!(x instanceof Obj) && typeof x[Symbol.iterator] === "function" && typeof x.next === "function") return generator_type; return x.constructor; }
// What type() gives for a generator: no class of the program's, named as Python names it.
const generator_type = function generator() {};
generator_type.$cls = true; generator_type.$name = "generator"; generator_type.__name__ = "generator"; generator_type.$isa = (x) => typeName(x) === "generator";
export const NoneType = function NoneType() {};
// object(): a bare instance, equal only to itself.
export class object extends Obj { static $name = "object"; static $identity = true; $init() { return this; } }
// The builtin types as values: what isinstance tests and type() gives.
for (const [f, n, isa] of [[int, "int", (x) => Number.isInteger(x) || typeof x === "boolean"], [float, "float", (x) => typeof x === "number"], [str, "str", (x) => typeof x === "string"], [bool, "bool", (x) => typeof x === "boolean"], [list, "list", (x) => Array.isArray(x) && !(x instanceof Tuple)], [tuple, "tuple", (x) => x instanceof Tuple], [dict, "dict", (x) => x instanceof Map], [set, "set", (x) => x instanceof Set && !(x instanceof FrozenSet)], [frozenset, "frozenset", (x) => x instanceof FrozenSet], [bytes, "bytes", (x) => x instanceof Bytes], [bytearray, "bytearray", (x) => x instanceof ByteArray], [range, "range", (x) => x instanceof Range], [NoneType, "NoneType", (x) => x === undefined]]) {
    f.$cls = true; f.$name = n; f.$isa = isa; f.__name__ = n;
}
export function input(prompt) { raise(EOFError, "EOF when reading a line" + (prompt ? "" : "")); }
export function issubclass(a, b) { return a === b || (typeof a === "function" && a.prototype instanceof b); }
// A class's name (`type(x).__name__`).
export const type_name = (C) => C.$name || C.name;

// ---- what a value typed `any` does, asked of the value
export function dyn(op, a, b) {
    if (a instanceof Obj || b instanceof Obj) {
        const m = DUNDER[op];
        if (a instanceof Obj && typeof a[m] === "function") { const r = a[m](b); if (r !== NotImplemented) return r; }
        const rm = "__r" + m.slice(2);
        if (b instanceof Obj && typeof b[rm] === "function") return b[rm](a);
    }
    const num = (x) => typeof x === "number" || typeof x === "boolean" || typeof x === "bigint";
    if (num(a) && num(b)) {
        // (An i64 or a u64 an any holds is an int there, trapping past ±2**53.)
        a = typeof a === "bigint" ? small(a) : Number(a); b = typeof b === "bigint" ? small(b) : Number(b);
        const ints = Number.isInteger(a) && Number.isInteger(b);
        switch (op) {
            case "+": return ints ? add_i(a, b) : a + b;
            case "-": return ints ? sub_i(a, b) : a - b;
            case "*": return ints ? mul_i(a, b) : a * b;
            case "/": return div(a, b);
            case "//": return ints ? floordiv_i(a, b) : floordiv_f(a, b);
            case "%": return ints ? mod_i(a, b) : mod_f(a, b);
            case "**": return ints ? pow_i(a, b) : pow_f(a, b);
            case "<<": return shl_i(a, b);
            case ">>": return shr_i(a, b);
            case "&": return and_i(a, b);
            case "|": return or_i(a, b);
            case "^": return xor_i(a, b);
        }
    }
    if (op === "+" && typeof a === "string" && typeof b === "string") return a + b;
    if (op === "+" && Array.isArray(a) && Array.isArray(b) && (a instanceof Tuple) === (b instanceof Tuple)) return a.concat(b);
    if (op === "*" && (typeof a === "string" || Array.isArray(a)) && Number.isInteger(b)) return seq_mul(a, b);
    if (op === "*" && (typeof b === "string" || Array.isArray(b)) && Number.isInteger(a)) return seq_mul(b, a);
    if (op === "%" && typeof a === "string") return percent(a, b);
    if (op === "|" && a instanceof Map && b instanceof Map) return dict_merge(a, b);
    if (a instanceof Set && b instanceof Set) { const f = { "|": set_union, "&": set_intersection, "-": set_difference, "^": set_symmetric_difference }[op]; if (f) return f(a, b); }
    raise(TypeError, "unsupported operand type(s) for " + op + ": '" + typeName(a) + "' and '" + typeName(b) + "'");
}
const DUNDER = { "+": "__add__", "-": "__sub__", "*": "__mul__", "/": "__truediv__", "//": "__floordiv__", "%": "__mod__", "**": "__pow__", "<<": "__lshift__", ">>": "__rshift__", "&": "__and__", "|": "__or__", "^": "__xor__", "@": "__matmul__" };
export const NotImplemented = Object.freeze({ toString: () => "NotImplemented" });
export const Ellipsis = Object.freeze({ toString: () => "Ellipsis" });
export function neg(a) { if (a instanceof Obj && typeof a.__neg__ === "function") return a.__neg__(); if (typeof a === "number" || typeof a === "boolean") return -a; raise(TypeError, "bad operand type for unary -: '" + typeName(a) + "'"); }
export function seq_mul(a, n) {
    if (typeof a === "string") return n > 0 ? a.repeat(n) : "";
    let r = [];
    for (let i = 0; i < n; i++) r = r.concat(a);
    return a instanceof Tuple ? Tuple.from(r) : r;
}
// `xs += ys` on a list: in place, as Python's is.
export function list_iadd(xs, ys) { for (const v of iter(ys)) xs.push(v); return xs; }
// `a op= b` of a value typed `any`: what it holds changed in place where
// Python changes it in place (a list, a bytearray, a set, a dict, an object
// with the operator's in-place method), else `a op b`.
export function idyn(op, a, b) {
    if (a instanceof Obj) {
        const m = "__i" + DUNDER[op].slice(2);
        if (typeof a[m] === "function") { const r = a[m](b); if (r !== NotImplemented) return r; }
        return dyn(op, a, b);
    }
    const seq = Array.isArray(a) && !(a instanceof Tuple) ? a : a instanceof ByteArray ? a.b : undefined;
    if (seq && op === "+" && (Array.isArray(a) || b instanceof Bytes || b instanceof ByteArray)) { list_iadd(seq, b); return a; }
    if (seq && op === "*" && Number.isInteger(b)) { const once = seq.slice(); seq.length = 0; for (let i = 0; i < b; i++) for (const v of once) seq.push(v); return a; }
    if (a instanceof Set && !(a instanceof FrozenSet) && b instanceof Set) {
        const f = { "|": set_update, "&": set_intersection_update, "-": set_difference_update, "^": set_symmetric_difference_update }[op];
        if (f) { f(a, b); return a; }
    }
    if (op === "|" && a instanceof Map && b instanceof Map) { dict_update(a, b); return a; }
    return dyn(op, a, b);
}
// A Jac function's parameters, from its `$p`: each name marked by how a call
// binds it (`*name` the *args, `**name` the **kwargs, `/name` by position
// only, `!name` by keyword only) and `=` after it when it has a default.
const PARAMS = new WeakMap();
function paramsOf(marks) {
    let ps = PARAMS.get(marks);
    if (ps !== undefined) return ps;
    ps = marks.map((m) => {
        const dflt = m.endsWith("="), body = dflt ? m.slice(0, -1) : m;
        const kind = body.startsWith("**") ? "**" : "*/!".includes(body[0]) ? body[0] : "";
        return { name: body.slice(kind.length), kind, dflt };
    });
    PARAMS.set(marks, ps);
    return ps;
}
// Whether `o` is a value of Jac's: of a builtin type, a function Jac
// compiled, or an object of a class of the program's or of this runtime's
// (each marked `$jac`, below its classes). Any other is JavaScript's own.
function jac_own(o) {
    if (o === undefined || o === null) return true;
    if (typeof o === "function") return o.$p !== undefined || o.$cls !== undefined;
    if (typeof o !== "object" || o.$jac === true || Array.isArray(o) || o instanceof Map || o instanceof Set || o instanceof Bytes) return true;
    return typeof o.next === "function" && typeof o[Symbol.iterator] === "function";
}
// `x[k](...)`, the item of a value whose type the check doesn't know, called.
// Where `x` is JavaScript's own object and the item a function of
// JavaScript's, it is a method read by its key (`re[Symbol.replace]`), and
// is called as JavaScript calls `x[k](...)`: on `x`. An item of one of Jac's
// values (a list's, a dict's), and a function Jac compiled, is called as it is.
export function call_item(x, k, args, kws) {
    const f = getitem(x, k);
    const theirs = typeof f === "function" && f.$p === undefined && f.$cls === undefined && f.$self === undefined && !jac_own(x);
    return call(held(f), args, kws, theirs ? x : undefined);
}
// A call of a value whose type check doesn't know: a Jac function or class,
// whose parameters (`$p`, paramsOf) take the positional arguments and the
// keyword arguments `kws` (a Dict) as Python binds them, its errors worded
// as CPython's, naming it as `$q` does (a method's counting its self); or a
// JS function, handed what `plain` makes of each: a dict as an object.
export function call(f, args, kws, self) {
    if (typeof f !== "function") { if (f instanceof Obj && typeof f.__call__ === "function") return call(f.__call__, args, kws, f); raise(TypeError, "'" + typeName(f) + "' object is not callable"); }
    // (A builtin type's function has no class behind it: it is called as it is.)
    const marks = f.$cls ? f.$ctor || (f.prototype && f.prototype.init && f.prototype.init.$p) : f.$p;
    if (marks === undefined) {
        // No function Jac compiled. A builtin type's, or a method of one of
        // Jac's values, is this runtime's: it takes Jac's values as they
        // are. Any other is JavaScript's, and what it is handed is too.
        const on = self !== undefined ? self : f.$self;
        if (!f.$cls && !(on !== undefined && jac_own(on))) args = args.map(plain);
        return f.apply(self, kws && kws.size ? [...args, plain(kws)] : args);
    }
    const ps = paramsOf(marks), fname = f.$cls ? f.$name || f.name : f.$q || f.$name || f.name;
    const own = self !== undefined || f.$self !== undefined ? 1 : 0;
    const star = ps.findIndex((p) => p.kind === "*"), dstar = ps.findIndex((p) => p.kind === "**");
    let npos = 0;
    while (npos < ps.length && (ps[npos].kind === "" || ps[npos].kind === "/")) npos++;
    const given = [];
    for (let i = 0; i < Math.min(args.length, npos); i++) given[i] = args[i];
    if (args.length > npos && star < 0) {
        const ndflt = ps.slice(0, npos).filter((p) => p.dflt).length;
        rt_check_args(args.length + own, 0, npos + own, ndflt, [], 0, npos + own, fname);
    }
    if (star >= 0) given[star] = args.slice(npos);
    const extra = new Dict();
    if (kws) for (const [k, v] of kws) {
        const i = ps.findIndex((p) => p.name === k && (p.kind === "" || p.kind === "!"));
        if (i >= 0) {
            if (i in given) raise(TypeError, fname + "() got multiple values for argument '" + k + "'");
            given[i] = v;
        } else if (dstar >= 0) extra.set(k, v);
        else raise(TypeError, fname + "() got an unexpected keyword argument '" + k + "'");
    }
    for (const [kind, which] of [["positional", (p) => p.kind === "" || p.kind === "/"], ["keyword-only", (p) => p.kind === "!"]]) {
        const missing = ps.filter((p, i) => which(p) && !p.dflt && !(i in given)).map((p) => p.name);
        if (missing.length) raise(TypeError, fname + "() missing " + missing.length + " required " + kind + " argument" + (missing.length === 1 ? "" : "s") + ": " + nameList(missing));
    }
    if (dstar >= 0) given[dstar] = extra;
    // What's left out takes its default: the callee fills an argument it isn't
    // given, at the end or marked NA before one it is.
    let n = given.length;
    while (n > 0 && !(n - 1 in given)) n--;
    const out = given.slice(0, n);
    for (let i = 0; i < n; i++) if (!(i in out)) out[i] = NA;
    return f.$cls ? f.$new(...out) : (f.$b || f).apply(self, out);
}
// A method of `o` called by its name.
export function callattr(o, name, args, kws) {
    if (o instanceof Map && name in DICT_M) return DICT_M[name](o, ...args);
    if (Array.isArray(o) && name in LIST_M) return LIST_M[name](o, ...args);
    if (typeof o === "string" && typeof METHODS["str_" + name] === "function") return METHODS["str_" + name](o, ...args);
    if (o instanceof Set && typeof METHODS["set_" + name] === "function") return METHODS["set_" + name](o, ...args);
    if (o === undefined || o === null || typeof o[name] !== "function") return held(call(getattr(o, name), args, kws));
    // (A function one of Jac's objects keeps in a field is no method of it.)
    return held(o instanceof Obj && G.Object.hasOwn(o, name) ? call(o[name], args, kws) : call(o[name], args, kws, o));
}
// A component's `**props`: the props it was given that none of its
// parameters `named` takes, as a dict, each as given.
export const props_of = (p, named) => new Dict(G.Object.entries(p).filter(([k]) => !named.includes(k)));
// A value handed to JavaScript: a dict a plain object of it and a list an
// array, each deeply, and a Jac function one JavaScript calls (js_fn).
export function plain(x) {
    if (x instanceof Map) { const o = {}; for (const [k, v] of x) o[k] = plain(v); return o; }
    if (Array.isArray(x)) return x.map(plain);
    if (typeof x === "function") return js_fn(x);
    return x;
}
// A Jac function handed to JavaScript, which calls it as its own: a
// coroutine the call makes is run, and JavaScript gets its promise (an
// event handler that is an `async def` so does its work). One function
// stays one JavaScript value, so what was added by it can be removed by it;
// and it is still the Jac function to Jac, which binds a call of it by the
// same parameters and awaits what it gives.
const jsFns = new WeakMap();
export function js_fn(f) {
    if (typeof f !== "function" || f.$p === undefined || f.$cls || f.$js) return f;
    let w = jsFns.get(f);
    if (w === undefined) {
        w = function (...a) { const r = f.apply(this, a); return r instanceof Coroutine ? run(r) : r; };
        w.$js = true; w.$p = f.$p; w.$q = f.$q; w.$name = f.$name || f.name; w.$self = f.$self;
        jsFns.set(f, w);
    }
    return w;
}
// A dict spread over a component of the program's: its props, each as it is
// but a function (js_fn).
export function attrs(d) { const o = {}; for (const [k, v] of d) o[k] = js_fn(v); return o; }

// ---- the methods of the builtin types (rt/methods.jac's names)
const ws = /^[\s\x1c-\x1f]+|[\s\x1c-\x1f]+$/g;
function strip(s, chars, l, r) {
    if (chars === undefined) return l && r ? s.replace(ws, "") : l ? s.replace(/^[\s\x1c-\x1f]+/, "") : s.replace(/[\s\x1c-\x1f]+$/, "");
    const cs = Array.from(s), set = Array.from(chars);
    let a = 0, b = cs.length;
    if (l) while (a < b && set.includes(cs[a])) a++;
    if (r) while (b > a && set.includes(cs[b - 1])) b--;
    return cs.slice(a, b).join("");
}
function within(s, start, end) { const w = wide(s) || s; const [a, b] = span(w.length, start, end, 1); return [Array.isArray(w) ? w.slice(a, b).join("") : w.slice(a, b), a]; }
function upos(s, i) { return wide(s) ? Array.from(s.slice(0, i)).length : i; }
export const str_capitalize = (s) => { const cs = Array.from(s); return cs.length ? cs[0].toUpperCase() + cs.slice(1).join("").toLowerCase() : s; };
export const str_casefold = (s) => s.toUpperCase().toLowerCase();
export const str_center = (s, w, f = " ") => { const n = slen(s); if (w <= n) return s; const p = w - n, l = Math.floor(p / 2) + (p & w & 1); return f.repeat(l) + s + f.repeat(p - l); };
export const str_count = (s, x, start, end) => { const [t] = within(s, start, end); if (x === "") return slen(t) + 1; let n = 0, i = 0; while ((i = t.indexOf(x, i)) >= 0) { n++; i += x.length; } return n; };
export const str_encode = (s) => Bytes.from(new TextEncoder().encode(s));
const affix = (s, p, start, end, f) => { const [t] = within(s, start, end); return p instanceof Tuple || Array.isArray(p) ? p.some((x) => f(t, x)) : f(t, p); };
export const str_endswith = (s, p, start, end) => affix(s, p, start, end, (t, x) => t.endsWith(x));
export const str_startswith = (s, p, start, end) => affix(s, p, start, end, (t, x) => t.startsWith(x));
export const str_expandtabs = (s, n = 8) => s.split("\n").map((line) => { let o = ""; for (const c of line) o += c === "\t" ? " ".repeat(n - (slen(o) % n || 0) || n) : c; return o; }).join("\n");
export const str_find = (s, x, start, end) => { const [t, a] = within(s, start, end); const i = t.indexOf(x); return i < 0 ? -1 : a + upos(t, i); };
export const str_rfind = (s, x, start, end) => { const [t, a] = within(s, start, end); const i = t.lastIndexOf(x); return i < 0 ? -1 : a + upos(t, i); };
export const str_index = (s, x, start, end) => { const i = str_find(s, x, start, end); if (i < 0) raise(ValueError, "substring not found"); return i; };
export const str_rindex = (s, x, start, end) => { const i = str_rfind(s, x, start, end); if (i < 0) raise(ValueError, "substring not found"); return i; };
export const str_isalnum = (s) => /^[\p{L}\p{N}]+$/u.test(s);
export const str_isalpha = (s) => /^\p{L}+$/u.test(s);
export const str_isascii = (s) => /^[\x00-\x7f]*$/.test(s);
export const str_isdecimal = (s) => /^\p{Nd}+$/u.test(s);
export const str_isdigit = (s) => /^\p{Nd}+$/u.test(s);
export const str_isnumeric = (s) => /^\p{N}+$/u.test(s);
export const str_isidentifier = (s) => /^[\p{L}_][\p{L}\p{N}_]*$/u.test(s);
export const str_isprintable = (s) => !/[\p{C}]/u.test(s);
export const str_isspace = (s) => /^\s+$/.test(s);
export const str_islower = (s) => /\p{Ll}/u.test(s) && !/\p{Lu}/u.test(s);
export const str_isupper = (s) => /\p{Lu}/u.test(s) && !/\p{Ll}/u.test(s);
export const str_istitle = (s) => /\p{L}/u.test(s) && s === str_title(s);
export const str_join = (s, xs) => Array.from(iter(xs), (x, i) => { if (typeof x !== "string") raise(TypeError, "sequence item " + i + ": expected str instance, " + typeName(x) + " found"); return x; }).join(s);
export const str_ljust = (s, w, f = " ") => s + f.repeat(Math.max(0, w - slen(s)));
export const str_rjust = (s, w, f = " ") => f.repeat(Math.max(0, w - slen(s))) + s;
export const str_lower = (s) => s.toLowerCase();
export const str_upper = (s) => s.toUpperCase();
export const str_swapcase = (s) => Array.from(s, (c) => (c === c.toUpperCase() ? c.toLowerCase() : c.toUpperCase())).join("");
export const str_title = (s) => s.replace(/\p{L}+/gu, (w) => w[0].toUpperCase() + w.slice(1).toLowerCase());
export const str_lstrip = (s, c) => strip(s, c, true, false);
export const str_rstrip = (s, c) => strip(s, c, false, true);
export const str_strip = (s, c) => strip(s, c, true, true);
export const str_partition = (s, x) => { const i = s.indexOf(x); return i < 0 ? tup(s, "", "") : tup(s.slice(0, i), x, s.slice(i + x.length)); };
export const str_rpartition = (s, x) => { const i = s.lastIndexOf(x); return i < 0 ? tup("", "", s) : tup(s.slice(0, i), x, s.slice(i + x.length)); };
export const str_removeprefix = (s, p) => (p && s.startsWith(p) ? s.slice(p.length) : s);
export const str_removesuffix = (s, p) => (p && s.endsWith(p) ? s.slice(0, -p.length) : s);
export function str_replace(s, a, b, n = -1) {
    if (n < 0) return a === "" ? Array.from(s).join(b).replace(/^/, b) + b : s.split(a).join(b);
    let out = "", rest = s;
    for (let k = 0; k < n; k++) { const i = rest.indexOf(a); if (i < 0) break; out += rest.slice(0, i) + b; rest = rest.slice(i + a.length); }
    return out + rest;
}
export function str_split(s, sep, maxsplit = -1) {
    if (sep === undefined) {
        const out = [];
        let rest = s.replace(/^\s+/, "");
        while (rest !== "") {
            if (maxsplit >= 0 && out.length === maxsplit) { out.push(rest.replace(/\s+$/, "")); break; }
            const m = /\s+/.exec(rest);
            if (!m) { out.push(rest); break; }
            out.push(rest.slice(0, m.index));
            rest = rest.slice(m.index + m[0].length);
        }
        return out;
    }
    if (sep === "") raise(ValueError, "empty separator");
    const parts = s.split(sep);
    return maxsplit < 0 || parts.length <= maxsplit + 1 ? parts : [...parts.slice(0, maxsplit), parts.slice(maxsplit).join(sep)];
}
export function str_rsplit(s, sep, maxsplit = -1) {
    if (maxsplit < 0) return str_split(s, sep);
    if (sep === undefined) { const all = str_split(s); return all.length <= maxsplit + 1 ? all : [s.trimEnd().slice(0, s.trimEnd().length - all.slice(all.length - maxsplit).join(" ").length).trimEnd(), ...all.slice(all.length - maxsplit)]; }
    const parts = s.split(sep);
    return parts.length <= maxsplit + 1 ? parts : [parts.slice(0, parts.length - maxsplit).join(sep), ...parts.slice(parts.length - maxsplit)];
}
export function str_splitlines(s, keep = false) {
    const out = [], re = /\r\n|[\n\r\v\f\x1c-\x1e\x85\p{Zl}\p{Zp}]/gu;
    let at = 0, m;
    while ((m = re.exec(s))) { out.push(s.slice(at, keep ? m.index + m[0].length : m.index)); at = m.index + m[0].length; }
    if (at < s.length) out.push(s.slice(at));
    return out;
}
export const str_zfill = (s, w) => { const n = slen(s); if (w <= n) return s; const sign = s[0] === "+" || s[0] === "-" ? s[0] : ""; return sign + "0".repeat(w - n) + s.slice(sign.length); };
export const str_translate = (s, table) => Array.from(s, (c) => { const v = table.get(c.codePointAt(0)); return v === undefined ? (table.has(c.codePointAt(0)) ? "" : c) : typeof v === "number" ? String.fromCodePoint(v) : v; }).join("");
export const str_maketrans = (x, y = "", z = "") => { const d = new Dict(); if (x instanceof Map) { for (const [k, v] of x) d.set(typeof k === "string" ? k.codePointAt(0) : k, v); return d; } const a = Array.from(x), b = Array.from(y); a.forEach((c, i) => d.set(c.codePointAt(0), b[i].codePointAt(0))); for (const c of z) d.set(c.codePointAt(0), undefined); return d; };
export const str_format_map = (s, m) => str_format(s, [], m);
export const str_mul = (s, n) => (n > 0 ? s.repeat(n) : "");
// A str's character at `i` (as `for` and `[]` count them, by code point).
export const str_at = (s, i) => getitem(s, i);
export const bytes_decode = (b) => new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(bytesOf(b)));
export const bytearray_decode = bytes_decode;
export const bytes_hex = (b) => Array.from(bytesOf(b), (v) => v.toString(16).padStart(2, "0")).join("");
export const bytearray_hex = bytes_hex;
// Python's bytes.fromhex: pairs of hex digits, ASCII whitespace between pairs
// only, and its two errors.
const hexDigit = (c) => (c >= 48 && c <= 57 ? c - 48 : c >= 97 && c <= 102 ? c - 87 : c >= 65 && c <= 70 ? c - 55 : -1);
export function bytes_fromhex(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const c = s.charCodeAt(i);
        if (c === 32 || (c >= 9 && c <= 13)) { i++; continue; }
        const hi = hexDigit(c);
        if (hi < 0) raise(ValueError, `non-hexadecimal number found in fromhex() arg at position ${i}`);
        if (i + 1 >= s.length) raise(ValueError, "fromhex() arg must contain an even number of hexadecimal digits");
        const lo = hexDigit(s.charCodeAt(i + 1));
        if (lo < 0) raise(ValueError, `non-hexadecimal number found in fromhex() arg at position ${i + 1}`);
        out.push(hi * 16 + lo);
        i += 2;
    }
    return Bytes.from(out);
}
export const bytes_lower = (b) => Bytes.from(b, (v) => (v >= 65 && v <= 90 ? v + 32 : v));
export const bytes_upper = (b) => Bytes.from(b, (v) => (v >= 97 && v <= 122 ? v - 32 : v));
export const bytes_isascii = (b) => Array.prototype.every.call(bytesOf(b), (v) => v < 128);
// A bytes method as the str method over its bytes as Latin-1 text: its
// first argument a bytes or a byte (an int), any after it positions.
const viaText = (f) => (b, ...a) => {
    const t = (x) => (x === undefined ? undefined : String.fromCharCode(...bytesOf(x)));
    const r = f(t(b), ...a.map((x, i) => (i === 0 && typeof x === "number" ? String.fromCharCode(x) : typeof x === "number" ? x : t(x))));
    const back = (s) => Bytes.from(s, (c) => c.charCodeAt(0));
    return Array.isArray(r) ? r.map(back) : typeof r === "string" ? (b instanceof ByteArray ? new ByteArray(back(r)) : back(r)) : r;
};
export const bytes_count = viaText(str_count);
export const bytes_find = viaText(str_find);
export const bytes_rfind = viaText(str_rfind);
export const bytes_index = viaText(str_index);
export const bytes_rindex = viaText(str_rindex);
// bytes.startswith and endswith: the affix a bytes, a bytearray or a tuple of
// them, looked for in the bytes from `start` up to `end`, as a slice's are.
const bytes_affix = (name, ends) => (b, p, start, end) => {
    const isBytes = (x) => x instanceof Bytes || x instanceof ByteArray;
    if (!isBytes(p) && !(p instanceof Tuple && p.every(isBytes))) raise(TypeError, name + " first arg must be bytes or a tuple of bytes, not " + typeName(p instanceof Tuple ? p.find((x) => !isBytes(x)) : p));
    const all = bytesOf(b), n = all.length;
    const lo = start === undefined ? 0 : start < 0 ? Math.max(0, n + start) : start;
    const hi = end === undefined ? n : end < 0 ? Math.max(0, n + end) : Math.min(end, n);
    if (lo > n) return false;
    const one = (x) => { const y = bytesOf(x), at = ends ? hi - y.length : lo; if (y.length > hi - lo) return false; for (let i = 0; i < y.length; i++) if (all[at + i] !== y[i]) return false; return true; };
    return p instanceof Tuple ? p.some(one) : one(p);
};
export const bytes_startswith = bytes_affix("startswith", false);
export const bytes_endswith = bytes_affix("endswith", true);
export const bytearray_startswith = bytes_startswith;
export const bytearray_endswith = bytes_endswith;
export const bytes_isdigit = (b) => bytesOf(b).length > 0 && Array.prototype.every.call(bytesOf(b), (v) => v >= 48 && v <= 57);
// bytes.maketrans and translate: a table of 256 bytes, each byte's its
// place in it; `del` the bytes left out.
export function bytes_maketrans(frm, to) {
    const a = bytesOf(frm), b = bytesOf(to);
    if (a.length !== b.length) raise(ValueError, "maketrans arguments must have same length");
    const t = Bytes.from({ length: 256 }, (_, i) => i);
    for (let i = 0; i < a.length; i++) t[a[i]] = b[i];
    return t;
}
export function bytes_translate(b, table, del) {
    const t = table === undefined || table === null ? undefined : bytesOf(table);
    if (t !== undefined && t.length !== 256) raise(ValueError, "translation table must be 256 characters long");
    const gone = new Set(del === undefined ? [] : bytesOf(del));
    return Bytes.from(Array.from(bytesOf(b)).filter((v) => !gone.has(v)).map((v) => (t === undefined ? v : t[v])));
}
// Where bytes `x` is in bytes `b`, the first place or the last; -1 for none.
const bytes_at = (b, x, last) => {
    const n = b.length - x.length;
    for (let k = 0; k <= n; k++) { const i = last ? n - k : k; let same = true; for (let j = 0; j < x.length && same; j++) same = b[i + j] === x[j]; if (same) return i; }
    return -1;
};
const bytes_part = (last) => (b, sep) => {
    const xs = Bytes.from(bytesOf(b)), x = bytesOf(sep);
    if (x.length === 0) raise(ValueError, "empty separator");
    const i = bytes_at(xs, x, last), none = new Bytes(0);
    if (i < 0) return last ? tup(none, none, xs) : tup(xs, none, none);
    return tup(xs.slice(0, i), Bytes.from(x), xs.slice(i + x.length));
};
export const bytes_partition = bytes_part(false);
export const bytes_rpartition = bytes_part(true);
export const bytearray_count = bytes_count;
export const bytearray_find = bytes_find;
export const bytearray_index = bytes_index;
export const bytes_replace = viaText(str_replace);
export const bytes_split = viaText(str_split);
export const bytes_strip = viaText(str_strip);
export const bytes_lstrip = viaText(str_lstrip);
export const bytes_rstrip = viaText(str_rstrip);
export const bytes_join = (b, xs) => Bytes.from(Array.from(iter(xs)).flatMap((x, i) => (i ? [...bytesOf(b), ...bytesOf(x)] : [...bytesOf(x)])));
export const bytearray_append = (b, v) => { b.b.push(v); };
export const bytearray_clear = (b) => { b.b.length = 0; };
export const bytearray_copy = (b) => new ByteArray(b.b);
export const bytearray_extend = (b, xs) => { for (const v of iter(xs)) b.b.push(v); };
export const bytearray_insert = (b, i, v) => { b.b.splice(i < 0 ? Math.max(0, b.b.length + i) : i, 0, v); };
export const bytearray_pop = (b, i = -1) => { if (!b.b.length) raise(IndexError, "pop from empty bytearray"); return b.b.splice(index(i, b.b.length, "pop"), 1)[0]; };
export const bytearray_remove = (b, v) => { const i = b.b.indexOf(v); if (i < 0) raise(ValueError, "value not found in bytearray"); b.b.splice(i, 1); };
export const bytearray_reverse = (b) => { b.b.reverse(); };
export const int_bit_count = (x) => Math.abs(x).toString(2).replace(/0/g, "").length;
export const int_bit_length = (x) => (x === 0 ? 0 : Math.abs(x).toString(2).length);
export const int_as_integer_ratio = (x) => tup(x, 1);
export const int_conjugate = (x) => x;
export const int_from_bytes = (b, order = "big", signed = false) => { let a = Array.from(bytesOf(b)); if (order === "little") a.reverse(); let v = 0n; for (const x of a) v = (v << 8n) | BigInt(x); if (signed && a.length && a[0] & 0x80) v -= 1n << BigInt(8 * a.length); return ovf(Number(v)); };
export const int_to_bytes = (x, n = 1, order = "big", signed = false) => { let v = BigInt(x); if (v < 0n) { if (!signed) raise(OverflowError, "can't convert negative int to unsigned"); v += 1n << BigInt(8 * n); } const out = []; for (let i = 0; i < n; i++) { out.unshift(Number(v & 255n)); v >>= 8n; } if (v !== 0n) raise(OverflowError, "int too big to convert"); return Bytes.from(order === "little" ? out.reverse() : out); };
export const float_is_integer = (x) => Number.isInteger(x);
export const float_conjugate = (x) => x;
export const float_as_integer_ratio = (x) => { if (!Number.isFinite(x)) raise(Number.isNaN(x) ? ValueError : OverflowError, "cannot convert " + fstr(x) + " to integer ratio"); let d = 1; while (!Number.isInteger(x)) { x *= 2; d *= 2; } return tup(x, d); };
// float.hex: its sign, its 52 bits of mantissa in hex after a leading 1
// (0 for a subnormal) and its binary exponent.
export function float_hex(x) {
    if (!Number.isFinite(x)) return fstr(x);
    const v = new DataView(new ArrayBuffer(8));
    v.setFloat64(0, x);
    const hi = v.getUint32(0), lo = v.getUint32(4), sign = hi >>> 31 ? "-" : "", e = (hi >>> 20) & 0x7ff;
    const mant = (hi & 0xfffff).toString(16).padStart(5, "0") + lo.toString(16).padStart(8, "0");
    if (e === 0 && mant === "0000000000000") return sign + "0x0.0p+0";
    const exp = e === 0 ? -1022 : e - 1023;
    return sign + "0x" + (e === 0 ? "0" : "1") + "." + mant + "p" + (exp < 0 ? "-" : "+") + Math.abs(exp);
}
export function float_fromhex(s) {
    const m = /^\s*([+-])?(?:0x)?([0-9a-f]*)(?:\.([0-9a-f]*))?(?:p([+-]?\d+))?\s*$/i.exec(s);
    if (!m || (m[2] === "" && (m[3] === undefined || m[3] === ""))) raise(ValueError, "invalid hexadecimal floating-point string");
    let v = parseInt(m[2] || "0", 16);
    const frac = m[3] || "";
    for (let i = 0; i < frac.length; i++) v += parseInt(frac[i], 16) / 16 ** (i + 1);
    v *= 2 ** (m[4] ? +m[4] : 0);
    return m[1] === "-" ? -v : v;
}
export const range_count = (r, v) => (contains(r, v) ? 1 : 0);
export const range_index = (r, v) => { if (!contains(r, v)) raise(ValueError, v + " is not in range"); return (v - r.start) / r.step; };
export const list_clear = (l) => { l.length = 0; };
export const list_copy = (l) => l.slice();
export const list_reverse = (l) => { l.reverse(); };
export const list_count = (l, v) => l.reduce((n, x) => n + (eq(x, v) ? 1 : 0), 0);
export const list_index = (l, v, start = 0, stop = MAX) => { const [a, b] = span(l.length, start, stop, 1); for (let i = a; i < b; i++) if (eq(l[i], v)) return i; raise(ValueError, repr(v) + " is not in list"); };
export const list_pop = (l, i = -1) => { if (!l.length) raise(IndexError, "pop from empty list"); return l.splice(index(i, l.length, "pop"), 1)[0]; };
export const list_remove = (l, v) => { for (let i = 0; i < l.length; i++) if (eq(l[i], v)) { l.splice(i, 1); return; } raise(ValueError, "list.remove(x): x not in list"); };
export const list_extend = (l, xs) => { if (xs === l) xs = l.slice(); for (const v of iter(xs)) l.push(v); };
export const list_insert = (l, i, v) => { l.splice(i < 0 ? Math.max(0, l.length + i) : Math.min(i, l.length), 0, v); };
export const tuple_count = list_count;
export const tuple_index = list_index;
export const dict_clear = (d) => { d.clear(); };
export const dict_copy = (d) => dict(d);
export const dict_get = (d, k, v) => (d.has(k) ? d.get(k) : v);
export const dict_pop = (d, k, ...v) => { if (d.has(k)) { const r = d.get(k); d.delete(k); return r; } if (v.length) return v[0]; raise(KeyError, k); };
export const dict_setdefault = (d, k, v) => { if (!d.has(k)) d.set(k, v); return d.get(k); };
export const dict_popitem = (d) => { if (!d.size) raise(KeyError, "popitem(): dictionary is empty"); const k = Array.from(d.keys()).pop(), v = d.get(k); d.delete(k); return tup(k, v); };
export const dict_update = (d, o, kws) => { if (o !== undefined) for (const [k, v] of o instanceof Map ? o : Array.from(iter(o), (p) => unpack(p, 2))) d.set(k, v); if (kws) for (const [k, v] of kws) d.set(k, v); };
// A dict's keys, values or items: a view, which follows the dict.
export class View {
    constructor(d, kind) { this.d = d; this.kind = kind; }
    get length() { return this.d.size; }
    [Symbol.iterator]() { const k = this.kind, d = this.d; return k === "dict_keys" ? new Walk(d, d.keys()) : k === "dict_values" ? new Walk(d, d.values()) : new Walk(d, d.entries(), (e) => tup(e[0], e[1])); }
}
export const dict_items = (d) => new View(d, "dict_items");
export const dict_keys = (d) => new View(d, "dict_keys");
export const dict_values = (d) => new View(d, "dict_values");
export const dict_fromkeys = (ks, v) => { const d = new Dict(); for (const k of iter(ks)) d.set(k, v); return d; };
export const dict_merge = (a, b) => { const d = dict(a); for (const [k, v] of b) d.set(k, v); return d; };
export const set_clear = (s) => { s.clear(); };
export const set_copy = (s) => (s instanceof FrozenSet ? frozen_of(s) : set_of(s));
const like = (s, items) => (s instanceof FrozenSet ? frozen_of(items) : set_of(items));
export const set_union = (s, ...os) => like(s, [...s, ...os.flatMap((o) => Array.from(iter(o)))]);
export const set_intersection = (s, o) => { const b = set(o); return like(s, [...s].filter((x) => b.has(x))); };
export const set_difference = (s, o) => { const b = set(o); return like(s, [...s].filter((x) => !b.has(x))); };
export const set_symmetric_difference = (s, o) => { const b = set(o); return like(s, [...[...s].filter((x) => !b.has(x)), ...[...b].filter((x) => !s.has(x))]); };
export const set_update = (s, o) => { for (const x of iter(o)) s.add(x); };
export const set_add = (s, x) => { s.add(x); };
export const set_difference_update = (s, o) => { for (const x of iter(o)) s.delete(x); };
export const set_intersection_update = (s, o) => { const b = set(o); for (const x of [...s]) if (!b.has(x)) s.delete(x); };
export const set_symmetric_difference_update = (s, o) => { for (const x of set(o)) if (!s.delete(x)) s.add(x); };
export const set_discard = (s, x) => { s.delete(x); };
export const set_remove = (s, x) => { if (!s.delete(x)) raise(KeyError, x); };
export const set_pop = (s) => { if (!s.size) raise(KeyError, "pop from an empty set"); const x = s.values().next().value; s.delete(x); return x; };
export const set_isdisjoint = (s, o) => [...iter(o)].every((x) => !s.has(x));
export const set_issubset = (s, o) => { const b = set(o); return [...s].every((x) => b.has(x)); };
export const set_issuperset = (s, o) => [...iter(o)].every((x) => s.has(x));
const METHODS = { str_split, str_strip };
for (const [k, v] of Object.entries({ str_capitalize, str_casefold, str_center, str_count, str_encode, str_endswith, str_startswith, str_find, str_rfind, str_index, str_rindex, str_join, str_ljust, str_rjust, str_lower, str_upper, str_lstrip, str_rstrip, str_partition, str_rpartition, str_replace, str_rsplit, str_splitlines, str_title, str_zfill, str_isdigit, str_isalpha, str_isalnum, str_isspace, str_isupper, str_islower, set_add, set_union, set_intersection, set_difference, set_discard, set_remove, set_update, set_pop })) METHODS[k] = v;
const LIST_M = { append: (l, v) => { l.push(v); }, extend: list_extend, insert: list_insert, pop: list_pop, remove: list_remove, index: list_index, count: list_count, reverse: list_reverse, copy: list_copy, clear: list_clear, sort: (l) => list_sort(l) };
const DICT_M = { get: dict_get, pop: dict_pop, setdefault: dict_setdefault, keys: dict_keys, values: dict_values, items: dict_items, update: dict_update, copy: dict_copy, clear: dict_clear, popitem: dict_popitem };

// ---- memory regions, erased on a JS host once the checks have run:
// a handle holds nothing, what an open region's block makes is
// the host's memory management's to free, and no object is in a region.
export class Region extends Obj {
    init() {}
    // A child region of this one.
    partition() { return new Region().$init(); }
}
Region.$name = "Region"; Region.$fields = []; Region.$ctor = [];
export const region_of = (x) => undefined;

// ---- flow and wait: a JS host has one thread for a program's code, so
// `flow e` computes e then and there, keeping its value or what it raised,
// and `wait t` gives the value or raises what it raised.
// A task's type is this class, a type as the builtin ones are: named Task.
export class Task { static $cls = true; static $name = "Task"; static __name__ = "Task"; constructor(value, error, failed) { this.value = value; this.error = error; this.failed = failed; } }
export function flow(compute) { try { return new Task(compute(), undefined, false); } catch (e) { return new Task(undefined, e, true); } }
export function wait(t) { if (t.failed) throw t.error; return t.value; }

// ---- coroutines: an async function's body is a generator, which its
// Coroutine drives: an await delegates to what it awaits (`yield* aw(x)`),
// whose suspensions go to what drives the outermost coroutine (send, or a
// JS host's promise jobs, `run`), as Python's do.
export class Coroutine {
    constructor(g, name) { this.g = g; this.name = name; this.st = 0; }
    $go(how, v) {
        if (this.st === 2) raise(RuntimeError, "cannot reuse already awaited coroutine");
        this.st = 1;
        let r;
        try { r = this.g[how](v); } catch (e) { this.st = 2; throw e; }
        if (r.done) { this.st = 2; const e = exc(StopIteration); e.value = r.value; e.args = tup(r.value); throw e; }
        return r.value;
    }
    send(v) { return this.$go("next", v); }
    throw(e) { return this.$go("throw", e); }
    close() { if (this.st !== 2) { this.st = 2; this.g.return(undefined); } }
    __await__() { return aw(this); }
    // A JS host awaiting it runs it on its promise jobs.
    then(ok, fail) { return run(this).then(ok, fail); }
}
export const coro = (g, name) => new Coroutine(g, name);
// A generator closed or thrown into where it is paused, as Python's is:
// GeneratorExit is raised at its `yield`, and it may not answer with an item.
// An iterator that is no generator has nothing to close.
export function iterator_close(g) {
    if (g === null || g === undefined || typeof g.throw !== "function") return;
    let r;
    try { r = g.throw(exc(GeneratorExit)); } catch (e) { if (e instanceof GeneratorExit || e instanceof StopIteration) return; throw e; }
    if (!r.done) raise(RuntimeError, "generator ignored GeneratorExit");
}
export function iterator_throw(g, e) {
    if (g === null || g === undefined || typeof g.throw !== "function") throw e;
    const r = g.throw(e);
    if (r.done) throw exc(StopIteration);
    return r.value;
}
export const coroutine_send = (c, v) => c.send(v);
export const coroutine_throw = (c, e) => c.throw(e);
export const coroutine_close = (c) => c.close();
// What `await x` delegates to: a coroutine's own generator (once), an
// awaitable's __await__, or a JS promise, which the driver waits for.
export function aw(x) {
    if (x instanceof Coroutine) {
        if (x.st !== 0) raise(RuntimeError, "cannot reuse already awaited coroutine");
        x.st = 1;
        return (function* () { try { return yield* x.g; } finally { x.st = 2; } })();
    }
    if (x instanceof Obj && typeof x.__await__ === "function") return iter(x.__await__());
    if (x !== null && (typeof x === "object" || typeof x === "function") && typeof x.then === "function") return (function* () { return yield x; })();
    if (x !== null && typeof x === "object" && typeof x.next === "function" && typeof x.throw === "function") return x;
    raise(TypeError, "object " + typeName(x) + " can't be used in 'await' expression");
}
// A promise of what awaiting `x` gives, driven on the host's promise jobs: a
// promise it suspends on is waited for; any other suspension takes a turn.
export function run(x) {
    const it = aw(x);
    return new G.Promise((resolve, reject) => {
        const step = (how, v) => {
            let r;
            try { r = it[how](v); } catch (e) { reject(e); return; }
            if (r.done) { resolve(r.value); return; }
            const y = r.value;
            if (y !== null && (typeof y === "object" || typeof y === "function") && typeof y.then === "function") y.then((w) => step("next", w), (e) => step("throw", e));
            else G.queueMicrotask(() => step("next", undefined));
        };
        step("next", undefined);
    });
}
// An async generator: its body's generator yields its items (`item`) and,
// between them, what its awaits suspend on.
export class Item { constructor(v) { this.v = v; } }
export const item = (v) => new Item(v);
export class AsyncGen {
    constructor(g, name) { this.g = g; this.name = name; this.done = false; }
    __aiter__() { return this; }
    __anext__() { return this.$step("next", undefined); }
    asend(v) { return this.$step("next", v); }
    athrow(e) { return this.$step("throw", e); }
    aclose() { return this.$step("return", undefined); }
    $step(how, v) {
        const self = this;
        return new Coroutine((function* () {
            if (self.done) { if (how === "throw") throw v; if (how === "return") return undefined; raise(StopAsyncIteration); }
            let m = how, x = v;
            for (;;) {
                let r;
                try { r = self.g[m](x); } catch (e) { self.done = true; throw e; }
                if (r.done) { self.done = true; if (how === "return") return undefined; raise(StopAsyncIteration); }
                if (r.value instanceof Item) { if (how === "return") raise(RuntimeError, "async generator ignored GeneratorExit"); return r.value.v; }
                try { x = yield r.value; m = "next"; } catch (e) { x = e; m = "throw"; }
            }
        })(), how);
    }
    [Symbol.asyncIterator]() { return { next: () => run(this.__anext__()).then((value) => ({ value, done: false }), (e) => { if (e instanceof StopAsyncIteration) return { value: undefined, done: true }; throw e; }) }; }
}
export const agen = (g, name) => new AsyncGen(g, name);
// A JavaScript async iterator as Jac's own: what `async for` reads its items
// from (a stream endpoint's events, post_stream).
export class Stream {
    constructor(it) { this.it = it; }
    __aiter__() { return this; }
    __anext__() {
        const it = this.it;
        return new Coroutine((function* () {
            const r = yield it.next();
            if (r.done) raise(StopAsyncIteration);
            return r.value;
        })(), "__anext__");
    }
    aclose() {
        const it = this.it;
        return new Coroutine((function* () { if (it.return) yield it.return(); })(), "aclose");
    }
}
// This runtime's classes: their objects are Jac's values (jac_own).
for (const C of [Obj, BaseException, ByteArray, Range, Member, View, Task, Coroutine, Item, AsyncGen, Stream]) G.Object.defineProperty(C.prototype, "$jac", { value: true });
export const async_generator___aiter__ = (g) => g;
export const async_generator___anext__ = (g) => g.__anext__();
export const async_generator_asend = (g, v) => g.asend(v);
export const async_generator_athrow = (g, e) => g.athrow(e);
export const async_generator_aclose = (g) => g.aclose();

// ---- crossings: a call to another space, over its protocol
export class RemoteError extends Exception {
    constructor(space, endpoint, detail) { super(); this.message = detail || "the call to " + endpoint + " failed"; this.space = space; this.endpoint = endpoint; this.detail = detail; }
}
export class RemoteUnavailable extends RemoteError {}
export class RemoteTimeout extends RemoteError {}
export class RemoteRejected extends RemoteError {}
export class RemoteDecodeError extends RemoteError {}
export class RemoteFailed extends RemoteError {}
const KINDS = { rejected: RemoteRejected, failed: RemoteFailed, decode: RemoteDecodeError, timeout: RemoteTimeout, unavailable: RemoteUnavailable };
// Each class a crossing can carry, by its module's key and name.
const registry = new Map();
export function register(cls, key) { registry.set(key, cls); }
// Set `o`'s own field `k` to `x`. A key a crossing carries is data whatever
// it is called: assigning `__proto__` would set the object's prototype, so
// each is defined, as JSON.parse defines it.
function put(o, k, x) {
    G.Object.defineProperty(o, k, { value: x, writable: true, enumerable: true, configurable: true });
}
// A value from a crossing, as its declared classes where the program has them.
export function revive(v) {
    if (v === null) return undefined;
    if (Array.isArray(v)) return v.map(revive);
    if (typeof v !== "object") return v;
    const cls = G.Object.hasOwn(v, "__jac") && typeof v.__jac === "string" ? registry.get(v.__jac) : undefined;
    const out = cls ? new cls() : new Dict();
    for (const k of G.Object.keys(v)) if (k !== "__jac") { if (cls) put(out, k, revive(v[k])); else out.set(k, revive(v[k])); }
    return out;
}
// A value for a crossing, as `revive` reads it: each object of a declared
// class tagged with its key, and None as null. The class is the one the
// object was made from, its prototype's, never a field named `constructor`.
export function encode(v) {
    if (v === undefined || v === null) return null;
    if (Array.isArray(v)) return Array.from(v, encode);
    if (v instanceof Set) return Array.from(v, encode);
    if (v instanceof Map) { const o = {}; for (const [k, x] of v) put(o, k, encode(x)); return o; }
    if (v instanceof Member) return encode(v.value);
    if (typeof v === "object") {
        if (typeof v.toJSON === "function") return v.toJSON();
        const out = {};
        const proto = G.Object.getPrototypeOf(v);
        const cls = proto && G.Object.hasOwn(proto, "constructor") ? proto.constructor : undefined;
        if (cls && cls.$key) out.__jac = cls.$key;
        for (const [k, x] of G.Object.entries(v)) put(out, k, encode(x));
        return out;
    }
    return v;
}

const TOKEN_KEY = "jac_token";
// Hermes has no localStorage, so a token there lasts as long as the app's process.
let heldToken = "";
const tokenStore = () => { try { return typeof localStorage === "undefined" ? null : localStorage; } catch (_) { return null; } };
export const token = () => { const s = tokenStore(); return s ? s.getItem(TOKEN_KEY) || "" : heldToken; };
export function setToken(t) {
    const s = tokenStore();
    if (!s) heldToken = t || "";
    else if (t) s.setItem(TOKEN_KEY, t);
    else s.removeItem(TOKEN_KEY);
}
export const apiBase = () => G.__JAC_API_BASE_URL__ || "";
// An app with no server of its own says where each space is: `[apps.<app>.remote]`.
const spaceBase = (space) => (G.__JAC_REMOTES__ && G.__JAC_REMOTES__[space]) || apiBase();

// A JSON value as the Jac value it is: null None, a list a list, an object a
// dict of its members; and a Jac value as JSON's, the other way. What a
// crossing carries is encoded and decoded by its type (stdjac's codec),
// which gives and takes these.
function json_in(v) {
    if (v === null) return undefined;
    if (Array.isArray(v)) return v.map(json_in);
    if (typeof v !== "object") return v;
    const out = new Dict();
    for (const k of G.Object.keys(v)) out.set(k, json_in(v[k]));
    return out;
}
function json_out(v) {
    if (v === undefined || v === null) return null;
    if (Array.isArray(v)) return Array.from(v, json_out);
    if (v instanceof Map) { const o = {}; for (const [k, x] of v) put(o, k, json_out(x)); return o; }
    return v;
}
// A crossing's reply that isn't what its type says: the call failing.
export function decode_failed(space, name, detail) { throw new RemoteDecodeError(space, name, detail); }
// The JS hosts' transport (stdjac.crossing calls it): `body`, a dict of
// JSON's values, posted to `path` of the app that has `space`; the reply's
// data, as JSON's values.
export async function post(space, name, path, body) {
    body = json_out(body);
    // A space the process runs itself (a native app's, stdjac.node_space):
    // its port, in-process.
    const carried = G.__JAC_IN_PROCESS__ && G.__JAC_IN_PROCESS__[space];
    let data;
    if (carried) {
        const [, text] = await carried(path, JSON.stringify(body), "", true);
        try { data = JSON.parse(text); } catch (e) { throw new RemoteDecodeError(space, name, "the response is not JSON"); }
    } else {
        let res;
        const headers = { "Content-Type": "application/json" };
        const t = token();
        if (t) headers.Authorization = "Bearer " + t;
        try {
            res = await G.fetch(spaceBase(space) + path, { method: "POST", headers, body: JSON.stringify(body) });
        } catch (e) {
            throw new RemoteUnavailable(space, name, String(e));
        }
        try { data = await res.json(); } catch (e) { throw new RemoteDecodeError(space, name, "the response is not JSON (status " + res.status + ")"); }
    }
    if (!data.ok) {
        const Kind = KINDS[data.kind] || RemoteFailed;
        throw new Kind(space, name, data.detail);
    }
    return json_in(data.data);
}

// A stream reply's text as it comes: [status, content type] first, then each
// piece of the body. Read from fetch's body where the host's fetch has one,
// and from an XMLHttpRequest's progress where it has none (React Native's).
async function* streamed(url, headers, text) {
    if (typeof G.ReadableStream !== "undefined" || typeof G.XMLHttpRequest === "undefined") {
        const res = await G.fetch(url, { method: "POST", headers, body: text });
        yield [res.status, res.headers.get("content-type") || ""];
        if (!res.body) { yield await res.text(); return; }
        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        try {
            for (;;) {
                const part = await reader.read();
                if (part.done) return;
                yield decoder.decode(part.value, { stream: true });
            }
        } finally {
            reader.cancel().catch(() => {});
        }
    }
    const xhr = new G.XMLHttpRequest();
    const got = [];
    let wake = null, seen = 0, failed = null, ended = false, head = false;
    const step = () => { if (wake) { const w = wake; wake = null; w(); } };
    xhr.open("POST", url);
    for (const k of Object.keys(headers)) xhr.setRequestHeader(k, headers[k]);
    xhr.onreadystatechange = () => {
        if (xhr.readyState >= 2 && !head) { head = true; got.push([xhr.status, xhr.getResponseHeader("content-type") || ""]); }
        if (xhr.readyState >= 3 && xhr.responseText.length > seen) { got.push(xhr.responseText.slice(seen)); seen = xhr.responseText.length; }
        if (xhr.readyState === 4) ended = true;
        step();
    };
    xhr.onerror = () => { failed = new G.Error("the request failed"); step(); };
    xhr.send(text);
    try {
        for (;;) {
            while (got.length > 0) yield got.shift();
            if (failed) throw failed;
            if (ended) return;
            await new Promise((r) => { wake = r; });
        }
    } finally {
        if (!ended) xhr.abort();
    }
}

// A stream endpoint's call (stdjac.crossing's call_async_stream): its items,
// as JSON's values, each as its event comes. A call the server refuses raises
// as any call's does, before the first item; a stream that fails raises what
// its error event says where the item would have come; one cut short is
// RemoteUnavailable. A loop that leaves the stream early ends the request.
export function post_stream(space, name, path, body) {
    return new Stream(posted_events(space, name, path, body));
}

async function* posted_events(space, name, path, body) {
    body = json_out(body);
    const carried = G.__JAC_IN_PROCESS__ && G.__JAC_IN_PROCESS__[space];
    if (carried) {
        // A space the process runs itself: its port, which opens the stream
        // and is pulled for each item (stdjac.remote).
        const said = (text) => { try { return JSON.parse(text); } catch (e) { throw new RemoteDecodeError(space, name, "the response is not JSON"); } };
        const opened = said((await carried(path, JSON.stringify(body), "", true))[1]);
        if (!opened.ok) throw new (KINDS[opened.kind] || RemoteFailed)(space, name, opened.detail);
        if (typeof opened.stream !== "string") throw new RemoteDecodeError(space, name, "the reply is no stream");
        let ended = false;
        try {
            for (;;) {
                const got = said((await carried("/__jac/stream/" + opened.stream, "", "", true))[1]);
                if (!got.ok) { ended = true; throw new (KINDS[got.kind] || RemoteFailed)(space, name, got.detail); }
                if (got.end) { ended = true; return; }
                yield json_in(got.data);
            }
        } finally {
            if (!ended) await carried("/__jac/stream/" + opened.stream + "/close", "", "", true);
        }
    }
    const headers = { "Content-Type": "application/json" };
    const t = token();
    if (t) headers.Authorization = "Bearer " + t;
    const pieces = streamed(spaceBase(space) + path, headers, JSON.stringify(body));
    try {
        let first;
        try { first = await pieces.next(); } catch (e) { throw new RemoteUnavailable(space, name, String(e)); }
        const [status, type] = first.value;
        let buf = "";
        if (!type.startsWith("text/event-stream")) {
            for await (const piece of pieces) buf += piece;
            let data;
            try { data = JSON.parse(buf); } catch (e) { throw new RemoteDecodeError(space, name, "the response is not JSON (status " + status + ")"); }
            if (data.ok) throw new RemoteDecodeError(space, name, "the reply is no stream");
            const Kind = KINDS[data.kind] || RemoteFailed;
            throw new Kind(space, name, data.detail);
        }
        for (;;) {
            let part;
            try { part = await pieces.next(); } catch (e) { throw new RemoteUnavailable(space, name, String(e)); }
            if (part.done) throw new RemoteUnavailable(space, name, "the stream ended before its end");
            buf += part.value;
            for (let at = buf.indexOf("\n\n"); at >= 0; at = buf.indexOf("\n\n")) {
                const event = buf.slice(0, at);
                buf = buf.slice(at + 2);
                let kind = "", text = null;
                for (const line of event.split("\n")) {
                    if (line.startsWith("event: ")) kind = line.slice(7);
                    else if (line.startsWith("data: ")) text = line.slice(6);
                }
                // (A comment keeps the stream alive, and carries nothing.)
                if (text === null) continue;
                let data;
                try { data = JSON.parse(text); } catch (e) { throw new RemoteDecodeError(space, name, "an event is not JSON"); }
                if (kind === "end") return;
                if (kind === "error") {
                    const Kind = KINDS[data.kind] || RemoteFailed;
                    throw new Kind(space, name, data.detail);
                }
                yield json_in(data);
            }
        }
    } finally {
        pieces.return().catch(() => {});
    }
}

export async function authPost(path, body) {
    const res = await G.fetch(apiBase() + "/__jac/auth/" + path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    const data = await res.json();
    if (!data.ok) throw new RemoteRejected("auth", path, data.detail);
    return data.data;
}

// A hook's object: these fields read what they follow, whenever they're read.
export function live(o, getters) {
    for (const k of Object.keys(getters)) G.Object.defineProperty(o, k, { get: getters[k], enumerable: true, configurable: true });
    return o;
}

// A `wasm` space in the page: its module loads on the first call, with the host
// its page bound. It runs on no OS: WASI's calls do what a page can.
const wasmHosts = new Map();
const wasmLoading = new Map();
export function bindWasmHost(space, host) { wasmHosts.set(space, host); }

function wasiImports(getMemory) {
    const text = new TextDecoder();
    return {
        environ_get: () => 0,
        environ_sizes_get: (count, size) => { const v = new DataView(getMemory().buffer); v.setUint32(count, 0, true); v.setUint32(size, 0, true); return 0; },
        fd_close: () => 0,
        fd_fdstat_get: () => 8,
        fd_pread: () => 8,
        fd_prestat_get: () => 8,
        fd_prestat_dir_name: () => 8,
        fd_read: () => 8,
        fd_seek: () => 8,
        fd_write: (fd, iovs, n, written) => {
            const m = getMemory().buffer, v = new DataView(m);
            let total = 0, s = "";
            for (let i = 0; i < n; i++) {
                const p = v.getUint32(iovs + i * 8, true), l = v.getUint32(iovs + i * 8 + 4, true);
                s += text.decode(new Uint8Array(m, p, l));
                total += l;
            }
            v.setUint32(written, total, true);
            (fd === 2 ? console.error : console.log)(s);
            return 0;
        },
        proc_exit: (code) => { throw new G.Error("the wasm space exited: " + code); },
    };
}

async function loadWasm(space) {
    const host = wasmHosts.get(space);
    const url = "/static/" + space + ".wasm";
    const res = await G.fetch(url);
    if (!res.ok) throw new RemoteUnavailable(space, "load", url + ": " + res.status);
    const mod = await G.WebAssembly.compile(await res.arrayBuffer());
    let inst;
    const memory = () => inst.exports.memory;
    const imports = { wasi_snapshot_preview1: wasiImports(memory) };
    for (const imp of G.WebAssembly.Module.imports(mod)) {
        if (imp.module === "wasi_snapshot_preview1") continue;
        imports[imp.module] = imports[imp.module] || {};
        if (!host || typeof host[imp.name] !== "function") {
            imports[imp.module][imp.name] = () => { throw new G.Error("the wasm space's host has no " + imp.name); };
        } else {
            imports[imp.module][imp.name] = (...args) => {
                const r = host[imp.name](...args);
                return r === undefined ? 0 : r === true ? 1 : r === false ? 0 : r;
            };
        }
    }
    inst = await G.WebAssembly.instantiate(mod, imports);
    if (host) { host.exports = inst.exports; host.mem = inst.exports.memory; }
    inst.exports._initialize();
    return inst;
}

export function wasm_export(space, name) {
    const f = async (...args) => {
        if (!wasmLoading.has(space)) wasmLoading.set(space, loadWasm(space));
        const inst = await wasmLoading.get(space);
        // Jac's ints and handles are 64-bit, which JavaScript gives wasm as BigInt.
        const r = inst.exports[name](...args.map((x) => (Number.isInteger(x) ? BigInt(x) : x)));
        return typeof r === "bigint" ? Number(r) : r;
    };
    f.__jacSpace = space;
    return f;
}
