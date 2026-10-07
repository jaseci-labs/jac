// Phase 5.9 — string_decoder tests
var assert = require("assert");
var StringDecoder = require("string_decoder").StringDecoder;
var Buffer = require("buffer").Buffer;

var passed = 0;
var failed = 0;

function test(name, fn) {
    try {
        fn();
        passed++;
    } catch (e) {
        failed++;
        console.log("FAIL: " + name + " — " + e.message);
    }
}

// ── Basic construction ──────────────────────────────────────────────────────

test("StringDecoder exists", function() {
    assert(typeof StringDecoder === "function", "StringDecoder is a function");
});

test("StringDecoder default encoding is utf8", function() {
    var d = new StringDecoder();
    assert(d.encoding === "utf8", "default encoding");
});

test("StringDecoder accepts encoding arg", function() {
    var d = new StringDecoder("ascii");
    assert(d.encoding === "ascii", "ascii encoding");
});

test("StringDecoder normalizes encoding names", function() {
    var d1 = new StringDecoder("UTF-8");
    assert(d1.encoding === "utf8", "UTF-8 → utf8");
    var d2 = new StringDecoder("Latin1");
    assert(d2.encoding === "latin1", "Latin1 → latin1");
    var d3 = new StringDecoder("BINARY");
    assert(d3.encoding === "latin1", "BINARY → latin1");
});

// ── ASCII / Latin1 (single-byte, no buffering) ─────────────────────────────

test("write ASCII buffer", function() {
    var d = new StringDecoder("ascii");
    var buf = Buffer.from("hello", "ascii");
    assert(d.write(buf) === "hello", "ascii decode");
});

