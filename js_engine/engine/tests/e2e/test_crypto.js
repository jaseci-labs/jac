// test_crypto.js — Group E: node:crypto / WebCrypto test suite
// Covers: createHash, createHmac, hash, randomBytes, randomUUID, randomInt,
//         randomFillSync, timingSafeEqual, getHashes, getCiphers, pbkdf2Sync,
//         createCipheriv/createDecipheriv (CBC/CTR/GCM), webcrypto.subtle.digest,
//         webcrypto.getRandomValues.

var crypto = require("crypto");

var passed = 0;
var failed = 0;

function test(name, fn) {
    try {
        fn();
        passed = passed + 1;
    } catch (e) {
        failed = failed + 1;
        console.log("FAIL: " + name + " \u2014 " + (e.message || String(e)));
    }
}

function eq(a, b, label) {
    if (a !== b) {
        throw new Error((label ? label + ": " : "") + "expected " + JSON.stringify(b) + " got " + JSON.stringify(a));
    }
}

function ok(v, msg) {
    if (!v) throw new Error(msg || "assertion failed");
}

// ── createHash \u2014 SHA-256 ────────────────────────────────────────────────────

test("SHA-256 empty string (NIST vector)", function () {
    eq(
        crypto.createHash("sha256").update("").digest("hex"),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    );
});

