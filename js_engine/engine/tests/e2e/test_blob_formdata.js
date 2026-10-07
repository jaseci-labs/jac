// test_blob_formdata.js — Phase 6.14A: Blob, FormData, Response.formData()
// Tests Blob constructor/methods, FormData API, Response.formData() parsing

var passed = 0;
var failed = 0;

function assert(cond, msg) {
    if (cond) { passed++; console.log("  PASS: " + msg); }
    else { failed++; console.log("  FAIL: " + msg); }
}
function assertEq(a, b, msg) {
    if (a === b) { passed++; console.log("  PASS: " + msg); }
    else { failed++; console.log("  FAIL: " + msg + " — got " + String(a) + ", expected " + String(b)); }
}

// ── 1. Blob constructor ─────────────────────────────────────────────────────
var b1 = new Blob(["hello"], { type: "text/plain" });
assertEq(b1.size, 5,           "1. Blob size");
assertEq(b1.type, "text/plain", "2. Blob type");

var b2 = new Blob(["hello", " world"]);
assertEq(b2.size, 11, "3. Blob concat parts");

var b3 = new Blob();
assertEq(b3.size, 0, "4. Blob empty");
assertEq(b3.type, "", "5. Blob type empty");

// ── 2. Blob.text() ──────────────────────────────────────────────────────────
var p1 = b1.text().then(function(t) {
    assertEq(t, "hello", "6. Blob.text()");
});

// ── 3. Blob.arrayBuffer() ───────────────────────────────────────────────────
var p2 = b1.arrayBuffer().then(function(ab) {
    assert(ab instanceof ArrayBuffer,        "7. Blob.arrayBuffer() instanceof ArrayBuffer");
    assertEq(ab.byteLength, 5,               "8. Blob.arrayBuffer() byteLength");
    var u8 = new Uint8Array(ab);
    assertEq(u8[0], 104,                     "9. Blob.arrayBuffer() first byte h=104");
});

// ── 4. Blob.bytes() ─────────────────────────────────────────────────────────
var p3 = b1.bytes().then(function(u8) {
    assert(u8 instanceof Uint8Array,         "10. Blob.bytes() instanceof Uint8Array");
    assertEq(u8.length, 5,                   "11. Blob.bytes() length");
});

// ── 5. Blob.slice() ─────────────────────────────────────────────────────────
var b4 = new Blob(["hello world"]);
var b5 = b4.slice(6, 11, "text/plain");
assertEq(b5.size, 5,           "12. Blob.slice() size");
assertEq(b5.type, "text/plain","13. Blob.slice() type");
var p4 = b5.text().then(function(t) {
    assertEq(t, "world", "14. Blob.slice() content");
});

// ── 6. Blob.stream() ────────────────────────────────────────────────────────
var b6 = new Blob(["abc"]);
var rs = b6.stream();
assert(rs instanceof ReadableStream, "15. Blob.stream() returns ReadableStream");
var p5 = rs.getReader().read().then(function(chunk) {
    assertEq(chunk.value, "abc", "16. Blob.stream() first chunk");
});

// ── 7. Blob from Blob part ───────────────────────────────────────────────────
var b7 = new Blob([b1, " there"]);
assertEq(b7.size, 11,          "17. Blob from Blob+string parts");
var p6 = b7.text().then(function(t) {
    assertEq(t, "hello there", "18. Blob from Blob+string content");
});

// ── 8. Response.blob() returns real Blob ────────────────────────────────────
var fakeServer = "data:text/html;base64,aGVsbG8=";  // "hello" in base64
// Use Response constructor directly
var r1 = new Response("data", { headers: { "content-type": "application/octet-stream" } });
var p7 = r1.blob().then(function(bl) {
    assert(bl instanceof Blob,                 "19. Response.blob() returns Blob instance");
    assertEq(bl.size, 4,                       "20. Response.blob() size");
    assertEq(bl.type, "application/octet-stream", "21. Response.blob() type from header");
    return bl.text();
}).then(function(t) {
    assertEq(t, "data",                        "22. Response.blob().text() content");
});

// ── 9. FormData basic API ────────────────────────────────────────────────────
var fd1 = new FormData();
fd1.append("name", "Alice");
fd1.append("age", "30");
assertEq(fd1.get("name"), "Alice",  "23. FormData.get()");
assertEq(fd1.get("age"),  "30",     "24. FormData.get() second field");
assert(fd1.has("name"),             "25. FormData.has() true");
assert(!fd1.has("missing"),         "26. FormData.has() false");

fd1.append("name", "Bob");
var all = fd1.getAll("name");
assertEq(all.length, 2,            "27. FormData.getAll() count");
assertEq(all[0], "Alice",          "28. FormData.getAll() first");
assertEq(all[1], "Bob",            "29. FormData.getAll() second");