test("write latin1 buffer", function() {
    var d = new StringDecoder("latin1");
    var buf = Buffer.from([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
    assert(d.write(buf) === "Hello", "latin1 decode");
});

// ── UTF-8 complete characters ───────────────────────────────────────────────

test("write complete ASCII via utf8", function() {
    var d = new StringDecoder("utf8");
    var buf = Buffer.from("abc");
    assert(d.write(buf) === "abc", "complete ASCII");
});

test("write complete 2-byte UTF-8 char", function() {
    var d = new StringDecoder("utf8");
    // é = U+00E9 = 0xC3 0xA9
    var buf = Buffer.from([0xC3, 0xA9]);
    assert(d.write(buf) === "\u00e9", "2-byte char");
});

test("write complete 3-byte UTF-8 char", function() {
    var d = new StringDecoder("utf8");
    // € = U+20AC = 0xE2 0x82 0xAC
    var buf = Buffer.from([0xE2, 0x82, 0xAC]);
    assert(d.write(buf) === "\u20ac", "3-byte char (€)");
});

test("write complete 4-byte UTF-8 char (emoji)", function() {
    var d = new StringDecoder("utf8");
    // 😀 = U+1F600 = 0xF0 0x9F 0x98 0x80
    var buf = Buffer.from([0xF0, 0x9F, 0x98, 0x80]);
    var result = d.write(buf);
    // Engine may represent as 1 char (single code point) or 2 (surrogate pair)
    assert(result.length >= 1, "decoded non-empty");
});

// ── UTF-8 split across writes (the key feature) ────────────────────────────

test("2-byte char split across two writes", function() {
    var d = new StringDecoder("utf8");
    // é = 0xC3 0xA9
    var r1 = d.write(Buffer.from([0xC3]));
    assert(r1 === "", "first write returns empty (incomplete)");
    var r2 = d.write(Buffer.from([0xA9]));
    assert(r2 === "\u00e9", "second write completes the char");
});

test("3-byte char split across two writes", function() {
    var d = new StringDecoder("utf8");
    // € = 0xE2 0x82 0xAC
    var r1 = d.write(Buffer.from([0xE2, 0x82]));
    assert(r1 === "", "first write returns empty");
    var r2 = d.write(Buffer.from([0xAC]));
    assert(r2 === "\u20ac", "second write completes €");
});

test("3-byte char split across three writes", function() {
    var d = new StringDecoder("utf8");
    // € = 0xE2 0x82 0xAC
    assert(d.write(Buffer.from([0xE2])) === "", "byte 1");
    assert(d.write(Buffer.from([0x82])) === "", "byte 2");
    assert(d.write(Buffer.from([0xAC])) === "\u20ac", "byte 3 completes");
});

test("4-byte char split in middle", function() {
    var d = new StringDecoder("utf8");
    // 😀 = 0xF0 0x9F 0x98 0x80
    var r1 = d.write(Buffer.from([0xF0, 0x9F]));
    assert(r1 === "", "first 2 bytes -> empty");
    var r2 = d.write(Buffer.from([0x98, 0x80]));
    // Engine may represent as 1 char (single code point) or 2 (surrogate pair)
    assert(r2.length >= 1, "second write decodes emoji");
});

test("mixed ASCII + split multi-byte", function() {
    var d = new StringDecoder("utf8");
    // "a" + first byte of é
    var r1 = d.write(Buffer.from([0x61, 0xC3]));
    assert(r1 === "a", "ASCII char returned, multi-byte buffered");
    var r2 = d.write(Buffer.from([0xA9, 0x62]));
    assert(r2 === "\u00e9b", "completed char + following ASCII");
});

// ── end() flushes remaining bytes ───────────────────────────────────────────

test("end() with no leftover returns empty", function() {
    var d = new StringDecoder("utf8");
    d.write(Buffer.from("hello"));
    assert(d.end() === "", "no leftover");
});

test("end() flushes incomplete UTF-8 as replacement chars", function() {
    var d = new StringDecoder("utf8");
    d.write(Buffer.from([0xE2, 0x82]));  // 2 of 3 bytes for €
    var flushed = d.end();
    // Node.js emits replacement chars for incomplete sequences
    assert(flushed.length > 0, "flushed something");
});

test("end(buffer) writes buffer then flushes", function() {
    var d = new StringDecoder("utf8");
    d.write(Buffer.from([0xC3]));  // first byte of é
    var result = d.end(Buffer.from([0xA9]));  // second byte → completes
    assert(result === "\u00e9", "end completes the char");
});

// ── Hex encoding ────────────────────────────────────────────────────────────

test("hex encoding decode", function() {
    var d = new StringDecoder("hex");
    var buf = Buffer.from([0xDE, 0xAD, 0xBE, 0xEF]);
    assert(d.write(buf) === "deadbeef", "hex output");
});

// ── UTF-16LE encoding ───────────────────────────────────────────────────────

test("utf16le complete pair", function() {
    var d = new StringDecoder("utf16le");
    // "A" in UTF-16LE = 0x41 0x00
    var buf = Buffer.from([0x41, 0x00, 0x42, 0x00]);
    assert(d.write(buf) === "AB", "utf16le AB");
});

test("utf16le split across writes (odd byte)", function() {
    var d = new StringDecoder("utf16le");
    // "A" = 0x41 0x00    "B" = 0x42 0x00
    var r1 = d.write(Buffer.from([0x41]));
    assert(r1 === "", "odd byte → empty");
    var r2 = d.write(Buffer.from([0x00, 0x42, 0x00]));
    assert(r2 === "AB", "pair completed");
});

// ── Base64 encoding ─────────────────────────────────────────────────────────

test("base64 encoding complete triple", function() {
    var d = new StringDecoder("base64");
    // "Man" → TWFu
    var buf = Buffer.from([0x4D, 0x61, 0x6E]);
    assert(d.write(buf) === "TWFu", "base64 triple");
});

test("base64 encoding partial (2 bytes)", function() {
    var d = new StringDecoder("base64");
    var buf = Buffer.from([0x4D, 0x61]);
    var r1 = d.write(buf);
    assert(r1 === "", "2 bytes buffered");
    var r2 = d.end();
    assert(r2 === "TWE=", "flushed with padding");
});

// ── Edge cases ──────────────────────────────────────────────────────────────

test("write empty buffer returns empty string", function() {
    var d = new StringDecoder("utf8");
    assert(d.write(Buffer.alloc(0)) === "", "empty buffer");
});

test("write null returns empty string", function() {
    var d = new StringDecoder("utf8");
    assert(d.write(null) === "", "null input");
});

test("write undefined returns empty string", function() {
    var d = new StringDecoder("utf8");
    assert(d.write(undefined) === "", "undefined input");
});

test("write string passthrough", function() {
    var d = new StringDecoder("utf8");
    assert(d.write("hello") === "hello", "string passthrough");
});

test("multiple complete writes", function() {
    var d = new StringDecoder("utf8");
    var r1 = d.write(Buffer.from("hello "));
    var r2 = d.write(Buffer.from("world"));
    assert(r1 === "hello ", "first write");
    assert(r2 === "world", "second write");
});

test("require with node: prefix", function() {
    var sd2 = require("node:string_decoder");
    assert(typeof sd2.StringDecoder === "function", "node:string_decoder works");
});

console.log("\n=== string_decoder tests: " + passed + " passed, " + failed + " failed ===");