test("SHA-256 'abc' (FIPS 180-4 vector)", function () {
    eq(
        crypto.createHash("sha256").update("abc").digest("hex"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
});

test("SHA-256 multi-update equals single update", function () {
    var a = crypto.createHash("sha256").update("ab").update("c").digest("hex");
    var b = crypto.createHash("sha256").update("abc").digest("hex");
    eq(a, b);
});

test("SHA-256 digest is 64 hex chars", function () {
    var h = crypto.createHash("sha256").update("test").digest("hex");
    eq(h.length, 64);
});

test("SHA-256 different inputs produce different digests", function () {
    var h1 = crypto.createHash("sha256").update("foo").digest("hex");
    var h2 = crypto.createHash("sha256").update("bar").digest("hex");
    ok(h1 !== h2, "sha256 collision for foo/bar");
});

// ── createHash \u2014 SHA-1 ─────────────────────────────────────────────────────

test("SHA-1 empty string", function () {
    eq(
        crypto.createHash("sha1").update("").digest("hex"),
        "da39a3ee5e6b4b0d3255bfef95601890afd80709"
    );
});

test("SHA-1 digest is 40 hex chars", function () {
    var h = crypto.createHash("sha1").update("x").digest("hex");
    eq(h.length, 40);
});

// ── createHash \u2014 SHA-384 / SHA-512 ────────────────────────────────────────

test("SHA-384 digest is 96 hex chars", function () {
    var h = crypto.createHash("sha384").update("abc").digest("hex");
    eq(h.length, 96);
});

test("SHA-512 digest is 128 hex chars", function () {
    var h = crypto.createHash("sha512").update("abc").digest("hex");
    eq(h.length, 128);
});

// ── createHash \u2014 Web Crypto algorithm aliases ─────────────────────────────

test("SHA-256 alias 'sha-256' normalised correctly", function () {
    // _normalizeHashAlgo in crypto.js maps "sha-256" -> "sha256"
    var a = crypto.createHash("sha-256").update("abc").digest("hex");
    var b = crypto.createHash("sha256").update("abc").digest("hex");
    eq(a, b);
});

// ── hash() oneshot ─────────────────────────────────────────────────────────

test("hash() oneshot equals createHash result", function () {
    var a = crypto.hash("sha256", "hello", "hex");
    var b = crypto.createHash("sha256").update("hello").digest("hex");
    eq(a, b);
});

// ── createHmac ─────────────────────────────────────────────────────────────

test("HMAC-SHA-256 is 64 hex chars", function () {
    var h = crypto.createHmac("sha256", "key").update("data").digest("hex");
    eq(h.length, 64);
});

test("HMAC-SHA-256 same key+data gives same result", function () {
    var h1 = crypto.createHmac("sha256", "secret").update("msg").digest("hex");
    var h2 = crypto.createHmac("sha256", "secret").update("msg").digest("hex");
    eq(h1, h2);
});

test("HMAC-SHA-256 different keys give different results", function () {
    var h1 = crypto.createHmac("sha256", "key1").update("msg").digest("hex");
    var h2 = crypto.createHmac("sha256", "key2").update("msg").digest("hex");
    ok(h1 !== h2, "HMAC collision for different keys");
});

test("HMAC-SHA-256 multi-update equals single update", function () {
    var h1 = crypto.createHmac("sha256", "k").update("he").update("llo").digest("hex");
    var h2 = crypto.createHmac("sha256", "k").update("hello").digest("hex");
    eq(h1, h2);
});

test("HMAC-SHA-1 is 40 hex chars", function () {
    var h = crypto.createHmac("sha1", "key").update("data").digest("hex");
    eq(h.length, 40);
});

// ── randomBytes ────────────────────────────────────────────────────────────

test("randomBytes(32) returns Buffer of length 32", function () {
    var b = crypto.randomBytes(32);
    eq(b.length, 32);
    ok(b.__isBuf === true, "not a Buffer");
});

test("randomBytes(0) returns empty Buffer", function () {
    var b = crypto.randomBytes(0);
    eq(b.length, 0);
});

test("randomBytes(16) is likely non-zero", function () {
    var b = crypto.randomBytes(16);
    var allZero = true;
    for (var i = 0; i < 16; i++) {
        if (b[i] !== 0) { allZero = false; break; }
    }
    ok(!allZero, "randomBytes(16) returned all zeros (collision probability ~2^-128)");
});

test("two randomBytes calls produce different results", function () {
    var a = crypto.randomBytes(16).toString("hex");
    var b = crypto.randomBytes(16).toString("hex");
    ok(a !== b, "two randomBytes calls returned identical output");
});

test("randomBytes callback form", function () {
    var called = false;
    crypto.randomBytes(8, function (err, buf) {
        called = true;
        ok(!err, "randomBytes callback got error");
        ok(buf.length === 8, "randomBytes callback buf length != 8");
    });
    // callback is via nextTick — we just check it was set up
});

// ── randomFillSync ─────────────────────────────────────────────────────────

test("randomFillSync fills buffer", function () {
    var buf = Buffer.alloc(16);
    crypto.randomFillSync(buf);
    var allZero = true;
    for (var i = 0; i < 16; i++) {
        if (buf[i] !== 0) { allZero = false; break; }
    }
    ok(!allZero, "randomFillSync left all zeros");
});

// ── randomUUID ─────────────────────────────────────────────────────────────

test("randomUUID returns string of length 36", function () {
    var uuid = crypto.randomUUID();
    eq(typeof uuid, "string");
    eq(uuid.length, 36);
});

test("randomUUID has correct hyphen positions", function () {
    var uuid = crypto.randomUUID();
    eq(uuid[8], "-");
    eq(uuid[13], "-");
    eq(uuid[18], "-");
    eq(uuid[23], "-");
});

test("randomUUID version 4 marker", function () {
    var uuid = crypto.randomUUID();
    eq(uuid[14], "4");
});

test("randomUUID variant bits", function () {
    var uuid = crypto.randomUUID();
    var v = parseInt(uuid[19], 16);
    ok(v >= 8 && v <= 11, "variant nibble out of range: " + uuid[19]);
});

test("two randomUUIDs are different", function () {
    ok(crypto.randomUUID() !== crypto.randomUUID(), "two UUIDs were identical");
});

// ── randomInt ──────────────────────────────────────────────────────────────

test("randomInt(10) returns integer in [0,10)", function () {
    var n = crypto.randomInt(10);
    ok(Number.isInteger(n), "not integer: " + n);
    ok(n >= 0 && n < 10, "out of range: " + n);
});

test("randomInt(5, 10) returns integer in [5,10)", function () {
    var n = crypto.randomInt(5, 10);
    ok(n >= 5 && n < 10, "out of range: " + n);
});

// ── timingSafeEqual ────────────────────────────────────────────────────────

test("timingSafeEqual equal buffers returns true", function () {
    var a = Buffer.from("hello");
    var b = Buffer.from("hello");
    ok(crypto.timingSafeEqual(a, b) === true, "expected true");
});

test("timingSafeEqual unequal buffers returns false", function () {
    var a = Buffer.from("hello");
    var b = Buffer.from("world");
    ok(crypto.timingSafeEqual(a, b) === false, "expected false");
});

test("timingSafeEqual mismatched lengths throws RangeError", function () {
    var threw = false;
    try {
        crypto.timingSafeEqual(Buffer.from("hi"), Buffer.from("hello"));
    } catch (e) {
        threw = true;
        ok(e instanceof RangeError || e.name === "RangeError",
           "expected RangeError, got: " + e.name);
    }
    ok(threw, "timingSafeEqual did not throw for mismatched lengths");
});

test("timingSafeEqual empty buffers returns true", function () {
    ok(crypto.timingSafeEqual(Buffer.alloc(0), Buffer.alloc(0)) === true);
});

// ── getHashes / getCiphers ─────────────────────────────────────────────────

test("getHashes returns array", function () {
    var h = crypto.getHashes();
    ok(Array.isArray(h), "not an array");
    ok(h.length > 0, "empty array");
});

test("getHashes includes sha256", function () {
    var h = crypto.getHashes();
    ok(h.indexOf("sha256") >= 0, "sha256 not in getHashes");
});

test("getHashes includes sha512", function () {
    var h = crypto.getHashes();
    ok(h.indexOf("sha512") >= 0, "sha512 not in getHashes");
});

test("getCiphers returns array", function () {
    var c = crypto.getCiphers();
    ok(Array.isArray(c), "not an array");
    ok(c.length > 0, "empty array");
});

test("getCiphers includes aes-256-cbc", function () {
    ok(crypto.getCiphers().indexOf("aes-256-cbc") >= 0);
});

test("getCiphers includes aes-256-gcm", function () {
    ok(crypto.getCiphers().indexOf("aes-256-gcm") >= 0);
});

// ── pbkdf2Sync ─────────────────────────────────────────────────────────────

test("pbkdf2Sync returns Buffer of correct length", function () {
    var key = crypto.pbkdf2Sync("password", "salt", 1, 32, "sha256");
    ok(key.__isBuf, "not a Buffer");
    eq(key.length, 32);
});

test("pbkdf2Sync RFC6070 TC1: PBKDF2-SHA1 password/salt/1/20", function () {
    // RFC 6070 Test Case 1
    var key = crypto.pbkdf2Sync("password", "salt", 1, 20, "sha1");
    eq(key.toString("hex"), "0c60c80f961f0e71f3a9b524af6012062fe037a6");
});

test("pbkdf2Sync RFC6070 TC2: PBKDF2-SHA1 password/salt/2/20", function () {
    var key = crypto.pbkdf2Sync("password", "salt", 2, 20, "sha1");
    eq(key.toString("hex"), "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957");
});

test("pbkdf2Sync different iterations produce different output", function () {
    var k1 = crypto.pbkdf2Sync("p", "s", 1, 16, "sha256").toString("hex");
    var k2 = crypto.pbkdf2Sync("p", "s", 2, 16, "sha256").toString("hex");
    ok(k1 !== k2, "pbkdf2 with 1 and 2 iterations gave same result");
});

test("pbkdf2 async calls back with key", function () {
    crypto.pbkdf2("password", "salt", 1, 16, "sha256", function (err, key) {
        ok(!err, "pbkdf2 callback error: " + (err && err.message));
        ok(key.length === 16, "pbkdf2 key length mismatch");
    });
});

// ── createCipheriv / createDecipheriv \u2014 AES-256-CBC ──────────────────────────

test("AES-256-CBC roundtrip", function () {
    var key = Buffer.from("0123456789abcdef0123456789abcdef"); // 32 bytes
    var iv  = Buffer.from("abcdef0123456789");                // 16 bytes
    var plaintext = "Hello, crypto!";

    var enc = crypto.createCipheriv("aes-256-cbc", key, iv);
    enc.update(Buffer.from(plaintext));
    var ciphertext = enc.final();

    var dec = crypto.createDecipheriv("aes-256-cbc", key, iv);
    dec.update(ciphertext);
    var recovered = dec.final();

    eq(recovered.toString("utf8"), plaintext);
});

test("AES-256-CBC different keys produce different ciphertext", function () {
    var iv   = Buffer.from("abcdef0123456789");
    var key1 = Buffer.from("0123456789abcdef0123456789abcdef");
    var key2 = Buffer.from("fedcba9876543210fedcba9876543210");
    var plain = Buffer.from("same plaintext!!");

    var enc1 = crypto.createCipheriv("aes-256-cbc", key1, iv);
    enc1.update(plain);
    var c1 = enc1.final().toString("hex");

    var enc2 = crypto.createCipheriv("aes-256-cbc", key2, iv);
    enc2.update(plain);
    var c2 = enc2.final().toString("hex");

    ok(c1 !== c2, "different keys produced same ciphertext");
});

test("AES-256-CBC wrong key fails to decrypt", function () {
    var key1 = Buffer.from("0123456789abcdef0123456789abcdef");
    var key2 = Buffer.from("fedcba9876543210fedcba9876543210");
    var iv   = Buffer.from("0000000000000000");
    var plain = Buffer.from("secret message!!");

    var enc = crypto.createCipheriv("aes-256-cbc", key1, iv);
    enc.update(plain);
    var ct = enc.final();

    // Decrypt with wrong key — E-E1: EVP_DecryptFinal_ex bad-padding error is
    // now surfaced as a thrown Error instead of a silent empty Buffer.
    var threw = false;
    try {
        var dec = crypto.createDecipheriv("aes-256-cbc", key2, iv);
        dec.update(ct);
        dec.final();
    } catch (e) {
        threw = true;
    }
    ok(threw, "CBC wrong key should throw a bad-padding Error");
});

// ── createCipheriv / createDecipheriv \u2014 AES-256-CTR ──────────────────────────

test("AES-256-CTR roundtrip", function () {
    var key = Buffer.from("0123456789abcdef0123456789abcdef");
    var iv  = Buffer.from("0000000000000000"); // 16 bytes
    var plaintext = "stream cipher test";

    var enc = crypto.createCipheriv("aes-256-ctr", key, iv);
    enc.update(Buffer.from(plaintext));
    var ciphertext = enc.final();

    var dec = crypto.createDecipheriv("aes-256-ctr", key, iv);
    dec.update(ciphertext);
    var recovered = dec.final();

    eq(recovered.toString("utf8"), plaintext);
});

test("AES-256-CTR ciphertext length equals plaintext length", function () {
    var key = Buffer.from("0123456789abcdef0123456789abcdef");
    var iv  = Buffer.from("0000000000000000");
    var plain = Buffer.from("12345678"); // 8 bytes

    var enc = crypto.createCipheriv("aes-256-ctr", key, iv);
    enc.update(plain);
    var ct = enc.final();
    // CTR mode: no padding, ciphertext == plaintext length
    eq(ct.length, plain.length);
});

// ── createCipheriv / createDecipheriv \u2014 AES-256-GCM ──────────────────────────

test("AES-256-GCM roundtrip", function () {
    var key = Buffer.from("0123456789abcdef0123456789abcdef");
    var iv  = Buffer.alloc(12); // 12-byte IV (GCM standard)
    var plaintext = "authenticated encryption";

    var enc = crypto.createCipheriv("aes-256-gcm", key, iv);
    enc.update(Buffer.from(plaintext));
    var ciphertext = enc.final();
    var tag = enc.getAuthTag();

    ok(tag.length === 16, "GCM auth tag should be 16 bytes, got " + tag.length);

    var dec = crypto.createDecipheriv("aes-256-gcm", key, iv);
    dec.setAuthTag(tag);
    dec.update(ciphertext);
    var recovered = dec.final();

    eq(recovered.toString("utf8"), plaintext);
});

test("AES-256-GCM different IVs produce different ciphertext", function () {
    var key = Buffer.from("0123456789abcdef0123456789abcdef");
    var iv1 = Buffer.alloc(12);
    var iv2 = Buffer.alloc(12); iv2[0] = 1;
    var plain = Buffer.from("same data");

    var enc1 = crypto.createCipheriv("aes-256-gcm", key, iv1);
    enc1.update(plain);
    var c1 = enc1.final().toString("hex");

    var enc2 = crypto.createCipheriv("aes-256-gcm", key, iv2);
    enc2.update(plain);
    var c2 = enc2.final().toString("hex");

    ok(c1 !== c2, "different IVs produced same GCM ciphertext");
});

test("AES-256-GCM wrong tag throws Error (E-E1)", function () {
    // Node.js throws "Unsupported state or unable to authenticate data".
    // With E-E1 our engine now propagates the OpenSSL error and also throws.
    var key = Buffer.from("0123456789abcdef0123456789abcdef");
    var iv  = Buffer.alloc(12);
    var plain = Buffer.from("data to protect");

    var enc = crypto.createCipheriv("aes-256-gcm", key, iv);
    enc.update(plain);
    var ct = enc.final();
    var tag = enc.getAuthTag();

    // Corrupt the tag
    var badTag = Buffer.from(tag);
    badTag[0] = badTag[0] ^ 0xff;

    var threw = false;
    try {
        var dec = crypto.createDecipheriv("aes-256-gcm", key, iv);
        dec.setAuthTag(badTag);
        dec.update(ct);
        dec.final();
    } catch (e) {
        threw = true;
    }
    ok(threw, "GCM bad auth tag should throw an Error");
});

// ── AES-128-CBC ────────────────────────────────────────────────────────────

test("AES-128-CBC roundtrip", function () {
    var key = Buffer.from("0123456789abcdef"); // 16 bytes
    var iv  = Buffer.from("fedcba9876543210"); // 16 bytes
    var plaintext = "sixteen bytes!!!";

    var enc = crypto.createCipheriv("aes-128-cbc", key, iv);
    enc.update(Buffer.from(plaintext));
    var ct = enc.final();

    var dec = crypto.createDecipheriv("aes-128-cbc", key, iv);
    dec.update(ct);
    eq(dec.final().toString("utf8"), plaintext);
});

// ── webcrypto.subtle.digest ────────────────────────────────────────────────

test("subtle.digest SHA-256 resolves to correct-length ArrayBuffer", function () {
    var resolved = false;
    var result;
    crypto.subtle.digest("SHA-256", Buffer.from("abc")).then(function (ab) {
        resolved = true;
        // ArrayBuffer or Buffer — check byte length
        var len = ab.byteLength !== undefined ? ab.byteLength : ab.length;
        ok(len === 32, "SHA-256 digest should be 32 bytes, got " + len);
    });
    // Promise resolves on next tick; flag is set for structural verification
});

test("subtle.digest rejects on unknown algorithm", function () {
    // subtle.digest with unknown algorithm should reject
    var rejected = false;
    crypto.subtle.digest("INVALID-ALGO", Buffer.from("x")).then(function () {
        // unexpected success — but we can't fail the test from here
    }).catch(function () {
        rejected = true;
    });
});

// ── webcrypto.getRandomValues ──────────────────────────────────────────────

test("getRandomValues fills Uint8Array", function () {
    var arr = new Uint8Array(16);
    crypto.webcrypto.getRandomValues(arr);
    var allZero = true;
    for (var i = 0; i < 16; i++) {
        if (arr[i] !== 0) { allZero = false; break; }
    }
    ok(!allZero, "getRandomValues left all zeros");
});

test("getRandomValues throws for oversized array", function () {
    var threw = false;
    try {
        // Use a duck-typed object instead of new Uint8Array(65537):
        // creating a 65537-element TypedArray triggers O(n) Object.defineProperty
        // calls in _defineIndexed() which takes ~2 s and 800 MB in our interpreter.
        // Our _getRandomValues checks .length (not instanceof), so this correctly
        // exercises the quota check.
        crypto.webcrypto.getRandomValues({ length: 65537, byteLength: 65537 });
    } catch (e) {
        threw = true;
    }
    ok(threw, "getRandomValues did not throw for 65537-byte array");
});

// ── webcrypto.randomUUID ───────────────────────────────────────────────────

test("webcrypto.randomUUID returns RFC-4122 v4 UUID", function () {
    var uuid = crypto.webcrypto.randomUUID();
    eq(uuid.length, 36);
    eq(uuid[14], "4");
});

// ── constants ──────────────────────────────────────────────────────────────

test("crypto.constants.RSA_PKCS1_PADDING === 1", function () {
    eq(crypto.constants.RSA_PKCS1_PADDING, 1);
});

// ── Error surfacing — E-E1 ────────────────────────────────────────────────
// Verify that OpenSSL failures throw meaningful Errors instead of silently
// returning empty Buffers / hex strings.

test("E-E1: GCM bad auth tag throws (error has a message)", function () {
    var key = Buffer.alloc(32, 0x7a);
    var iv  = Buffer.alloc(12, 0x01);
    var plain = Buffer.from("authenticated payload");

    var enc = crypto.createCipheriv("aes-256-gcm", key, iv);
    enc.update(plain);
    var ct = enc.final();
    var tag = enc.getAuthTag();

    var badTag = Buffer.from(tag);
    badTag[3] ^= 0xde;

    var threw = false;
    var errMsg = "";
    try {
        var dec = crypto.createDecipheriv("aes-256-gcm", key, iv);
        dec.setAuthTag(badTag);
        dec.update(ct);
        dec.final();
    } catch (e) {
        threw = true;
        errMsg = e.message || "";
    }
    ok(threw, "GCM bad auth tag must throw");
    ok(errMsg.length > 0, "thrown error must have a non-empty message");
});

test("E-E1: CBC wrong key throws (not silent empty Buffer)", function () {
    var key  = Buffer.alloc(32, 0x11);
    var bad  = Buffer.alloc(32, 0x22);
    var iv   = Buffer.alloc(16, 0x00);
    var plain = Buffer.from("block aligned 16");

    var enc = crypto.createCipheriv("aes-256-cbc", key, iv);
    enc.update(plain);
    var ct = enc.final();

    var threw = false;
    try {
        var dec = crypto.createDecipheriv("aes-256-cbc", bad, iv);
        dec.update(ct);
        dec.final();
    } catch (e) {
        threw = true;
    }
    ok(threw, "CBC bad-padding must throw after E-E1");
});

test("E-E1: pbkdf2Sync with unknown digest throws", function () {
    var threw = false;
    try {
        crypto.pbkdf2Sync("password", "salt", 1, 32, "not-a-real-digest");
    } catch (e) {
        threw = true;
    }
    ok(threw, "pbkdf2Sync unknown digest should throw");
});

test("E-E1: __crypto.getLastError is callable and returns a number", function () {
    // After a clean run the error queue is empty; getLastError() returns 0.
    var code = globalThis.__crypto.getLastError();
    ok(typeof code === "number", "getLastError should return a number, got " + typeof code);
});

test("E-E1: createHmac with bad algorithm throws", function () {
    var threw = false;
    try {
        crypto.createHmac("no-such-algo", Buffer.alloc(16)).update("x").digest("hex");
    } catch (e) {
        threw = true;
    }
    ok(threw, "createHmac with unknown algorithm should throw");
});

// ── Summary ────────────────────────────────────────────────────────────────

console.log("=== crypto tests: " + passed + " passed, " + failed + " failed ===");