// ── 10. FormData.set() ───────────────────────────────────────────────────────
fd1.set("name", "Charlie");
assertEq(fd1.getAll("name").length, 1, "30. FormData.set() replaces all");
assertEq(fd1.get("name"), "Charlie",   "31. FormData.set() new value");

// ── 11. FormData.delete() ────────────────────────────────────────────────────
fd1.delete("age");
assert(!fd1.has("age"),                "32. FormData.delete() removes field");

// ── 12. FormData.forEach() ───────────────────────────────────────────────────
var fd2 = new FormData();
fd2.append("a", "1");
fd2.append("b", "2");
var fkeys = [];
var fvals = [];
fd2.forEach(function(val, key) { fkeys.push(key); fvals.push(val); });
assertEq(fkeys.join(","), "a,b",   "33. FormData.forEach() keys");
assertEq(fvals.join(","), "1,2",   "34. FormData.forEach() values");

// ── 13. FormData.entries/keys/values iterators ───────────────────────────────
var fd3 = new FormData();
fd3.append("x", "10");
fd3.append("y", "20");
var eArr = [];
for (var kv of fd3.entries()) { eArr.push(kv[0] + "=" + kv[1]); }
assertEq(eArr.join(","), "x=10,y=20", "35. FormData.entries() iterator");

var kArr = [];
for (var k of fd3.keys()) { kArr.push(k); }
assertEq(kArr.join(","), "x,y",       "36. FormData.keys() iterator");

var vArr = [];
for (var v of fd3.values()) { vArr.push(v); }
assertEq(vArr.join(","), "10,20",     "37. FormData.values() iterator");

// ── 14. FormData Symbol.iterator ─────────────────────────────────────────────
var fd4 = new FormData();
fd4.append("p", "q");
var pairs = [];
for (var pair of fd4) { pairs.push(pair[0] + ":" + pair[1]); }
assertEq(pairs.join(","), "p:q",     "38. FormData[Symbol.iterator]");

// ── 15. Response.formData() — urlencoded ────────────────────────────────────
var r2 = new Response("foo=bar&baz=qux", {
    headers: { "content-type": "application/x-www-form-urlencoded" }
});
var p8 = r2.formData().then(function(fd) {
    assert(fd instanceof FormData,          "39. Response.formData() returns FormData");
    assertEq(fd.get("foo"), "bar",          "40. formData urlencoded get foo");
    assertEq(fd.get("baz"), "qux",          "41. formData urlencoded get baz");
});

// ── 16. Response.formData() — percent-encoded ────────────────────────────────
var r3 = new Response("q=hello+world&n=42", {
    headers: { "content-type": "application/x-www-form-urlencoded" }
});
var p9 = r3.formData().then(function(fd) {
    assertEq(fd.get("q"), "hello world",   "42. formData urlencoded plus-space decode");
    assertEq(fd.get("n"), "42",            "43. formData urlencoded number field");
});

// ── 17. Response.formData() — multipart ──────────────────────────────────────
var mp = "--boundary123\r\n" +
         "Content-Disposition: form-data; name=\"field1\"\r\n\r\n" +
         "value1\r\n" +
         "--boundary123\r\n" +
         "Content-Disposition: form-data; name=\"field2\"\r\n\r\n" +
         "value2\r\n" +
         "--boundary123--\r\n";
var r4 = new Response(mp, {
    headers: { "content-type": "multipart/form-data; boundary=boundary123" }
});
var p10 = r4.formData().then(function(fd) {
    assert(fd instanceof FormData,          "44. Response.formData() multipart returns FormData");
    assertEq(fd.get("field1"), "value1",   "45. multipart field1");
    assertEq(fd.get("field2"), "value2",   "46. multipart field2");
});

// ── 18. FormData with Blob value ─────────────────────────────────────────────
var fd5 = new FormData();
var blobPart = new Blob(["filecontents"], { type: "text/plain" });
fd5.append("file", blobPart, "test.txt");
assert(fd5.get("file") instanceof Blob,    "47. FormData Blob value instanceof Blob");
assertEq(fd5.get("file").size, 12,         "48. FormData Blob value size");

// ── 19. Blob type normalisation ───────────────────────────────────────────────
// Use \x80 (128) which is > 0x7E: our charCode loop will catch it.
// (Null byte \x00 is C null-terminator and gets lost in native strings.)
var bInvalid = new Blob(["x"], { type: "text\x80plain" });
assertEq(bInvalid.type, "",                "49. Blob type cleared for non-ASCII byte in type");

// ── 20. Default fetch timeout property ───────────────────────────────────────
assert(typeof globalThis.fetchTimeout === "undefined" || typeof globalThis.fetchTimeout === "number",
       "50. fetchTimeout is undefined (not set) or number");

// Wait for all async tests and print summary
Promise.all([p1, p2, p3, p4, p5, p6, p7, p8, p9, p10]).then(function() {
    console.log("=== Tests: " + passed + " passed, " + failed + " failed ===");
});
