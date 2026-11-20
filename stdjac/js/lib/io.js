// Python's io module on a JS host (rt/stdlib/io.jac's names): text and
// bytes held in memory. A compiled module imports it as it uses it.
import { Obj, Bytes, exc, ValueError, bytes } from "../core.js";

function closed(f) { if (f.closed) throw exc(ValueError, "I/O operation on closed file."); }

// Text held in memory, read and written at a position.
export class StringIO extends Obj {
    static $name = "StringIO";
    constructor() { super(); this.buf = ""; this.pos = 0; this.closed = false; }
    init(initial_value = "") { this.buf = initial_value; }
    // (As the runtime makes it, by its parameter's name.)
    set initial_value(v) { this.buf = v === undefined ? "" : v; }
    readable() { closed(this); return true; }
    writable() { closed(this); return true; }
    seekable() { closed(this); return true; }
    write(s) {
        closed(this);
        this.buf = this.buf.slice(0, this.pos) + s + this.buf.slice(this.pos + s.length);
        this.pos += s.length;
        return s.length;
    }
    read(size = -1) {
        closed(this);
        const end = size < 0 ? this.buf.length : Math.min(this.buf.length, this.pos + size);
        const out = this.buf.slice(this.pos, end);
        this.pos = end;
        return out;
    }
    readline(size = -1) {
        closed(this);
        let end = this.buf.indexOf("\n", this.pos);
        end = end < 0 ? this.buf.length : end + 1;
        if (size >= 0) end = Math.min(end, this.pos + size);
        const out = this.buf.slice(this.pos, end);
        this.pos = end;
        return out;
    }
    getvalue() { closed(this); return this.buf; }
    tell() { closed(this); return this.pos; }
    seek(pos, whence = 0) { closed(this); this.pos = whence === 0 ? pos : whence === 1 ? this.pos + pos : this.buf.length + pos; return this.pos; }
    flush() {}
    close() { this.closed = true; }
    __enter__() { return this; }
    __exit__() { this.close(); return false; }
}

// Bytes held in memory, read and written at a position.
export class BytesIO extends Obj {
    static $name = "BytesIO";
    constructor() { super(); this.buf = []; this.pos = 0; this.closed = false; }
    init(initial_bytes = new Bytes(0)) { this.buf = Array.from(initial_bytes); }
    set initial_bytes(v) { this.buf = v === undefined ? [] : Array.from(v); }
    readable() { closed(this); return true; }
    writable() { closed(this); return true; }
    seekable() { closed(this); return true; }
    write(b) { closed(this); const xs = Array.from(bytes(b)); this.buf.splice(this.pos, xs.length, ...xs); this.pos += xs.length; return xs.length; }
    read(size = -1) { closed(this); const end = size < 0 ? this.buf.length : Math.min(this.buf.length, this.pos + size); const out = Bytes.from(this.buf.slice(this.pos, end)); this.pos = end; return out; }
    read1(size = -1) { return this.read(size); }
    getvalue() { closed(this); return Bytes.from(this.buf); }
    tell() { closed(this); return this.pos; }
    seek(pos, whence = 0) { closed(this); this.pos = whence === 0 ? pos : whence === 1 ? this.pos + pos : this.buf.length + pos; return this.pos; }
    flush() {}
    close() { this.closed = true; }
    __enter__() { return this; }
    __exit__() { this.close(); return false; }
}
