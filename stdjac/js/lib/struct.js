// Python's struct module on a JS host (rt/struct.jac's names): values packed
// into bytes and unpacked from them, by a format of byte order and item codes.
// A compiled module imports it as it uses it.
import { Bytes, Tuple, exc, OverflowError, TypeError, bytes } from "../core.js";

// What `<`, `>`, `!` and `=` give each code (standard sizes, no padding), and
// `@` (native: sizes and alignment of the host's C, little-endian).
const STD = { x: 1, c: 1, b: 1, B: 1, "?": 1, h: 2, H: 2, i: 4, I: 4, l: 4, L: 4, q: 8, Q: 8, n: 8, N: 8, e: 2, f: 4, d: 8, s: 1, p: 1 };
const NATIVE = { ...STD, l: 8, L: 8 };


// The format's items: each code, how many, its size and its offset.
function parse(fmt) {
    let i = 0, little = true, native = true;
    if ("<>!=@".includes(fmt[0])) {
        native = fmt[0] === "@";
        little = fmt[0] === "<" || fmt[0] === "=" || fmt[0] === "@";
        i = 1;
    }
    const sizes = native ? NATIVE : STD;
    const items = [];
    let off = 0;
    while (i < fmt.length) {
        if (fmt[i] === " ") { i++; continue; }
        let count = "";
        while (i < fmt.length && fmt[i] >= "0" && fmt[i] <= "9") count += fmt[i++];
        const code = fmt[i++];
        if (!(code in sizes)) throw exc(TypeError, "bad char in struct format");
        const n = count === "" ? 1 : parseInt(count, 10), size = sizes[code];
        if (native && size > 1) off = Math.ceil(off / size) * size;
        items.push({ code, n, size, off });
        off += code === "s" || code === "p" ? n : size * n;
    }
    return { items, little, size: off };
}

export function calcsize(fmt) { return parse(fmt).size; }

function range(code, size, v) {
    const bits = BigInt(size * 8);
    const signed = code === code.toLowerCase() && code !== "?";
    const lo = signed ? -(1n << (bits - 1n)) : 0n, hi = signed ? (1n << (bits - 1n)) - 1n : (1n << bits) - 1n;
    const b = BigInt(v);
    if (b < lo || b > hi) throw exc(OverflowError, "'" + code + "' format requires " + lo + " <= number <= " + hi);
    return b;
}

export function pack(fmt, values) {
    const { items, little, size } = parse(fmt);
    const view = new DataView(new ArrayBuffer(size));
    let k = 0;
    for (const { code, n, size: sz, off } of items) {
        if (code === "x") continue;
        if (code === "s" || code === "p") { const b = bytes(values[k++]); for (let j = 0; j < n && j < b.length; j++) view.setUint8(off + j, b[j]); continue; }
        for (let j = 0; j < n; j++) {
            const at = off + j * sz, v = values[k++];
            if (code === "f") view.setFloat32(at, v, little);
            else if (code === "d") view.setFloat64(at, v, little);
            else if (code === "e") throw exc(TypeError, "struct: format 'e' on a JS host");
            else if (code === "c") view.setUint8(at, bytes(v)[0]);
            else if (code === "?") view.setUint8(at, v ? 1 : 0);
            else {
                const b = range(code, sz, v), u = BigInt.asUintN(sz * 8, b);
                for (let m = 0; m < sz; m++) view.setUint8(at + (little ? m : sz - 1 - m), Number((u >> BigInt(8 * m)) & 255n));
            }
        }
    }
    return Bytes.from(new Uint8Array(view.buffer));
}

export function unpack(fmt, buffer) {
    const { items, little, size } = parse(fmt);
    const data = bytes(buffer);
    if (data.length !== size) throw exc(TypeError, "unpack requires a buffer of " + size + " bytes");
    const view = new DataView(Uint8Array.from(data).buffer);
    const out = [];
    for (const { code, n, size: sz, off } of items) {
        if (code === "x") continue;
        if (code === "s" || code === "p") { out.push(Bytes.from(data.slice(off, off + n))); continue; }
        for (let j = 0; j < n; j++) {
            const at = off + j * sz;
            if (code === "f") out.push(view.getFloat32(at, little));
            else if (code === "d") out.push(view.getFloat64(at, little));
            else if (code === "c") out.push(Bytes.from([view.getUint8(at)]));
            else if (code === "?") out.push(view.getUint8(at) !== 0);
            else {
                let u = 0n;
                for (let m = 0; m < sz; m++) u |= BigInt(view.getUint8(at + (little ? m : sz - 1 - m))) << BigInt(8 * m);
                const v = code === code.toLowerCase() ? BigInt.asIntN(sz * 8, u) : u;
                if (v > BigInt(Number.MAX_SAFE_INTEGER) || v < -BigInt(Number.MAX_SAFE_INTEGER)) throw exc(OverflowError, "integer overflow");
                out.push(Number(v));
            }
        }
    }
    return Tuple.from(out);
}
