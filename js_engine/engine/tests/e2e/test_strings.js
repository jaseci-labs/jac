// String method tests — js_engine engine
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── 1: length ─────────────────────────────────────────────────────────────
check(1, "length of 'hello' === 5", "hello".length, 5);

// ── 2: length of empty string ─────────────────────────────────────────────
check(2, "length of '' === 0", "".length, 0);

// ── 3: charAt ─────────────────────────────────────────────────────────────
check(3, "'hello'.charAt(1) === 'e'", "hello".charAt(1), "e");

// ── 4: charCodeAt ─────────────────────────────────────────────────────────
check(4, "'A'.charCodeAt(0) === 65", "A".charCodeAt(0), 65);

// ── 5: at (negative index) ────────────────────────────────────────────────
check(5, "'hello'.at(-1) === 'o'", "hello".at(-1), "o");

// ── 6: indexOf ────────────────────────────────────────────────────────────
check(6, "'hello world'.indexOf('world') === 6", "hello world".indexOf("world"), 6);

// ── 7: indexOf not found ──────────────────────────────────────────────────
check(7, "'hello'.indexOf('xyz') === -1", "hello".indexOf("xyz"), -1);

// ── 8: lastIndexOf ────────────────────────────────────────────────────────
check(8, "'abcabc'.lastIndexOf('b') === 4", "abcabc".lastIndexOf("b"), 4);

// ── 9: includes ───────────────────────────────────────────────────────────
check(9, "'hello world'.includes('world') === true", "hello world".includes("world"), true);

// ── 10: includes false ────────────────────────────────────────────────────
check(10, "'hello'.includes('xyz') === false", "hello".includes("xyz"), false);

// ── 11: startsWith ────────────────────────────────────────────────────────
check(11, "'hello'.startsWith('hel') === true", "hello".startsWith("hel"), true);

// ── 12: endsWith ──────────────────────────────────────────────────────────
check(12, "'hello'.endsWith('llo') === true", "hello".endsWith("llo"), true);

// ── 13: slice ─────────────────────────────────────────────────────────────
check(13, "'hello world'.slice(6,11) === 'world'", "hello world".slice(6, 11), "world");

// ── 14: slice negative ────────────────────────────────────────────────────
check(14, "'hello world'.slice(-5) === 'world'", "hello world".slice(-5), "world");

// ── 15: substring ─────────────────────────────────────────────────────────
check(15, "'hello world'.substring(0,5) === 'hello'", "hello world".substring(0, 5), "hello");

// ── 16: toUpperCase ───────────────────────────────────────────────────────
check(16, "'hello'.toUpperCase() === 'HELLO'", "hello".toUpperCase(), "HELLO");

// ── 17: toLowerCase ───────────────────────────────────────────────────────
check(17, "'HELLO'.toLowerCase() === 'hello'", "HELLO".toLowerCase(), "hello");

// ── 18: trim ──────────────────────────────────────────────────────────────
check(18, "'  hi  '.trim() === 'hi'", "  hi  ".trim(), "hi");

// ── 19: trimStart ─────────────────────────────────────────────────────────
check(19, "'  hi'.trimStart() === 'hi'", "  hi".trimStart(), "hi");

// ── 20: trimEnd ───────────────────────────────────────────────────────────
check(20, "'hi  '.trimEnd() === 'hi'", "hi  ".trimEnd(), "hi");

// ── 21: split ─────────────────────────────────────────────────────────────
var parts = "a,b,c".split(",");
check(21, "'a,b,c'.split(',')[1] === 'b'", parts[1], "b");

// ── 22: split length ──────────────────────────────────────────────────────
check(22, "'a,b,c'.split(',').length === 3", "a,b,c".split(",").length, 3);

// ── 23: replace ───────────────────────────────────────────────────────────
check(23, "'hello world'.replace('world','JS') === 'hello JS'", "hello world".replace("world", "JS"), "hello JS");

// ── 24: replaceAll ────────────────────────────────────────────────────────
check(24, "'aababc'.replaceAll('a','x') === 'xxbxbc'", "aababc".replaceAll("a", "x"), "xxbxbc");

// ── 25: padStart ──────────────────────────────────────────────────────────
check(25, "'5'.padStart(3,'0') === '005'", "5".padStart(3, "0"), "005");

// ── 26: padEnd ────────────────────────────────────────────────────────────
check(26, "'5'.padEnd(3,'0') === '500'", "5".padEnd(3, "0"), "500");

// ── 27: repeat ────────────────────────────────────────────────────────────
check(27, "'ab'.repeat(3) === 'ababab'", "ab".repeat(3), "ababab");

// ── 28: concat ────────────────────────────────────────────────────────────
check(28, "'foo'.concat('bar') === 'foobar'", "foo".concat("bar"), "foobar");

// ── 29: toString ──────────────────────────────────────────────────────────
check(29, "'hello'.toString() === 'hello'", "hello".toString(), "hello");

// ── 30: codePointAt ───────────────────────────────────────────────────────
check(30, "'A'.codePointAt(0) === 65", "A".codePointAt(0), 65);

// ── Summary ───────────────────────────────────────────────────────────────
console.log("\n=== String tests: " + _passed + " passed, " + _failed + " failed ===");
